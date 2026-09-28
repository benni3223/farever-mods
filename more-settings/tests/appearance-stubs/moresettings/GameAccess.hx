package moresettings;

/** Audited native skin-copy/property boundary, with controllable failures. */
class GameAccess {
    public static var portraitScene:Dynamic;
    public static var portraitPrefab:Dynamic;
    public static var portraitButtons:Array<Dynamic> = [];
    public static var portraitViews:Array<Dynamic> = [];
    public static var portraitInputs:Array<Dynamic> = [];
    public static var portraitRenders:Array<Dynamic> = [];
    public static var portraitSetups = 0;
    public static var failPortrait = false;
    // DOMKit reapplies bitmap dimensions after hover/selection. Direct native
    // Bitmap setters do not update these styles.
    public static function reflowPortrait(button:Dynamic):Void {
        var icon = field(button, "icon");
        var styles:Dynamic = field(field(icon, "dom"), "styles");
        for (axis in ["width", "height"]) {
            var fixed = field(styles, axis);
            set(icon, axis, fixed == null ? 64.0 : fixed);
        }
    }
    public static function current(t:String, n:String):Dynamic {
        if (t != "gfx.PortraitGen") throw "Unexpected global";
        return n == "scene" ? portraitScene : portraitPrefab;
    }
    public static function setCurrent(t:String, n:String, value:Dynamic):Void {
        if (t != "gfx.PortraitGen") throw "Unexpected global";
        if (n == "scene") portraitScene = value; else portraitPrefab = value;
    }
    public static var writes = 0;
    public static var failCopy = false;
    public static var ignoreWrite = false;
    public static var bodyWrites = 0;
    public static var refreshes = 0;
    public static var dialogTitle:String;
    public static var dialogText:String;
    public static var dialogButton:Dynamic;
    public static var swatchBitmaps:Array<Dynamic> = [];
    public static var swatchBorders:Array<Dynamic> = [];
    public static function field(o:Dynamic, n:String):Dynamic return o == null ? null : Reflect.field(o, n);
    public static function set(o:Dynamic, n:String, value:Dynamic):Void if (o != null) Reflect.setField(o, n, value);
    public static function text(v:Dynamic):String return v == null ? "" : Std.string(v);
    public static function number(v:Dynamic, fallback:Float = 0):Float return v == null ? fallback : Std.parseFloat(Std.string(v));
    public static function integer(v:Dynamic, fallback = 0):Int return v == null ? fallback : Std.int(number(v));
    public static function array(v:Dynamic):Array<Dynamic> return v == null ? [] : cast v;
    public static function call(t:String, n:String, o:Dynamic, ?args:Array<Dynamic>):Dynamic {
        if (t == "h3d.scene.Object") {
            switch n {
                case "getObjectByName": return field(o, "head");
                case "getAbsPos": return field(o, "matrix");
                case "addChild": set(args[0], "parent", o); return null;
                case "remove": set(o, "parent", null); return null;
                default: throw "Unexpected scene call";
            }
        }
        if (t == "h3d.Camera" && n == "update") return null;
        if (t == "domkit.Properties" && n == "initStyle") {
            var styles = field(o, "styles");
            if (styles == null) { styles = {}; set(o, "styles", styles); }
            set(styles, args[0], args[1]); return null;
        }
        if (t == "client.UnitView" && n == "setUnit") {
            portraitSetups++;
            set(o, "skin", args[2]); set(o, "model", args[1]); return null;
        }
        if (t == "client.UnitView" && n == "isReady") return field(o, "ready");
        if (t == "hxd.res.Any" && n == "toPrefab") return {};
        if (t == "h3d.mat.Texture" && n == "dispose") { set(o, "disposed", true); return null; }
        if (t == "ui.comp.BodyPreviewButton" && n == "refreshPortrait") {
            portraitRenders.push(o);
            var skin = field(field(o, "view"), "skin");
            var snapshot:Dynamic = {};
            staticCall("data.UnitSkinData", "copySkinData", [skin, snapshot]);
            portraitInputs.push(snapshot);
            // Native pickers modify their renderer's skin during capture.
            set(skin, "hair", "temporary thumbnail hair");
            set(skin, "shapes", [{name: "temporary shape", val: 1.0}]);
            if (failPortrait) throw "Thumbnail failed";
            return null;
        }
        if (t == "ui.UIElement" && ["set_selected", "set_checkEnable", "set_onClick"].indexOf(n) >= 0) {
            set(o, n.substr(4), args[0]); return args[0];
        }
        if (t == "h2d.Flow" && ["set_padding", "set_minWidth", "set_maxWidth", "set_minHeight", "set_maxHeight"].indexOf(n) >= 0) {
            set(o, n.substr(4), args[0]); return args[0];
        }
        if (t == "h2d.Tile" && n == "sub") return {
            innerTex: field(o, "innerTex"), x: number(field(o, "x")) + number(args[0]),
            y: number(field(o, "y")) + number(args[1]), width: args[2], height: args[3]
        };
        if (t == "h2d.Flow" && n == "getProperties") {
            var props:Dynamic = {};
            set(args[0], "flowProperties", props); return props;
        }
        if (t == "h2d.FlowProperties" && n == "set_isAbsolute") { set(o, "isAbsolute", args[0]); return args[0]; }
        if (t == "h2d.Object" && n == "setPosition") { set(o, "x", args[0]); set(o, "y", args[1]); return null; }
        if (t == "h2d.Bitmap" && (n == "set_width" || n == "set_height")) { set(o, n.substr(4), args[0]); return args[0]; }
        if (t == "h2d.Graphics" && (n == "lineStyle" || n == "drawRect")) { set(o, n, args.copy()); return null; }
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
        if (t == "hxd.Res" && n == "load") return {};
        if (t == "gfx.PortraitGen") {
            switch n {
                case "initRenderContext": portraitScene = {disposed: false}; portraitPrefab = {}; return null;
                case "get_renderScene": return portraitScene;
                case "clearRenderContext": set(portraitScene, "disposed", true); portraitScene = null; return null;
                default: throw "Unexpected portrait renderer call";
            }
        }
        if (t == "lib.ExtensionsUI" && n == "toTile") return field(args[0], "tile");
        if (t == "domkit.Properties" && n == "createNew") {
            if (["template-pick-button", "body-part-pick-button", "blend-shape-pick-button"].indexOf(args[0]) >= 0) {
                var params:Array<Dynamic> = args[2];
                var object:Dynamic = {view: params[1], tex: {disposed: false, realloc: () -> {}}};
                object.icon = {parent: {parent: object}, dom: {}};
                portraitButtons.push(object); return {obj: object};
            }
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

    public static function create(t:String, args:Array<Dynamic>):Dynamic {
        if (t == "client.UnitView") {
            var object:Dynamic = {ready: true, parent: args[0]};
            portraitViews.push(object); return object;
        }
        if (t == "h2d.Bitmap") {
            var object:Dynamic = {tile: args[0], parent: args[1]};
            swatchBitmaps.push(object); return object;
        }
        if (t == "h2d.Graphics") {
            var object:Dynamic = {parent: args[0]};
            swatchBorders.push(object); return object;
        }
        // Texture allocations, native color pickers, GPU readbacks and driver
        // calls are deliberately unsupported: using one must fail the test.
        throw "Unexpected native constructor: " + t;
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
