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
        refreshFocus();
        apply();
        travelMusic.configure(config);
    }

    public function update(hero:Dynamic):Void {
        refreshFocus();
        apply();
        travelMusic.update(hero, config);
    }

    function refreshFocus():Void {
        var window = G.staticCall("hxd.Window", "getInstance", []);
        focused = window == null || G.call("hxd.Window", "get_isFocused", window) == true;
    }

    public function startTravel(hero:Dynamic):Void travelMusic.update(hero, config);

    public function masterChanged():Void {
        // Options.applyAudio also runs before FMOD starts. Its setters guard
        // initialization, but getVcaVolume dereferences the system immediately.
        if (!audioReady()) return;
        refreshFocus();
        if (!state.active && VolumeState.target(config, focused) == null) return;
        var current:Float = G.staticCall("fmod.Api", "getVcaVolume", [MASTER]);
        state.masterChanged(nativeMuted() ? configuredMaster(current) : current);
        apply(true);
    }

    function audioReady():Bool return G.current("fmod.Api", "initialized") == true;

    function nativeMuted():Bool {
        // Missing on the live client. Reading the option never changes or
        // persists the player's native focus preference.
        return !focused && G.current("Options", "audioRequireFocus") == true;
    }

    function configuredMaster(fallback:Float):Float {
        // PTR applyAudio writes zero while unfocused. Recover its configured
        // baseline rather than saving that temporary mute as the master level.
        var options = G.field(G.current("Data", "option"), "byId");
        var inf = options == null ? null : G.call("haxe.ds.StringMap", "get", options, ["AudioMaster"]);
        var maximum = G.number(G.field(G.field(inf, "props"), "maxVal"));
        var value = G.number(G.current("Options", "audioMaster"), Math.NaN);
        return maximum > 0 && Math.isFinite(value) ? Math.max(0, Math.min(1, value / maximum)) : fallback;
    }

    function apply(force:Bool = false):Void {
        var target = VolumeState.target(config, focused);
        if (!force && lastTarget == target) return;
        if (!audioReady()) return;
        var current:Float = G.staticCall("fmod.Api", "getVcaVolume", [MASTER]);
        var muted = nativeMuted();
        var baseline = muted ? configuredMaster(current) : current;
        if (muted) state.masterChanged(baseline);
        var volume = state.apply(baseline, target);
        // Disabling our override hands control back to the native mute.
        if (muted && target == null) volume = 0;
        if (current != volume) G.staticCall("fmod.Api", "setVcaVolume", [MASTER, volume]);
        lastTarget = target;
    }

    public function dispose():Void {
        travelMusic.dispose();
        if (!state.active) return;
        if (!audioReady()) {
            state = new VolumeState();
            lastTarget = null;
            return;
        }
        refreshFocus();
        var current:Float = G.staticCall("fmod.Api", "getVcaVolume", [MASTER]);
        var restored = state.apply(current, null);
        G.staticCall("fmod.Api", "setVcaVolume", [MASTER, nativeMuted() ? 0.0 : restored]);
        lastTarget = null;
    }
}
