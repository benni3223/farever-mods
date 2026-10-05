package moresettings;

import sys.thread.Thread;

/** Thread gate around the pure timing buffer; background compilation is never touched. */
class StallMetrics {
    public static var enabled(default, null) = false;
    static var metrics:FrameMetrics;
    static var mainThread:Null<Thread>;

    public static function configure(value:Bool):Void {
        if (enabled == value) return;
        enabled = value;
        metrics = value ? new FrameMetrics() : null;
    }
    static inline function onMain():Bool return enabled && mainThread != null && Thread.current() == mainThread;
    public static function beginFrame():Void {
        if (!enabled) return;
        if (mainThread == null) mainThread = Thread.current();
        if (onMain()) metrics.beginFrame();
    }
    public static function context(gameplay:Bool, combat:Bool, optimization:Bool):Void {
        if (onMain()) metrics.context(gameplay, combat, optimization);
    }
    public static function begin(id:Int):Void { if (onMain()) metrics.begin(id); }
    public static function end(id:Int):Void { if (onMain()) metrics.end(id); }
    public static function endFrame():Void {
        if (!onMain()) return;
        metrics.endFrame();
        if (!metrics.canReport()) return;
        // No disk writes, formatting, stack walks or telemetry while in combat.
        try {
            var line = metrics.report();
            if (line != null) trace(line);
        } catch (_:Dynamic) {
            // Diagnostics must never turn an output failure into a game failure.
            enabled = false;
        }
        metrics.reported();
    }
    public static function suspend():Void { if (onMain()) metrics.suspend(); }
}
