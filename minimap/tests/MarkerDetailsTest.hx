import minimap.MarkerDetails;
import minimap.MinimapGeometry;

class MarkerDetailsTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, message:String):Void {
        checks++;
        if (actual != expected) throw message + ': expected $expected, got $actual';
    }

    static function measurements(point:minimap.MarkerDetails.MarkerPosition, hero:minimap.MarkerDetails.MarkerPosition):String
        return [for (part in MarkerDetails.measurements(point, hero)) part.direction + ":" + part.metres].join("|");

    static function main():Void {
        var hero = {x: 10., y: 20., z: 100.};
        var above = {x: 13., y: 24., z: 112.};
        eq(measurements(above, hero), "horizontal:5|up:12", "horizontal distance is separate from height");
        eq(measurements({x: 10., y: 20., z: 91.}, hero), "horizontal:0|down:9", "directly below still has height");
        eq(measurements(hero, hero), "horizontal:0|vertical:0", "zero height uses a neutral double arrow");
        for (z in [99.6, 100., 100.4])
            eq(measurements({x: 13., y: 24., z: z}, hero), "horizontal:5|vertical:0", "rounded zero has no false direction");
        eq(measurements({x: 13., y: 24., z: 102.6}, hero), "horizontal:5|up:3", "rounds heights to whole metres");
        eq(measurements({x: 13., y: 24., z: 97.4}, hero), "horizontal:5|down:3", "rounds downward heights symmetrically");
        eq(measurements({x: 10., y: 25.6, z: 100.}, hero), "horizontal:6|vertical:0", "rounds distance to whole metres");
        eq(measurements({x: 13., y: 24., z: Math.NaN}, hero), "horizontal:5", "unknown target height is omitted");
        eq(measurements(above, {x: 10., y: 20., z: Math.NaN}), "horizontal:5", "unknown player height is omitted");
        eq(measurements({x: Math.NaN, y: 24., z: Math.NaN}, hero), "", "unavailable measurements are never invented");
        eq(measurements({x: 13., y: 24., z: 100.5}, hero), "horizontal:5|up:1", "half metre rounds up");
        eq(measurements({x: 13., y: 24., z: 99.5}, hero), "horizontal:5|down:1", "negative half metre uses the same rounding");
        eq(measurements({x: Math.NaN, y: 24., z: 112.}, hero), "up:12", "height remains available without horizontal data");
        var hover = MarkerDetails.hover("Active Rift", above);
        eq(hover.name, "Active Rift", "retains marker name separately from details");
        eq(measurements(hover, hero), "horizontal:5|up:12", "hover uses destination coordinates, including on edge arrows");

        eq(MarkerDetails.threshold(0), 15., "minimum threshold");
        eq(MarkerDetails.threshold(101), 100., "maximum threshold");
        eq(MarkerDetails.threshold(42), 42., "valid threshold is preserved");
        eq(MarkerDetails.threshold(Math.NaN), 15., "invalid threshold uses default");
        eq(MarkerDetails.threshold(Math.POSITIVE_INFINITY), 15., "infinite threshold uses default");
        for (z in [85., 100., 115.]) eq(MarkerDetails.hidden(z, 100, true, 15), false, "exact threshold remains visible");
        for (z in [84.99, 115.01]) eq(MarkerDetails.hidden(z, 100, true, 15), true, "beyond either threshold is hidden");
        eq(MarkerDetails.hidden(0, 100, true, 100), false, "100 metre threshold is inclusive");
        eq(MarkerDetails.hidden(-0.01, 100, true, 100), true, "greater than 100 metres is hidden");
        eq(MarkerDetails.hidden(1000, 0, false, 15), false, "disabled filter keeps distant markers");
        eq(MarkerDetails.hidden(Math.NaN, 100, true, 15), false, "unknown marker height stays visible");
        eq(MarkerDetails.hidden(100, Math.NaN, true, 15), false, "unknown player height stays visible");

        var points = [{kind: "companion", x: 13., y: 24., z: 116.}, {kind: "npc", x: 13., y: 24., z: 85.},
            {kind: "upcomingRift", x: 13., y: 24., z: 100.}, {kind: "ore", x: 13., y: 24., z: Math.NaN},
            {kind: "enemy", x: 13., y: 24., z: 84.}];
        var filtered = MarkerDetails.filter(points, 100, true, 15);
        eq(filtered.length, 3, "mixed marker collection excludes both above and below threshold");
        eq(filtered[0] == points[1] && filtered[1] == points[2] && filtered[2] == points[3], true,
            "filter retains sampled positions and draw order for hit-testing");
        eq(MarkerDetails.filter(points, 100, false, 15) == points, true, "disabled filtering retains the original list");

        // Arrows stay eligible when the marker is filtered out. Their position
        // still uses normal circular/square edge geometry, independent of height.
        for (circular in [true, false]) {
            var hasMarker = !MarkerDetails.hidden(150, 100, true, 15);
            eq(MinimapGeometry.showAlert(hasMarker, 25, 10, 250, circular, 12), true,
                "height-hidden on-map destinations still get guidance arrows");
            eq(MinimapGeometry.showAlert(hasMarker, 500, 10, 250, circular, 12), true,
                "off-screen guidance arrows survive height filtering");
            hasMarker = !MarkerDetails.hidden(115, 100, true, 15);
            eq(MinimapGeometry.showAlert(hasMarker, 25, 10, 250, circular, 12), false,
                "visible in-range marker suppresses duplicate arrow");
        }
        Sys.println('Marker details: $checks checks passed.');
    }
}
