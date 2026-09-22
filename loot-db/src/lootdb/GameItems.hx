package lootdb;

import lootdb.GameAccess as G;
import lootdb.Log;

/** Resolves Metaforge names to Farever's own item definitions, icons, and localized labels. */
class GameItems {
    static var byName:Map<String, String>;
    static var attempted:Bool = false;
    static var unitsByName:Map<String, Dynamic>;
    static var unitsAttempted:Bool = false;

    public static function idFor(name:String):String {
        var known = ItemNames.idFor(name);
        if (known != "") return known;
        ensure();
        if (byName == null || name == null || name == "") return "";
        var id = byName[name.toLowerCase()];
        return id == null ? "" : id;
    }

    public static function displayName(id:String):String {
        if (id == "") return "";
        try {
            var name = G.text(G.staticCall("HText", "itemById", [id]));
            return name == id ? "" : name;
        } catch (_:Dynamic) return "";
    }

    public static function slotName(id:String):String {
        var def = definition(id);
        if (def == null) return "";
        var slot = G.field(def, "slot");
        if (slot == null) return "";
        try {
            var name = G.text(G.staticCall("HText", "equipmentSlot", [slot]));
            if (name != "") return name;
        } catch (_:Dynamic) {}
        return G.text(slot);
    }

    /** In-game unit portrait. The unit sheet is preferred; skill ids such as R1CrabBoss_TidalSlash point at the same file. */
    public static function portrait(name:String, skillId:String):Dynamic {
        ensureUnits();
        var def = unitsByName == null || name == null ? null : unitsByName[name.toLowerCase()];
        if (def != null) {
            var tile = tileFromGfx(G.field(def, "gfx"));
            if (tile != null) return tile;
        }
        var stem = skillId == null ? "" : skillId;
        var cut = stem.lastIndexOf("_");
        if (cut <= 0) return null;
        return tileFromGfx("UI/Portraits/Units/" + stem.substr(0, cut) + ".png");
    }

    public static function skillDefinition(id:String):Dynamic {
        if (id == null || id == "") return null;
        try return G.call("haxe.ds.StringMap", "get", G.field(G.current("Data", "skill"), "byId"), [id])
        catch (_:Dynamic) return null;
    }

    /** Localized skill name. A raw id or an unresolved text key stays blank. */
    public static function skillName(id:String):String {
        var def = skillDefinition(id);
        if (def == null) return "";
        var name = named(G.field(G.field(def, "texts"), "name"));
        if (name == "" || name == id || StringTools.startsWith(name, "[")) return "";
        return name;
    }

    public static function skillIcon(id:String):Dynamic {
        var def = skillDefinition(id);
        var gfx = def == null ? null : G.field(def, "gfx");
        if (gfx == null && id != null && id != "") {
            try gfx = G.field(G.staticCall("HSkill", "getSkillRef", [id]), "gfx") catch (_:Dynamic) gfx = null;
        }
        return tileFromGfx(gfx);
    }

    public static function icon(id:String):Dynamic {
        var def = definition(id);
        if (def == null) return null;
        var gfx = G.field(def, "gfx");
        if (gfx == null) gfx = G.field(def, "icon");
        if (gfx == null) {
            try gfx = G.staticCall("HItem", "getGfx", [def]) catch (_:Dynamic) gfx = null;
        }
        if (gfx == null || G.text(gfx) == "") return null;
        try {
            var tile = G.staticCall("ui.BaseUI", "getTile", [gfx, null, null]);
            return copyTile(tile);
        } catch (_:Dynamic) return null;
    }

    /** A private copy with a real size. A shared or zero-size tile scales to infinity and blacks the scene. */
    static function tileFromGfx(gfx:Dynamic):Dynamic {
        if (gfx == null) return null;
        var file = G.field(gfx, "file");
        var source = file != null && G.text(file) != "" ? file : gfx;
        if (G.text(source) == "") return null;
        try return copyTile(G.staticCall("ui.BaseUI", "getTile", [source, null, null]))
        catch (_:Dynamic) return null;
    }

    static function ensureUnits():Void {
        if (unitsByName != null || unitsAttempted) return;
        unitsAttempted = true;
        for (sheet in ["unit", "units", "npc", "creature", "foe"]) {
            try {
                var data = G.current("Data", sheet);
                if (data == null) continue;
                var all = definitions(G.field(data, "byId"));
                if (all.length == 0) continue;
                var indexed:Map<String, Dynamic> = [];
                for (def in all) {
                    var id = G.text(G.field(def, "id"));
                    if (id != "") indexed[id.toLowerCase()] = def;
                    var texts = G.field(def, "texts");
                    var label = texts == null ? "" : named(G.field(texts, "name"));
                    if (label != "") indexed[label.toLowerCase()] = def;
                }
                if (indexed.iterator().hasNext()) {
                    unitsByName = indexed;
                    Log.write("unit portraits from Data." + sheet + " (" + all.length + ")");
                    return;
                }
            } catch (error:Dynamic) Log.once("unit sheet " + sheet + " " + Log.problem(error));
        }
        Log.once("unit portraits use skill-id files");
    }

    static function named(value:Dynamic):String {
        if (value == null) return "";
        var inner = G.field(value, "v");
        var text = G.text(inner != null ? inner : value);
        return text == "[object Object]" ? "" : text;
    }

    static function copyTile(tile:Dynamic):Dynamic {
        if (tile == null) return null;
        try {
            var copy = G.call("h2d.Tile", "clone", tile);
            if (copy == null) return null;
            var w = G.number(G.field(copy, "width"), 0);
            var h = G.number(G.field(copy, "height"), 0);
            return w >= 1 && h >= 1 && w <= 2048 && h <= 2048 ? copy : null;
        } catch (_:Dynamic) return null;
    }

    public static function definition(id:String):Dynamic {
        if (id == "") return null;
        try return G.call("haxe.ds.StringMap", "get", G.field(G.current("Data", "item"), "byId"), [id])
        catch (_:Dynamic) return null;
    }

    static function ensure():Void {
        if (byName != null || attempted) return;
        attempted = true;
        var indexed:Map<String, String> = [];
        try {
            var sheet = G.current("Data", "item");
            var all = G.array(G.field(sheet, "all"));
            if (all.length == 0) all = G.array(G.field(sheet, "lines"));
            if (all.length == 0) all = definitions(G.field(sheet, "byId"));
            for (def in all) {
                var id = G.text(G.field(def, "id"));
                if (id == "") continue;
                remember(indexed, id, id);
                remember(indexed, G.text(G.field(def, "name")), id);
                remember(indexed, displayName(id), id);
            }
        } catch (_:Dynamic) {
            attempted = false;
            return;
        }
        if (!indexed.iterator().hasNext()) {
            attempted = false;
            return;
        }
        byName = indexed;
    }

    static function definitions(map:Dynamic):Array<Dynamic> {
        var out:Array<Dynamic> = [];
        if (map == null) return out;
        var keys = G.call("haxe.ds.StringMap", "keys", map);
        var iteratorType = "haxe.ds._StringMap.StringMapKeysIterator";
        var guard = 0;
        while (G.call(iteratorType, "hasNext", keys) == true) {
            if (guard++ > 8000) break;
            var id = G.text(G.call(iteratorType, "next", keys));
            var def = G.call("haxe.ds.StringMap", "get", map, [id]);
            if (def != null) out.push(def);
        }
        return out;
    }

    static function remember(index:Map<String, String>, name:String, id:String):Void {
        if (name == "") return;
        index[name.toLowerCase()] = id;
    }
}
