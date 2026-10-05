package itemutilities;

/** Simulated native scene and UI calls for utility ownership/lifecycle checks. */
class InspectAccess {
    public static var ui:Dynamic;
    public static var geometryCalls = 0;
    public static function field(object:Dynamic, name:String):Dynamic return object == null ? null : Reflect.field(object, name);
    public static function set(object:Dynamic, name:String, value:Dynamic):Void Reflect.setField(object, name, value);
    public static function integer(value:Dynamic, fallback:Int = 0):Int return value == null ? fallback : cast value;
    public static function current(type:String, name:String):Dynamic return type == "hxd.Cursor" ? "Button" : ui;
    public static function object(type:String, parent:Dynamic):Dynamic {
        var value:Dynamic = {type:type,parent:parent,children:[],visible:true,removed:false,enable:true,x:0.,y:0.,items:[],selectedIndex:-1};
        value.dom = {obj:value};
        if (parent != null) parent.children.push(value);
        return value;
    }
    public static function create(type:String, args:Array<Dynamic>):Dynamic {
        if (type == "h2d.Graphics") return object(type,args[0]);
        if (type == "h2d.Interactive") {
            var result = object(type,args[2]); result.width=args[0]; result.height=args[1]; return result;
        }
        throw "Unexpected native constructor: " + type;
    }
    public static function call(type:String, name:String, value:Dynamic, ?args:Array<Dynamic>):Dynamic {
        if (type == "h2d.Graphics") { geometryCalls++; return null; }
        return switch type + "." + name {
            case "hl.types.ArrayObj.slice": (cast value:Array<Dynamic>).slice(args[0],args[1]);
            case "hl.types.ArrayObj.pushDyn": (cast value:Array<Dynamic>).push(args[0]);
            case "ui.UIElement.set_onClick": value.onClick=args[0]; null;
            case "ui.UIElement.set_textTip": value.textTip=args[0]; null;
            case "ui.UIElement.set_selected": value.selected=args[0]; null;
            case "ui.UIElement.set_enable", "ui.comp.Dropdown.set_enable": value.enable=args[0]; null;
            case "ui.comp.Dropdown.set_options": value.options=args[0]; null;
            case "ui.comp.Dropdown.initSelectedIndex": value.selectedIndex=args[0]; null;
            case "ui.comp.Dropdown.isOpen": value.listWindow != null;
            case "ui.comp.Dropdown.close":
                if (value.listWindow != null) call("h2d.Object","remove",value.listWindow);
                value.listWindow=null; null;
            case "h2d.Interactive.set_cursor": value.cursor=args[0]; null;
            case "h2d.Object.getScene":
                var object:Dynamic=value;
                while (object != null && object.type != "Scene") object=object.parent;
                object;
            case "h2d.Object.contains":
                var object:Dynamic=args[0];
                while (object != null && object != value) object=object.parent;
                object != null;
            case "h2d.Object.remove":
                if (value.parent != null) value.parent.children.remove(value);
                value.parent=null; value.removed=true; null;
            case "ui.BaseUI.getTopInteractiveElement": value.top;
            default: throw "Unexpected native UI call: " + type + "." + name;
        }
    }
}
