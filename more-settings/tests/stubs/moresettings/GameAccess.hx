package moresettings;

/** Test adapter: plain objects stand in for native HL objects and arrays. */
class GameAccess {
    public static var master:Float = 1;
    public static var focused:Bool = true;
    public static var writes:Int = 0;
    public static var data:Dynamic;
    public static var inputArrayCalls:Int = 0;
    public static var keysPressed:Map<Int, Bool> = [];
    public static var cinematicCapture:Bool = false;
    public static var nativeCalls:Int = 0;
    public static function field(o:Dynamic, name:String):Dynamic return o == null ? null : Reflect.field(o, name);
    public static function set(o:Dynamic, name:String, value:Dynamic):Void if (o != null) Reflect.setField(o, name, value);
    public static function text(v:Dynamic, fallback:String = ""):String return v == null ? fallback : Std.string(v);
    public static function number(v:Dynamic, fallback:Float = 0):Float {
        var n = Std.parseFloat(text(v)); return Math.isFinite(n) ? n : fallback;
    }
    public static function integer(v:Dynamic, fallback:Int = 0):Int return Std.int(number(v, fallback));
    public static function array(v:Dynamic, proxy:Bool = false):Array<Dynamic> {
        if (proxy) v = field(v, "array"); return v == null ? [] : cast v;
    }
    public static function isA(o:Dynamic, name:String):Bool {
        if (o == null) return false;
        var types:Array<String> = field(o, "types"); return types != null && types.indexOf(name) >= 0;
    }
    public static function callInstance(o:Dynamic, name:String):Dynamic return call("", name, o);
    public static function current(type:String, name:String):Dynamic return field(data, name);
    public static function call(type:String, name:String, o:Dynamic, ?args:Array<Dynamic>):Dynamic {
        nativeCalls++;
        return switch name {
        case "getDyn": inputArrayCalls++; o.items[args[0]];
        case "setDyn": inputArrayCalls++; o.items[args[0]] = args[1]; null;
        case "getFocusedTextInput": field(o, "textInput");
        case "get": field(o, args[0]);
        case "getSourceSkill": field(o, "sourceSkill") == null ? o : field(o, "sourceSkill");
        case "getSourceObject": field(o, "instigator") != null ? field(o, "instigator") : field(o, "owner");
        case "resolveProxy": field(o, "proxy") == null ? o : field(o, "proxy");
        case "isEnemy": field(args[0], "enemy") == true;
        case "get_isFocused": focused;
        case "isFlyingToObelisk": field(o, "flying") == true;
        case "isDead": field(o, "dead") == true;
        case "getActiveSkill": field(o, "activeSkill");
        case "isUsingVehicle": field(o, "vehicle") == true;
        case "isInputBlocked": field(o, "blocked") == true;
        case "isActive": field(o, "playing") == true;
        case "stop": set(o, "playing", false); set(o, "stops", integer(field(o, "stops")) + 1); null;
        default: throw "Unexpected native call: " + type + "." + name;
        };
    }
    public static function staticCall(type:String, name:String, args:Array<Dynamic>):Dynamic {
        nativeCalls++;
        return switch name {
        case "getInstance": {};
        case "isPressed":
            if (type != "hxd.Key") throw "Unexpected input query";
            keysPressed[args[0]] == true;
        case "cinematicCapturesKbd": cinematicCapture;
        case "getVcaVolume":
            if (args[0] != "vca:/MASTER") throw "Unexpected VCA read: " + args[0];
            master;
        case "setVcaVolume":
            if (args[0] != "vca:/MASTER") throw "Unexpected VCA write: " + args[0];
            master = args[1]; writes++; null;
        default: throw "Unexpected native static call: " + type + "." + name;
        };
    }
}
