import AppearancePresetSerializationHost.AppearancePresetStringFixture;
import itemutilities.AppearancePresetPlan;

class AppearancePresetSerializationPlugin {
    @:hlNative("std", "sys_resolve_type")
    static function resolveType(type:hl.Type, companionType:hl.Type):Dynamic return null;

    static function check(value:Bool, message:String):Void {
        if (!value) throw message;
    }

    static function main():Void {
        var companion:hl.BaseType = cast AppearancePresetStringFixture;
        var host = resolveType(companion.__type__, hl.Type.getDynamic(companion));
        check(host != null, "Host fixture must be available.");
        var item:Dynamic = Reflect.field(host, "item");
        check(Std.string(item) == "Cosmetic_Chest_Test", "Read the host's item ID.");
        check(Type.getClass(item) != String, "Fixture must use a foreign String class.");
        var choices:Map<String, String> = [];
        choices.set(cast Reflect.field(host, "slot"), cast item);
        choices.set("Slot_Head", cast Reflect.field(host, "hidden"));
        choices.set("Slot_Back", null);

        // Exercise the actual save/reload boundary, not just in-memory decode.
        var encoded = AppearancePresetPlan.encode(choices);
        var decoded = AppearancePresetPlan.decode(haxe.Json.parse(haxe.Json.stringify(encoded)));
        check(decoded.get("Slot_Chest") == "Cosmetic_Chest_Test", "Preserve cosmetic item IDs.");
        check(decoded.get("Slot_Head") == "Hide_Gear", "Preserve hidden gear.");
        check(decoded.exists("Slot_Back") && decoded.get("Slot_Back") == null,
            "Preserve default appearances as null.");
        check(AppearancePresetPlan.same(decoded, choices), "Preserve every saved slot.");
        check(choices.get("Slot_Chest") == item, "Encoding must leave the source map intact.");
        Sys.println("Appearance preset cross-module serialization passed.");
    }
}
