import minimap.MinimapGeometry as M;
import minimap.MinimapCompass;
import minimap.GameAccess as G;

@:access(minimap.MinimapCompass)
class MinimapGeometryTest {
    static var checks = 0;
    static function check(value:Bool, message:String):Void {
        checks++;
        if (!value) throw message;
    }
    static function close(a:Float, b:Float, message:String):Void
        check(Math.isFinite(a) && Math.abs(a - b) < .00001, message + ': expected $b, got $a');

    static function main():Void {
        for (circular in [false, true]) {
            check(!M.showAlert(true, 30, 20, 160, circular, 10.5), "Visible companion markers suppress edge arrows");
            check(!M.showAlert(true, 85, 0, 160, circular, 10.5), "A partly clipped sparkling ring is still visible");
            check(M.showAlert(true, 91, 0, 160, circular, 10.5), "The arrow appears once the marker is fully outside");
            check(M.showAlert(false, 30, 20, 160, circular, 10.5), "Hiding regular companion markers preserves independent alerts");
            check(!M.showAlert(false, 0, 0, 160, circular, 10.5), "A coincident target has no direction arrow");
            check(!M.showAlert(true, 50 * .6, 0, 160, circular, 10.5)
                && M.showAlert(true, 50 * 3, 0, 160, circular, 10.5), "Zoom changes on-screen visibility using UI-pixel distances");
        }
        check(M.showAlert(true, 70, 70, 160, true, 10.5)
            && !M.showAlert(true, 70, 70, 160, false, 10.5), "Circle corners are clipped while square corners remain visible");
        check(!M.showAlert(true, 86, 86, 160, false, 10.5)
            && M.showAlert(true, 88, 88, 160, false, 10.5), "Square corner intersections include marker radius in both axes");
        var diagonal = 95 / Math.sqrt(2);
        check(M.showAlert(true, 95, 0, 160, false, 10.5)
            && !M.showAlert(true, diagonal, diagonal, 160, false, 10.5), "A square map's rotation can bring the same marker into view");
        check(M.showAlert(true, 95, 0, 160, true, 10.5)
            == M.showAlert(true, diagonal, diagonal, 160, true, 10.5), "Circular clipping remains invariant under rotation");

        for (size in [160, 250, 400]) for (scale in [.5, 1., 2.]) for (circular in [false, true])
            for (rotation in [0., Math.PI / 4, Math.PI / 2, Math.PI, -Math.PI / 2]) {
                var north = M.north(size, circular, rotation, scale);
                var nx = north.x - size / 2, ny = north.y - size / 2;
                var extent = circular ? Math.sqrt(nx * nx + ny * ny) : Math.max(Math.abs(nx), Math.abs(ny));
                close(extent, size / 2 - 14 * scale, "North stays on the rim across rotation, shape, size and marker scale");
                check(extent + 12 * scale <= size / 2 - 2 * scale + .00001, "The enlarged N retains padding inside both map shapes");
                close(nx * Math.cos(rotation) + ny * Math.sin(rotation), 0, "North follows the map's north vector");
                check(nx * Math.sin(rotation) - ny * Math.cos(rotation) > 0, "North points outward in the correct hemisphere");
                for (angle in [rotation - Math.PI / 2, 0., .7, 2.3, 4.1]) {
                    var x = Math.cos(angle) * 1000, y = Math.sin(angle) * 1000;
                    var arrow = M.alert(x, y, size, circular, scale, north);
                    var ax = arrow.x - size / 2, ay = arrow.y - size / 2;
                    var edge = circular ? Math.sqrt(ax * ax + ay * ay) : Math.max(Math.abs(ax), Math.abs(ay));
                    check(edge + 12 * scale <= size / 2 + .00001, "The complete alert ring stays inside the map");
                    close(ax * Math.sin(angle) - ay * Math.cos(angle), 0, "Edge placement preserves the companion bearing");
                    var dx = arrow.x - north.x, dy = arrow.y - north.y;
                    check(dx * dx + dy * dy >= 24 * 24 * scale * scale - .00001, "Alert rings leave the enlarged compass readable");
                }
            }
        var top = M.north(250, true, 0, 1);
        close(top.x, 125, "Fixed maps place N at top centre");
        close(top.y, 14, "Fixed maps leave padding above the enlarged needle");
        var right = M.north(250, true, Math.PI / 2, 1);
        close(right.x, 236, "A quarter turn moves north to the right edge");
        close(right.y, 125, "A quarter turn preserves the vertical centre");

        var compass = new MinimapCompass(null);
        var graphic = compass.graphic;
        var drawn = G.graphicsCalls;
        compass.update(250, true, 0, 1);
        close(graphic.x, top.x, "The native compass uses the tested geometry");
        close(graphic.y, top.y, "The native compass uses the tested top inset");
        var transformed = G.transformCalls;
        for (i in 0...100) compass.update(250, true, 0, 1);
        check(G.transformCalls == transformed && G.graphicsCalls == drawn, "A stationary compass neither transforms nor redraws per frame");
        compass.update(250, true, Math.PI / 2, 1);
        close(graphic.rotation, Math.PI / 2, "The N and compass needle turn with the map");
        close(graphic.x, right.x, "Rotating changes the compass's native position");
        compass.update(160, false, Math.PI / 4, 2);
        close(graphic.scale, 2, "The north indicator follows marker size");
        check(G.graphicsCalls == drawn, "Rotation, map resizing and marker scaling retain the same geometry");
        Sys.println('Minimap geometry tests passed ($checks checks)');
    }
}
