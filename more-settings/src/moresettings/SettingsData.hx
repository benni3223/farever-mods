package moresettings;

typedef MoreSettingsConfig = {
    var quickCast:Bool;
    var disableTargetLockCameraMovement:Bool;
    var fancyDamageNumbers:Bool;
    var pinkCrits:Bool;
    var threeColourCriticals:Bool;
    var criticalLightColour:String;
    var criticalMiddleColour:String;
    var criticalDarkColour:String;
    var magicalCriticalLightColour:String;
    var magicalCriticalMiddleColour:String;
    var magicalCriticalDarkColour:String;
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
        pinkCrits: false,
        threeColourCriticals: false,
        criticalLightColour: "",
        criticalMiddleColour: "",
        criticalDarkColour: "",
        // Null identifies a missing preference on the first load after splitting
        // crit colours. normalize copies the former shared colours once.
        magicalCriticalLightColour: null,
        magicalCriticalMiddleColour: null,
        magicalCriticalDarkColour: null,
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
        // Keep the old shared keys for physical crits. Seed only missing magical
        // fields from them; an explicitly blank field must stay on its preset.
        // Inspect raw fields before typed String access to recover damaged input.
        for (stop in ["Light", "Middle", "Dark"]) {
            var key = "critical" + stop + "Colour";
            var magicalKey = "magicalCritical" + stop + "Colour";
            if (!Std.isOfType(Reflect.field(config, key), String))
                Reflect.setField(config, key, "");
            if (Reflect.field(config, magicalKey) == null)
                Reflect.setField(config, magicalKey, Reflect.field(config, key));
            else if (!Std.isOfType(Reflect.field(config, magicalKey), String))
                Reflect.setField(config, magicalKey, "");
        }
        // Same single-key range as Better Mod Settings; zero means unassigned.
        if (config.hideUiKey < 0 || config.hideUiKey >= 512 || config.hideUiKey == 27) config.hideUiKey = 113;
        config.backgroundVolume = percent(config.backgroundVolume);
        config.fastTravelVolume = percent(config.fastTravelVolume);
    }
}
