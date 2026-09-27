package moresettings;

import moresettings.GameAccess as G;

/** Frame the face using the native body's bounds and projection, without moving inside its near plane. */
class AppearanceCamera {
    var body:Array<Float>;
    var waiting = true;
    var lastClose:Null<Bool>;

    public function new() {}
    public function invalidate():Void { waiting = true; lastClose = null; }

    public function update(preview:Dynamic, close:Bool):Void {
        var camera = G.field(G.field(G.field(preview, "unitScene"), "s3d"), "camera");
        var bounds = G.field(preview, "preAnimBounds");
        if (camera == null || bounds == null) return;
        if (G.integer(G.field(preview, "needFit")) >= 0) {
            // UnitScene fits distance using fovY, without accounting for zoom.
            // Restore the body projection before it refits so the next baseline
            // cannot accidentally include our previous close-up magnification.
            if (body != null) G.set(camera, "zoom", body[6]);
            invalidate();
            return;
        }
        var pos = G.field(camera, "pos"), target = G.field(camera, "target");
        if (waiting) {
            body = [for (v in [pos, target]) for (axis in ["x", "y", "z"]) G.number(G.field(v, axis))];
            body.push(G.number(G.field(camera, "zoom"), 1.0));
            waiting = false;
        }
        if (lastClose == close) return;
        // Stay in the same coordinate space as the successful full-body fit.
        // Skeleton attachment transforms are not a reliable camera focus point
        // across the body models. 0.38 above center frames the upper 88% point.
        var height = Math.max(0, G.number(G.field(bounds, "zMax")) - G.number(G.field(bounds, "zMin")));
        var offset = close ? height * 0.38 : 0.0;
        var axes = ["x", "y", "z"];
        for (i in 0...3) {
            var shift = i == 2 ? offset : 0.0;
            G.set(target, axes[i], body[i + 3] + shift);
            G.set(pos, axes[i], body[i] + shift);
        }
        // Optical zoom preserves the already-working camera distance and clip
        // range instead of pushing the camera through the model/near plane.
        G.set(camera, "zoom", close ? body[6] / 0.38 : body[6]);
        G.call("h3d.Camera", "update", camera);
        lastClose = close;
    }
}
