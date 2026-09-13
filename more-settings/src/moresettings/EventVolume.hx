package moresettings;

/** The game's Haxe FMOD wrapper does not expose per-event volume. */
class EventVolume {
    public static function handle(sound:Dynamic):Dynamic {
        var instance = GameAccess.field(sound, "inst");
        return instance == null ? null : HlxRuntime.unboxPointer(instance);
    }

    public static function sameHandle(a:Dynamic, b:Dynamic):Bool {
        var left:hl.Bytes = cast a;
        var right:hl.Bytes = cast b;
        return left == right;
    }

    public static function get(handle:Dynamic):Float return getVolume(cast handle);
    public static function set(handle:Dynamic, volume:Float):Bool return setVolume(cast handle, volume);

    @:hlNative("?more_settings_audio", "event_get_volume")
    static function getVolume(handle:hl.Bytes):Float return -1;

    @:hlNative("?more_settings_audio", "event_set_volume")
    static function setVolume(handle:hl.Bytes, volume:Float):Bool return false;
}
