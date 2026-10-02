package bettermodsettings;

import bettermodsettings.SettingTooltip.TooltipBounds;

/** Independent help-icon hit targets, with tips in the native unclipped tooltip layer. */
class NativeSettingTooltip {
    static var members:Map<String, hlx.runtime.ResolvedMember> = [];
    static var active:{icon:Dynamic, tip:Dynamic, ui:Dynamic};

    public static function attach(label:Dynamic, text:String):Void {
        if (label == null || text == null) return;
        var parent = field(label, "parent");
        var properties = field(parent, "dom");
        if (properties == null) return;
        // OptionLine's nameContainer already owns the label. Appending here
        // reserves real layout space immediately after it, before the separator.
        var horizontal = HlxRuntime.constructEnum(HlxRuntime.resolveType("h2d.FlowLayout"), "Horizontal", []);
        style(properties, "layout", horizontal);
        style(properties, "hspacing", 6);
        var props = staticCall("domkit.Properties", "createNew", [
            "flow", properties, [], {"class": "bms-tooltip-icon"}
        ]);
        var icon = field(props, "obj");
        style(props, "width", 18);
        style(props, "height", 18);
        style(props, "padding", 0);
        var middle = HlxRuntime.constructEnum(HlxRuntime.resolveType("h2d.FlowAlign"), "Middle", []);
        for (child in [label, icon]) {
            var layout = call("h2d.Flow", "getProperties", parent, [child]);
            HlxRuntime.setField(layout, "verticalAlign", middle);
        }
        var graphics = create("h2d.Graphics", [icon]);
        absolute(icon, graphics);
        call("h2d.Graphics", "beginFill", graphics, [0x8A5F46, 1.0]);
        call("h2d.Graphics", "drawCircle", graphics, [9.0, 9.0, 8.0, 24]);
        call("h2d.Graphics", "endFill", graphics);
        call("h2d.Graphics", "beginFill", graphics, [0xF6E4C1, 1.0]);
        call("h2d.Graphics", "drawCircle", graphics, [9.0, 9.0, 6.4, 24]);
        call("h2d.Graphics", "endFill", graphics);
        var mark = create("h2d.Text", [field(label, "font"), icon]);
        absolute(icon, mark);
        call("h2d.Text", "set_text", mark, ["?"]);
        call("h2d.Text", "set_textColor", mark, [0x71452C]);
        var width = number(call("h2d.Text", "get_textWidth", mark));
        var height = number(call("h2d.Text", "get_textHeight", mark));
        var scale = Math.min(10 / Math.max(1, width), 14 / Math.max(1, height));
        call("h2d.Object", "setScale", mark, [scale]);
        call("h2d.Object", "setPosition", mark, [(18 - width * scale) / 2, (18 - height * scale) / 2]);
        var input = create("h2d.Interactive", [18.0, 18.0, icon, null]);
        absolute(icon, input);
        HlxRuntime.setField(input, "propagateEvents", false);
        HlxRuntime.setField(input, "onOver", function(_:Dynamic):Void {
            try show(icon, label, text) catch (error:Dynamic) {
                hide();
                trace("[BetterModSettings] Could not show setting tooltip: " + error);
            }
        });
        HlxRuntime.setField(input, "onOut", function(_:Dynamic):Void {
            if (active != null && active.icon == icon) hide();
        });
    }

    static function show(icon:Dynamic, label:Dynamic, text:String):Void {
        hide();
        if (!visible(icon)) return;
        var ui = HlxRuntime.resolveStaticField(HlxRuntime.resolveType("ui.BaseUI"), "current");
        if (ui == null) return;
        var props = staticCall("domkit.Properties", "createNew", ["flow", null, [], null]);
        var content = field(props, "obj");
        // Plain Text treats quotes, angle brackets and ampersands literally.
        // Never feed a mod author's tooltip into FmtText's markup parser.
        var body = create("h2d.Text", [field(label, "font"), content]);
        var scale = number(field(label, "scaleX"), 1);
        if (scale <= 0) scale = 1;
        call("h2d.Object", "setScale", body, [scale]);
        call("h2d.Text", "set_maxWidth", body, [360.0 / scale]);
        call("h2d.Text", "set_lineBreak", body, [true]);
        call("h2d.Text", "set_textColor", body, [0xF5F0E8]);
        call("h2d.Text", "set_text", body, [text]);
        var tip = call("ui.BaseUI", "setTip", ui, [content, icon, null, null]);
        if (tip == null) {
            call("h2d.Object", "remove", content);
            return;
        }
        active = {icon: icon, tip: tip, ui: ui};
        // BaseUI.setTip attaches to rootTips, above windows and outside the
        // scrolling panel. Position only after native layout has measured it.
    }

