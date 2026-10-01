package fixtargetlock;

import hlx.runtime.ResolvedMember;

/** All game objects stay in their original HL module; never cast game arrays to Array<Dynamic>. */
class GameAccess {
    static var members:Map<String, ResolvedMember> = [];
    public static function field(object:Dynamic, name:String):Dynamic {
        if (object == null) return null;
        try return HlxRuntime.resolveField(object, name) catch (_:Dynamic) return null;
    }
    public static function text(value:Dynamic, fallback:String = ""):String {
        return value == null ? fallback : Std.string(value);
    }
    public static function number(value:Dynamic, fallback:Float = 0):Float {
        if (value == null) return fallback;
        var n = Std.parseFloat(Std.string(value));
        return Math.isFinite(n) ? n : fallback;
    }
    public static function integer(value:Dynamic, fallback:Int = 0):Int {
        return Std.int(number(value, fallback));
    }
    public static function member(type:String, name:String, isStatic:Bool = false):ResolvedMember {
        var key = type + (isStatic ? "::" : ".") + name;
        if (members.exists(key)) return members[key];
        var t = HlxRuntime.resolveType(type);
        if (t == null) throw "Game type unavailable: " + type;
        var m = isStatic ? HlxRuntime.resolveStaticMember(t, name) : HlxRuntime.resolveMember(t, name);
        if (m == null) throw "Game member unavailable: " + key;
        members[key] = m;
        return m;
    }
    public static function call(type:String, name:String, object:Dynamic, ?args:Array<Dynamic>):Dynamic {
        var all:Array<Dynamic> = [object];
        if (args != null) for (a in args) all.push(a);
        return HlxRuntime.callResolved(member(type, name), all);
    }
    /** Resolve on the receiver's type so native overrides keep their behavior. */
    public static function callInstance(object:Dynamic, name:String):Dynamic
        return object == null ? null : call(hl.Type.getDynamic(object).getTypeName(), name, object);

    public static function staticCall(type:String, name:String, args:Array<Dynamic>):Dynamic {
        return HlxRuntime.callResolved(member(type, name, true), args);
    }
    public static function current(type:String, name:String):Dynamic {
        var t = HlxRuntime.resolveType(type);
        return t == null ? null : HlxRuntime.resolveStaticField(t, name);
    }
    public static function setCurrent(type:String, name:String, value:Dynamic):Void {
        var t = HlxRuntime.resolveType(type);
        if (t == null) throw "Game type unavailable: " + type;
        HlxRuntime.setStaticField(t, name, value);
    }
    public static function set(object:Dynamic, name:String, value:Dynamic):Void {
        if (object != null) HlxRuntime.setField(object, name, value);
    }
}
