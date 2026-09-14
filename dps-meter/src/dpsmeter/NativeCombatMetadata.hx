package dpsmeter;

import dpsmeter.GameAccess as G;
import dpsmeter.HistoryCatalog;

/** Read the running game's definitions, including inherited activities and skill references. */
class NativeCombatMetadata {
    public static function activityCategory(id:String, isRift:Bool):String {
        if (isRift) return HistoryCategory.WORLD;
        if (id == "") return HistoryCategory.OTHER;
        try return category(G.staticCall("HActivity", "getInf", [id])) catch (_:Dynamic) return HistoryCategory.OTHER;
    }
    static function category(inf:Dynamic):String {
        if (inf == null) return HistoryCategory.OTHER;
        return HistoryCategory.fromTypes(
            G.staticCall("HActivity", "isOfType", [inf, "Rift"]) == true,
            G.staticCall("HActivity", "isOfType", [inf, "Boss"]) == true,
            G.staticCall("HActivity", "isOfType", [inf, "Dungeon"]) == true);
    }
    public static function catalog():HistoryCatalog {
        var result:HistoryCatalog = {activities: [], names: [], bosses: []};
        // All is intentionally unfiltered: retained logs can refer to retired
        // activities. Reading definitions does not load their maps or prefabs.
        try for (definition in G.array(G.staticCall("HActivity", "all", [null]))) {
            var inf = G.field(definition, "inf");
            var id = G.text(G.field(inf, "id"));
            if (id != "") result.activities[id] = category(inf);
        } catch (_:Dynamic) {}
        var units = G.current("Data", "unit");
        for (inf in G.array(G.field(units, "all"))) {
            var id = G.text(G.field(inf, "id"));
            if (id == "") continue;
            result.bosses[id] = (G.integer(G.field(inf, "flags")) & 0x10) != 0;
            try {
                var name = G.text(G.staticCall("HText", "unit", [inf, null]));
                if (name != "" && name != id) result.names[id] = name;
            } catch (_:Dynamic) {}
        }
        return result;
    }
    public static function skillName(id:String):String {
        if (id == "") return "Unknown skill";
        try {
            var sheet = G.current("Data", "skill");
            var inf = G.call("haxe.ds.StringMap", "get", G.field(sheet, "byId"), [id]);
            if (inf != null) {
                // The native name resolver follows explicit text references and
                // SKILLS_AUTO_REFS (e.g. a projectile's owning class ability).
                var masteries = G.call("hl.types.ArrayObj", "slice", G.field(sheet, "all"), [0, 0]);
                var spec:Dynamic = {inf: inf, rank: 1, maxRank: 1, masteries: masteries};
                var name = G.text(G.staticCall("HText", "skill", [spec, null, null, null, null, null]));
                if (name != "" && name != id) return name;
            }
        } catch (_:Dynamic) {}
        // A removed/untranslated skill should still be readable in old logs.
        return StringTools.replace(id, "_", " ");
    }
}
