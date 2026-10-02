package bettermodsettings;

import bettermodsettings.SettingTooltip.TooltipBounds;
import haxe.ds.ObjectMap;

private typedef HelpIcon = {
    var label:Dynamic;
    var parent:Dynamic;
    var icon:Dynamic;
    var mark:Dynamic;
    var layoutErrorLogged:Bool;
}

/** Independent help icons with padded, unclipped foreground tooltips. */
class NativeSettingTooltip {
    static inline var ICON_SIZE = 24;
    static inline var ICON_GAP = 8;
    static inline var BACKGROUND_COLOR = 0xEBD6CD;
    static inline var FOREGROUND_COLOR = 0x4B2313;
    static var icons:ObjectMap<Dynamic, HelpIcon> = new ObjectMap();
    static var members:Map<String, hlx.runtime.ResolvedMember> = [];
    static var active:{icon:Dynamic, tip:Dynamic, ui:Dynamic};

    public static function attach(label:Dynamic, text:String):Void {
        if (label == null || text == null) return;
        var parent = field(label, "parent");
        var properties = field(parent, "dom");
        if (properties == null) return;
        // Keep the native label's layout, and reserve trailing padding for an
        // absolute icon. Flow otherwise centers against the font's line box,
        // not its visible glyphs, and can leave the separator behind the icon.
        var icon = create("h2d.Object", [parent]);
        absolute(parent, icon);
        var graphics = create("h2d.Graphics", [icon]);
        smoothCircle(graphics, 11.0, FOREGROUND_COLOR);
        smoothCircle(graphics, 9.4, BACKGROUND_COLOR);
        // More segments alone cannot smooth pixel edges. Supersample only
        // this small circle, then bilinearly downsample through the native
        // filter path; leave the text and window at their normal resolution.
        var antialias = create("h2d.filter.Nothing", []);
        HlxRuntime.setField(antialias, "smooth", true);
        HlxRuntime.setField(antialias, "boundsExtend", 1.0);
        call("h2d.filter.Filter", "set_useScreenResolution", antialias, [true]);
        call("h2d.filter.Filter", "set_resolutionScale", antialias, [4.0]);
        call("h2d.Object", "set_filter", graphics, [antialias]);
        var mark = create("h2d.Text", [field(label, "font"), icon]);
        call("h2d.Text", "set_text", mark, ["?"]);
        call("h2d.Text", "set_textColor", mark, [FOREGROUND_COLOR]);
        var entry:HelpIcon = {label: label, parent: parent, icon: icon, mark: mark, layoutErrorLogged: false};
        icons.set(label, entry);
        var previous = field(parent, "onAfterReflow");
        HlxRuntime.setField(parent, "onAfterReflow", function():Void {
            if (previous != null) Reflect.callMethod(parent, previous, []);
            try positionIcon(entry) catch (error:Dynamic) {
                if (!entry.layoutErrorLogged) {
                    entry.layoutErrorLogged = true;
                    trace("[BetterModSettings] Could not align setting tooltip icon: " + error);
                }
            }
        });
        refreshLabel(label);
        var input = create("h2d.Interactive", [24.0, 24.0, icon, null]);
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
        // This panel owns its fill and padding. The native Tooltip wrapper
        // supplies anchoring/lifecycle but has no background for this content.
        var content = create("h2d.Object", [null]);
        var background = create("h2d.Graphics", [content]);
        // Plain Text treats quotes, angle brackets and ampersands literally.
        var body = create("h2d.Text", [field(label, "font"), content]);
        var scale = number(field(label, "scaleX"), 1);
        if (scale <= 0) scale = 1;
        scale *= 0.9;
        call("h2d.Object", "setScale", body, [scale]);
        // Keep a whole-pixel line advance at the tooltip's reduced font size,
        // with a little extra leading so descenders don't crowd the next row.
        var fontLineHeight = Math.max(1, number(field(field(label, "font"), "lineHeight"), 20));
        var lineAdvance = Math.ceil(fontLineHeight * scale) + 2;
        call("h2d.Text", "set_lineSpacing", body, [lineAdvance / scale - fontLineHeight]);
        call("h2d.Text", "set_maxWidth", body, [360.0 / scale]);
        call("h2d.Text", "set_lineBreak", body, [true]);
        call("h2d.Text", "set_textColor", body, [FOREGROUND_COLOR]);
        call("h2d.Text", "set_text", body, [text]);
        var ink = bounds(call("h2d.Object", "getBounds", body, [body, null]));
        var width = (ink.xMax - ink.xMin) * scale + 28;
        var height = (ink.yMax - ink.yMin) * scale + 24;
        call("h2d.Object", "setPosition", body, [14 - ink.xMin * scale, 12 - ink.yMin * scale]);
        // Layered translucent shapes give a soft shadow without a render-target
        // filter. Its bounds are included in the existing screen-edge clamp.
        panelRect(background, -2, 3, width + 4, height + 5, 8, 0x332014, 0.06);
        panelRect(background, 0, 4, width + 2, height + 2, 7, 0x332014, 0.10);
        panelRect(background, 2, 4, width, height, 6, 0x332014, 0.18);
        panelRect(background, 0, 0, width, height, 6, FOREGROUND_COLOR, 1);
        panelRect(background, 1, 1, width - 2, height - 2, 5, BACKGROUND_COLOR, 1);
        var tip = call("ui.BaseUI", "setTip", ui, [content, icon, null, null]);
        if (tip == null) {
            call("h2d.Object", "remove", content);
            return;
        }
        active = {icon: icon, tip: tip, ui: ui};
        // The foreground overlay is above regular windows, dropdowns and tips.
        // BaseUI still owns removal; placement uses this parent's coordinates.
        var overlay = field(ui, "rootOverlay");
        if (overlay != null) {
            call("h2d.Object", "addChild", overlay, [tip]);
            absolute(overlay, tip);
        }
    }

