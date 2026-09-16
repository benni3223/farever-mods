package minimap;

/** Seconds throughout, matching Time.serverTime and WorldEvent's native timers. */
class RiftTiming {
    public static function untilNext(serverTime:Float, period:Float):Float {
        if (!Math.isFinite(serverTime) || !Math.isFinite(period) || period <= 0) return Math.NaN;
        return period - ((serverTime % period + period) % period);
    }

    public static function caption(seconds:Float):String {
        if (!Math.isFinite(seconds)) return "";
        var value = Math.ceil(Math.max(0, seconds));
        return StringTools.lpad(Std.string(Std.int(value / 60)), "0", 2) + ":"
            + StringTools.lpad(Std.string(value % 60), "0", 2);
    }

    public static function alert(seconds:Float):Bool
        return Math.isFinite(seconds) && seconds >= 0 && seconds <= 15 * 60;
}
