package moresettings;

import moresettings.GameAccess as G;

/** A depth-independent boundary, separate from the native projected decal. */
class RockfallOutline {
    static inline var SEGMENTS = 64;

    public static function create(area:Dynamic):Dynamic {
        var parent = G.field(area, "obj");
        if (parent == null) return null;
        var radius = G.number(G.call("st.skill.SkillArea", "getRange", area));
        if (!Math.isFinite(radius) || radius <= 0) return null;
        var root = G.create("h3d.scene.Object", [parent]);
        try {
            // Screen-space line width stays legible when the camera zooms out.
            // Dark backing contrasts with bright water; the amber core contrasts
            // with dark water. Separate meshes retain their own line widths.
            circle(root, radius, 6.0, 0x281609, 1);
            circle(root, radius, 3.0, 0xFFE18A, 2);
            return root;
        } catch (error:Dynamic) {
            remove(root);
            throw error;
        }
    }

    static function circle(parent:Dynamic, radius:Float, width:Float, color:Int, layer:Int):Void {
        var mesh = G.create("h3d.scene.Graphics", [parent]);
        var pass = G.field(G.field(mesh, "material"), "passes");
        G.call("h3d.mat.Pass", "setPassName", pass, ["overlay"]);
        G.call("h3d.mat.Pass", "set_depthTest", pass, [G.enumeration("h3d.mat.Compare", "Always")]);
        G.call("h3d.mat.Pass", "set_depthWrite", pass, [false]);
        G.set(pass, "layer", layer);
        // Graphics creates an unlit, double-sided, vertex-coloured material.
        // It has no scene-depth/decal projection or water-fade shader.
        G.call("h3d.scene.Graphics", "lineStyle", mesh, [width, color, 1.0]);
        G.call("h3d.scene.Graphics", "moveTo", mesh, [radius, 0.0, 0.05]);
        for (i in 1...SEGMENTS) {
            var angle = i * Math.PI * 2 / SEGMENTS;
            G.call("h3d.scene.Graphics", "lineTo", mesh,
                [Math.cos(angle) * radius, Math.sin(angle) * radius, 0.05]);
        }
        // Close with the exact first coordinate so the native join has no seam.
        G.call("h3d.scene.Graphics", "lineTo", mesh, [radius, 0.0, 0.05]);
        G.call("h3d.scene.Graphics", "flush", mesh);
    }

    public static function remove(root:Dynamic):Void {
        if (root != null) G.call("h3d.scene.Object", "remove", root);
    }
}
