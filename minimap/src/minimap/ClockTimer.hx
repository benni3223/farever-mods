package minimap;

/** Local wall time for Clock; the existing synchronized Rift countdown for Timer. */
class ClockTimer {
    public static function mode(value:Dynamic, legacyShowRiftTimer:Dynamic):String {
        if (Std.isOfType(value, String)) switch (cast(value, String)) {
            case "None", "Rift timer", "Clock": return cast value;
        }
        return legacyShowRiftTimer == false ? "None" : "Rift timer";
    }

    public static function caption(mode:String, remaining:Float, ?localTime:Date):String {
        return switch (mode) {
            case "Clock":
                var now = localTime == null ? Date.now() : localTime;
                StringTools.lpad(Std.string(now.getHours()), "0", 2) + ":"
                    + StringTools.lpad(Std.string(now.getMinutes()), "0", 2);
            case "Rift timer": RiftTiming.caption(remaining);
            default: "";
        };
    }
}