    /** Reapply after native styles settle, just like the option label itself. */
    public static function refreshLabel(label:Dynamic):Void {
        var entry = icons.get(label);
        if (entry == null) return;
        call("h2d.Flow", "set_paddingRight", entry.parent, [ICON_GAP + ICON_SIZE]);
        call("h2d.Text", "set_font", entry.mark, [field(label, "font")]);
        var ink = bounds(call("h2d.Object", "getBounds", entry.mark, [entry.mark, null]));
        var scale = Math.min(13 / Math.max(1, ink.xMax - ink.xMin),
            17 / Math.max(1, ink.yMax - ink.yMin));
        call("h2d.Object", "setScale", entry.mark, [scale]);
        // Text bounds include the origin and advance width, so positive glyph
        // bearings leave blank space above/beside a lone question mark. Keep
        // its size but center its actual glyph tile, including both bearings.
        var character = call("h2d.Font", "getChar", field(label, "font"), [63]);
        var tile = field(character, "t");
        if (tile != null && number(field(tile, "width")) > 0 && number(field(tile, "height")) > 0) {
            ink.xMin = number(field(tile, "dx"));
            ink.yMin = number(field(tile, "dy"));
            ink.xMax = ink.xMin + number(field(tile, "width"));
            ink.yMax = ink.yMin + number(field(tile, "height"));
        }
        call("h2d.Object", "setPosition", entry.mark, [
            (ICON_SIZE - (ink.xMax + ink.xMin) * scale) / 2,
            (ICON_SIZE - (ink.yMax + ink.yMin) * scale) / 2
        ]);
        positionIcon(entry);
    }

    static function positionIcon(entry:HelpIcon):Void {
        var ink = bounds(call("h2d.Object", "getBounds", entry.label, [entry.label, null]));
        var x = number(field(entry.label, "x")) + ink.xMax * number(field(entry.label, "scaleX"), 1) + ICON_GAP;
        var y = number(field(entry.label, "y"))
            + (ink.yMin + ink.yMax) * number(field(entry.label, "scaleY"), 1) / 2 - ICON_SIZE / 2;
        call("h2d.Object", "setPosition", entry.icon, [x, y]);
    }

    public static function reset():Void {
        hide();
        icons = new ObjectMap();
    }

    static function smoothCircle(graphics:Dynamic, radius:Float, color:Int):Void {
        // A one-pixel coverage ramp softens both edges of the ring. Bilinear
        // downsampling alone samples only a few high-resolution texels and can
        // still leave steps on a thin, high-contrast outline. Adjust each
        // layer's opacity so their combined coverage increases linearly.
        var previousCoverage = 0.0;
        for (step in 1...9) {
            var coverage = step / 8.0;
            var alpha = (coverage - previousCoverage) / (1 - previousCoverage);
            var edgeRadius = radius + 0.5 - (step - 0.5) / 8.0;
            call("h2d.Graphics", "beginFill", graphics, [color, alpha]);
            call("h2d.Graphics", "drawCircle", graphics, [12.0, 12.0, edgeRadius, 96]);
            call("h2d.Graphics", "endFill", graphics);
            previousCoverage = coverage;
        }
    }

    static function panelRect(g:Dynamic, x:Float, y:Float, w:Float, h:Float,
            radius:Float, color:Int, alpha:Float):Void {
        call("h2d.Graphics", "beginFill", g, [color, alpha]);
        call("h2d.Graphics", "drawRoundedRect", g, [x, y, w, h, radius, 8]);
        call("h2d.Graphics", "endFill", g);
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
}
