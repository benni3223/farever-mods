package dpsmeter;

typedef SkillNameDefinition = {name:String, nameRef:String, source:String};

/** Resolve presentation metadata without changing the recorded damage-source ID. */
class SkillNames {
    public static function resolve(id:String, lookup:String->Null<SkillNameDefinition>):String {
        var seen:Map<String, Bool> = [];
        function visit(key:String):String {
            if (key == "" || seen.exists(key) || Lambda.count(seen) >= 16) return "";
            seen[key] = true;
            var inf = lookup(key);
            if (inf == null) return "";
            var name = StringTools.trim(inf.name);
            var reference = ~/^\[([A-Za-z0-9_]+)\]$/;
            if (reference.match(name)) {
                var resolved = visit(reference.matched(1));
                if (resolved != "") return resolved;
            } else if (name != "" && name != key) return name;
            for (ref in [inf.nameRef, inf.source]) {
                var resolved = visit(ref);
                if (resolved != "") return resolved;
            }
            return "";
        }
        var name = visit(id);
        return name != "" ? name : id == "" ? "Unknown ability" : StringTools.replace(id, "_", " ");
    }
}
