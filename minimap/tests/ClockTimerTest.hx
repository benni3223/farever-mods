import haxe.Json;
import minimap.ClockTimer;
import minimap.RiftTiming;

class ClockTimerTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, message:String):Void {
        checks++;
        if (actual != expected) throw message + ': expected $expected, got $actual';
    }

    static function main():Void {
        eq(ClockTimer.mode(null, true), "Rift timer", "Preserve an enabled legacy timer");
        eq(ClockTimer.mode(null, false), "None", "Preserve a disabled legacy timer");
        eq(ClockTimer.mode(null, null), "Rift timer", "New installs retain the default timer");
        for (mode in ["None", "Rift timer", "Clock"]) {
            for (legacy in [true, false]) {
                var config:Dynamic = Json.parse(Json.stringify({clockTimerMode: mode, showRiftTimer: legacy}));
                eq(ClockTimer.mode(config.clockTimerMode, config.showRiftTimer), mode,
                    "Explicit saved choice takes precedence over the obsolete checkbox");
            }
        }
        for (invalid in ([null, "clock", "", 0, true, {bytes: "???", length: 5}]:Array<Dynamic>)) {
            eq(ClockTimer.mode(invalid, true), "Rift timer", "Invalid choice falls back safely");
            eq(ClockTimer.mode(invalid, false), "None", "Invalid choice respects legacy false");
        }

        for (sample in [
            {hour: 0, minute: 0, expected: "00:00"},
            {hour: 9, minute: 5, expected: "09:05"},
            {hour: 12, minute: 34, expected: "12:34"},
            {hour: 23, minute: 59, expected: "23:59"}
        ]) {
            // Date's constructor and getters use local time, regardless of the test machine's zone.
            var now = new Date(2026, 8, 29, sample.hour, sample.minute, 59);
            eq(ClockTimer.caption("Clock", Math.NaN, now), sample.expected,
                "Clock reads local hours and minutes even without Rift timing");
            eq(ClockTimer.caption("Clock", 494, now), sample.expected,
                "Synchronized Rift countdown never replaces local wall time");
            eq(ClockTimer.caption("None", 494, now), "", "None hides the caption");
            eq(ClockTimer.caption("Rift timer", 494, now), "08:14", "Rift countdown ignores local clock");
        }
        var beforeMidnight = new Date(2026, 8, 29, 23, 59, 59);
        eq(ClockTimer.caption("Clock", 1, Date.fromTime(beforeMidnight.getTime() + 1000)), "00:00",
            "Local clock rolls over at midnight");
        for (seconds in [Math.NaN, -1., 0., 59.1, 900., 3600.])
            eq(ClockTimer.caption("Rift timer", seconds), RiftTiming.caption(seconds),
                "Existing Rift formatting is unchanged");
        Sys.println('Clock/timer: $checks checks passed.');
    }
}
