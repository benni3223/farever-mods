package moresettings;

typedef MoreSettingsConfig = {
    var quickCast:Bool;
    var disableTargetLockCameraMovement:Bool;
    var fancyDamageNumbers:Bool;
    var rawTopColour:String;
    var rawBottomColour:String;
    var rawCriticalTopColour:String;
    var rawCriticalMiddleColour:String;
    var rawCriticalBottomColour:String;
    var disableProfanityFilter:Bool;
    var showBossHealth:Bool;
    var performanceOptimization:Bool;
    var waitForParty:Bool;
    var hideUiKey:Int;
    var adjustUnfocusedVolume:Bool;
    var backgroundVolume:Float;
    var adjustFastTravelVolume:Bool;
    var fastTravelVolume:Float;
    var riftHideAllyAttacks:Bool;
    var riftHideAllyBuffs:Bool;
    var riftHideAllies:Bool;
    var dungeonHideAllyAttacks:Bool;
    var dungeonHideAllyBuffs:Bool;
    var dungeonHideAllies:Bool;
    var overworldHideAllyAttacks:Bool;
    var overworldHideAllyBuffs:Bool;
    var overworldHideAllies:Bool;
}

class SettingsData {
    public static function defaults():MoreSettingsConfig return {
        quickCast: false,
        disableTargetLockCameraMovement: false,
        fancyDamageNumbers: false,
        rawTopColour: "",
        rawBottomColour: "",
        rawCriticalTopColour: "",
        rawCriticalMiddleColour: "",
        rawCriticalBottomColour: "",
        disableProfanityFilter: true,
        showBossHealth: false,
        performanceOptimization: false,
        waitForParty: true,
        hideUiKey: 113, // hxd.Key.F2
        adjustUnfocusedVolume: true, backgroundVolume: 0,
        adjustFastTravelVolume: false, fastTravelVolume: 0,
        riftHideAllyAttacks: false, riftHideAllyBuffs: false, riftHideAllies: false,
        dungeonHideAllyAttacks: false, dungeonHideAllyBuffs: false, dungeonHideAllies: false,
        overworldHideAllyAttacks: false, overworldHideAllyBuffs: false, overworldHideAllies: false
    };

    public static function percent(value:Float):Float
        return Math.isFinite(value) ? Math.max(0, Math.min(100, value)) : 0;

    static var rgbHex = ~/^[0-9a-fA-F]{6}$/;

    /** Invalid or unfinished input uses the preset without rewriting saved text. */
    public static function hexColour(value:Dynamic, fallback:Int):Int {
        if (!Std.isOfType(value, String)) return fallback;
        var hex = StringTools.trim(cast value);
        if (StringTools.startsWith(hex, "#")) hex = hex.substr(1);
        else if (hex.substr(0, 2).toLowerCase() == "0x") hex = hex.substr(2);
        if (!rgbHex.match(hex)) return fallback;
        var colour = Std.parseInt("0x" + hex);
        return colour == null ? fallback : colour;
    }

    public static function normalize(config:MoreSettingsConfig):Void {
        // Inspect raw fields before typed String access to recover damaged input.
        // New Raw fields are independent of the retired physical/magical inputs.
        for (key in ["rawTopColour", "rawBottomColour", "rawCriticalTopColour",
            "rawCriticalMiddleColour", "rawCriticalBottomColour"]) {
            if (!Std.isOfType(Reflect.field(config, key), String))
                Reflect.setField(config, key, "");
        }
        // Same single-key range as Better Mod Settings; zero means unassigned.
        if (config.hideUiKey < 0 || config.hideUiKey >= 512 || config.hideUiKey == 27) config.hideUiKey = 113;
        config.backgroundVolume = percent(config.backgroundVolume);
        config.fastTravelVolume = percent(config.fastTravelVolume);
    }
}
