package dpsmeter;

/** Plain data shared with the archive worker; no native objects cross threads. */
typedef HistoryCatalog = {
    activities:Map<String, String>,
    names:Map<String, String>,
    bosses:Map<String, Bool>,
    ?difficulties:Map<Int, String>
};

class HistoryCategory {
    public static inline var BOSS = "Boss Dungeons";
    public static inline var DUNGEON = "Classic Dungeons";
    public static inline var WORLD = "World Bosses";
    public static inline var OTHER = "Other";
    public static function all():Array<String> return [BOSS, DUNGEON, WORLD, OTHER];
    public static inline var VERSION = 2;
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
    public static function resolve(record:Dynamic, catalog:Null<HistoryCatalog>):String {
        var stored = FightHistory.text(record.category);
        var phase = FightHistory.text(record.phase);
        var name = FightHistory.text(record.name);
        if (StringTools.startsWith(phase, "Rift:") || StringTools.startsWith(name, "Rift:")) return WORLD;
        var activity = FightHistory.text(record.activityId);
        if (catalog != null && catalog.activities[activity] == WORLD) return WORLD;
        // Version 1 inferred these labels from implementation inheritance,
        // which does not describe whether a dungeon has a clearing phase.
        if (record.categoryVersion == VERSION && all().indexOf(stored) >= 0 && stored != OTHER) return stored;
        var boss = FightHistory.text(record.bossKind);
        if (boss == "" || (catalog != null && catalog.bosses.exists(boss) && !catalog.bosses[boss])) return OTHER;
        // Old exports carry activity IDs. The first history format didn't;
        // those stay in Other rather than guessing from a boss-name substring.
        if (catalog != null && activity != "" && catalog.activities.exists(activity)) {
            var category = catalog.activities[activity];
            if (category != OTHER) return category;
        }
        return activity == "" ? OTHER : legacyBoss(boss);
    }
    public static function displayName(record:Dynamic, catalog:Null<HistoryCatalog>):String {
        var name = FightHistory.text(record.name);
        if (catalog == null) return name;
        if (catalog.names.exists(name)) return catalog.names[name];
        if (StringTools.startsWith(name, "Rift: ")) {
            var id = name.substr(6);
            if (catalog.names.exists(id)) return "Rift: " + catalog.names[id];
        }
        return name;
    }
    public static function encounterName(record:Dynamic, catalog:Null<HistoryCatalog>):String {
        var name = displayName(record, catalog);
        var difficulty = FightHistory.difficulty(record.difficulty);
        if (difficulty >= 0) {
            var label = catalog != null && catalog.difficulties != null ? catalog.difficulties[difficulty] : null;
            if (label == null || label == "") label = switch (difficulty) {
                case 0: "Normal"; case 1: "Hard"; case 2: "Heroic";
                default: "Difficulty " + difficulty;
            };
            return name + " - " + label;
        }
        var category = resolve(record, catalog);
        return name + (category == BOSS || category == DUNGEON ? " - Unknown difficulty" : "");
    }
}
