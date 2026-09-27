import moddependencies.DependencyCheck;
import sys.FileSystem;
import sys.io.File;

class DependencyCheckTest {
    static var checks = 0;

    static function equal(actual:Dynamic, expected:Dynamic):Void {
        checks++;
        if (actual != expected) throw 'Expected $expected, got $actual';
    }

    static function main():Void {
        for (id in ["dps-meter", "minimap", "item-utilities", "more-settings", "fix-target-lock"]) {
            equal(DependencyCheck.missing(id, false, true, true).join(","), "Better Mod Settings");
            equal(DependencyCheck.missing(id, true, false, true).join(","), "Mod Update Alerts");
            equal(DependencyCheck.missing(id, false, false, true).join(","), "Better Mod Settings,Mod Update Alerts");
            equal(DependencyCheck.missing(id, true, true, true).length, 0);
            equal(DependencyCheck.missing(id, true, true, false).join(","),
                id == "item-utilities" ? "Farever ImGui plugin" : "");
            var message = DependencyCheck.message(id, ["Better Mod Settings"]);
            equal(message.indexOf(DependencyCheck.title(id)) >= 0, true);
            equal(message.indexOf("Missing critical dependencies") >= 0, true);
            equal(message.indexOf("https://www.nexusmods.com/farever/mods/10") >= 0, true);
            equal(message.indexOf("https://www.nexusmods.com/farever/mods/17") >= 0, false);
            var alertsMessage = DependencyCheck.message(id, ["Mod Update Alerts"]);
            equal(alertsMessage.indexOf("https://www.nexusmods.com/farever/mods/17") >= 0, true);
            equal(alertsMessage.indexOf("https://www.nexusmods.com/farever/mods/10") >= 0, false);
        }
        equal(DependencyCheck.missing("item-utilities", false, false, false).join(","),
            "Better Mod Settings,Mod Update Alerts,Farever ImGui plugin");
        var directory = "dependency-test-" + Std.string(Std.random(1000000000));
        FileSystem.createDirectory(directory);
        var path = directory + "/better-mod-settings.hl";
        equal(DependencyCheck.isBytecode(path), false);
        equal(DependencyCheck.isBytecode(directory), false);
        File.saveContent(path, "");
        equal(DependencyCheck.isBytecode(path), false);
        File.saveContent(path, "not bytecode");
        equal(DependencyCheck.isBytecode(path), false);
        File.saveBytes(path, haxe.io.Bytes.ofHex("484c4204"));
        equal(DependencyCheck.isBytecode(path), true);
        var hash = haxe.crypto.Sha256.make(File.getBytes(path)).toHex();
        equal(DependencyCheck.matchesImplementation(path, hash), true);
        equal(DependencyCheck.matchesImplementation(path, "wrong version"), false);
        FileSystem.rename(path, path + ".disabled");
        equal(DependencyCheck.isBytecode(path), false);
        equal(DependencyCheck.matchesImplementation(path, hash), false);
        FileSystem.deleteFile(path + ".disabled");
        FileSystem.deleteDirectory(directory);
        trace('Dependency checks passed ($checks checks)');
    }
}
