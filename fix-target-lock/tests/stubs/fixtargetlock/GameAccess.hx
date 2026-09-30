package fixtargetlock;

class GameAccess {
    public static var data:Dynamic;
    public static var inputActive = true;
    public static var releasedInput:String;
    public static var releaseReads = 0;
    public static var failRelease = false;
    public static function field(o:Dynamic, name:String):Dynamic return o == null ? null : Reflect.field(o, name);
    public static function set(o:Dynamic, name:String, value:Dynamic):Void Reflect.setField(o, name, value);
    public static function current(type:String, name:String):Dynamic return field(data, name);
    public static function setCurrent(type:String, name:String, value:Dynamic):Void set(data, name, value);
    public static function number(v:Dynamic, fallback:Float):Float {
        var n = Std.parseFloat(Std.string(v));
        return Math.isFinite(n) ? n : fallback;
    }
    public static function staticCall(type:String, name:String, args:Array<Dynamic>):Dynamic {
        if (type != "lib.Input" || name != "isReleased") throw "Unexpected input call";
        releaseReads++;
        if (failRelease) throw "Input failure";
        if (data._noCheckMode != true) throw "Aiming mode was not bypassed";
        return inputActive && args[0] == releasedInput;
    }
}
