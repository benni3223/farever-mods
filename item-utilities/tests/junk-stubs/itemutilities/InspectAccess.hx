package itemutilities;

class InspectAccess {
    public static function field(object:Dynamic, name:String):Dynamic return object == null ? null : Reflect.field(object, name);
    public static function text(value:Dynamic):String return value == null ? "" : Std.string(value);
    public static function typeName(object:Dynamic):String return object.nativeType;
    public static function isA(object:Dynamic, type:String):Bool return object.nativeType == type
        || (type == "st.item.Gear" && ["st.item.Armor", "st.item.Weapon"].indexOf(object.nativeType) >= 0);
    public static function array(value:Dynamic, proxy:Bool = false):Array<Dynamic> {
        if (proxy) value = field(value, "array");
        return value == null ? [] : cast value;
    }
}
