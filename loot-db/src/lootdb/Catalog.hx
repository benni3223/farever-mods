package lootdb;

import haxe.Json;

typedef SkillLine = {id:String, name:String, cooldown:Null<Float>, duration:Null<Float>, power:String};
typedef StatLine = {label:String, value:String};
typedef ScaleStep = {mode:String, rarity:String, level:Null<Int>, stats:Array<StatLine>};
typedef DropLine = {name:String, slug:String, chance:String, rarity:String, group:String};
typedef ItemRecord = {
    id:String, name:String, slug:String, category:String, subcategory:String,
    classes:Array<String>, rarity:String, level:Null<Int>, description:String,
    obtain:Array<String>, stats:Array<StatLine>, scales:Array<ScaleStep>, skills:Array<SkillLine>, recipe:String
};
typedef CreatureRecord = {
    id:String, name:String, slug:String, faction:String, subcategory:String,
    level:Null<Int>, description:String, skills:Array<SkillLine>, drops:Map<String, Array<DropLine>>
};
typedef InstanceRecord = {
    id:String, name:String, kind:String, bosses:Array<String>, names:Array<String>,
    pinX:Null<Float>, pinY:Null<Float>, drops:Array<String>
};
typedef PinRecord = {
    id:String, x:Float, y:Float, kind:String, label:String, instanceId:String, creatureId:String
};
typedef DropSource = {
    creatureId:String, creatureName:String, group:String, chance:String, instanceId:String
};
typedef SearchHit = {id:String, title:String, subtitle:String, kind:String};

/** Searchable snapshot of the exported Metaforge database. */
class Catalog {
    public var exportedAt:String = "";
    public var items:Array<ItemRecord> = [];
    public var creatures:Array<CreatureRecord> = [];
    public var instances:Array<InstanceRecord> = [];
    public var pins:Array<PinRecord> = [];
    var itemsBySlug:Map<String, ItemRecord> = [];
    var creaturesById:Map<String, CreatureRecord> = [];
    var instancesById:Map<String, InstanceRecord> = [];
    var dropped:Map<String, Array<DropSource>> = [];
    var bossInstance:Map<String, String> = [];

    public function new() {}

    public static function parse(raw:String):Catalog {
        var catalog = new Catalog();
        var root:Dynamic = Json.parse(raw);
        catalog.exportedAt = text(Reflect.field(root, "exportedAt"));
        for (item in array(Reflect.field(root, "items"))) {
            var record = readItem(item);
            catalog.items.push(record);
            catalog.itemsBySlug[record.slug] = record;
        }
        for (creature in array(Reflect.field(root, "creatures"))) {
            var record = readCreature(creature);
            catalog.creatures.push(record);
            catalog.creaturesById[record.id] = record;
        }
        for (instance in array(Reflect.field(root, "instances"))) {
            var record = readInstance(instance);
            catalog.instances.push(record);
            catalog.instancesById[record.id] = record;
        }
        for (pin in array(Reflect.field(root, "pins"))) catalog.pins.push(readPin(pin));
        var sources:Dynamic = Reflect.field(root, "droppedBy");
        if (sources != null) for (key in Reflect.fields(sources))
            catalog.dropped[key.toLowerCase()] = readSources(Reflect.field(sources, key));
        var bosses:Dynamic = Reflect.field(root, "bossInstance");
        if (bosses != null) for (key in Reflect.fields(bosses))
            catalog.bossInstance[key] = text(Reflect.field(bosses, key));
        return catalog;
    }

    public function search(tab:String, query:String, className:String = "", slot:String = "", category:String = ""):Array<SearchHit> {
        return searchFiltered(tab, query, className == "" ? [] : [className], slot == "" ? [] : [slot], category == "" ? [] : [category]);
    }

    /** Empty lists mean "every value". A list matches when the item fits any chosen value. */
    public function searchFiltered(tab:String, query:String, classes:Array<String>, slots:Array<String>, categories:Array<String>):Array<SearchHit> {
        var needle = query.toLowerCase();
        var hits:Array<SearchHit> = [];
        switch (tab) {
            case "instances":
                for (instance in instances) if (instance.kind != "location" && matchesInstance(instance, needle))
                    hits.push({id: instance.id, title: instance.name, subtitle: instanceSubtitle(instance), kind: "instance"});
            case "bosses":
                for (creature in creatures) if (isBoss(creature) && (needle == "" || contains(creature.name, needle) || contains(creature.faction, needle)))
                    hits.push({id: creature.id, title: creature.name, subtitle: bossSubtitle(creature), kind: "creature"});
            case "weapons":
                for (item in items) if (item.category == "weapons" && matchesItem(item, needle, classes, slots, []))
                    hits.push(itemHit(item));
            case "items":
                for (item in items) if (item.category != "weapons" && matchesItem(item, needle, classes, slots, categories))
                    hits.push(itemHit(item));
            default:
        }
        return hits;
    }

