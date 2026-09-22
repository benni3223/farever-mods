import minimap.MinimapGeometry;
import minimap.PartyPin;
import minimap.PinMessage;
import minimap.PinPlacement;

class PinMessageTest {
    static var checks = 0;

    static function check(value:Bool, message:String):Void {
        checks++;
        if (!value) throw message;
    }

    static function close(actual:Float, expected:Float, message:String):Void {
        checks++;
        if (!Math.isFinite(actual) || Math.abs(actual - expected) > 0.001)
            throw message + ": expected " + expected + ", got " + actual;
    }

    static function main():Void {
        var zone = "World/W1_Siagarta";
        var formatted = PinMessage.format({x: 1234.4, y: -56.6, zone: zone});
        check(formatted == "Pin 1234, -57 @" + zone, "format rounds coordinates and keeps the zone");
        var parsed = PinMessage.parse(formatted);
        check(parsed != null && parsed.x == 1234 && parsed.y == -57 && parsed.zone == zone, "a pin line round-trips");
        var prefixed = PinMessage.parse("Aria: " + formatted);
        check(prefixed != null && prefixed.x == 1234 && prefixed.zone == zone, "a name prefix still parses");
        check(PinMessage.parse("hello there") == null, "a normal chat line is ignored");
        check(PinMessage.parse("Pin 1, 2") == null, "a pin without a zone is ignored");
        var history = PinMessage.parse("Pin 1, 2 @" + zone + "\nPin 9, 8 @" + zone);
        check(history != null && history.x == 9 && history.y == 8, "a chat log uses the latest pin");
        check(!PartyPin.receive(formatted, "World/Other"), "another zone does not set the pin");
        check(PartyPin.current() == null, "a rejected message leaves the pin empty");
        check(PartyPin.receive(formatted, zone), "the matching zone sets the pin");
        check(!PartyPin.receive("Mara: " + formatted, zone), "our own echoed line does not place a second pin");
        PartyPin.clear();
        check(PartyPin.current() == null && PartyPin.takeOutgoing() == null, "clearing does not send a chat line");

        var inside = PinPlacement.screen(20, 0, 0, 0, 1, 0);
        check(!PinPlacement.offScreen(inside.x, inside.y, 250, true, 8), "a nearby pin stays on the minimap");
        var outside = PinPlacement.screen(400, 0, 0, 0, 1, 0);
        check(PinPlacement.offScreen(outside.x, outside.y, 250, true, 8), "a far pin is outside the minimap");
        var edge = PinPlacement.edge(outside.x, outside.y, 250, true, 1, null);
        var expected = MinimapGeometry.alert(outside.x, outside.y, 250, true, 1, null);
        close(edge.x, expected.x, "the off-screen pin uses the shared edge arrow");
        close(edge.y, expected.y, "the off-screen pin uses the shared edge arrow");

        var back = PinPlacement.world(125 + inside.x, 125 + inside.y, 250, 0, 0, 1, 0);
        close(back.x, 20, "a minimap click inverts to the world position");
        close(back.y, 0, "a minimap click keeps the other axis");
        check(PinPlacement.doubleClick({x: 10, y: 10, time: 1}, 12, 11, 1.2), "a second close click is a double-click");
        check(!PinPlacement.doubleClick({x: 10, y: 10, time: 1}, 40, 10, 1.2), "a distant second click is not a double-click");
        var dragged = PinPlacement.drag(0, 0, 20, -8, 0, 2);
        close(dragged.x, -10, "dragging the map follows the cursor");
        close(dragged.y, 4, "dragging the map follows the cursor vertically");
        var wide = MinimapGeometry.edge(100, 0, 400, false, 0, 200);
        close(wide.x, 400, "a wide map places the arrow on the side");
        close(wide.y, 100, "a wide map keeps the arrow at mid-height");
        var square = MinimapGeometry.edge(100, 0, 400, false, 0);
        var same = MinimapGeometry.edge(100, 0, 400, false, 0, 400);
        close(square.x, same.x, "a square map keeps the existing edge");
        close(square.y, same.y, "a square map keeps the existing edge");
        Sys.println("Pin message tests passed (" + checks + " checks)");
    }
}
