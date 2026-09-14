package dpsmeter;

/** Interpreter-only metadata bridge. Unexpected native calls fail the test;
    production builds do not include this classpath. */
class GameAccess {
    public static var globals:Map<String, Dynamic> = [];
    public static function field(object:Dynamic, name:String):Dynamic return object == null ? null : Reflect.field(object, name);
    public static function text(value:Dynamic, fallback:String = ""):String return value == null ? fallback : Std.string(value);
    public static function integer(value:Dynamic, fallback:Int = 0):Int return value == null ? fallback : Std.int(value);
    public static function current(type:String, name:String):Dynamic return globals[type + "." + name];
    public static function array(value:Dynamic, proxy:Bool = false):Array<Dynamic> {
        if (proxy) value = field(value, "array");
        return value == null ? [] : cast value;
    }
    public static function call(type:String, name:String, object:Dynamic, ?args:Array<Dynamic>):Dynamic return switch (type + "." + name) {
        case "haxe.ds.StringMap.get": (cast object:Map<String, Dynamic>).get(args[0]);
        case "st.Player.getActivityContext": field(object, "context");
        default: throw "Unexpected native metadata call: " + type + "." + name;
    };
    public static function staticCall(type:String, name:String, args:Array<Dynamic>):Dynamic return switch (type + "." + name) {
        case "HActivity.all": [];
        case "HActivity.getInf": (cast globals["activities"]:Map<String, Dynamic>).get(args[0]);
        case "HActivity.isOfType": (cast field(args[0], "types"):Array<String>).indexOf(args[1]) >= 0;
        case "HSkill.getSkillRef": (cast globals["skillRefs"]:Map<String, Dynamic>).get(args[0]);
        case "ui.BaseUI.getTile": args[0];
        // In particular HText.skill is intentionally unavailable: readable
        // names must not depend on constructing a native SkillSpec.
        default: throw "Unexpected native metadata call: " + type + "." + name;
    };
}
