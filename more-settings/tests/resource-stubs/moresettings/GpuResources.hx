package moresettings;

class GpuResources {
    public static var now:Float = 0;
    public static var cost:Float = 0;
    public static var released:Array<Dynamic> = [];
    public static var failId:Int = -1;
    public static function resolve(value:Dynamic):Dynamic {
        if (value.id == failId) throw "abstract conversion failed";
        return value;
    }
    public static function release(value:Dynamic):Void {
        if (!value.ready) throw "released before native fence checkpoint";
        if (value.releases != 0) throw "double release";
        value.releases++;
        released.push(value);
        now += cost;
    }
}
