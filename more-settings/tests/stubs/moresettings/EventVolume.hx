package moresettings;

class EventVolume {
    public static var reads:Int = 0;
    public static var writes:Int = 0;
    public static var available:Bool = true;
    public static function handle(sound:Dynamic):Dynamic return GameAccess.field(sound, "inst");
    public static function sameHandle(a:Dynamic, b:Dynamic):Bool return a == b;
    public static function get(handle:Dynamic):Float {
        reads++;
        return available && handle != null && handle.valid ? handle.volume : -1;
    }
    public static function set(handle:Dynamic, volume:Float):Bool {
        if (!available || handle == null || !handle.valid) return false;
        writes++; handle.volume = volume; return true;
    }
}
