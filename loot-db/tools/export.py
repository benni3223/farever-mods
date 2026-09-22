"""Refresh loot-db/data/database.json from Metaforge's Farever database.

Metaforge does not publish a Farever API. The site is SvelteKit, and each
database page embeds its payload at /__data.json using devalue references.
Re-run this script after the site changes:

    python tools/export.py

The game never contacts Metaforge. It reads the JSON written here.
"""
from __future__ import annotations

import json
import sys
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "data" / "database.json"
ORIGIN = "https://metaforge.app"
LIST_URL = ORIGIN + "/farever/database/{tab}/page/{page}/__data.json"
DETAIL_URL = ORIGIN + "/farever/database/{tab}/{slug}"
CREATURE_URL = ORIGIN + "/farever/database/creatures/{slug}/__data.json"
MAP_URL = ORIGIN + "/farever/map/siagarta/__data.json"
SCALE_TABS = ("weapons", "armor", "jewellery", "tools")
RARITY_RANK = {"Common": 0, "Uncommon": 1, "Rare": 2, "Epic": 3, "Legendary": 4}
MODE_RANK = {"normal": 0, "max": 1, "heroic": 2}
USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"
)
ITEM_TABS = [
    "weapons", "armor", "jewellery", "tools", "materials", "consumables",
    "augments", "recipes", "mounts", "gliders", "skills", "runes", "npcs", "quests",
]
WORKERS = 6


def unflatten(values):
    """Resolve a SvelteKit devalue list. Nested ints are indexes, not numbers."""
    hydrated = []
    for value in values:
        if isinstance(value, list):
            hydrated.append([])
        elif isinstance(value, dict):
            hydrated.append({})
        else:
            hydrated.append(value)
    for index, value in enumerate(values):
        if isinstance(value, list):
            hydrated[index].extend(hydrated[item] for item in value)
        elif isinstance(value, dict):
            for key, item in value.items():
                hydrated[index][key] = hydrated[item]
    return hydrated[0] if hydrated else None


def payloads(document):
    nodes = document.get("nodes") if isinstance(document, dict) else None
    if not isinstance(nodes, list):
        return []
    found = []
    for node in nodes:
        if not isinstance(node, dict):
            continue
        data = node.get("data")
        if isinstance(data, list) and data:
            found.append(unflatten(data))
    return found


def payload_with(document, key):
    for data in payloads(document):
        if isinstance(data, dict) and key in data:
            return data
    return None


def fetch_text(url):
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": "text/html,application/json"})
    delay = 1.0
    last = None
    for _ in range(4):
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                return response.read().decode("utf-8", "replace")
        except urllib.error.HTTPError as error:
            last = error
            if error.code == 404:
                return ""
            if error.code not in (429, 500, 502, 503, 504):
                raise
        except (urllib.error.URLError, TimeoutError) as error:
            last = error
        time.sleep(delay)
        delay *= 2
    raise RuntimeError(f"Failed to fetch {url}: {last}")


def fetch(url):
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": "application/json"})
    delay = 1.0
    last = None
    for _ in range(4):
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            last = error
            if error.code not in (429, 500, 502, 503, 504):
                raise
        except (urllib.error.URLError, TimeoutError) as error:
            last = error
        time.sleep(delay)
        delay *= 2
    raise RuntimeError(f"Failed to fetch {url}: {last}")


def text(value):
    if value is None or isinstance(value, (dict, list)):
        return ""
    return str(value).strip()


def number(value):
    if isinstance(value, bool) or value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    return None


def chance_text(row):
    percent = number(row.get("probability_pct"))
    probability = number(row.get("probability"))
    if percent is None and probability is not None:
        percent = probability * 100 if probability <= 1 else probability
    if percent is None:
        return ""
    return f"{percent:g}%"


def slugify(value):
    cleaned = []
    previous = False
    for char in text(value).lower():
        if char.isalnum():
            cleaned.append(char)
            previous = False
        elif not previous:
            cleaned.append("-")
            previous = True
    return "".join(cleaned).strip("-")


def rarities_of(item):
    found = []
    for variant in item.get("stat_variants") or []:
        if isinstance(variant, dict):
            rarity = text(variant.get("rarity"))
            if rarity and rarity not in found:
                found.append(rarity)
    single = text(item.get("rarity"))
    if single and single not in found:
        found.insert(0, single)
    return found


def stats_of(item):
    found = []
    seen = set()
    for row in item.get("stats_scaled") or []:
        if not isinstance(row, dict):
            continue
        label = text(row.get("label"))
        if label == "" or label in seen:
            continue
        seen.add(label)
        found.append({"label": label, "value": text(row.get("value"))})
    return found


