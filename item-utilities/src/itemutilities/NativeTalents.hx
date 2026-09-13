package itemutilities;

import hlx.runtime.ResolvedMember;
import itemutilities.TalentPresetPlan.TalentRule;

/** Read game definitions and submit the same non-forced RPC as the Talents UI. */
class NativeTalents {
    static inline var SPECIALIZATION = "st.player.HeroSpecialization";
    static var members:Map<String, ResolvedMember> = [];

    static function call(type:String, name:String, object:Dynamic, args:Array<Dynamic>):Dynamic {
        var key = type + "." + name;
        var member = members.get(key);
        if (member == null) {
            var nativeType = HlxRuntime.resolveType(type);
            if (nativeType == null) throw "Game type unavailable: " + type;
            member = HlxRuntime.resolveMember(nativeType, name);
            if (member == null) throw "Game member unavailable: " + key;
            members.set(key, member);
        }
        return HlxRuntime.callResolved(member, [object].concat(args));
    }

    static function field(object:Dynamic, name:String):Dynamic {
        return object == null ? null : HlxRuntime.resolveField(object, name);
    }

    static function arrayGet(array:Dynamic, index:Int):Dynamic {
        return call(hl.Type.getDynamic(array).getTypeName(), "getDyn", array, [index]);
    }

    public static function current(specialization:Dynamic):Map<String, Int> {
        var map = field(field(specialization, "talents"), "map");
        if (map == null) throw "Talents are not ready yet.";
        var iterator = call("haxe.ds.StringMap", "keys", map, []);
        // keys() returns a virtual Iterator. Use its bound functions rather
        // than assuming a concrete iterator class across HL modules.
        var hasNext = field(iterator, "hasNext");
        var next = field(iterator, "next");
        if (hasNext == null || next == null) throw "Unable to read talent ranks.";
        var ranks:Map<String, Int> = [];
        while (Reflect.callMethod(null, hasNext, []) == true) {
            var skill:String = cast Reflect.callMethod(null, next, []);
            var rank:Int = cast call("haxe.ds.StringMap", "get", map, [skill]);
            if (rank > 0) ranks.set(skill, rank);
        }
        return ranks;
    }

    public static function totalPoints(specialization:Dynamic):Int {
        return cast call(SPECIALIZATION, "getTotalTalentPoints", specialization, []);
    }

    public static function rules(hero:Dynamic):Array<TalentRule> {
        var trees = field(field(hero, "inf"), "talentTrees");
        var dataType = HlxRuntime.resolveType("Data");
        var constType = HlxRuntime.resolveType("Const");
        if (trees == null || dataType == null || constType == null)
            throw "The talent tree is not available yet.";
        var skills = field(HlxRuntime.resolveStaticField(dataType, "skill"), "byId");
        var thresholds = field(HlxRuntime.resolveStaticField(constType, "Hero"), "Talents_TierThresholds");
        if (skills == null || thresholds == null) throw "The talent rules are not available yet.";
        var result:Array<TalentRule> = [];
        var treeCount:Int = cast field(trees, "length");
        var thresholdCount:Int = cast field(thresholds, "length");
        for (i in 0...treeCount) {
            var tree = arrayGet(trees, i);
            var talents = field(tree, "talents");
            var count:Int = cast field(talents, "length");
            for (j in 0...count) {
                var talent = arrayGet(talents, j);
                var skill:String = cast field(talent, "skill");
                var definition = call("haxe.ds.StringMap", "get", skills, [skill]);
                // Match the native setTalentRank validation (Talent type = 21).
                if (definition == null || field(definition, "type") != 21
                    || field(field(definition, "texts"), "name") == null) continue;
                var props = field(field(definition, "props"), "talent");
                var tier:Int = cast field(talent, "tier");
                if (tier < 0 || tier >= thresholdCount) throw "Unknown talent tier.";
                var threshold:Float = cast arrayGet(thresholds, tier);
                result.push({skill: skill, root: cast field(tree, "root"), tier: tier,
                    branch: cast field(talent, "branch"),
                    maxRank: props == null ? 1 : cast field(props, "maxPoints"),
                    threshold: Std.int(Math.ceil(threshold))});
            }
        }
        if (result.length == 0) throw "This character has no available talent tree.";
        return result;
    }

    public static function setRank(specialization:Dynamic, skill:String, rank:Int,
        callback:Bool->Void):Void {
        // null is the native optional 'force = false'. Never mutate talents or
        // call the implementation/reset helpers directly on the client.
        call(SPECIALIZATION, "setTalentRank", specialization, [skill, rank, null, callback]);
    }
}
