package minimap;

import minimap.PinMessage.PinPoint;

/** The one current pin. A newer placement or party message replaces it. */
class PartyPin {
    static var pin:PinPoint;
    static var outgoing:String;

    public static function current():PinPoint return pin;

    public static function place(x:Float, y:Float, zone:String):Void {
        if (zone == null || zone == "" || !Math.isFinite(x) || !Math.isFinite(y)) return;
        pin = {x: x, y: y, zone: zone};
        outgoing = PinMessage.format(pin);
    }

    public static function clear():Void {
        pin = null;
        outgoing = null;
    }

    public static function takeOutgoing():String {
        var line = outgoing;
        outgoing = null;
        return line;
    }

    /** Same coordinates are the echo of our own send and do not create another pin. */
    public static function receive(line:String, zone:String):Bool {
        var parsed = PinMessage.parse(line);
        if (parsed == null || zone == null || zone == "") return false;
        if (parsed.zone != zone && !StringTools.startsWith(parsed.zone, zone)) return false;
        if (pin != null && Math.round(pin.x) == Math.round(parsed.x) && Math.round(pin.y) == Math.round(parsed.y))
            return false;
        pin = {x: parsed.x, y: parsed.y, zone: zone};
        outgoing = null;
        return true;
    }
}