def extract_array(html, key):
    """Slice the first JS array named `key` out of a Metaforge item page."""
    token = key + ":"
    at = html.find(token)
    if at < 0:
        return ""
    start = html.find("[", at)
    if start < 0:
        return ""
    depth = 0
    in_string = False
    escaped = False
    for index in range(start, len(html)):
        char = html[index]
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            continue
        if char == '"':
            in_string = True
            continue
        if char == "[":
            depth += 1
        elif char == "]":
            depth -= 1
            if depth == 0:
                return html[start:index + 1]
    return ""


def quote_js_keys(raw):
    """Turn a JS object literal with bare keys into JSON. Strings stay untouched."""
    out = []
    index = 0
    length = len(raw)
    in_string = False
    escaped = False
    while index < length:
        char = raw[index]
        if in_string:
            out.append(char)
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            index += 1
            continue
        if char == '"':
            in_string = True
            out.append(char)
            index += 1
            continue
        if char.isalpha() or char == "_":
            start = index
            while index < length and (raw[index].isalnum() or raw[index] == "_"):
                index += 1
            word = raw[start:index]
            if index < length and raw[index] == ":":
                out.append('"' + word + '"')
            else:
                out.append(word)
            continue
        out.append(char)
        index += 1
    return "".join(out)


def scale_mode(variant):
    difficulty = text(variant.get("difficulty") or variant.get("mode")).lower()
    if variant.get("is_heroic") is True or difficulty == "heroic":
        return "heroic"
    if variant.get("is_hardcore") is True or difficulty in ("max", "levelmax", "hardcore"):
        return "max"
    return "normal"


def scales_of_html(html):
    raw = extract_array(html, "stat_variants")
    if raw == "":
        return []
    quoted = quote_js_keys(raw).replace(":.", ":0.").replace(",.", ",0.").replace("[.", "[0.")
    try:
        variants = json.loads(quoted)
    except json.JSONDecodeError:
        return []
    found = []
    seen = set()
    for variant in variants if isinstance(variants, list) else []:
        if not isinstance(variant, dict):
            continue
        rarity = text(variant.get("rarity"))
        level = number(variant.get("level"))
        mode = scale_mode(variant)
        tiers = variant.get("upgrade_table") or []
        base = tiers[0] if isinstance(tiers, list) and tiers and isinstance(tiers[0], dict) else {}
        stats = []
        for row in base.get("stats") or []:
            if not isinstance(row, dict):
                continue
            label = text(row.get("label"))
            value = text(row.get("value"))
            if label == "" or value == "":
                continue
            stats.append({"label": label, "value": value})
        if rarity == "" or not stats:
            continue
        key = (mode, rarity, None if level is None else int(level))
        if key in seen:
            continue
        seen.add(key)
        found.append({
            "mode": mode,
            "rarity": rarity,
            "level": None if level is None else int(level),
            "stats": stats,
        })
    # A level ladder with no hardcore row still has a max-level version: the top step.
    if not any(row["mode"] == "max" for row in found):
        levels = {row["level"] for row in found if row["mode"] == "normal" and row["level"] is not None}
        if len(levels) >= 2:
            top = max(levels)
            for row in found:
                if row["mode"] == "normal" and row["level"] == top:
                    row["mode"] = "max"
    found.sort(key=lambda row: (
        MODE_RANK.get(row["mode"], 9),
        row["level"] if row["level"] is not None else 0,
        RARITY_RANK.get(row["rarity"], 9),
    ))
    return found


def load_scales(item):
    slug = text(item.get("slug"))
    tab = text(item.get("category"))
    if slug == "" or tab not in SCALE_TABS:
        return []
    html = fetch_text(DETAIL_URL.format(tab=tab, slug=slug))
    return scales_of_html(html)


def attach_scales(items):
    targets = [item for item in items if text(item.get("category")) in SCALE_TABS]
    print(f"Fetching scaled stats for {len(targets)} items...", flush=True)
    by_slug = {}
    with ThreadPoolExecutor(max_workers=WORKERS) as pool:
        futures = [pool.submit(load_scales, item) for item in targets]
        done = 0
        for future, item in zip_done(futures, targets):
            done += 1
            if done % 40 == 0 or done == len(futures):
                print(f"  scales {done}/{len(futures)}", flush=True)
            try:
                by_slug[item["slug"]] = future.result()
            except Exception as error:
                print(f"  scales failed for {item.get('slug')}: {error}", flush=True)
                by_slug[item["slug"]] = []
    for item in items:
        if item.get("slug") in by_slug:
            item["scales"] = by_slug[item["slug"]]
        elif "scales" not in item:
            item["scales"] = []
    filled = sum(1 for item in items if item.get("scales"))
    print(f"Scaled stats on {filled} items", flush=True)


