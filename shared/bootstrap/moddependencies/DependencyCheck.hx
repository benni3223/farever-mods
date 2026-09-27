package moddependencies;

import sys.FileSystem;
import sys.io.File;

/** The entry module uses no mod, game, or ImGui code before this check passes. */
class DependencyCheck {
    public static function title(id:String):String {
        return switch (id) {
            case "dps-meter": "DPS Meter";
            case "minimap": "Minimap";
            case "item-utilities": "Item Utilities";
            case "more-settings": "More Settings";
            case "fix-target-lock": "Fix Target Lock";
            default: throw "Unknown dependency-checked mod: " + id;
        };
    }

    public static function missing(id:String, settingsInstalled:Bool, updateAlertsInstalled:Bool, imguiLoaded:Bool):Array<String> {
        var result = [];
        if (!settingsInstalled) result.push("Better Mod Settings");
        if (!updateAlertsInstalled) result.push("Mod Update Alerts");
        if (id == "item-utilities" && !imguiLoaded) result.push("Farever ImGui plugin");
        return result;
    }

    public static function message(id:String, missing:Array<String>):String {
        return title(id) + " cannot start. Missing critical dependencies:\n\n"
            + [for (name in missing) "- " + name].join("\n")
            + "\n\nInstall or enable these dependencies, deploy them in Vortex "
            + "(or extract their complete archives into the Farever game folder), then restart Farever."
            + (missing.indexOf("Better Mod Settings") < 0 ? ""
                : "\n\nBetter Mod Settings: https://www.nexusmods.com/farever/mods/10")
            + (missing.indexOf("Mod Update Alerts") < 0 ? ""
                : "\n\nMod Update Alerts: https://www.nexusmods.com/farever/mods/17")
            + "\n\nFarever will close when you dismiss this message.";
    }

    public static function isBytecode(path:String):Bool {
        // A leftover directory, config file, or disabled/empty binary is not an install.
        try {
            if (!FileSystem.exists(path) || FileSystem.isDirectory(path)
                || FileSystem.stat(path).size < 4) return false;
            var file = File.read(path, true);
            var header = try file.readString(3) catch (e:Dynamic) {
                file.close();
                return false;
            };
            file.close();
            return header == "HLB";
        } catch (_:Dynamic) return false;
    }

    public static function matchesImplementation(path:String, hash:String):Bool {
        try return isBytecode(path) && haxe.crypto.Sha256.make(File.getBytes(path)).toHex() == hash
        catch (_:Dynamic) return false;
    }
}
