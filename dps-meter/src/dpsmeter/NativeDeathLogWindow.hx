package dpsmeter;

import dpsmeter.DeathLog;
import dpsmeter.GameAccess as G;
import dpsmeter.NativeUi.*;

/** Timeline of the last 10 seconds before death: time, health, amount, spell, and source. */
class NativeDeathLogWindow {
    public static var constructing:Bool = false;
    static inline var WIDTH:Int = 760;
    static inline var HEADER:Int = 48;
    static inline var COLUMNS:Int = 0;
    static inline var ROW:Int = 30;
    static inline var VISIBLE:Int = 16;

    var window:Dynamic;
    var owner:Dynamic;
    var root:Dynamic;
    var windowContent:Dynamic;
    var frameBackground:Dynamic;
    var header:Dynamic;
    var title:Dynamic;
    var close:Dynamic;
    var body:Dynamic;
    var container:Dynamic;
    var wrappers:Array<Dynamic> = [];
    var mask:Dynamic;
    var content:Dynamic;
    var wheel:Dynamic;
    var report:Null<DeathReport>;
    var rowCount:Int = 0;
    var scroll:Float = 0;
    var maxScroll:Float = 0;
    var width:Int = 0;
    var height:Int = 0;
    var retryAt:Float = 0;
    var timelineFont:Dynamic;
    var timelineWidth:Int = -1;
    var timelineHeight:Int = 0;

    public function new() {}

    public function present(next:DeathReport):Void {
        pending = next;
        if (window != null) dispose();
    }

    var pending:Null<DeathReport>;

    public function isOpen():Bool return window != null || pending != null;

    public function dismiss():Void {
        pending = null;
        dispose();
    }

    public function update(enabled:Bool, now:Float):Void {
        var ui = G.current("ui.BaseUI", "current");
        if (owner != null && owner != ui) dispose();
        if (window != null && G.field(window, "removed") == true) dispose();
        if (!enabled) { pending = null; dispose(); return; }
        if (ui == null) { dispose(); return; }
        if (pending != null && now >= retryAt) {
            var next = pending;
            try {
                dispose();
                build(ui, next);
                pending = null;
            } catch (error:Dynamic) {
                constructing = false;
                dispose();
                pending = next;
                retryAt = now + 1;
                trace("[DPS Meter] Death log: " + Std.string(error));
                return;
            }
        }
        if (window != null) layout();
    }

    function build(ui:Dynamic, shown:DeathReport):Void {
        owner = ui;
        report = shown;
        constructing = true;
        try window = G.create("ui.win.TitleWindow", ["Options", null])
        catch (error:Dynamic) { constructing = false; throw error; }
        constructing = false;
        if (window == null) throw "TitleWindow construction returned null";
        G.call("ui.win.BaseWindow", "set_windowFlags", window, [8192]);
        root = G.field(ui, "root");
        G.call("h2d.Flow", "addChildAt", root, [window, G.call("h2d.Object", "get_numChildren", root)]);
        absolute(root, window);
        var dom = G.field(window, "dom");
        windowContent = G.field(dom, "contentRoot");
        for (child in children(window)) if (G.field(child, "bgMask") != null) {
            frameBackground = child;
            absolute(window, frameBackground);
            break;
        }
        G.set(dom, "component", G.staticCall("domkit.Component", "get", ["options-window", null]));
        header = G.field(window, "header");
        G.set(header, "headText", "Death Log");
        title = G.field(header, "headerTitle");
        setText(title, "Death Log · Damage " + compact(shown.damage) + " · Healing " + compact(shown.healing));
        var left = G.enumeration("h2d.Align", "Left");
        G.call("h2d.Text", "set_textAlign", title, [left]);
        style(title, "text-align", left);
        show(title, true);
        absolute(header, title);
        close = G.field(header, "closeBtn");
        show(close, true);
        absolute(header, close);
        G.call("ui.UIElement", "set_onClick", close, [() -> dismiss()]);

        body = node("options-content", dom, [0], "dpsDeathLogBody");
        var bodyObject = G.field(body, "obj");
        container = prepareChartBody(body);
        var options = G.field(bodyObject, "optionsList");
        wrappers = [bodyObject, options, container];
        for (object in [window, frameBackground, windowContent, header, bodyObject, options, container]) {
            if (object == null) continue;
            padding(object, 0);
            var limit = G.enumeration("h2d.FlowOverflow", "Limit");
            G.call("h2d.Flow", "set_overflow", object, [limit]);
            style(object, "overflow", limit);
        }
        absolute(window, header);
        absolute(window, windowContent);
        absolute(windowContent, bodyObject);
        absolute(bodyObject, options);
        absolute(options, container);

        var fontParent = label(G.field(container, "dom"), "");
        show(fontParent, false);
        var font = G.field(fontParent, "font");
        timelineFont = font;
        rowCount = shown.rows.length;
        var viewW = (WIDTH - 32) * 1.0;
        var viewH = VISIBLE * ROW * 1.0;
        mask = G.create("h2d.Mask", [viewW, viewH, container]);
        try absolute(container, mask) catch (_:Dynamic) {}
        content = G.create("h2d.Object", [mask]);
        // The shape argument is required. Omitting it aborts the whole window.
        try {
            wheel = G.create("h2d.Interactive", [viewW, viewH, container, null]);
            try absolute(container, wheel) catch (_:Dynamic) {}
            G.set(wheel, "onWheel", onWheel);
        } catch (error:Dynamic) {
            wheel = null;
            trace("[DPS Meter] Death log scroll: " + Std.string(error));
        }
        layout();
    }

