package moddependencies;

/**
 * HLX catches exceptions from a mod's main(), while native imports are resolved
 * before main() can run. Keep this entry separate from the implementation so a
 * missing ImGui library cannot prevent our actionable error from being shown.
 */
@:access(String)
class Bootstrap {
    // Optional binding: probing a missing plugin must not abort native linking.
    #if dependency_imgui
    @:hlNative("?imgui", "igGetVersion")
    static function imguiVersion():hl.Bytes { return null; }
    #end

    // Farever ships this native desktop dialog on both live and PTR. It needs
    // neither the game UI nor ImGui; a missing UI library still leaves a log.
    @:hlNative("?ui", "ui_dialog")
    static function dialog(title:hl.Bytes, text:hl.Bytes, flags:Int):Int { return 0; }

    @:hlNative("std", "sys_load_plugin")
    static function loadModule(path:hl.Bytes):Bool { return false; }

    static function main():Void {
        var id = Build.modId();
        var missing = DependencyCheck.missing(id,
            DependencyCheck.isBytecode("hlx/mods/better-mod-settings/better-mod-settings.hl"),
            DependencyCheck.isBytecode("hlx/mods/mod-update-alerts/mod-update-alerts.hl"),
            #if dependency_imgui hl.Api.isPrimLoaded(imguiVersion) #else true #end);
        if (missing.length > 0) stop(DependencyCheck.message(id, missing));

        // Keep the original basename: HLX derives moduleName(), config paths,
        // bus topics and log attribution from the filename of the loaded module.
        var path = "hlx/mods/" + id + "/implementation/" + id + ".hl";
        // Reject mixed-version/partial upgrades. Binding the entry to its code
        // also keeps binary-hash version detection accurate for manual installs.
        if (!DependencyCheck.matchesImplementation(path, Build.implementationHash())) stop(incomplete(id));
        var loaded = false;
        // Unlike filesystem primitives, sys_load_plugin consumes a UTF-16
        // string on both Windows and Linux (converting it internally on Linux).
        try loaded = loadModule(path.bytes) catch (error:Dynamic) {
            stop(DependencyCheck.title(id) + " could not start:\n\n" + Std.string(error)
                + "\n\nReinstall the complete mod archive and its required dependencies, then restart Farever.");
        }
        if (!loaded) stop(incomplete(id));
    }

    static function incomplete(id:String):String {
        return DependencyCheck.title(id) + " is not fully installed.\n\n"
            + "Reinstall or redeploy the complete mod archive, including its implementation folder, "
            + "then restart Farever.\n\nFarever will close when you dismiss this message.";
    }

    static function stop(message:String):Void {
        trace(message);
        if (hl.Api.isPrimLoaded(dialog)) {
            try dialog("Farever mod dependency error".bytes, message.bytes, 2)
            catch (error:Dynamic) trace("Could not display dependency error: " + Std.string(error));
        }
        // Throwing here is insufficient: HLX would catch it and keep launching.
        Sys.exit(1);
    }
}
