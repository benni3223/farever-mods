package minimap;

typedef PinPoint = {x:Float, y:Float, zone:String};

/** One visible group-chat line. Parsing does not touch game objects. */
class PinMessage {
    static var pattern = ~/Pin (-?\d+), (-?\d+) @(\S+)/;

    public static function format(pin:PinPoint):String {
        return "Pin " + Math.round(pin.x) + ", " + Math.round(pin.y) + " @" + pin.zone;
    }

    /** The last pin in the line. A chat log can contain older pins above it. */
    public static function parse(line:String):PinPoint {
        if (line == null) return null;
        var text = StringTools.trim(line);
        var searchFrom = 0;
        var last:PinPoint = null;
        while (searchFrom < text.length) {
            var start = text.indexOf("Pin ", searchFrom);
            if (start < 0) break;
            if (pattern.match(text.substr(start))) {
                var pin = readMatch();
                if (pin != null) last = pin;
            }
            searchFrom = start + 4;
        }
        return last;
    }

    static function readMatch():PinPoint {
        var x = Std.parseInt(pattern.matched(1));
        var y = Std.parseInt(pattern.matched(2));
        var zone = pattern.matched(3);
        if (x == null || y == null || zone == null || zone == "") return null;
        return {x: x, y: y, zone: zone};
    }
}
