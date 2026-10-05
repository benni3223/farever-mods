package moresettings;

/** Native rendering boundary for the Crabgantua warning lifecycle checks. */
class GameAccess {
    public static var materialReads = 0;
    public static var writes = 0;
    public static var failNextDepthTest = false;
    public static var created:Array<Dynamic> = [];
    public static final always:Dynamic = {name: "native Always"};

    public static function field(object:Dynamic, name:String):Dynamic
        return object == null ? null : Reflect.field(object, name);
    public static function text(value:Dynamic, fallback:String = ""):String
        return value == null ? fallback : Std.string(value);
    public static function number(value:Dynamic, fallback:Float = 0):Float
        return value == null ? fallback : value;
    public static function set(object:Dynamic, name:String, value:Dynamic):Void
        Reflect.setField(object, name, value);
    public static function create(type:String, args:Array<Dynamic>):Dynamic {
        if (args.length != 1 || (type != "h3d.scene.Object" && type != "h3d.scene.Graphics"))
            throw "Unexpected scene constructor";
        var object:Dynamic = {parent:args[0], children:[], removed:false, points:[], material:{passes:{}}};
        args[0].children.push(object);
        created.push(object);
        return object;
    }
    public static function array(value:Dynamic):Array<Dynamic>
        return value == null ? [] : cast value;
    public static function enumeration(type:String, name:String):Dynamic {
        if (type != "h3d.mat.Compare" || name != "Always") throw "Unexpected native enum lookup";
        return always;
    }
    public static function call(type:String, name:String, object:Dynamic, ?args:Array<Dynamic>):Dynamic {
        if (type == "st.skill.SkillArea" && name == "getRange") return object.range;
        if (type == "h3d.scene.Object" && name == "remove") {
            object.removed = true;
            for (child in (cast object.children:Array<Dynamic>).copy()) call(type, name, child);
            object.parent.children.remove(object);
            return null;
        }
        if (type == "h3d.scene.Graphics") {
            switch name {
                case "lineStyle": object.width = args[0]; object.color = args[1]; object.alpha = args[2];
                case "moveTo", "lineTo": object.points.push(args.copy());
                case "flush": object.flushed = true;
                default: throw "Unexpected graphics call";
            }
            return null;
        }
        if (type == "h3d.scene.Object" && name == "getMaterials") {
            if (args.length != 2 || args[0] != null || args[1] != null) throw "Incorrect getMaterials signature";
            materialReads++;
            return object.materials;
        }
        if (type != "h3d.mat.Pass" || args.length != 1) throw "Unexpected native call";
        writes++;
        switch name {
            case "setPassName": object.name = args[0]; object.passId = args[0];
            case "set_depthTest":
                if (failNextDepthTest) { failNextDepthTest = false; throw "Test depth setter failure"; }
                object.depthTest = args[0]; object.testBits = args[0];
            case "set_depthWrite": object.depthWrite = args[0]; object.writeBits = args[0];
            default: throw "Unexpected native pass mutation: " + name;
        }
        return args[0];
    }
}
