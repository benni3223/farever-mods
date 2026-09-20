package minimap;

typedef MarkerPosition = {x:Float, y:Float, z:Float};
typedef MarkerHover = {name:String, x:Float, y:Float, z:Float};

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

    public static function caption(point:MarkerPosition, hero:MarkerPosition, arrows:Bool = true):String {
        var parts:Array<String> = [];
        var dx = point.x - hero.x, dy = point.y - hero.y;
        var distance = Math.sqrt(dx * dx + dy * dy);
        if (Math.isFinite(distance)) parts.push(Math.round(distance) + " m away");
        var height = point.z - hero.z;
        if (Math.isFinite(height)) {
            if (Math.abs(height) <= 2) parts.push("Same height");
            else {
                var metres = Math.round(Math.abs(height)) + " m";
                parts.push(arrows ? (height > 0 ? "↑ " : "↓ ") + metres
                    : metres + (height > 0 ? " above" : " below"));
            }
        }
        return parts.join(" · ");
    }
}
