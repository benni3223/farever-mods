package moresettings;

import moresettings.GameAccess as G;

/** Apply zoom from the last native full-body fit, so tab changes never compound it. */
class AppearanceCamera {
    var body:Array<Float>;
    var waiting = true;
    var lastClose:Null<Bool>;

    public function new() {}
    public function invalidate():Void { waiting = true; lastClose = null; }

    public function update(preview:Dynamic, close:Bool):Void {
        if (G.integer(G.field(preview, "needFit")) >= 0) { invalidate(); return; }
        var camera = G.field(G.field(G.field(preview, "unitScene"), "s3d"), "camera");
        var bounds = G.field(preview, "preAnimBounds");
        if (camera == null || bounds == null) return;
        var pos = G.field(camera, "pos"), target = G.field(camera, "target");
        if (waiting) {
            body = [for (v in [pos, target]) for (axis in ["x", "y", "z"]) G.number(G.field(v, axis))];
            waiting = false;
        }
        if (lastClose == close) return;
        var focus = body[5];
        if (close) {
            var head = G.call("h3d.scene.Object", "getObjectByName", G.field(preview, "unitView"), ["B_Head"]);
            var height = G.number(G.field(bounds, "zMax")) - G.number(G.field(bounds, "zMin"));
            focus = head == null ? G.number(G.field(bounds, "zMin")) + height * 0.88
                : G.number(G.field(G.call("h3d.scene.Object", "getAbsPos", head), "_43"));
        }
        var distance = close ? 0.38 : 1.0;
        var axes = ["x", "y", "z"];
        for (i in 0...3) {
            var center = i == 2 ? focus : body[i + 3];
            G.set(target, axes[i], center);
            G.set(pos, axes[i], center + (body[i] - body[i + 3]) * distance);
        }
        G.call("h3d.Camera", "update", camera);
        lastClose = close;
    }
}