    public function slotsFor(category:String):Array<String> {
        var seen:Map<String, Bool> = [];
        var names:Array<String> = [];
        for (item in items) {
            if (category == "weapons") {
                if (item.category != "weapons") continue;
            } else if (category != "") {
                if (item.category != category) continue;
            } else if (item.category == "weapons") continue;
            if (item.subcategory == "" || seen.exists(item.subcategory)) continue;
            seen[item.subcategory] = true;
            names.push(item.subcategory);
        }
        names.sort(Reflect.compare);
        return names;
    }

    public function droppedBy(nameOrSlug:String):Array<DropSource> {
        var key = nameOrSlug.toLowerCase();
        if (dropped.exists(key)) return dropped[key];
        var item = itemsBySlug[key];
        if (item != null && dropped.exists(item.name.toLowerCase())) return dropped[item.name.toLowerCase()];
        return [];
    }

    public function instanceOfBoss(creatureId:String):Null<InstanceRecord> {
        var id = bossInstance[creatureId];
        return id == null ? null : instancesById[id];
    }

    public function instanceById(id:String):Null<InstanceRecord> return instancesById[id];
    public function creature(id:String):Null<CreatureRecord> return creaturesById[id];
    public function item(slug:String):Null<ItemRecord> return itemsBySlug[slug];

    public function pinsFor(query:String, dungeons:Bool, worldBosses:Bool, searchHits:Bool):Array<PinRecord> {
        var needle = query.toLowerCase();
        var allowed:Map<String, Bool> = [];
        if (searchHits && needle != "") for (hit in search("instances", query)) allowed[hit.id] = true;
        var result = [];
        for (pin in pins) {
            var instance = instancesById[pin.instanceId];
            var kind = instance != null ? instance.kind : pin.kind;
            var visible = (dungeons && (kind == "dungeon" || kind == "rift")) || (worldBosses && kind == "world-boss");
            if (searchHits && needle != "" && (allowed.exists(pin.instanceId) || contains(pin.label, needle))) visible = true;
            if (visible) result.push(pin);
        }
        return result;
    }

    function matchesInstance(instance:InstanceRecord, needle:String):Bool {
        if (needle == "") return true;
        if (contains(instance.name, needle) || contains(instance.kind, needle)) return true;
        for (name in instance.names) if (contains(name, needle)) return true;
        for (drop in instance.drops) if (contains(drop, needle)) return true;
        for (boss in instance.bosses) {
            var creature = creaturesById[boss];
            if (creature != null && contains(creature.name, needle)) return true;
        }
        return false;
    }

    function matchesItem(item:ItemRecord, needle:String, classes:Array<String>, slots:Array<String>, categories:Array<String>):Bool {
        if (categories.length > 0 && categories.indexOf(item.category) < 0) return false;
        if (slots.length > 0 && slots.indexOf(item.subcategory) < 0) return false;
        if (classes.length > 0 && !hasAnyClass(item, classes)) return false;
        if (needle == "") return true;
        if (contains(item.name, needle) || contains(item.subcategory, needle) || contains(item.rarity, needle)) return true;
        for (name in item.classes) if (contains(name, needle)) return true;
        for (skill in item.skills) if (contains(skill.name, needle)) return true;
        return false;
    }

    function hasAnyClass(item:ItemRecord, classes:Array<String>):Bool {
        for (name in classes) if (hasClass(item, name)) return true;
        return false;
    }

    function hasClass(item:ItemRecord, className:String):Bool {
        var needle = className.toLowerCase();
        for (name in item.classes) if (name.toLowerCase() == needle) return true;
        return false;
    }

    function isBoss(creature:CreatureRecord):Bool {
        var kind = creature.subcategory.toLowerCase();
        return kind == "bosses" || kind == "boss" || bossInstance.exists(creature.id);
    }

    function instanceSubtitle(instance:InstanceRecord):String {
        var bossNames = [for (id in instance.bosses) if (creaturesById.exists(id)) creaturesById[id].name];
        var label = instance.kind == "world-boss" ? "World boss" : instance.kind == "dungeon" ? "Dungeon" : instance.kind == "rift" ? "Rift" : "Location";
        return bossNames.length == 0 ? label : label + " · " + bossNames.join(", ");
    }

    function bossSubtitle(creature:CreatureRecord):String {
        var instance = instanceOfBoss(creature.id);
        var place = instance == null ? creature.faction : instance.name;
        return (creature.level == null ? "" : "Lv " + creature.level + " · ") + place;
    }

