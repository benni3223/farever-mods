package itemutilities;

class AppearancePresetStore {
    /** Copy first so a failed save cannot erase the running mod's presets. */
    public static function cleared(values:Dynamic):Dynamic {
        if (values == null || !Reflect.isObject(values) || Std.isOfType(values, String)
            || Std.isOfType(values, Array)) throw "Item Utilities configuration must be a JSON object.";
        var result:Dynamic = {};
        for (key in Reflect.fields(values))
            Reflect.setField(result, key, Reflect.field(values, key));
        Reflect.setField(result, "appearancePresets", []);
        Reflect.setField(result, "selectedAppearancePresets", []);
        return result;
    }
}
