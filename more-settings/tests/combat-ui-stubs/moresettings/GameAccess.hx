package moresettings;

class GameAccess {
    public static var hero:Dynamic;
    public static var nodes = 0;
    public static var relativeTo:Dynamic;
    public static function field(o:Dynamic, name:String):Dynamic return o == null ? null : Reflect.field(o, name);
    public static function set(o:Dynamic, name:String, value:Dynamic):Void if (o != null) Reflect.setField(o, name, value);
    public static function text(v:Dynamic, fallback = ""):String return v == null ? fallback : Std.string(v);
    public static function number(v:Dynamic, fallback:Float = 0):Float return v == null ? fallback : v;
    public static function integer(v:Dynamic, fallback = 0):Int return Std.int(number(v, fallback));
    public static function array(v:Dynamic):Array<Dynamic> return v == null ? [] : cast v.items;
    public static function isA(o:Dynamic, type:String):Bool return field(o, "type") == type;
    public static function create(type:String, args:Array<Dynamic>):Dynamic throw "Unexpected constructor " + type;
    public static function staticCall(type:String, name:String, args:Array<Dynamic>):Dynamic {
        if (type == "GameApp" && name == "getMyHero") return hero;
        if (type == "domkit.Properties" && name == "createNew") {
            if (args[0] != "button") throw "Expected a native button";
            var parent = field(args[1], "obj");
            var parameters:Array<Dynamic> = args[2];
            var button:Dynamic = {parent:parent, text:parameters[0], visible:true, x:0.0, y:0.0, props:{}, callbacks:[]};
            var dom:Dynamic = {obj:button, styles:{}, id:field(args[3], "id")};
            button.dom = dom;
            var children:Array<Dynamic> = parent.children; children.push(button); nodes++;
            return dom;
        }
        throw type + "." + name;
    }
    public static function call(type:String, name:String, o:Dynamic, ?args:Array<Dynamic>):Dynamic {
        if (args == null) args = [];
        switch name {
            case "isEnemy": return field(o, "enemy") == true;
            case "bindUpdate":
                var callbacks:Array<Float->Void> = o.callbacks;
                var callback:Float->Void = args[0]; callbacks.push(callback); callback(0); return null;
            case "getProperties": return field(args[0], "props");
            case "initStyle": set(field(o, "styles"), args[0], args[1]); return null;
            case "getBounds": relativeTo = args[0]; return field(o, "bounds");
            case "setPosition": set(o, "x", args[0]); set(o, "y", args[1]); return null;
            case "remove":
                var parent = field(o, "parent");
                if (parent != null) { var children:Array<Dynamic> = parent.children; children.remove(o); }
                set(o, "parent", null); return null;
            case "set_visible":
                if (type == "ui.UIElement" && MinionHealthBars.intercept(o, args[0])) return false;
            default:
        }
        if (StringTools.startsWith(name, "set_")) { set(o, name.substr(4), args[0]); return args[0]; }
        throw type + "." + name;
    }
}
