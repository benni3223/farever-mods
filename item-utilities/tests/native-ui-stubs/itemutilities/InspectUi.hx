package itemutilities;

class InspectUi {
    public static function node(kind:String, parent:Dynamic, args:Array<Dynamic>, id:String):Dynamic {
        var object = InspectAccess.object(kind,parent.obj);
        object.id=id;
        return object.dom;
    }
    public static function absolute(parent:Dynamic, object:Dynamic):Void object.absolute=true;
    public static function position(object:Dynamic, x:Float, y:Float):Void { object.x=x; object.y=y; }
    public static function padding(object:Dynamic, value:Int):Void object.padding=value;
    public static function size(object:Dynamic, w:Int, h:Int):Void { object.width=w; object.height=h; }
}
