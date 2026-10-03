import SkillPresetSerializationHost.SkillPresetStringFixture;
import itemutilities.SkillPresetPlan;
import itemutilities.SkillPresetPlan.SkillPresetState;
import itemutilities.SkillPresetPlan.SkillPresetRules;

class SkillPresetSerializationPlugin {
    @:hlNative("std", "sys_resolve_type")
    static function resolveType(type:hl.Type, companionType:hl.Type):Dynamic return null;

    static function check(value:Bool, message:String):Void {
        if (!value) throw message;
    }

    static function main():Void {
        var companion:hl.BaseType = cast SkillPresetStringFixture;
        var host = resolveType(companion.__type__, hl.Type.getDynamic(companion));
        check(host != null, "Host fixture must be available.");
        var skill:String = cast Reflect.field(host, "skill");
        var firstRune:String = cast Reflect.field(host, "firstRune");
        var secondRune:String = cast Reflect.field(host, "secondRune");
        var otherRune:String = cast Reflect.field(host, "otherRune");
        var owners:Map<String, String> = [];
        owners.set(firstRune, skill);
        owners.set(secondRune, skill);
        owners.set(otherRune, cast Reflect.field(host, "otherSkill"));
        check(Type.getClass(skill) != String && Type.getClass(firstRune) != String,
            "Fixture must use foreign skill and rune String classes.");
        var rules:SkillPresetRules = {
            skills: [skill => [firstRune, secondRune]],
            unlockedSlots: [true, true, true, true], maxRunes: 2
        };

        for (runes in [[], [firstRune], [secondRune], [firstRune, secondRune]]) {
            var current:SkillPresetState = {slots: [skill, null, null, null], runes: runes.concat([otherRune])};
            var encoded = SkillPresetPlan.saved(current, owners);
            // Applying immediately and applying after a login use different paths.
            var immediate = SkillPresetPlan.decode(encoded);
            var restored = SkillPresetPlan.decode(haxe.Json.parse(haxe.Json.stringify(encoded)));
            for (target in [immediate, restored]) {
                check(target[0].skill == "ClassSkill_Test", "Preserve the skill ID.");
                check(target[0].runes.join(",") == runes.join(","), "Preserve the exact rune selection.");
                check(Std.isOfType(target[0].skill, String), "Save a local skill String.");
                for (rune in target[0].runes) check(Std.isOfType(rune, String), "Save local rune Strings.");
                for (slot in target.slice(1))
                    check(slot.skill == null && slot.runes.length == 0, "Keep empty slots null.");
                SkillPresetPlan.validate(target, rules);
                check(SkillPresetPlan.build(current, target, rules, owners).length == 0,
                    "An unchanged native skill/rune selection sends no requests.");
            }
            check(Type.getClass(current.slots[0]) != String, "Saving leaves the game-owned state intact.");
        }

        var current:SkillPresetState = {slots: [skill, null, null, null], runes: [firstRune, otherRune]};
        var target = SkillPresetPlan.decode(haxe.Json.parse(haxe.Json.stringify(
            SkillPresetPlan.saved({slots: current.slots, runes: [secondRune, otherRune]}, owners))));
        var changes = SkillPresetPlan.build(current, target, rules, owners);
        check(changes.length == 2, "Changing only a rune requires exactly two requests.");
        check(changes[0].slot == -1 && !changes[0].enable && changes[0].rune == firstRune,
            "Remove the previous rune before enabling the saved rune.");
        check(changes[1].slot == -1 && changes[1].enable && changes[1].rune == secondRune,
            "Enable the saved replacement rune without changing skill slots.");
        check(SkillPresetPlan.same(changes[1].after,
            {slots: current.slots, runes: [secondRune, otherRune]}),
            "Preserve rune preferences belonging to unequipped skills.");
        Sys.println("Skill preset cross-module serialization passed.");
    }
}
