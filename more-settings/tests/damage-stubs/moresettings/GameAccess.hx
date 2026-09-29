package moresettings;

/** Native rendering boundary for filter composition, alpha, and resource-lifetime tests. */
class GameAccess {
    public static var textures:Array<Dynamic> = [];
    public static function field(o:Dynamic, name:String):Dynamic return o == null ? null : Reflect.field(o, name);
    public static function set(o:Dynamic, name:String, value:Dynamic):Void Reflect.setField(o, name, value);
    public static function text(value:Dynamic, fallback:String = ""):String
        return value == null ? fallback : Std.string(value);
    public static function isA(o:Dynamic, type:String):Bool
        return o != null && field(o, "nativeType") == type;
    public static function array(value:Dynamic, proxy:Bool = false):Array<Dynamic>
        return value == null ? [] : cast value;
    public static function enumeration(type:String, name:String):Dynamic return type + "." + name;
    public static function create(type:String, args:Array<Dynamic>):Dynamic return switch type {
        case "h3d.MatrixImpl": {};
        case "h3d.pass.ColorMatrixShader": {maskMatA__: {}, maskMatB__: {}, maskChannel__: {}};
        case "h2d.filter.Shader": {kind: "gradient", shader: args[0], pass: {shader: args[0]}};
        case "h2d.filter.Outline": {kind: "outline", color: 0, alpha: 1.0};
        case "h2d.filter.Group": {kind: "group", filters: new Array<Dynamic>()};
        default: throw "Unexpected native constructor: " + type;
    };
    public static function staticCall(type:String, name:String, args:Array<Dynamic>):Dynamic {
        if (type == "hxd.Pixels" && name == "alloc") return {width: args[0], height: args[1], colors: new Array<Int>(), disposed: false};
        if (type == "h3d.mat.Texture" && name == "fromPixels") {
            var texture:Dynamic = {pixels: args[0], disposed: false, uploads: 1};
            textures.push(texture); return texture;
        }
        throw "Unexpected static call: " + type + "." + name;
    }
    public static function call(type:String, name:String, o:Dynamic, ?args:Array<Dynamic>):Dynamic {
        if (type == "ui.comp.FmtText" && name == "set_text") {
            o.text = args[0];
            o.needsRebuild = true;
            return args[0];
        }
        if (type == "h2d.Text" && name == "updateSize") return null;
        if (type == "st.skill.DamageResult" && name == "get_isMagic") return o.magic;
        if (type == "h3d.pass.ColorMatrixShader" && StringTools.startsWith(name, "set_")) {
            set(o, name.substr(4) + "__", args[0]); return args[0];
        }
        if (type == "domkit.Properties" && name == "initStyle") {
            set(o.styles, args[0], args[1]); return null;
        }
        if (type == "h3d.MatrixImpl" && name == "zero") {
            for (row in 1...5) for (col in 1...5) set(o, '_$row$col', 0.0);
            return null;
        }
        if (type == "h2d.filter.Group" && name == "add") {
            (cast o.filters:Array<Dynamic>).push(args[0]); return null;
        }
        if (type == "hxd.Pixels" && name == "setPixel") {
            (cast o.colors:Array<Int>)[args[1]] = args[2]; return null;
        }
        if (name == "dispose") { o.disposed = true; return null; }
        if (type == "h3d.mat.Texture") switch name {
            case "isDisposed": return o.disposed;
            case "preventAutoDispose": o.pinned = true; return null;
            case "uploadPixels":
                if (args[0].disposed) throw "Used released ramp pixels";
                o.uploads++; return null;
        }
        if (StringTools.startsWith(name, "set_")) { set(o, name.substr(4), args[0]); return args[0]; }
        throw "Unexpected native call: " + type + "." + name;
    }
}
