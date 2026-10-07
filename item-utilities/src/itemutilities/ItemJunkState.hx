package itemutilities;

typedef JunkRule = {
    var characterId:String;
    var kind:String;
    var fingerprint:String;
}

/** Persistent exact-item templates, independent of transient item/stack IDs. */
class ItemJunkState {
    var rules:Array<JunkRule> = [];
    var index:Map<String, Map<String, Map<String, Bool>>> = [];
    public function new() {}

    public function load(value:Dynamic):Void {
        rules = []; index = [];
        if (!Std.isOfType(value, Array)) return;
        for (row in (cast value:Array<Dynamic>)) {
            if (row == null) continue;
            var character:Dynamic = Reflect.field(row, "characterId");
            var kind:Dynamic = Reflect.field(row, "kind");
            var fingerprint:Dynamic = Reflect.field(row, "fingerprint");
            if (!Std.isOfType(character, String) || !StringTools.startsWith(character, "db:")
                || !Std.isOfType(kind, String) || kind == ""
                || !Std.isOfType(fingerprint, String) || !StringTools.startsWith(fingerprint, "junk-v1:")) continue;
            set(character, kind, fingerprint, true);
        }
    }

    public function hasKind(character:String, kind:String):Bool {
        if (character == null || kind == null) return false;
        var kinds = index.get(character);
        return kinds != null && kinds.exists(kind);
    }

    public function matches(character:String, kind:String, fingerprint:String, locked:Bool = false):Bool {
        if (locked || fingerprint == null || !hasKind(character, kind)) return false;
        return index[character][kind].exists(fingerprint);
    }

    public function set(character:String, kind:String, fingerprint:String, junk:Bool):Void {
        if (character == null || kind == null || fingerprint == null) return;
        if (junk) {
            if (matches(character, kind, fingerprint)) return;
            if (!index.exists(character)) index.set(character, new Map<String, Map<String, Bool>>());
            if (!index[character].exists(kind)) index[character].set(kind, new Map<String, Bool>());
            index[character][kind][fingerprint] = true;
            rules.push({characterId: Std.string(character), kind: Std.string(kind), fingerprint: Std.string(fingerprint)});
        } else {
            if (!hasKind(character, kind)) return;
            index[character][kind].remove(fingerprint);
            if (!index[character][kind].iterator().hasNext()) index[character].remove(kind);
            rules = [for (rule in rules) if (rule.characterId != character || rule.kind != kind
                || rule.fingerprint != fingerprint) rule];
        }
    }

    public function saved():Array<Dynamic>
        return [for (rule in rules) {characterId: rule.characterId, kind: rule.kind, fingerprint: rule.fingerprint}];
}
