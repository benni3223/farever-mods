package lootdb;

import lootdb.GameAccess as G;

/** DOMKit helpers for the loot browser. */
class NativeUi {
    public static function prepareBody(body:Dynamic):Dynamic {
        var object = G.field(body, "obj");
        var options = G.field(object, "optionsList");
        var input = G.field(object, "inputList");
        var container = G.field(options, "container");
        if (container == null) throw "Native Options content container was not found";
        for (component in [object, options, input])
            if (component != null) G.call("ui.UIElement", "clearBinds", component);
        show(input, false);
        show(G.field(options, "applyBtn"), false);
        for (child in children(container)) show(child, false);
        return container;
    }
    public static function bodyIntact(body:Dynamic, container:Dynamic):Bool {
        return container != null && G.field(container, "removed") != true
            && G.field(container, "parent") != null
            && G.field(G.field(G.field(body, "obj"), "optionsList"), "container") == container;
    }
    public static function node(component:String, parent:Dynamic, args:Array<Dynamic>, id:String, ?layout:String):Dynamic {
        var attributes:Dynamic = {id: id};
        if (layout != null) Reflect.setField(attributes, "layout", layout);
        var result = G.staticCall("domkit.Properties", "createNew", [component, parent, args, attributes]);
        if (result == null) throw "Could not create " + component;
        return result;
    }
    public static function label(parent:Dynamic, value:String):Dynamic {
        var d = node("text", parent, [LiteralText.escape(value)], "lootDbText");
        var obj = G.field(d, "obj");
        G.call("h2d.Text", "set_textColor", obj, [0x5b4334]);
        return obj;
    }
    /** Flat control drawn by us: interactive, fill, and a text label. Not a DOMKit button. */
    public static function face(parent:Dynamic, font:Dynamic, text:String, click:Void->Void):Dynamic {
        var host = G.field(parent, "obj");
        if (host == null) host = parent;
        var root = G.create("h2d.Interactive", [10.0, 10.0, host, null]);
        var bg = G.create("h2d.Graphics", [root]);
        var title = G.create("h2d.Text", [font, root]);
        G.call("h2d.Text", "set_text", title, [text]);
        G.call("h2d.Text", "set_textColor", title, [0x3a2a22]);
        if (click != null) {
            G.set(root, "onClick", (event:Dynamic) -> {
                G.set(event, "propagate", false);
                try click() catch (error:Dynamic) Log.write("click failed: " + Log.problem(error));
            });
            G.set(root, "onPush", (event:Dynamic) -> G.set(event, "propagate", false));
        }
        return {obj: root, bg: bg, title: title, key: ""};
    }

    public static function paintFace(face:Dynamic, w:Float, h:Float, fill:Int, textColor:Int, textX:Float = -1):Void {
        if (face == null) return;
        G.set(face.obj, "width", w);
        G.set(face.obj, "height", h);
        G.call("h2d.Graphics", "clear", face.bg);
        G.call("h2d.Graphics", "beginFill", face.bg, [fill, 1.0]);
        G.call("h2d.Graphics", "drawRect", face.bg, [0, 0, w, h]);
        G.call("h2d.Graphics", "endFill", face.bg);
        G.call("h2d.Text", "set_textColor", face.title, [textColor]);
        var tw = G.number(G.call("h2d.Text", "get_textWidth", face.title), 0);
        var th = G.number(G.call("h2d.Text", "get_textHeight", face.title), 14);
        var x = textX < 0 ? Math.max(6, (w - tw) / 2) : textX;
        position(face.title, x, Math.max(2, (h - th) / 2));
    }

    public static function button(parent:Dynamic, value:String, id:String, click:Void->Void):Dynamic {
        var object = G.field(node("button", parent, [LiteralText.escape(value)], id), "obj");
        G.call("ui.UIElement", "set_onClick", object, [click]);
        return object;
    }

