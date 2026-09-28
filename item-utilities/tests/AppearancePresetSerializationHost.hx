// A separate HashLink module owns these strings, just as the game does.
@:keep
class AppearancePresetStringFixture {
    public static var slot:String;
    public static var item:String;
    public static var hidden:String;
}

class AppearancePresetSerializationHost {
    @:hlNative("std", "sys_load_plugin")
    static function loadPlugin(path:hl.Bytes):Bool return false;

    static function main():Void {
        AppearancePresetStringFixture.slot = "Slot_Chest";
        AppearancePresetStringFixture.item = "Cosmetic_Chest_Test";
        AppearancePresetStringFixture.hidden = "Hide_Gear";
        if (!loadPlugin(@:privateAccess "build/appearance-serialization-plugin.hl".bytes))
            throw "Unable to load appearance serialization test plugin.";
    }
}
