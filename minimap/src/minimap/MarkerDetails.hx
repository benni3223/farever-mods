package minimap;

typedef MarkerPosition = {x:Float, y:Float, z:Float};
typedef MarkerHover = {name:String, x:Float, y:Float, z:Float};
typedef MarkerMeasurement = {direction:String, metres:Int};

/** World-space hover measurements and the shared vertical visibility rule. */
class MarkerDetails {
    public static function threshold(value:Float):Float
        return Math.isFinite(value) ? Math.max(15, Math.min(100, value)) : 15;

    public static function hidden(z:Float, heroZ:Float, enabled:Bool, limit:Float):Bool {
        var difference = z - heroZ;
        // Unknown elevation is not evidence that a marker is too far away.
        return enabled && Math.isFinite(difference) && Math.abs(difference) > threshold(limit);
    }

    public static function filter<T:{z:Float}>(points:Array<T>, heroZ:Float, enabled:Bool, limit:Float):Array<T>
        return !enabled ? points : [for (point in points) if (!hidden(point.z, heroZ, enabled, limit)) point];

    public static function hover(name:String, point:MarkerPosition):MarkerHover
        return {name: name, x: point.x, y: point.y, z: point.z};

    public static function measurements(point:MarkerPosition, hero:MarkerPosition):Array<MarkerMeasurement> {
        var parts:Array<MarkerMeasurement> = [];
        var dx = point.x - hero.x, dy = point.y - hero.y;
        var distance = Math.sqrt(dx * dx + dy * dy);
        if (Math.isFinite(distance)) parts.push({direction: "horizontal", metres: Math.round(distance)});
        var height = point.z - hero.z;
        if (Math.isFinite(height)) {
            var metres = Math.round(Math.abs(height));
            parts.push({direction: metres == 0 ? "vertical" : height > 0 ? "up" : "down", metres: metres});
        }
        return parts;
    }
}
