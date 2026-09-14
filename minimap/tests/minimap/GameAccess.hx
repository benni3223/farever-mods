package minimap;

/** Native activity/progress and item boundaries for interpreter regression tests. */
class GameAccess {
    public static var definitions:Map<String, Dynamic> = [];
    public static var completionReads:Int = 0;
    public static var items:Map<String, Dynamic> = [];
    public static var itemReads:Int = 0;
    public static var graphicsCalls:Int = 0;
    public static var transformCalls:Int = 0;

    public static function create(type:String, args:Array<Dynamic>):Dynamic {
        if (type == "h2d.Graphics") return {parent: args[0], x: 0., y: 0., rotation: 0., scale: 1.};
        throw "Unexpected native constructor: " + type;
    }

    public static function field(object:Dynamic, name:String):Dynamic
        return object == null ? null : Reflect.field(object, name);

    public static function text(value:Dynamic, fallback:String = ""):String
        return value == null ? fallback : Std.string(value);

    public static function array(value:Dynamic):Array<Dynamic>
        return value == null ? [] : cast value;

    public static function current(type:String, name:String):Dynamic {
        if (type == "Data" && name == "item") return {byId: items};
        throw "Unexpected native static field";
    }

    public static function staticCall(type:String, name:String, args:Array<Dynamic>):Dynamic {
        if (type != "HActivity" || name != "isOfType") throw "Unexpected native static call";
        var inf = args[0];
        // Native HActivity.isOfType follows IDs through the inheritance chain.
        while (inf != null) {
            if (field(inf, "id") == args[1]) return true;
            var parent = field(inf, "inherit");
            if (parent == null) return false;
            inf = definitions[parent];
        }
        return false;
    }

    public static function call(type:String, name:String, object:Dynamic, ?args:Array<Dynamic>):Dynamic {
        if (type == "h2d.Graphics") {
            if (["beginFill", "endFill", "moveTo", "lineTo", "lineStyle"].indexOf(name) < 0)
                throw "Unexpected drawing call: " + name;
            if (name == "lineStyle" && args.length != 3) throw "Native lineStyle requires three optional argument slots";
            graphicsCalls++;
            return null;
        }
        if (type == "h2d.Object") {
            switch (name) {
                case "setPosition": object.x = args[0]; object.y = args[1];
                case "set_rotation": object.rotation = args[0];
                case "setScale": object.scale = args[0];
                default: throw "Unexpected native transform: " + name;
            }
            transformCalls++;
            return null;
        }
        if (type == "haxe.ds.StringMap" && name == "get") {
            itemReads++;
            return items[args[0]];
        }
        if (type != "st.player.Progress" || name != "hasActivityCompleted") throw "Unexpected native call";
        completionReads++;
        return object.completed == args[0];
    }
}
