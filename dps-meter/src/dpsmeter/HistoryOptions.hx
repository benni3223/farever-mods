package dpsmeter;

import dpsmeter.FightHistory;

/** Archive-only sort/filter data; no native UI objects or per-query disk reads. */
class HistoryOptions {
    public static function characterKey(entry:HistoryEntry):String {
        // Combat UIDs identify spawned heroes and can change after relogging.
        // Name plus class is the stable identity available in existing archives.
        return haxe.Json.stringify([entry.playerName, entry.playerClass]);
    }
    public static function characters(entries:Iterator<HistoryEntry>):Array<HistoryCharacter> {
        var found:Map<String, HistoryCharacter> = [];
        for (entry in entries) {
            var key = characterKey(entry);
            found[key] = {key: key, name: entry.playerName == "" ? "Unknown character" : entry.playerName, className: entry.playerClass};
        }
        var result = [for (value in found) value];
        result.sort((a, b) -> {
            var name = Reflect.compare(a.name.toLowerCase(), b.name.toLowerCase());
            return name != 0 ? name : Reflect.compare(a.key, b.key);
        });
        return result;
    }
    public static function matches(entry:HistoryEntry, key:Null<String>):Bool
        return key == null || key == "" || characterKey(entry) == key;
    public static function compare(a:HistoryEntry, b:HistoryEntry, sortBy:Null<String>, ascending:Bool):Int {
        var x:Null<Float> = metric(a, sortBy); var y:Null<Float> = metric(b, sortBy);
        // Missing personal damage is unavailable, not zero. Keep it at the end
        // in both directions; actual zero-DPS fights remain sortable normally.
        if (x == null && y != null) return 1;
        if (x != null && y == null) return -1;
        var result = x == null || y == null ? 0 : Reflect.compare(x, y);
        if (result != 0) return ascending ? result : -result;
        result = Reflect.compare(b.startedAt, a.startedAt);
        return result != 0 ? result : Reflect.compare(b.id, a.id);
    }
    static function metric(entry:HistoryEntry, sortBy:Null<String>):Null<Float> return switch (sortBy) {
        case "dps": entry.personalDps;
        case "duration": entry.duration;
        default: entry.startedAt;
    };
}