    /** Called after native Tooltip.sync; never use screen pixels as local positions. */
    public static function fit(tip:Dynamic):Void {
        if (active == null || active.tip != tip) return;
        try {
            if (!visible(active.icon)) { hide(); return; }
            var parent = field(tip, "parent");
            var scene = call("h2d.Object", "getScene", tip);
            if (parent == null || scene == null) { hide(); return; }
            var anchor = bounds(call("h2d.Object", "getBounds", active.icon, [parent, null]));
            var box = bounds(call("h2d.Object", "getBounds", tip, [tip, null]));
            var first = point(parent, 8, 8);
            var last = point(parent, number(field(scene, "width")) - 8, number(field(scene, "height")) - 8);
            var viewport = {xMin: first.x, yMin: first.y, xMax: last.x, yMax: last.y};
            var gapPoint = point(parent, 8, 16);
            var fit = SettingTooltip.place(anchor, box, viewport, Math.abs(gapPoint.y - first.y));
            call("h2d.Object", "setScale", tip, [fit.scale]);
            call("h2d.Object", "setPosition", tip, [fit.x, fit.y]);
        } catch (error:Dynamic) {
            hide();
            trace("[BetterModSettings] Could not position setting tooltip: " + error);
        }
    }

    public static function onPointerEvent(event:Dynamic):Void {
        if (active == null) return;
        var kind = Type.enumConstructor(field(event, "kind"));
        if (kind == "EWheel" || kind == "EPush" || kind == "EFocusLost") hide();
    }

    public static function hide():Void {
        if (active == null) return;
        var previous = active;
        active = null;
        try {
            if (field(previous.ui, "currentTip") == previous.tip)
                call("ui.BaseUI", "removeTip", previous.ui, [null]);
            else if (field(previous.tip, "parent") != null)
                call("h2d.Object", "remove", previous.tip);
        } catch (_:Dynamic) {}
    }

    static function visible(object:Dynamic):Bool {
        if (object == null || field(object, "parent") == null) return false;
        while (object != null) {
            if (field(object, "visible") == false) return false;
            object = field(object, "parent");
        }
        return true;
    }
    static function point(parent:Dynamic, x:Float, y:Float):{x:Float, y:Float} {
        var p = HlxRuntime.allocInstance(HlxRuntime.resolveType("h2d.col.PointImpl"));
        HlxRuntime.setField(p, "x", x); HlxRuntime.setField(p, "y", y);
        var local = call("h2d.Object", "globalToLocal", parent, [p]);
        return {x: number(field(local, "x")), y: number(field(local, "y"))};
    }
    static function bounds(value:Dynamic):TooltipBounds
        return {xMin: number(field(value, "xMin")), yMin: number(field(value, "yMin")),
            xMax: number(field(value, "xMax")), yMax: number(field(value, "yMax"))};
    static function absolute(parent:Dynamic, child:Dynamic):Void {
        var properties = call("h2d.Flow", "getProperties", parent, [child]);
        call("h2d.FlowProperties", "set_isAbsolute", properties, [true]);
    }
    static function style(properties:Dynamic, name:String, value:Dynamic):Void
        call("domkit.Properties", "initStyle", properties, [name, value]);
    static function field(object:Dynamic, name:String):Dynamic
        return object == null ? null : HlxRuntime.resolveField(object, name);
    static function number(value:Dynamic, fallback:Float = 0):Float {
        var parsed = value == null ? fallback : Std.parseFloat(Std.string(value));
        return Math.isFinite(parsed) ? parsed : fallback;
    }
    static function create(type:String, args:Array<Dynamic>):Dynamic
        return HlxRuntime.constructInstanceByName(HlxRuntime.resolveType(type), args.length, args);
    static function member(type:String, name:String, isStatic:Bool):hlx.runtime.ResolvedMember {
        var key = type + (isStatic ? "::" : ".") + name;
        if (members.exists(key)) return members[key];
        var resolved = HlxRuntime.resolveType(type);
        var method = isStatic ? HlxRuntime.resolveStaticMember(resolved, name) : HlxRuntime.resolveMember(resolved, name);
        if (method == null) throw "Native member unavailable: " + key;
        members[key] = method;
        return method;
    }
    static function call(type:String, name:String, object:Dynamic, ?args:Array<Dynamic>):Dynamic {
        var all:Array<Dynamic> = [object];
        if (args != null) for (arg in args) all.push(arg);
        return HlxRuntime.callResolved(member(type, name, false), all);
    }
    static function staticCall(type:String, name:String, args:Array<Dynamic>):Dynamic
        return HlxRuntime.callResolved(member(type, name, true), args);
}
