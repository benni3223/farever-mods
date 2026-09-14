package dpsmeter;

/** Plain data shared with the archive worker; no native objects cross threads. */
typedef HistoryCatalog = {
    activities:Map<String, String>,
    names:Map<String, String>,
    bosses:Map<String, Bool>
};

class HistoryCategory {
    public static inline var BOSS = "Boss Dungeons";
    public static inline var DUNGEON = "Classic Dungeons";
    public static inline var WORLD = "World Bosses";
    public static inline var OTHER = "Other";
    public static function all():Array<String> return [BOSS, DUNGEON, WORLD, OTHER];
    public static function fromTypes(rift:Bool, boss:Bool, dungeon:Bool):String
        return rift ? WORLD : boss ? BOSS : dungeon ? DUNGEON : OTHER;
    public static function resolve(record:Dynamic, catalog:Null<HistoryCatalog>):String {
        var stored = FightHistory.text(record.category);
        if (all().indexOf(stored) >= 0) return stored;
        var phase = FightHistory.text(record.phase);
        var name = FightHistory.text(record.name);
        if (StringTools.startsWith(phase, "Rift:") || StringTools.startsWith(name, "Rift:")) return WORLD;
        var activity = FightHistory.text(record.activityId);
        // Old exports carry activity IDs. The first history format didn't;
        // those stay in Other rather than guessing from a boss-name substring.
        if (catalog != null && activity != "" && catalog.activities.exists(activity)) {
            var category = catalog.activities[activity];
            var boss = FightHistory.text(record.bossKind);
            if (category != WORLD && (boss == "" || (catalog.bosses.exists(boss) && !catalog.bosses[boss]))) return OTHER;
            return category;
        }
        return OTHER;
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
}
