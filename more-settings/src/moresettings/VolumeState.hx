package moresettings;

import moresettings.SettingsData.MoreSettingsConfig;

/** Saves and restores the master volume while the game is unfocused. */
class VolumeState {
    public var active(default, null):Bool = false;
    public var saved(default, null):Float = 1;

    public function new() {}

    public static function target(config:MoreSettingsConfig, focused:Bool):Null<Float> {
        return !focused && config.adjustUnfocusedVolume ? SettingsData.percent(config.backgroundVolume) / 100 : null;
    }

    public function apply(current:Float, target:Null<Float>):Float {
        if (target == null) {
            if (!active) return current;
            active = false;
            return saved;
        }
        if (!active) { saved = current; active = true; }
        // Temporary limits never make a quieter master setting louder.
        return Math.min(saved, target);
    }

    public function masterChanged(current:Float):Void {
        if (active) saved = current;
    }
}
