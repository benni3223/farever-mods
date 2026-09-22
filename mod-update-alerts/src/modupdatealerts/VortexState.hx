package modupdatealerts;

import haxe.io.Path;

/** Reconstruct only Farever's current mod records, never backup snapshots. */
class VortexState {
    public static function read(folder:String, progress:Void->Void):Map<String,Dynamic> {
        var prefix = "persistent###mods###farever";
        var values = new LevelDbSnapshot(Path.join([folder, "state.v2"]), prefix, progress).read();
        var mods:Dynamic = {};
        var keys = [for (key in values.keys()) key]; keys.sort(Reflect.compare);
        for (key in keys) {
            var value:Dynamic = haxe.Json.parse(values[key]);
            if (key == prefix) { mods = value; continue; }
            var parts = key.substr(prefix.length + 3).split("###"), node = mods;
            for (i in 0...parts.length - 1) {
                var next:Dynamic = Reflect.field(node, parts[i]);
                if (next == null) { next = {}; Reflect.setField(node, parts[i], next); }
                node = next;
            }
            Reflect.setField(node, parts[parts.length - 1], value);
        }
        var result:Map<String,Dynamic> = [], ambiguous:Map<String,Bool> = [];
        for (key in Reflect.fields(mods)) {
            var record = Reflect.field(mods, key);
            if (InstalledMods.text(record, "state") != "installed") continue;
            var path = InstalledMods.text(record, "installationPath");
            if (path == "") path = key;
            // A deployment source is the installationPath, not necessarily its
            // original archive ID or mod-record key. Never choose arbitrarily.
            if (result.exists(path)) ambiguous[path] = true;
            result[path] = record;
        }
        for (path in ambiguous.keys()) result.remove(path);
        return result;
    }
}
