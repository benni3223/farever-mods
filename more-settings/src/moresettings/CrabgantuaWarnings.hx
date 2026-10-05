package moresettings;

import haxe.ds.ObjectMap;
import moresettings.GameAccess as G;

private typedef WarningPass = {
    var pass:Dynamic;
    var name:String;
    var depthTest:Dynamic;
    var depthWrite:Bool;
}

private typedef WarningFx = {
    var passes:Array<WarningPass>;
    var applied:Bool;
}

/** Keep only Crabgantua's heroic Avalanche telegraphs above its water effects. */
class CrabgantuaWarnings {
    public static var enabled(default, null):Bool = false;
    static var warnings = new ObjectMap<Dynamic, WarningFx>();
    static var reported:Bool = false;

    public static function configure(value:Bool):Void {
        if (enabled == value) return;
        enabled = value;
        for (fx => warning in warnings) {
            if (enabled) sync(fx);
            else restore(warning);
        }
    }

    public static function attach(area:Dynamic):Void {
        var skill = G.field(area, "baseSkill");
        if (G.text(G.field(G.field(skill, "inf"), "id")) != "R1CrabBoss_Heroic_Avalanche") return;
        var fx = G.field(area, "telegraphFx");
        if (fx == null || G.field(fx, "removed") == true) return;
        if (!warnings.exists(fx)) warnings.set(fx, {passes: [], applied: false});
        // Track even while disabled so enabling during a warning works too.
        sync(fx);
    }

    public static function sync(fx:Dynamic):Void {
        if (!enabled) return;
        var warning = warnings.get(fx);
        if (warning == null || G.field(fx, "removed") == true) return;
        if (warning.applied) return;
        try {
            var always = G.enumeration("h3d.mat.Compare", "Always");
            if (always == null) throw "Native depth comparison unavailable";
            // getMaterials traverses this warning's live FX only. Native mesh
            // clones own their materials; neither the prefab nor other FX is edited.
            var materials = G.array(G.call("h3d.scene.Object", "getMaterials", fx, [null, null]));
            var seen = new ObjectMap<Dynamic, Bool>();
            for (material in materials) {
                var pass = G.field(material, "passes");
                while (pass != null && !seen.exists(pass)) {
                    seen.set(pass, true);
                    var name = G.text(G.field(pass, "name"));
                    if (colorPass(name)) {
                        // Record before the first write so even a partial failure
                        // can put every native pass property back.
                        warning.passes.push({pass: pass, name: name, depthTest: G.field(pass, "depthTest"),
                            depthWrite: G.field(pass, "depthWrite") == true});
                        // client.Renderer draws overlay after water, distortion,
                        // and tone mapping. Use setters to update passId/bits too.
                        G.call("h3d.mat.Pass", "setPassName", pass, ["overlay"]);
                        G.call("h3d.mat.Pass", "set_depthTest", pass, [always]);
                        G.call("h3d.mat.Pass", "set_depthWrite", pass, [false]);
                    }
                    pass = G.field(pass, "nextPass");
                }
            }
            // A just-created FX may not have its meshes until its first sync.
            warning.applied = warning.passes.length > 0;
        } catch (error:Dynamic) {
            restore(warning);
            report(error);
        }
    }

    static function colorPass(name:String):Bool return switch name {
        case "default", "alpha", "additive", "forward", "forwardAlpha", "overlay",
            "beforeTonemapping", "beforeTonemappingAlpha", "beforeTonemappingDecal", "afterTonemapping", "afterTonemappingDecal",
            "afterFog", "transparentOverlay", "volumetricOverlay": true;
        // Depth/shadow passes and deferred G-buffer outputs must keep their
        // original pipeline. Only colour passes can use the native overlay output.
        default: false;
    };

    static function restore(warning:WarningFx):Void {
        for (saved in warning.passes) try {
            G.call("h3d.mat.Pass", "setPassName", saved.pass, [saved.name]);
            G.call("h3d.mat.Pass", "set_depthTest", saved.pass, [saved.depthTest]);
            G.call("h3d.mat.Pass", "set_depthWrite", saved.pass, [saved.depthWrite]);
        } catch (error:Dynamic) report(error);
        warning.passes = [];
        warning.applied = false;
    }

    public static function forget(fx:Dynamic):Void {
        var warning = warnings.get(fx);
        if (warning == null) return;
        restore(warning);
        warnings.remove(fx);
    }

    public static function dispose():Void {
        for (warning in warnings) restore(warning);
        warnings = new ObjectMap();
    }

    static function report(error:Dynamic):Void {
        if (reported) return;
        reported = true;
        trace("[More Settings] Crabgantua rockfall warnings: " + Std.string(error));
    }
}