    function onWheel(event:Dynamic):Void {
        var dy = G.number(G.field(event, "dy"), G.number(G.field(event, "wheelDelta")));
        if (dy == 0 || content == null) return;
        scroll = Math.max(0, Math.min(maxScroll, scroll + dy * ROW));
        position(content, 0, -scroll);
    }

    function layout():Void {
        var scene = G.field(owner, "s2d");
        var top = localPoint(0, 0);
        var bottom = localPoint(G.number(G.field(scene, "width"), 1920), G.number(G.field(scene, "height"), 1080));
        var w = Std.int(Math.min(WIDTH, bottom.x - top.x - 40));
        var rowHeight = DeathTimeline.rowHeight(w - 32);
        var fullHeight = 62 + Math.max(1, rowCount) * rowHeight + (rowCount <= 1 ? 30 : 0);
        var h = Std.int(Math.min(HEADER + Math.min(520, fullHeight) + 16, bottom.y - top.y - 40));
        if (width == w && height == h) return;
        width = w;
        height = h;
        size(window, width, height);
        if (frameBackground != null) { size(frameBackground, width, height); position(frameBackground, 0, 0); }
        size(header, width - 2, HEADER);
        position(header, 0, 0);
        size(close, 36, 36);
        position(close, width - 52, 6);
        G.call("ui.comp.FmtText", "set_maxWidthText", title, [width - 120]);
        position(title, 16, 12);
        var bodyHeight = height - HEADER - 8;
        size(windowContent, width - 16, bodyHeight);
        position(windowContent, 8, HEADER);
        for (object in wrappers) { size(object, width - 16, bodyHeight); position(object, 0, 0); }
        var viewH = Math.max(1, bodyHeight - 8);
        if (mask != null) {
            G.set(mask, "width", width - 32);
            G.set(mask, "height", viewH);
            position(mask, 0, COLUMNS);
        }
        if (wheel != null) {
            G.set(wheel, "width", width - 32);
            G.set(wheel, "height", viewH);
            position(wheel, 0, COLUMNS);
        }
        if (timelineWidth != width - 32) {
            timelineWidth = width - 32;
            G.call("h2d.Object", "removeChildren", content);
            timelineHeight = NativeDeathTimeline.render(content, timelineFont, report, timelineWidth);
        }
        maxScroll = Math.max(0, timelineHeight - viewH);
        scroll = maxScroll;
        position(content, 0, -scroll);
        place(top, bottom);
    }

    function place(top:{x:Float, y:Float}, bottom:{x:Float, y:Float}):Void {
        position(window, top.x + (bottom.x - top.x - width) / 2, top.y + Math.max(24, (bottom.y - top.y - height) / 5));
    }

    function localPoint(x:Float, y:Float):{x:Float, y:Float} {
        var point = HlxRuntime.allocInstance(HlxRuntime.resolveType("h2d.col.PointImpl"));
        G.set(point, "x", x); G.set(point, "y", y);
        var local = G.call("h2d.Object", "globalToLocal", root, [point]);
        return {x: G.number(G.field(local, "x")), y: G.number(G.field(local, "y"))};
    }

    public function dispose():Void {
        if (window != null) { var old = window; window = null; G.call("h2d.Object", "remove", old); }
        owner = null; root = null; wrappers = [];
        frameBackground = null; body = null; container = null;
        header = null; title = null; close = null; windowContent = null;
        mask = null; content = null; wheel = null; report = null;
        rowCount = 0; scroll = 0; maxScroll = 0;
        timelineFont = null; timelineWidth = -1; timelineHeight = 0;
        width = 0; height = 0;
    }
}
