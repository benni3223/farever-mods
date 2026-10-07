package dpsmeter;

/** Plain data shared with the archive worker; no native objects cross threads. */
typedef HistoryCatalog = {
    activities:Map<String, String>,
    names:Map<String, String>,
    bosses:Map<String, Bool>,
    ?bossCategories:Map<String, String>,
    ?difficulties:Map<Int, String>
};

class HistoryCategory {
    public static inline var BOSS = "Boss Dungeons";
    public static inline var DUNGEON = "Classic Dungeons";
    public static inline var WORLD = "World Bosses";
    public static inline var DUMMY = "Target Dummies";
    public static inline var OTHER = "Other";
    public static function all():Array<String> return [BOSS, DUNGEON, WORLD, DUMMY, OTHER];
    public static inline var VERSION = 2;
    /** Recognized encounters and dummy practice save; existing files remain browsable. */
    public static function canArchive(record:Dynamic, catalog:Null<HistoryCatalog> = null):Bool {
        if (record.targetDummy == true) return true;
        if (record.categoryVersion == VERSION && FightHistory.text(record.category) == OTHER) return false;
        return resolve(record, catalog) != OTHER;
    }
    /** The server adds the clearing objective only when dungeon foes exist.
        A populated KillBoss target is required before interpreting its absence. */
    public static function fromObjectives(rift:Bool, dungeon:Bool, bossReady:Bool, clearFoes:Bool):String
        return rift ? WORLD : !dungeon ? OTHER : clearFoes ? DUNGEON : bossReady ? BOSS : OTHER;
    public static function legacyBoss(kind:String):String return switch (kind) {
        // Confirmed older encounters whose logs predate objective metadata.
        // Chakram's internal unit ID is Phrixes. New fights use objectives.
        case "Ratsar", "Phrixes": BOSS;
        case "RobinHoof": DUNGEON;
        default: OTHER;
    };
    public static function observeBoss(categories:Map<String, String>, kind:String, category:String):Void {
        if (kind == "" || (category != BOSS && category != DUNGEON)) return;
        // A reused boss ID can appear in both dungeon formats. Ambiguous
        // evidence must never override an encounter's actual activity context.
        if (!categories.exists(kind)) categories[kind] = category;
        else if (categories[kind] != category) categories[kind] = OTHER;
    }
    public static function resolve(record:Dynamic, catalog:Null<HistoryCatalog>):String {
        var stored = FightHistory.text(record.category);
        // Reclassify earlier dummy logs in memory without rewriting them, and
        // keep practice separate even if its area later hosts a boss event.
        if ((stored == DUMMY && record.categoryVersion == VERSION)
            || (stored == OTHER && record.targetDummy == true)) return DUMMY;
        var phase = FightHistory.text(record.phase);
        var name = FightHistory.text(record.name);
        if (isRiftName(phase) || isRiftName(name)) return WORLD;
        var activity = FightHistory.text(record.activityId);
        if (catalog != null && catalog.activities[activity] == WORLD) return WORLD;
        // Version 1 inferred these labels from implementation inheritance,
        // which does not describe whether a dungeon has a clearing phase.
        if (record.categoryVersion == VERSION && all().indexOf(stored) >= 0 && stored != OTHER) return stored;
        var boss = FightHistory.text(record.bossKind);
        if (boss == "" && catalog != null) {
            // First-release imports sometimes saved only the display name.
            // Accept an exact, unique known-boss name; never substring-match.
            if (catalog.bosses[name] == true) boss = name;
            else for (id => label in catalog.names) if (label == name && catalog.bosses[id] == true) {
                if (boss != "") return OTHER;
                boss = id;
            }
        }
        if (boss == "" || (catalog != null && catalog.bosses.exists(boss) && !catalog.bosses[boss])) return OTHER;
        if (catalog != null && activity != "" && catalog.activities.exists(activity)) {
            var category = catalog.activities[activity];
            if (category != OTHER) return category;
        }
        if (catalog != null && catalog.bossCategories != null && catalog.bossCategories.exists(boss))
            return catalog.bossCategories[boss];
        return legacyBoss(boss);
    }
    public static function displayName(record:Dynamic, catalog:Null<HistoryCatalog>):String {
        var original = FightHistory.text(record.name);
        if (catalog != null && catalog.names.exists(original)) return normalizeName(catalog.names[original]);
        var name = normalizeName(original);
        if (catalog != null && StringTools.startsWith(name, "Rift - ")) {
            var id = name.substr(7);
            if (catalog.names.exists(id)) return "Rift - " + catalog.names[id];
        }
        return name;
    }
    static function isRiftName(name:String):Bool
        return StringTools.startsWith(name, "Rift:") || StringTools.startsWith(name, "Rift - ");
    /** Presentation only: retain the existing phase IDs in uploaded reports. */
    public static function normalizeName(name:String):String
        return StringTools.startsWith(name, "Rift:") ? "Rift - " + StringTools.trim(name.substr(5)) : name;
    public static function folderName(record:Dynamic, catalog:Null<HistoryCatalog>):String {
        var name = encounterName(record, catalog);
        name = ~/[<>:"\/\\|?*\x00-\x1F]+/g.replace(name, " - ");
        name = ~/\s+/g.replace(name, " ");
        name = ~/[. ]+$/g.replace(StringTools.trim(name), "");
        if (name == "") name = "Unknown encounter";
        // Windows device names are reserved even when followed by an extension.
        if (~/^(CON|PRN|AUX|NUL|COM[1-9¹²³]|LPT[1-9¹²³]|CONIN\$|CONOUT\$)(\.|$)/i.match(name)) name = "_" + name;
        // Bound the added path component while keeping long names distinct.
        if (haxe.io.Bytes.ofString(name).length > 100) {
            var hash = haxe.crypto.Md5.encode(name).substr(0, 8);
            var prefix = "";
            for (code in new haxe.iterators.StringIteratorUnicode(name)) {
                var next = prefix + String.fromCharCode(code);
                if (haxe.io.Bytes.ofString(next).length > 88) break;
                prefix = next;
            }
            name = prefix + " - " + hash;
        }
        return name;
    }
    public static function encounterName(record:Dynamic, catalog:Null<HistoryCatalog>):String {
        var name = displayName(record, catalog);
        var difficulty = FightHistory.difficulty(record.difficulty);
        if (difficulty >= 0) {
            var label = catalog != null && catalog.difficulties != null ? catalog.difficulties[difficulty] : null;
            if (label == null || label == "") label = switch (difficulty) {
                case 0: "Normal"; case 1: "Veteran"; case 2: "Heroic";
                default: "Difficulty " + difficulty;
            };
            return name + " - " + label;
        }
        var category = resolve(record, catalog);
        return name + (category == BOSS || category == DUNGEON ? " - Unknown difficulty" : "");
    }
}
