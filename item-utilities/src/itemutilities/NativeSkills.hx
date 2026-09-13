package itemutilities;

import hlx.runtime.ResolvedMember;
import itemutilities.SkillPresetPlan.SkillPresetState;
import itemutilities.SkillPresetPlan.SkillPresetRules;
import itemutilities.SkillPresetPlan.SkillPresetChange;

/** Bridge to the class skill UI's slot setter and normal rune RPC. */
class NativeSkills {
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

    static function arrayLength(array:Dynamic):Int return array == null ? 0 : cast field(array, "length");

    static function strings(array:Dynamic):Array<String> {
        if (array == null) throw "The character's skills are not ready yet.";
        return [for (i in 0...arrayLength(array)) cast arrayGet(array, i)];
    }

    static function staticField(type:String, name:String):Dynamic {
        var nativeType = HlxRuntime.resolveType(type);
        if (nativeType == null) throw "Game type unavailable: " + type;
        return HlxRuntime.resolveStaticField(nativeType, name);
    }

    static function definition(skill:String):Dynamic {
        var map = field(staticField("Data", "skill"), "byId");
        return call("haxe.ds.StringMap", "get", map, [skill]);
    }

    public static function current(specialization:Dynamic):SkillPresetState {
        // Read replicated specialization data, never the optimistic hero.slot
        // cache: a local UI update is not confirmation of a server change.
        var slots = strings(field(field(specialization, "skillSlots"), "array"));
        var runes = strings(field(field(specialization, "skillMasteries"), "array"));
        return {slots: [for (i in 0...SkillPresetPlan.SLOT_COUNT) i < slots.length ? slots[i] : null],
            runes: runes};
    }

    public static function ensureSynchronized(hero:Dynamic, state:SkillPresetState):Void {
        var visible = field(hero, "skillSlots");
        for (i in 0...SkillPresetPlan.SLOT_COUNT) {
            var skill:String = i < arrayLength(visible) ? cast arrayGet(visible, i) : null;
            if (skill != state.slots[i]) throw "Wait for the pending skill change before using a preset.";
        }
    }

    public static function runeSkills(runes:Array<String>):Map<String, String> {
        var map = staticField("DataCache", "SKILLS_MASTERIES");
        var result:Map<String, String> = [];
        for (rune in runes) {
            var info = call("haxe.ds.StringMap", "get", map, [rune]);
            if (info == null) throw "An equipped rune is no longer available.";
            result.set(rune, cast field(info, "skill"));
        }
        return result;
    }

    public static function rules(hero:Dynamic):SkillPresetRules {
        var level:Int = cast call("ent.Unit", "get_level", hero, []);
        var skills = field(field(hero, "inf"), "skills");
        var progress = field(field(hero, "player"), "progress");
        var learned = strings(field(field(progress, "skillMasteriesLearnt"), "array"));
        var result:Map<String, Array<String>> = [];
        if (skills == null) throw "The character's skills are not ready yet.";
        for (i in 0...arrayLength(skills)) {
            var entry = arrayGet(skills, i);
            var skill:String = cast field(entry, "skill");
            var unlock:Dynamic = field(entry, "level");
            if (unlock != null && level < (cast unlock:Int)) continue;
            var inf = definition(skill);
            // HeroSkillSlots use type 11; matchSlotTypes permits class type 9.
            // Signature skills, weapons, prayers, and conduits have other UIs.
            if (inf == null || field(inf, "type") != 9) continue;
            var runes:Array<String> = [];
            var runeLevel:Dynamic = field(entry, "masteriesLevel");
            if (runeLevel == null || level >= (cast runeLevel:Int)) {
                var definitions = field(inf, "mastery");
                for (j in 0...arrayLength(definitions)) {
                    var rune:String = cast field(arrayGet(definitions, j), "id");
                    if (learned.indexOf(rune) >= 0) runes.push(rune);
                }
            }
            result.set(skill, runes);
        }
        var secondRune:Float = cast field(staticField("Const", "Hero"), "UnlockLevel_SecondMastery");
        return {skills: result,
            unlockedSlots: [for (i in 0...SkillPresetPlan.SLOT_COUNT)
                call("ent.Hero", "isSkillInputUnlocked", hero, ["Skill" + (i + 1)]) == true],
            maxRunes: level >= secondRune ? 2 : 1};
    }

    public static function ensureCanApply(hero:Dynamic):Void {
        if (field(hero, "isInCombat") == true) throw "Skill presets cannot be applied during combat.";
    }

    public static function apply(hero:Dynamic, change:SkillPresetChange, callback:Bool->Void):Void {
        ensureCanApply(hero);
        if (change.slot >= 0) {
            if (change.slot >= SkillPresetPlan.SLOT_COUNT) throw "Invalid skill slot.";
            if (change.skill != null) {
                var inf = definition(change.skill);
                if (inf == null || call("ent.Hero", "canPickSkill", hero, [inf, null, 11]) != true)
                    throw "The game does not allow this skill change right now.";
            }
            // Same setter as requestPickSkill: normal owned-object RPC plus
            // the native immediate UI cache update. Confirmation reads the
            // specialization's replicated array. No fake acknowledgement.
            call("ent.Hero", "setSkillSlot", hero, [change.skill, change.slot]);
        } else {
            call("ent.Hero", "toggleSkillMastery", hero, [change.rune, change.enable, callback]);
        }
    }
}
