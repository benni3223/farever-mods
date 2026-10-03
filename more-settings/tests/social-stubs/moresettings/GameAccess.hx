package moresettings;

class GameAccess {
    public static var me:Dynamic;
    public static var ui:Dynamic;
    public static var calls:Array<{type:String, name:String, object:Dynamic, args:Array<Dynamic>}> = [];
    public static var saved:Dynamic;
    public static var cancel:Dynamic;
    public static var dialog:Dynamic;
    public static var reason = "Ok";
    public static function field(object:Dynamic, name:String):Dynamic return object == null ? null : Reflect.field(object, name);
    public static function text(value:Dynamic, fallback = ""):String return value == null ? fallback : Std.string(value);
    public static function number(value:Dynamic, fallback:Float = 0):Float return value == null ? fallback : value;
    public static function integer(value:Dynamic, fallback = 0):Int return Std.int(number(value, fallback));
    public static function set(object:Dynamic, name:String, value:Dynamic):Void if (object != null) Reflect.setField(object, name, value);
    public static function isA(object:Dynamic, type:String):Bool return field(object, "type") == type;
    public static function array(value:Dynamic, proxy = false):Array<Dynamic> {
        if (proxy) value = field(value, "array");
        return value == null ? [] : cast value;
    }
    public static function enumeration(type:String, name:String):Dynamic return name;
    public static function enumValue(type:String, name:String, args:Array<Dynamic>):Dynamic return {type:type, name:name, args:args};
    public static function current(type:String, name:String):Dynamic return type == "Data" ? {byId: {}} : ui;
    public static function staticCall(type:String, name:String, args:Array<Dynamic>):Dynamic {
        if (type == "HText" && name == "reason") return args[0];
        throw type + "." + name;
    }
    public static function create(type:String, args:Array<Dynamic>):Dynamic {
        if (type != "h2d.Text") throw type;
        var obj:Dynamic = {type:type, font:args[0], parent:args[1], scaleX:1.0, text:"", children:[], x:0.0,y:0.0};
        var parent:Dynamic = args[1]; parent.children.push(obj);
        return obj;
    }
    public static function call(type:String, name:String, object:Dynamic, ?args:Array<Dynamic>):Dynamic {
        if (args == null) args = [];
        calls.push({type:type,name:name,object:object,args:args});
        if (type == "hl.types.ArrayObj") {
            var a:Array<Dynamic> = cast object;
            return switch name {
                case "pop": a.pop();
                case "insert": a.insert(args[0], args[1]); null;
                default: throw name;
            };
        }
        return switch name {
            case "get_myPlayer": me;
            case "get_baseUI": ui;
            case "getName": object.name;
            case "get_isSolo": object.players.array.length < 2;
            case "hasInvitePlayerAllowed", "invitePlayer", "requestLeave": reason;
            case "sendInviteGroup", "initStyle": null;
            case "chatError": object.errors.push(args[0]); null;
            case "focus": object.focused = true; null;
            case "unfocus": object.focused = false; null;
            case "setChannel": object.channel = args[0]; null;
            case "get" if (type == "haxe.ds.StringMap"): {name:"Send message"};
            case "bindAction": object.boundActions.push(args[0]); null;
            case "hasClass": var classes:Array<String> = object.classes; classes.indexOf(args[0]) >= 0;
            case "get_numChildren": object.children.length;
            case "getChildAt": object.children[args[0]];
            case "get_outerWidth": object.calculatedWidth;
            case "getProperties": {};
            case "set_isAbsolute": null;
            case "setScale": object.scaleX = args[0]; null;
            case "setPosition": object.x = args[0]; object.y = args[1]; null;
            case "getBounds":
                var max:Float = field(object, "maxWidthText") == null ? 10000 : object.maxWidthText;
                {xMin:0.0, xMax:Math.min(text(object.text).length * 7, max), yMin:0.0, yMax:16.0};
            case "calcTextWidth": text(args[0]).length * 7.0;
            case "set_font": object.font = args[0]; args[0];
            case "set_text": object.text = args[0]; args[0];
            case "set_textColor", "set_lineBreak", "set_textTip", "set_textMultiline", "set_useEllipsis", "set_maxWidthText":
                set(object,name.substr(4),args[0]); args[0];
            case "setText": object.text = args[0]; null;
            case "rebuild": object.rebuilds++; null;
            case "displayTextInputDialog":
                saved = args[3]; cancel = args[4];
                dialog = {input:{input:{text:args[2]}},buttons:[{},{}]}; dialog;
            default: throw type + "." + name;
        };
    }
}
