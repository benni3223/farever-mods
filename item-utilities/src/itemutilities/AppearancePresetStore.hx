package itemutilities;

class AppearancePresetStore {
    /** Copy first so a failed save cannot erase the running mod's presets. */
    public static function cleared(values:Dynamic, characterId:String):Dynamic {
        return CharacterResetStore.cleared(values, characterId, Appearance);
    }
}
