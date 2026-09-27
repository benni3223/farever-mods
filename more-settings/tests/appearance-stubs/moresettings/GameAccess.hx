package moresettings;

/** Audited native skin-copy/property boundary, with controllable failures. */
class GameAccess {
    public static var writes = 0;
    public static var failCopy = false;
    public static var ignoreWrite = false;
    public static var bodyWrites = 0;
    public static var refreshes = 0;
    public static var dialogTitle:String;
    public static var dialogText:String;
    public static var dialogButton:Dynamic;
    public static function field(o:Dynamic, n:String):Dynamic return o == null ? null : Reflect.field(o, n);
    public static function set(o:Dynamic, n:String, value:Dynamic):Void if (o != null) Reflect.setField(o, n, value);
    public static function text(v:Dynamic):String return v == null ? "" : Std.string(v);
    public static function number(v:Dynamic):Float return v == null ? 0 : Std.parseFloat(Std.string(v));
    public static function integer(v:Dynamic, fallback = 0):Int return v == null ? fallback : Std.int(number(v));
    public static function array(v:Dynamic):Array<Dynamic> return v == null ? [] : cast v;
    public static function call(t:String, n:String, o:Dynamic, ?args:Array<Dynamic>):Dynamic {
        if (t == "hl.types.ArrayObj" && n == "slice") return array(o).slice(args[0], args[1]);
        if (t == "hl.types.ArrayObj" && n == "pushDyn") return array(o).push(args[0]);
        if (t == "ui.BaseUI" && n == "displayDialog") {
            dialogTitle = parseText(args[0]); dialogText = parseText(args[1]);
            dialogButton = {};
            return {buttons: [dialogButton]};
        }
        if (t == "ui.comp.Button" && n == "setText") { set(o, "text", parseText(args[0])); return null; }
        if (t == "client.UnitView" && n == "applyModelInfo") { refreshes++; return null; }
        if (t != "ent.Unit") throw "Unexpected native type";
        if (n == "getSkin") return {template: field(o, "skin")};
        if (n == "set_skin") {
            bodyWrites++; Reflect.setField(o, "skin", args[0]); return args[0];
        }
        if (n != "set_skinData") throw "Unexpected native call";
        if (!ignoreWrite) { writes++; Reflect.setField(o, "skinData", args[0]); }
        return field(o, "skinData");
    }
    public static function staticCall(t:String, n:String, args:Array<Dynamic>):Dynamic {
        if (t == "domkit.Properties" && n == "createNew") {
            if (args[0] != "button") throw "Unexpected component";
            var params:Array<Dynamic> = args[2];
            return {obj: {text: parseText(params[0])}};
        }
        if (t != "data.UnitSkinData") throw "Unexpected native type";
        if (n == "getDefaultSkinData") return {};
        if (n != "copySkinData") throw "Unexpected native call";
        if (failCopy) throw "Copy failed";
        for (key in Reflect.fields(args[0])) {
            var value:Dynamic = field(args[0], key);
            if (key == "shapes" && value != null) {
                // Native copySkinData keeps active values and clones each shape.
                var shapes:Array<Dynamic> = [];
                for (s in array(value)) if (number(field(s, "val")) > 0)
                    shapes.push({name: text(field(s, "name")), val: number(field(s, "val"))});
                value = shapes;
            }
            Reflect.setField(args[1], key, value);
        }
        return null;
    }

    // Exercise the XML boundary that the native formatted-text controls use.
    // Do not simulate this with a passthrough string assignment: that hid the
    // original unescaped-arrow bug from the appearance state tests.
    static function parseText(value:String):String {
        var root = Xml.parse("<text>" + value + "</text>").firstElement();
        var result = "";
        for (child in root) {
            if (child.nodeType != Xml.PCData) throw "Unexpected markup in a literal label";
            result += child.nodeValue;
        }
        return result;
    }
}
