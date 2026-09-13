package itemutilities;

class AppearancePresetStore {
    /** Copy first so a failed save cannot erase the running mod's presets. */
    public static function cleared(values:Dynamic, characterId:String):Dynamic {
        if (characterId == null || StringTools.trim(characterId).length == 0)
            throw "A current character is required to reset appearance presets.";
        if (values == null || !Reflect.isObject(values) || Std.isOfType(values, String)
            || Std.isOfType(values, Array)) throw "Item Utilities configuration must be a JSON object.";
        var result:Dynamic = {};
        for (key in Reflect.fields(values))
            Reflect.setField(result, key, Reflect.field(values, key));
        for (key in ["appearancePresets", "selectedAppearancePresets"])
            Reflect.setField(result, key, withoutCharacter(Reflect.field(values, key), characterId));
        return result;
    }

    static function withoutCharacter(values:Dynamic, characterId:String):Array<Dynamic> {
        if (values == null) return [];
        if (!Std.isOfType(values, Array)) throw "Appearance preset storage must be an array.";
        var entries:Array<Dynamic> = cast values;
        return entries.filter(function(entry:Dynamic):Bool {
            // Keep unrecognized records; only an exact character ID permits deletion.
            return entry == null || !Reflect.isObject(entry) || Std.isOfType(entry, String)
                || Std.isOfType(entry, Array) || Reflect.field(entry, "characterId") != characterId;
        });
    }
}
