package minimap;

import minimap.GameAccess as G;

/** Sends a pin in group chat and notices one that arrives. */
class PinChat {
    static var noted = false;
    static var seen = "";
    static var box:Dynamic;
    static var missed = new Map<String, Bool>();
    static var nextSearch = 0.0;
    static var pauseUntil = 0.0;

    public static function send(app:Dynamic, line:String):Void {
        if (app == null || line == null || line == "") return;
        // A solo player still keeps the pin locally. Group chat is only for a real party.
        var hero = G.field(app, "hero");
        if (!PlayerMarkers.hasMembers(G.field(hero, "player"))) return;
        if (sendGroup(app, line)) return;
        note("party chat send unavailable");
    }

    static function sendGroup(app:Dynamic, line:String):Bool {
        var ui = G.current("ui.BaseUI", "current");
        var root = G.field(ui, "gameRoot");
        if (box == null || G.field(box, "parent") == null) box = findBox(root, 8);
        if (box != null && invoke(box, "ui.hud.ChatBox", "processMessage", ["!group " + line])) return true;
        var server = G.field(G.field(app, "world"), "chatServer");
        if (server == null) return false;
        var channel = groupChannel();
        if (channel != null && invoke(server, "st.ChatServer", "sendMessage", [channel, line])) return true;
        if (channel != null && invoke(server, "st.ChatServer", "sendMessage2", [channel, line])) return true;
        return invoke(server, "st.ChatServer", "sendMessage", [line])
            || invoke(server, "st.ChatServer", "sendMessage2", [line]);
    }

    static function invoke(object:Dynamic, type:String, name:String, args:Array<Dynamic>):Bool {
        var key = type + "." + name;
        if (object == null || missed.exists(key)) return false;
        var count = -1;
        try count = G.argumentCount(object, name) catch (_:Dynamic) {
            missed.set(key, true);
            return false;
        }
        if (count != args.length) return false;
        try {
            G.call(type, name, object, args);
            return true;
        } catch (_:Dynamic) return false;
    }

    public static function poll(ui:Dynamic, zone:String):Void {
        if (haxe.Timer.stamp() < pauseUntil) return;
        try read(ui, zone) catch (error:Dynamic) {
            pauseUntil = haxe.Timer.stamp() + 5;
            note(Std.string(error));
        }
    }

    static function read(ui:Dynamic, zone:String):Void {
        if (ui == null || zone == null || zone == "") return;
        var root = G.field(ui, "gameRoot");
        if (box == null || G.field(box, "parent") == null) {
            if (haxe.Timer.stamp() < nextSearch) return;
            nextSearch = haxe.Timer.stamp() + 1;
            box = findBox(root, 8);
        }
        if (box == null) return;
        var pin = newestPin(box, 12);
        if (pin == null) return;
        var key = PinMessage.format(pin);
        // The chat widget changes constantly. Re-reading an older pin must not
        // move a pin the player just placed.
        if (key == seen) return;
        seen = key;
        PartyPin.receive(key, zone);
    }

    static function groupChannel():Dynamic {
        try {
            for (type in ["ChatChannel", "EChatChannel", "st.ChatChannel", "ui.hud.ChatBox"]) {
                var value = G.current(type, "Chat_Group");
                if (value != null) return value;
            }
        } catch (_:Dynamic) {}
        return null;
    }

    static function findBox(object:Dynamic, depth:Int):Dynamic {
        if (object == null || depth < 0) return null;
        var name = typeName(object);
        if (name == "ui.hud.ChatBox") return object;
        var count = G.integer(G.call("h2d.Object", "get_numChildren", object));
        for (i in 0...count) {
            var found = findBox(G.call("h2d.Object", "getChildAt", object, [i]), depth - 1);
            if (found != null) return found;
        }
        return null;
    }

    /** Last pin in display order. Chat lines live on msgText, deeper than the box label. */
    static function newestPin(object:Dynamic, depth:Int):minimap.PinMessage.PinPoint {
        if (object == null || depth < 0) return null;
        var last = PinMessage.parse(lineText(object));
        var count = G.integer(G.call("h2d.Object", "get_numChildren", object));
        for (i in 0...count) {
            var child = newestPin(G.call("h2d.Object", "getChildAt", object, [i]), depth - 1);
            if (child != null) last = child;
        }
        return last;
    }

    static function lineText(object:Dynamic):String {
        var text = G.field(object, "msgText");
        if (!Std.isOfType(text, String)) text = G.field(text, "text");
        if (!Std.isOfType(text, String)) text = G.field(object, "text");
        if (!Std.isOfType(text, String)) text = G.field(object, "message");
        if (!Std.isOfType(text, String)) return null;
        var line = StringTools.trim(Std.string(text));
        return line == "" ? null : line;
    }

    static function typeName(object:Dynamic):String {
        try return hl.Type.getDynamic(object).getTypeName() catch (_:Dynamic) return "";
    }

    static function note(message:String):Void {
        if (noted) return;
        noted = true;
        trace("[Minimap] " + message);
        try {
            sys.FileSystem.createDirectory("hlx/mods/minimap");
            var file = sys.io.File.append("hlx/mods/minimap/minimap.log", false);
            file.writeString(message + "\n");
            file.close();
        } catch (_:Dynamic) {}
    }
}