    function itemHit(item:ItemRecord):SearchHit {
        var bits = [];
        if (item.subcategory != "") bits.push(prettySlot(item.subcategory));
        if (item.level != null) bits.push("Level " + item.level);
        else if (item.rarity != "") bits.push(item.rarity.split(" / ")[0]);
        return {id: item.slug, title: item.name, subtitle: bits.join(" · "), kind: "item"};
    }

    public static function prettySlot(slot:String):String {
        if (slot == null || slot == "") return "";
        if (StringTools.startsWith(slot, "Gear")) slot = slot.substr(4);
        if (slot == "Finger") return "Ring";
        var spaced = "";
        for (i in 0...slot.length) {
            var code = slot.charCodeAt(i);
            if (i > 0 && code >= 65 && code <= 90) spaced += " ";
            spaced += slot.charAt(i);
        }
        return spaced;
    }

    static function contains(value:String, needle:String):Bool return value.toLowerCase().indexOf(needle) >= 0;

    static function readItem(raw:Dynamic):ItemRecord {
        return {
            id: text(raw.id), name: text(raw.name), slug: text(raw.slug), category: text(raw.category),
            subcategory: text(raw.subcategory), classes: strings(raw.classes), rarity: text(raw.rarity),
            level: optionalInt(raw.level), description: text(raw.description), obtain: strings(raw.obtain),
            stats: [for (row in array(raw.stats)) {label: text(row.label), value: text(row.value)}],
            scales: [for (row in array(raw.scales)) readScale(row)],
            skills: [for (row in array(raw.skills)) readSkill(row)],
            recipe: text(raw.recipe)
        };
    }

    static function readCreature(raw:Dynamic):CreatureRecord {
        var drops:Map<String, Array<DropLine>> = [];
        var rawDrops:Dynamic = raw.drops;
        if (rawDrops != null) for (group in Reflect.fields(rawDrops))
            drops[group] = [for (row in array(Reflect.field(rawDrops, group))) readDrop(row, group)];
        return {
            id: text(raw.id), name: text(raw.name), slug: text(raw.slug), faction: text(raw.faction),
            subcategory: text(raw.subcategory), level: optionalInt(raw.level), description: text(raw.description),
            skills: [for (row in array(raw.skills)) readSkill(row)], drops: drops
        };
    }

    static function readInstance(raw:Dynamic):InstanceRecord {
        var pin:Dynamic = raw.pin;
        return {
            id: text(raw.id), name: text(raw.name), kind: text(raw.kind), bosses: strings(raw.bosses),
            names: strings(raw.names), pinX: pin == null ? null : optionalFloat(pin.x), pinY: pin == null ? null : optionalFloat(pin.y),
            drops: strings(raw.drops)
        };
    }

    static function readPin(raw:Dynamic):PinRecord {
        return {
            id: text(raw.id), x: float(raw.x), y: float(raw.y), kind: text(raw.kind), label: text(raw.label),
            instanceId: text(raw.instanceId), creatureId: text(raw.creatureId)
        };
    }

    static function readSources(raw:Dynamic):Array<DropSource> {
        return [for (row in array(raw)) {
            creatureId: text(row.creatureId), creatureName: text(row.creatureName), group: text(row.group),
            chance: text(row.chance), instanceId: text(row.instanceId)
        }];
    }

    static function readDrop(raw:Dynamic, group:String):DropLine {
        return {name: text(raw.name), slug: text(raw.slug), chance: text(raw.chance), rarity: text(raw.rarity), group: text(raw.group, group)};
    }

    static function readScale(raw:Dynamic):ScaleStep {
        return {
            mode: text(raw.mode), rarity: text(raw.rarity), level: optionalInt(raw.level),
            stats: [for (row in array(raw.stats)) {label: text(row.label), value: text(row.value)}]
        };
    }

    static function readSkill(raw:Dynamic):SkillLine {
        return {
            id: text(raw.id), name: text(raw.name), cooldown: optionalFloat(raw.cooldown),
            duration: optionalFloat(raw.duration), power: text(raw.power)
        };
    }

    static function strings(value:Dynamic):Array<String> return [for (entry in array(value)) text(entry)];
    static function array(value:Dynamic):Array<Dynamic> return value == null ? [] : value;
    static function text(value:Dynamic, fallback:String = ""):String return value == null ? fallback : Std.string(value);
    static function float(value:Dynamic):Float {
        var n = Std.parseFloat(Std.string(value));
        return Math.isFinite(n) ? n : 0;
    }
    static function optionalFloat(value:Dynamic):Null<Float> {
        if (value == null) return null;
        var n = Std.parseFloat(Std.string(value));
        return Math.isFinite(n) ? n : null;
    }
    static function optionalInt(value:Dynamic):Null<Int> {
        var n = optionalFloat(value);
        return n == null ? null : Std.int(n);
    }
}
