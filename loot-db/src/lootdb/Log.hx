package lootdb;

import sys.io.File;

/** Append-only notes for the black-screen click. Flushed every line so a dead frame still leaves a trail. */
class Log {
    static inline var PATH = "hlx/mods/loot-db/loot-db.log";
    static var last:String = "";

    public static function write(message:String):Void {
        var line = Date.now().toString() + " " + message;
        trace("[Loot] " + message);
        try {
            var out = File.append(PATH, false);
            out.writeString(line + "\n");
            out.close();
        } catch (_:Dynamic) {}
    }

    public static function once(message:String):Void {
        if (message == last) return;
        last = message;
        write(message);
    }

    public static function problem(error:Dynamic):String {
        var stack = "";
        try stack = haxe.CallStack.toString(haxe.CallStack.exceptionStack()) catch (_:Dynamic) {}
        var text = Std.string(error);
        return stack == "" ? text : text + "\n" + stack;
    }
}
