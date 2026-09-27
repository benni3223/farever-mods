package moresettings;

import moresettings.SettingsData.MoreSettingsConfig;

/** Import the two moved preferences once, without replacing More Settings choices. */
class CombatSettings {
    public static function migrate(config:MoreSettingsConfig, saved:Dynamic, previous:Dynamic):Void {
        if (previous == null) return;
        var previousEnabled:Dynamic = Reflect.field(previous, "enabled");
        var enabled = !Std.isOfType(previousEnabled, Bool) || (cast previousEnabled:Bool);
        for (entry in [
            {key: "quickCast", previous: "quickCast"},
            {key: "disableTargetLockCameraMovement", previous: "disableCameraMovement"}
        ]) {
            if (Reflect.field(saved, entry.key) != null) continue;
            var value:Dynamic = Reflect.field(previous, entry.previous);
            if (Std.isOfType(value, Bool)) Reflect.setField(config, entry.key, enabled && (cast value:Bool));
        }
    }

    public static function previous():Dynamic {
        for (path in ["hlx/config/fix-target-lock/config.json", "hlx/mods/fix-target-lock/config.json"]) {
            if (!sys.FileSystem.exists(path)) continue;
            try return haxe.Json.parse(sys.io.File.getContent(path)) catch (_:Dynamic) {}
        }
        return null;
    }
}
