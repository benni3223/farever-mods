package minimap;

import minimap.GameAccess as G;

/** One retained N/compass glyph; map rotation changes only its transform. */
class MinimapCompass {
    var graphic:Dynamic;
    var lastSize:Int = 0;
    var lastCircular:Bool = false;
    var lastRotation:Float = Math.NaN;
    var lastScale:Float = 0;

    public function new(parent:Dynamic) {
        graphic = G.create("h2d.Graphics", [parent]);
        // An ivory needle and a plain N, outlined against both light and dark
        // terrain. Local pixel geometry avoids font loading or per-frame redraw.
        for (outline in [true, false]) {
            G.call("h2d.Graphics", "beginFill", graphic, [outline ? 0x201b1b : 0xfff3d6, 1.0]);
            polygon(outline ? [0., -9., 4., -2., -4., -2.] : [0., -7., 2.3, -3., -2.3, -3.]);
            G.call("h2d.Graphics", "endFill", graphic);
        }
        for (outline in [true, false]) {
            G.call("h2d.Graphics", "lineStyle", graphic, [outline ? 3.5 : 1.7, outline ? 0x201b1b : 0xfff3d6, 1.0]);
            G.call("h2d.Graphics", "moveTo", graphic, [-3., 7.]);
            G.call("h2d.Graphics", "lineTo", graphic, [-3., 0.]);
            G.call("h2d.Graphics", "lineTo", graphic, [3., 7.]);
            G.call("h2d.Graphics", "lineTo", graphic, [3., 0.]);
        }
        G.call("h2d.Graphics", "lineStyle", graphic, [0., 0x000000, 1.0]);
    }

    public function update(size:Int, circular:Bool, rotation:Float, markerScale:Float):Void {
        if (size == lastSize && circular == lastCircular && rotation == lastRotation && markerScale == lastScale) return;
        var point = MinimapGeometry.north(size, circular, rotation, markerScale);
        G.call("h2d.Object", "setPosition", graphic, [point.x, point.y]);
        G.call("h2d.Object", "set_rotation", graphic, [rotation]);
        if (markerScale != lastScale) G.call("h2d.Object", "setScale", graphic, [markerScale]);
        lastSize = size; lastCircular = circular; lastRotation = rotation; lastScale = markerScale;
    }

    function polygon(points:Array<Float>):Void {
        for (i in 0...Std.int(points.length / 2) + 1) {
            var j = (i * 2) % points.length;
            G.call("h2d.Graphics", i == 0 ? "moveTo" : "lineTo", graphic, [points[j], points[j + 1]]);
        }
    }
}