    /** Small square HUD control with a chest icon for the loot catalog. */
    public static function chestButton(parent:Dynamic, click:Void->Void):Dynamic {
        var object = button(parent, "", "lootDbOpen", click);
        padding(object, 0);
        size(object, 34, 30);
        var chest = G.create("h2d.Graphics", [object]);
        absolute(object, chest);
        position(chest, 5, 4);
        G.call("h2d.Graphics", "lineStyle", chest, [1.5, 0x5b4334, 1.0]);
        G.call("h2d.Graphics", "beginFill", chest, [0xc48a3a, 1.0]);
        G.call("h2d.Graphics", "drawRect", chest, [1, 10, 22, 12]);
        G.call("h2d.Graphics", "endFill", chest);
        G.call("h2d.Graphics", "beginFill", chest, [0xd9a45a, 1.0]);
        G.call("h2d.Graphics", "drawRect", chest, [1, 6, 22, 6]);
        G.call("h2d.Graphics", "endFill", chest);
        G.call("h2d.Graphics", "lineStyle", chest, [1.5, 0x5b4334, 1.0]);
        G.call("h2d.Graphics", "moveTo", chest, [12, 6]);
        G.call("h2d.Graphics", "lineTo", chest, [12, 22]);
        G.call("h2d.Graphics", "beginFill", chest, [0xe8c878, 1.0]);
        G.call("h2d.Graphics", "drawRect", chest, [9, 12, 6, 5]);
        G.call("h2d.Graphics", "endFill", chest);
        G.call("h2d.Graphics", "beginFill", chest, [0xb48c50, 1.0]);
        G.call("h2d.Graphics", "drawCircle", chest, [12, 14.5, 1.2, 8]);
        G.call("h2d.Graphics", "endFill", chest);
        return object;
    }
    public static function flow(dom:Dynamic, method:String, value:Dynamic):Void G.call("h2d.Flow", method, G.field(dom, "obj"), [value]);
    public static function style(object:Dynamic, property:String, value:Dynamic):Void {
        var dom = G.field(object, "dom");
        if (dom != null) G.call("domkit.Properties", "initStyle", dom, [property, value]);
    }
    public static function padding(object:Dynamic, value:Int):Void {
        G.call("h2d.Flow", "set_padding", object, [value]);
        for (side in ["left", "right", "top", "bottom"]) style(object, "padding-" + side, value);
    }
    public static function size(object:Dynamic, w:Int, h:Int = -1):Void {
        G.call("h2d.Flow", "set_minWidth", object, [w]);
        G.call("h2d.Flow", "set_maxWidth", object, [w]);
        if (h >= 0) {
            G.call("h2d.Flow", "set_minHeight", object, [h]);
            G.call("h2d.Flow", "set_maxHeight", object, [h]);
        }
        var d = G.field(object, "dom");
        if (d != null) {
            for (property in ["width", "min-width", "max-width"]) G.call("domkit.Properties", "initStyle", d, [property, w]);
            if (h >= 0) for (property in ["height", "min-height", "max-height"]) G.call("domkit.Properties", "initStyle", d, [property, h]);
        }
    }
    public static function children(object:Dynamic):Array<Dynamic> {
        var count = G.integer(G.call("h2d.Object", "get_numChildren", object));
        return [for (i in 0...count) G.call("h2d.Object", "getChildAt", object, [i])];
    }
    public static function absolute(parent:Dynamic, child:Dynamic):Void {
        var p = G.call("h2d.Flow", "getProperties", parent, [child]);
        G.call("h2d.FlowProperties", "set_isAbsolute", p, [true]);
        G.set(p, "horizontalAlign", null); G.set(p, "verticalAlign", null);
        G.set(p, "offsetX", 0); G.set(p, "offsetY", 0);
        var dom = G.field(child, "dom");
        if (dom != null) {
            G.call("domkit.Properties", "initStyle", dom, ["position", true]);
            for (key in ["halign", "valign"]) G.call("domkit.Properties", "initStyle", dom, [key, null]);
            for (key in ["offset-x", "offset-y"]) G.call("domkit.Properties", "initStyle", dom, [key, 0]);
        }
    }
    public static function position(obj:Dynamic, x:Float, y:Float):Void G.call("h2d.Object", "setPosition", obj, [x, y]);
    public static function show(obj:Dynamic, visible:Bool):Void { if (obj != null) G.call("h2d.Object", "set_visible", obj, [visible]); }
    public static function setText(obj:Dynamic, value:String):Void {
        if (obj != null) G.call("ui.comp.FmtText", "set_text", obj, [LiteralText.escape(value)]);
    }
    public static function setPlain(obj:Dynamic, value:String):Void {
        if (obj != null) G.call("h2d.Text", "set_text", obj, [value]);
    }
    /** Game markup such as <good>, already escaped where it includes catalog text. */
    public static function setHtml(obj:Dynamic, value:String):Void {
        if (obj != null) G.call("ui.comp.FmtText", "set_text", obj, [value]);
    }
}
