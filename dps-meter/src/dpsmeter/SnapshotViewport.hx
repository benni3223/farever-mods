package dpsmeter;

import dpsmeter.GameAccess as G;

/** Keep native scroll masks in the same pixel coordinates as an off-screen image. */
class SnapshotViewport {
    public static function drawTo(window:Dynamic, texture:Dynamic):Void {
        var scene = G.call("h2d.Object", "getScene", window);
        var engine = G.current("h3d.Engine", "CURRENT");
        var width = G.number(G.field(engine, "width"));
        var height = G.number(G.field(engine, "height"));
        if (scene == null || width <= 0 || height <= 0)
            throw "The snapshot viewport is unavailable. Try again.";
        var names = ["viewportA", "viewportD", "viewportX", "viewportY"];
        var saved = [for (name in names) G.field(scene, name)];
        try {
            // drawTo/pushTargets gives geometry a texture-sized projection, but
            // RenderContext.setRZ still uses the live Scene viewport multiplied
            // by Engine.width/height. Neutralize that extra scale and offset.
            // These divisors must be the engine size, NOT the texture/strip size.
            G.set(scene, "viewportA", 2.0 / width);
            G.set(scene, "viewportD", 2.0 / height);
            G.set(scene, "viewportX", -1.0);
            G.set(scene, "viewportY", -1.0);
            G.call("h2d.Object", "drawTo", window, [texture]);
        } catch (error:Dynamic) {
            for (i in 0...names.length) G.set(scene, names[i], saved[i]);
            throw error;
        }
        // Restore after every strip, before readback or clipboard operations.
        for (i in 0...names.length) G.set(scene, names[i], saved[i]);
    }
}
