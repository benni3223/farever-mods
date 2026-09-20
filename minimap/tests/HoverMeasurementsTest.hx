import minimap.GameAccess as G;
import minimap.HoverMeasurements;

class HoverMeasurementsTest {
    static var checks = 0;
    static function check(value:Bool, message:String):Void {
        checks++;
        if (!value) throw message;
    }

    static function main():Void {
        for (fontSize in [12, 24]) {
            G.created = [];
            // This test font has no hasChar API. The row must never request
            // an arrow glyph or include one in a native text object's string.
            var row = new HoverMeasurements({}, {size: fontSize});
            var root = G.created[0];
            var texts = [for (o in G.created) if (o.nativeType == "h2d.Text") o];
            check(root.visible == false, "New row starts hidden");
            var values = [{direction: "horizontal", metres: 42}, {direction: "up", metres: 18}];
            row.setValues(values);
            row.place(100, 250, 188);
            check(root.visible && root.y == 250, "Row appears at the requested footer position");
            check(texts[1].text == "42 m" && texts[3].text == "18 m", "Native text only draws numbers and units");
            check(root.scale == 1 && root.x == 54, "Full arrow-plus-text row is centered at 12 UI pixels");
            check(texts[1].x == 16 && texts[3].x == 68, "Both numbers leave space for their arrow");
            var calls = G.graphicsCalls;
            row.setValues([{direction: "horizontal", metres: 43}, {direction: "up", metres: 19}]);
            check(G.graphicsCalls == calls, "Changing distances reuses arrow geometry");
            row.place(50, 260, 46);
            check(root.scale == 0.5 && root.x == 27, "Narrow footer fits arrows and text together");
            row.setValues([{direction: "down", metres: 9}]);
            row.place(100, 250, 188);
            check(texts[1].text == "9 m" && texts[3].visible == false, "Missing measurement removes its number");
            check(G.created[G.created.length - 1].visible == false, "Single measurement hides the separator");
            row.setValues([]);
            check(root.visible == false, "Leaving the marker hides all measurement graphics");
        }
        Sys.println('Hover measurements: $checks checks passed.');
    }
}
