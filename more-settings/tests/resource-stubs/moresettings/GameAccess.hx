package moresettings;

/** Simulates the cross-module boundary without casting production game arrays. */
class GameAccess {
    public static var failSwap = false;
    public static var failSlice = false;
    public static var memoryRead:Null<Void->Void>;
    public static function queue(values:Array<Dynamic>):Dynamic return {items:values, length:values.length};
    public static function field(value:Dynamic, name:String):Dynamic return value == null ? null : Reflect.field(value, name);
    public static function set(value:Dynamic, name:String, next:Dynamic):Void {
        if (failSwap) throw "field swap failed";
        Reflect.setField(value, name, next);
    }
    public static function number(value:Dynamic, fallback:Float = 0):Float return value == null ? fallback : value;
    public static function integer(value:Dynamic, fallback:Int = 0):Int return value == null ? fallback : value;
    public static function call(type:String, name:String, object:Dynamic, ?args:Array<Dynamic>):Dynamic {
        if (type == "GameApp" && name == "get_isLoading") return field(object, "loading");
        if (type == "h3d.impl.DX12Driver" && name == "getMemoryUsage") {
            if (memoryRead != null) memoryRead();
            return field(object, "memory");
        }
        if (type != "hl.types.ArrayObj") throw type + "." + name;
        var items:Array<Dynamic> = field(object, "items");
        return switch name {
            case "slice":
                if (failSlice) throw "allocation failed";
                queue(items.slice(args[0], args[1]));
            case "getDyn": items[args[0]];
            case "pop":
                var result = items.pop(); object.length = items.length; result;
            case "push":
                items.push(args[0]); object.length = items.length; items.length;
            default: throw name;
        };
    }
}