def zip_done(futures, targets):
    pending = {future: item for future, item in zip(futures, targets)}
    for future in as_completed(pending):
        yield future, pending[future]


def attach_saved_scales():
    database = json.loads(OUTPUT.read_text(encoding="utf-8"))
    items = database.get("items") or []
    attach_scales(items)
    OUTPUT.write_text(json.dumps(database, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"Updated scales in {OUTPUT}", flush=True)


def skills_of(item):
    found = []
    for row in item.get("weapon_skills_summary") or []:
        if not isinstance(row, dict):
            continue
        name = text(row.get("skill_name"))
        if name == "":
            continue
        cooldown = number(row.get("cooldown"))
        found.append({
            "id": text(row.get("skill_id")),
            "name": name,
            "cooldown": None if cooldown is None else cooldown,
        })
    return found


def normalize_item(item, tab):
    if not isinstance(item, dict):
        return None
    name = text(item.get("name"))
    slug = text(item.get("slug")) or slugify(name)
    if name == "" or slug == "":
        return None
    classes = [text(name) for name in (item.get("classes") or []) if text(name)]
    obtain = [text(name) for name in (item.get("obtain_kinds") or []) if text(name)]
    level = number(item.get("level"))
    description = text(item.get("description"))
    recipe = description if tab == "recipes" else ""
    return {
        "id": slug,
        "name": name,
        "slug": slug,
        "category": tab,
        "subcategory": text(item.get("subcategory")),
        "classes": classes,
        "rarity": " / ".join(rarities_of(item)),
        "level": None if level is None else int(level),
        "description": description,
        "obtain": obtain,
        "stats": stats_of(item),
        "scales": [],
        "skills": skills_of(item),
        "recipe": recipe,
    }


def list_tab(tab):
    first = fetch(LIST_URL.format(tab=tab, page=1))
    page = payload_with(first, "items")
    if page is None:
        raise RuntimeError(f"{tab} page 1 has no item list")
    items = [item for item in (page.get("items") or []) if isinstance(item, dict)]
    total_pages = int(number((page.get("pagination") or {}).get("totalPages")) or 1)
    for index in range(2, total_pages + 1):
        document = fetch(LIST_URL.format(tab=tab, page=index))
        nxt = payload_with(document, "items")
        if nxt is None:
            break
        items.extend(item for item in (nxt.get("items") or []) if isinstance(item, dict))
        print(f"  {tab} page {index}/{total_pages}", flush=True)
    print(f"{tab}: {len(items)} rows, {total_pages} page(s)", flush=True)
    return items


def place_name(instance_name):
    raw = text(instance_name)
    if raw == "":
        return ""
    marker = " inside "
    if marker in raw:
        return raw.split(marker, 1)[1].strip()
    if "—" in raw:
        return raw.split("—", 1)[0].strip()
    return raw


def instance_kind(subcategory, instance_name):
    blob = f"{subcategory} {instance_name}".lower()
    if "rift" in blob:
        return "rift"
    if " inside " in text(instance_name):
        return "dungeon"
    if text(subcategory).lower() in ("bosses", "boss"):
        return "world-boss"
    return "location"


def world_point(marker):
    """Metaforge labels game world coordinates as lat/lng. Geographic values are not drawable."""
    if not isinstance(marker, dict):
        return None
    lat = number(marker.get("lat"))
    lng = number(marker.get("lng"))
    if lat is None or lng is None:
        return None
    if abs(lat) <= 180 and abs(lng) <= 180:
        return None
    return {"x": lng, "y": lat}


def flatten_drops(rows, group, found, seen, depth=0):
    if depth > 3 or not isinstance(rows, list):
        return
    for row in rows:
        if not isinstance(row, dict):
            continue
        nested = row.get("nested_items")
        if isinstance(nested, list) and nested:
            flatten_drops(nested, group, found, seen, depth + 1)
            if text(row.get("item_name")) == "":
                continue
        name = text(row.get("item_name"))
        slug = text(row.get("item_slug")) or text(row.get("item_id"))
        if name == "":
            continue
        key = (group, slug or name.lower())
        if key in seen:
            continue
        seen.add(key)
        found.append({
            "name": name,
            "slug": slug,
            "chance": chance_text(row),
            "rarity": text(row.get("item_rarity")),
            "group": group,
        })


def creature_skills(details):
    found = []
    for row in (details or {}).get("skills_used") or []:
        if not isinstance(row, dict):
            continue
        name = text(row.get("skill_name"))
        if name == "":
            continue
        found.append({
            "id": text(row.get("skill_id")),
            "name": name,
            "cooldown": number(row.get("cooldown_seconds")),
            "duration": number(row.get("duration_seconds")),
            "power": text(row.get("primary_damage")),
        })
    return found


def normalize_creature(summary, document):
    page = payload_with(document, "creatureDetails") or payload_with(document, "entry") or {}
    details = page.get("creatureDetails") if isinstance(page.get("creatureDetails"), dict) else {}
    entry = page.get("entry") if isinstance(page.get("entry"), dict) else {}
    source = details or entry or summary or {}
    name = text(source.get("creature_name") or source.get("name") or (summary or {}).get("name"))
    slug = text(source.get("slug") or (summary or {}).get("slug")) or slugify(name)
    if name == "" or slug == "":
        return None
    subcategory = text((summary or {}).get("subcategory") or entry.get("subcategory") or source.get("tier") or source.get("type"))
    level = number(source.get("level") if source.get("level") is not None else (summary or {}).get("level"))
    drops = {"boss": [], "unit": [], "faction": [], "world": []}
    drop_source = source.get("drops") if isinstance(source.get("drops"), dict) else {}
    mapping = {
        "boss": drop_source.get("boss_loot"),
        "unit": drop_source.get("unit_loot"),
        "faction": drop_source.get("faction_loot"),
        "world": [drop_source.get("world_loot"), drop_source.get("shared_tables")],
    }
    for group, rows in mapping.items():
        seen = set()
        if group == "world":
            for part in rows:
                flatten_drops(part, group, drops[group], seen)
        else:
            flatten_drops(rows, group, drops[group], seen)
    markers = page.get("mapMarkers") or []
    if isinstance(markers, dict):
        markers = [markers]
    pins = []
    places = []
    for marker in markers if isinstance(markers, list) else []:
        point = world_point(marker)
        instance_name = text(marker.get("instanceName")) if isinstance(marker, dict) else ""
        place = place_name(instance_name)
        if place:
            places.append(place)
        if point is None:
            continue
        pins.append({
            "x": point["x"],
            "y": point["y"],
            "label": name,
            "place": place,
            "instanceName": instance_name,
            "kind": instance_kind(subcategory, instance_name),
        })
    return {
        "id": slug,
        "name": name,
        "slug": slug,
        "faction": text(source.get("faction") or (summary or {}).get("faction")),
        "subcategory": subcategory,
        "level": None if level is None else int(level),
        "description": text(source.get("description") or (summary or {}).get("description")),
        "skills": creature_skills(source),
        "drops": drops,
        "places": places,
        "pins": pins,
    }


def build_instances(creatures):
    grouped = {}
    for creature in creatures:
        places = creature.get("places") or []
        if not places and creature.get("pins"):
            places = [pin.get("place") or creature["name"] for pin in creature["pins"]]
        boss = text(creature.get("subcategory")).lower() in ("bosses", "boss")
        if not places and boss:
            places = [creature["name"]]
        for place in places:
            if not place:
                continue
            kind = "location"
            for pin in creature.get("pins") or []:
                if pin.get("place") == place:
                    kind = pin.get("kind") or kind
            if boss and kind == "location":
                kind = "world-boss"
            key = slugify(place) or slugify(creature["name"])
            instance = grouped.get(key)
            if instance is None:
                instance = {
                    "id": key,
                    "name": place,
                    "kind": kind,
                    "bosses": [],
                    "names": [place],
                    "pin": None,
                    "drops": [],
                }
                grouped[key] = instance
            if kind == "dungeon" or (kind == "world-boss" and instance["kind"] == "location"):
                instance["kind"] = kind
            if creature["name"] not in instance["names"]:
                instance["names"].append(creature["name"])
            is_boss = boss
            if is_boss and creature["id"] not in instance["bosses"]:
                instance["bosses"].append(creature["id"])
            for pin in creature.get("pins") or []:
                if instance["pin"] is None and pin.get("place") in ("", place):
                    instance["pin"] = {"x": pin["x"], "y": pin["y"]}
            for group in ("boss", "unit"):
                for drop in creature["drops"].get(group) or []:
                    label = drop["name"]
                    if label and label not in instance["drops"] and len(instance["drops"]) < 12:
                        instance["drops"].append(label)
    instances = list(grouped.values())
    instances.sort(key=lambda item: (item["kind"], item["name"].lower()))
    return instances


def build_indexes(creatures, instances):
    dropped = {}
    boss_instance = {}
    instance_by_boss = {}
    for instance in instances:
        for boss in instance["bosses"]:
            instance_by_boss[boss] = instance["id"]
    for creature in creatures:
        instance_id = instance_by_boss.get(creature["id"], "")
        if instance_id and text(creature.get("subcategory")).lower() in ("bosses", "boss"):
            boss_instance[creature["id"]] = instance_id
        for group, rows in (creature.get("drops") or {}).items():
            for drop in rows:
                record = {
                    "creatureId": creature["id"],
                    "creatureName": creature["name"],
                    "group": group,
                    "chance": drop.get("chance") or "",
                    "instanceId": instance_id,
                }
                for key in {drop.get("slug") or "", drop.get("name", "").lower()}:
                    if key == "":
                        continue
                    dropped.setdefault(key, [])
                    if record not in dropped[key]:
                        dropped[key].append(record)
    return dropped, boss_instance


def public_creature(creature):
    copy = dict(creature)
    copy.pop("places", None)
    copy.pop("pins", None)
    return copy


def public_pins(creatures):
    pins = []
    seen = set()
    for creature in creatures:
        for pin in creature.get("pins") or []:
            key = (round(pin["x"], 1), round(pin["y"], 1), creature["id"])
            if key in seen:
                continue
            seen.add(key)
            place = pin.get("place") or creature["name"]
            pins.append({
                "id": creature["id"] + ":" + (slugify(place) or "pin") + ":" + str(round(pin["x"])) + ":" + str(round(pin["y"])),
                "x": pin["x"],
                "y": pin["y"],
                "kind": pin.get("kind") or "location",
                "label": pin.get("label") or creature["name"],
                "instanceId": slugify(place),
                "creatureId": creature["id"],
            })
    return pins


def export(sample=False):
    items = []
    seen = set()
    for tab in ITEM_TABS:
        try:
            rows = list_tab(tab)
        except Exception as error:
            print(f"{tab}: skipped ({error})", flush=True)
            continue
        if sample and tab != "weapons":
            rows = rows[:3]
        for row in rows:
            item = normalize_item(row, tab)
            if item is None or item["slug"] in seen:
                continue
            seen.add(item["slug"])
            items.append(item)
        if sample and tab == "weapons":
            break
    if not sample:
        attach_scales(items)
    creatures_raw = []
    try:
        creatures_raw = list_tab("creatures")
    except Exception as error:
        print(f"creatures: skipped ({error})", flush=True)
    if sample:
        creatures_raw = creatures_raw[:2]
    creatures = []

    def load_creature(summary):
        slug = text(summary.get("slug"))
        if slug == "":
            return None
        document = fetch(CREATURE_URL.format(slug=slug))
        return normalize_creature(summary, document)

    print(f"Fetching {len(creatures_raw)} creature pages...", flush=True)
    with ThreadPoolExecutor(max_workers=WORKERS) as pool:
        futures = [pool.submit(load_creature, summary) for summary in creatures_raw]
        done = 0
        for future in as_completed(futures):
            done += 1
            if done % 25 == 0 or done == len(futures):
                print(f"  creatures {done}/{len(futures)}", flush=True)
            try:
                creature = future.result()
            except Exception as error:
                print(f"  creature failed: {error}", flush=True)
                continue
            if creature is not None:
                creatures.append(creature)
    creatures.sort(key=lambda creature: creature["name"].lower())
    items.sort(key=lambda item: (item["category"], item["name"].lower()))
    instances = build_instances(creatures)
    dropped_by, boss_instance = build_indexes(creatures, instances)
    database = {
        "exportedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "sources": [LIST_URL, CREATURE_URL, MAP_URL],
        "items": items,
        "creatures": [public_creature(creature) for creature in creatures],
        "instances": instances,
        "pins": public_pins(creatures),
        "droppedBy": dropped_by,
        "bossInstance": boss_instance,
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(database, ensure_ascii=False, indent=1), encoding="utf-8")
    bosses = sum(1 for creature in creatures if text(creature.get("subcategory")).lower() in ("bosses", "boss"))
    print(
        f"Wrote {OUTPUT} items={len(items)} creatures={len(creatures)} bosses={bosses} "
        f"instances={len(instances)} pins={len(database['pins'])} droppedBy={len(dropped_by)}",
        flush=True,
    )
    if not items or not creatures:
        raise SystemExit("Export produced an empty catalog")


if __name__ == "__main__":
    if "--scales" in sys.argv:
        attach_saved_scales()
    else:
        export(sample="--sample" in sys.argv)
