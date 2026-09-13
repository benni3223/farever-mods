package moresettings;

import moresettings.GameAccess as G;
import moresettings.SettingsData.MoreSettingsConfig;

class AudioControl {
    static inline var MASTER = "vca:/MASTER";
    var state = new VolumeState();
    var lastTarget:Null<Float> = null;
    var config:MoreSettingsConfig;
    var focused:Bool = true;
    var travelMusic = new TravelMusicControl();

    public function new(config:MoreSettingsConfig) this.config = config;

    public function configure(config:MoreSettingsConfig):Void {
        this.config = config;
        apply();
        travelMusic.configure(config);
    }

    public function update(hero:Dynamic):Void {
        var window = G.staticCall("hxd.Window", "getInstance", []);
        focused = window == null || G.call("hxd.Window", "get_isFocused", window) == true;
        apply();
        travelMusic.update(hero, config);
    }

    public function startTravel(hero:Dynamic):Void travelMusic.update(hero, config);

    public function masterChanged():Void {
        if (!state.active) return;
        var current:Float = G.staticCall("fmod.Api", "getVcaVolume", [MASTER]);
        state.masterChanged(current);
        apply(true);
    }

    function apply(force:Bool = false):Void {
        var target = VolumeState.target(config, focused);
        if (!force && lastTarget == target) return;
        var current:Float = G.staticCall("fmod.Api", "getVcaVolume", [MASTER]);
        var volume = state.apply(current, target);
        if (current != volume) G.staticCall("fmod.Api", "setVcaVolume", [MASTER, volume]);
        lastTarget = target;
    }

    public function dispose():Void {
        travelMusic.dispose();
        if (!state.active) return;
        var current:Float = G.staticCall("fmod.Api", "getVcaVolume", [MASTER]);
        G.staticCall("fmod.Api", "setVcaVolume", [MASTER, state.apply(current, null)]);
        lastTarget = null;
    }
}
