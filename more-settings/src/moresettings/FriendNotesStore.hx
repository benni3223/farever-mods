package moresettings;

import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;

/** Local, account-scoped notes. This file is separate from BMS settings. */
class FriendNotesStore {
    public static inline var LIMIT = 30;
    var path:String;
    var notes:Map<String, Map<String, String>> = [];
    var loaded = false;

    public function new(path:String) this.path = path;

    public static function clean(value:String):String {
        if (value == null) return "";
        value = StringTools.trim(~/[\x00-\x1f\x7f]+/g.replace(value, " "));
        // Iterate Unicode code points rather than cutting a surrogate pair.
        var result = new StringBuf();
        var count = 0;
        for (c in new haxe.iterators.StringIteratorUnicode(value)) {
            if (count++ >= LIMIT) break;
            result.addChar(c);
        }
        return StringTools.trim(result.toString());
    }

    function load():Void {
        if (loaded) return;
        // Recover the previous copy if the process stopped between renames.
        var source = FileSystem.exists(path) ? path : path + ".bak";
        if (FileSystem.exists(source)) {
            var data:Dynamic = haxe.Json.parse(File.getContent(source));
            if (data == null || data.version != 1 || !Std.isOfType(data.notes, Array))
                throw "Invalid friend notes file; existing notes have been preserved.";
            var rows:Array<Dynamic> = data.notes;
            var next:Map<String, Map<String, String>> = [];
            for (row in rows) {
                if (row == null || !Std.isOfType(row.owner, String) || !Std.isOfType(row.friend, String)
                    || !Std.isOfType(row.note, String)) throw "Invalid saved friend note.";
                var owner:String = row.owner;
                var friend:String = row.friend;
                if (!next.exists(owner)) next[owner] = new Map<String, String>();
                next[owner][friend] = clean(row.note);
            }
            notes = next;
        }
        loaded = true;
    }

    public function get(owner:String, friend:String):String {
        if (owner == "" || friend == "") return "";
        load();
        var account = notes[owner];
        return account == null || !account.exists(friend) ? "" : account[friend];
    }

    public function set(owner:String, friend:String, text:String):Void {
        if (owner == "" || friend == "") throw "The friend account is not available.";
        load();
        // Game Strings have a different class identity from module Strings.
        // Copy IDs as well as note text so JsonPrinter writes strings, never
        // native {bytes, length} objects (the same boundary as BMS text inputs).
        var ownerCopy = new StringBuf(); ownerCopy.add(owner); owner = ownerCopy.toString();
        var friendCopy = new StringBuf(); friendCopy.add(friend); friend = friendCopy.toString();
        var account = notes[owner];
        if (account == null) notes[owner] = account = [];
        var previous = account[friend];
        text = clean(text);
        if (text == "") account.remove(friend); else account[friend] = text;
        try {
            var rows = [];
            for (owner => account in notes) for (friend => note in account)
                rows.push({owner: owner, friend: friend, note: note});
            FileSystem.createDirectory(Path.directory(path));
            File.saveContent(path + ".tmp", haxe.Json.stringify({version: 1, notes: rows}, null, "  "));
            // Keep a previous copy before replacing the main file. Rename works
            // atomically on Windows too once the previous destination is moved.
            var previousFile = FileSystem.exists(path);
            if (previousFile) {
                if (FileSystem.exists(path + ".bak")) FileSystem.deleteFile(path + ".bak");
                FileSystem.rename(path, path + ".bak");
            }
            try FileSystem.rename(path + ".tmp", path) catch (e:Dynamic) {
                if (previousFile) FileSystem.rename(path + ".bak", path);
                throw e;
            }
        } catch (e:Dynamic) {
            if (previous == null) account.remove(friend); else account[friend] = previous;
            throw e;
        }
    }
}
