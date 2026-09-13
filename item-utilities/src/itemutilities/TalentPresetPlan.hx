package itemutilities;

typedef TalentRule = {
    var skill:String;
    var root:String;
    var tier:Int;
    var branch:Int;
    var maxRank:Int;
    var threshold:Int;
}

typedef TalentChange = {
    var skill:String;
    var rank:Int;
    var after:Map<String, Int>;
}

/** Validate the whole saved build before refunding any of the current points. */
class TalentPresetPlan {
    public static function decode(saved:Dynamic):Map<String, Int> {
        if (!Std.isOfType(saved, Array)) throw "This talent preset has invalid data. Save it again.";
        var ranks:Map<String, Int> = [];
        var seen:Map<String, Bool> = [];
        var entries:Array<Dynamic> = cast saved;
        for (entry in entries) {
            var skill:Dynamic = entry == null ? null : Reflect.field(entry, "skill");
            var rank:Dynamic = entry == null ? null : Reflect.field(entry, "rank");
            if (!Std.isOfType(skill, String) || skill == "" || !Std.isOfType(rank, Int)
                || rank < 0 || seen.exists(skill))
                throw "This talent preset has invalid data. Save it again.";
            seen.set(skill, true);
            if (rank > 0) ranks.set(skill, rank);
        }
        return ranks;
    }

    public static function encode(ranks:Map<String, Int>):Array<Dynamic> {
        var keys = [for (skill in ranks.keys()) skill];
        keys.sort(Reflect.compare);
        return [for (skill in keys) {skill: skill, rank: ranks[skill]}];
    }

    public static function same(a:Map<String, Int>, b:Map<String, Int>):Bool {
        if (a == null || b == null) return false;
        for (skill => rank in a) if (b.get(skill) != rank) return false;
        for (skill in b.keys()) if (!a.exists(skill)) return false;
        return true;
    }

    public static function validate(rules:Array<TalentRule>, ranks:Map<String, Int>, total:Int):Void {
        var bySkill:Map<String, TalentRule> = [];
        for (rule in rules) {
            if (bySkill.exists(rule.skill)) throw "The game's talent tree is ambiguous.";
            bySkill.set(rule.skill, rule);
        }
        var points = 0;
        var root:String = null;
        for (skill => rank in ranks) {
            var rule = bySkill.get(skill);
            if (rule == null || rank <= 0 || rank > rule.maxRank)
                throw "This preset contains a talent or rank that is no longer available. Save it again.";
            if (root != null && root != rule.root)
                throw "A talent preset must use a single talent tree.";
            root = rule.root;
            points += rank;
            var lowerPoints = 0;
            for (lower in rules)
                if (lower.root == rule.root && lower.tier < rule.tier
                    && (rule.branch == 0 || lower.branch == 0 || lower.branch == rule.branch)) {
                    var lowerRank = ranks.get(lower.skill);
                    if (lowerRank != null) lowerPoints += lowerRank;
                }
            if (lowerPoints < rule.threshold)
                throw "This talent preset no longer meets the tree's point requirements. Save it again.";
        }
        if (root != null && (!ranks.exists(root) || ranks[root] <= 0))
            throw "This talent preset is missing its root talent. Save it again.";
        if (points > total) throw "Not enough talent points for this preset.";
    }

    public static function build(rules:Array<TalentRule>, current:Map<String, Int>,
        target:Map<String, Int>, total:Int):Array<TalentChange> {
        validate(rules, target, total);
        validate(rules, current, total);
        if (same(current, target)) return [];
        var changes:Array<TalentChange> = [];
        // The normal root-rank removal refunds the entire tree, including
        // dependent tiers. Do not call resetTalents, which directly mutates state.
        for (rule in rules)
            if (rule.skill == rule.root && current.exists(rule.skill))
                changes.push({skill: rule.skill, rank: 0, after: new Map()});
        var ordered = rules.copy();
        ordered.sort(function(a, b) {
            var tier = a.tier - b.tier;
            return tier != 0 ? tier : Reflect.compare(a.skill, b.skill);
        });
        var expected:Map<String, Int> = [];
        for (rule in ordered) {
            var rank = target.get(rule.skill);
            if (rank == null) continue;
            expected.set(rule.skill, rank);
            changes.push({skill: rule.skill, rank: rank, after: expected.copy()});
        }
        return changes;
    }
}
