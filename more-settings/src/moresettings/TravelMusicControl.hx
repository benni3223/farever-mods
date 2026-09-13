package moresettings;

import moresettings.GameAccess as G;
import moresettings.SettingsData.MoreSettingsConfig;

/** Owns only the local hero's Hero_FlyToObelisk event, never a shared bus/VCA. */
class TravelMusicControl {
    var sound:Dynamic;
    var handle:Dynamic;
    var saved:Float = 1;
    var lastGain:Null<Float>;

    public function new() {}

    public function update(hero:Dynamic, config:MoreSettingsConfig):Void {
        var next = hero == null || G.field(hero, "removed") == true ? null : G.field(hero, "flySoundObj");
        var nextHandle = EventVolume.handle(next);
        if (sound != next || !EventVolume.sameHandle(handle, nextHandle)) {
            dispose();
            sound = next;
            handle = nextHandle;
        }
        configure(config);
    }

    public function configure(config:MoreSettingsConfig):Void {
        // A released/recreated event must never receive the previous event's saved volume.
        if (handle == null || !EventVolume.sameHandle(handle, EventVolume.handle(sound))) {
            sound = null; handle = null; lastGain = null;
            return;
        }
        var gain:Null<Float> = config.adjustFastTravelVolume ? SettingsData.percent(config.fastTravelVolume) / 100 : null;
        if (gain == lastGain) return;
        if (lastGain == null) {
            saved = EventVolume.get(handle);
            if (!Math.isFinite(saved) || saved < 0) throw "Cannot read fast travel music volume";
        }
        if (!EventVolume.set(handle, gain == null ? saved : saved * gain))
            throw "Cannot adjust fast travel music volume";
        lastGain = gain;
    }

    public function dispose():Void {
        var restore = lastGain != null && handle != null && EventVolume.sameHandle(handle, EventVolume.handle(sound));
        var oldHandle = handle;
        sound = null; handle = null; lastGain = null;
        // FMOD may already have released a stopped event; restoring that handle is a no-op.
        if (restore) EventVolume.set(oldHandle, saved);
    }
}
