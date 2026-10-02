// A separate HashLink module owns these strings, just as the game does.
@:keep
class SkillPresetStringFixture {
    public static var skill:String;
    public static var firstRune:String;
    public static var secondRune:String;
    public static var otherSkill:String;
    public static var otherRune:String;
}

class SkillPresetSerializationHost {
    @:hlNative("std", "sys_load_plugin")
    static function loadPlugin(path:hl.Bytes):Bool return false;

    static function main():Void {
        SkillPresetStringFixture.skill = "ClassSkill_Test";
        SkillPresetStringFixture.firstRune = "ClassSkill_Test_Rune1";
        SkillPresetStringFixture.secondRune = "ClassSkill_Test_Rune2";
        SkillPresetStringFixture.otherSkill = "ClassSkill_Other";
        SkillPresetStringFixture.otherRune = "ClassSkill_Other_Rune1";
        if (!loadPlugin(@:privateAccess "build/skill-serialization-plugin.hl".bytes))
            throw "Unable to load skill serialization test plugin.";
    }
}
