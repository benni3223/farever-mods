package dpsmeter;

import dpsmeter.CombatModel.Fight;
import dpsmeter.FightHistory;
import dpsmeter.GameAccess as G;
import dpsmeter.NativeUi.*;

/** One native browser: encounter names -> attempts -> the existing damage chart. */
class NativeHistoryWindow {
    public static var constructing:Bool = false;
    var requested:Bool = false;
    var window:Dynamic;
    var owner:Dynamic;
    var root:Dynamic;
    var content:Dynamic;
    var frame:Dynamic;
    var header:Dynamic;
    var title:Dynamic;
    var close:Dynamic;
    var body:Dynamic;
    var container:Dynamic;
    var wrappers:Array<Dynamic> = [];
    var panel:Dynamic;
    var back:Dynamic;
    var heading:Dynamic;
    var detail:Dynamic;
    var dateInfo:Dynamic;
    var list:Dynamic;
    var chartPanel:Dynamic;
    var chart:NativeDamageChart;
    var empty:Dynamic;
    var previous:Dynamic;
    var next:Dynamic;
    var pageLabel:Dynamic;
    var footer:Dynamic;
    var rows:Array<Dynamic> = [];
    var writer:RunWriter;
    var serial:Int = 0;
    var pending:Bool = false;
    var mode:String = "groups";
    var group:String = "";
    var groupsPage:Int = 0;
    var fightsPage:Int = 0;
    var page:Int = 0;
    var total:Int = 0;
    var fight:Fight;
    var width:Int = 0;
    var height:Int = 0;
    var lastRefresh:Float = -1;

    public function new() {}
    public function open():Void { requested = true; }
    public function update(writer:RunWriter, active:Bool, now:Float):Void {
        var ui = G.current("ui.BaseUI", "current");
        if (!active || ui == null) { dispose(); return; }
        if (owner != null && (owner != ui || this.writer != writer)) dispose();
        if (window != null && (G.field(window, "removed") == true || !chartBodyIntact(body, container))) dispose();
        this.writer = writer;
        if (requested) {
            requested = false;
            if (window == null) { build(ui); navigate("groups", "", 0); }
        }
        if (window == null) return;
        var response = writer.receiveHistory();
        while (response != null) {
            if (response.id == serial) display(response);
            response = writer.receiveHistory();
        }
        layout();
        if (mode == "chart" && !pending && fight != null) chart.update(fight, now);
        if (now - lastRefresh >= 0.20) {
            lastRefresh = now;
            alignLabels();
        }
    }
    function navigate(mode:String, group:String, page:Int, ?entry:HistoryEntry):Void {
        this.mode = mode; this.group = group; this.page = page;
        fight = null; pending = true; total = 0; serial++;
        if (mode == "groups") groupsPage = page;
        if (mode == "fights") fightsPage = page;
        for (row in rows) show(row.obj, false);
        show(G.field(list, "obj"), false); show(G.field(chartPanel, "obj"), false);
        setText(empty, "Loading fight history..."); show(empty, true);
        setText(heading, mode == "groups" ? "Choose an encounter" : group);
        setText(detail, mode == "groups" ? "All recorded fights, grouped by name" : mode == "fights"
            ? "Newest first · Times are shown in your local time" : entryDetail(entry));
        setText(dateInfo, mode == "chart" && entry != null ? entryDate(entry) : "");
        show(dateInfo, mode == "chart");
        show(back, mode != "groups");
        show(previous, false); show(next, false); show(pageLabel, false);
        setText(footer, mode == "chart" ? "Click a player for skills; click a skill to return to the players."
            : "Fight logs are kept indefinitely.");
        writer.requestHistory({id: serial, action: mode, group: group, page: page, fightId: entry == null ? "" : entry.id});
        lastRefresh = -1;
    }
    function goBack():Void {
        if (mode == "chart") navigate("fights", group, fightsPage);
        else navigate("groups", "", groupsPage);
    }
    function display(response:HistoryResponse):Void {
        pending = false; total = response.total; page = response.page;
        if (response.error != "") { setText(empty, response.error); show(empty, true); return; }
        if (mode == "chart") {
            try fight = FightHistory.decode(response.record)
            catch (e:Dynamic) {
                setText(empty, "This fight log could not be read. Choose another fight using Back.");
                show(empty, true);
                trace("[DPS Meter] Could not read chart: " + Std.string(e));
                return;
            }
            show(empty, false); show(G.field(chartPanel, "obj"), true);
        } else {
            if (mode == "groups") groupsPage = page; else fightsPage = page;
            var count = mode == "groups" ? response.groups.length : response.entries.length;
            for (i in 0...rows.length) {
                var row = rows[i]; show(row.obj, i < count);
                if (i >= count) continue;
                row.entry = mode == "fights" ? response.entries[i] : null;
                row.group = mode == "groups" ? response.groups[i].name : "";
                row.caption = mode == "groups" ? response.groups[i].name
                    : FightHistory.durationLabel(row.entry.duration) + "  ·  " + FightHistory.dpsLabel(row.entry.personalDps);
                row.description = mode == "groups" ? response.groups[i].count + (response.groups[i].count == 1 ? " fight" : " fights")
                    : entryDate(row.entry);
                setText(row.name, row.caption); setText(row.detail, row.description);
            }
            show(G.field(list, "obj"), count > 0); show(empty, count == 0);
            setText(empty, "No fights recorded yet. Finished fights will appear here.");
            G.set(G.field(list, "obj"), "scrollPosY", 0.0);
            flow(list, "set_needReflow", true);
            show(previous, page > 0); show(next, (page + 1) * FightHistory.PAGE_SIZE < total);
            show(pageLabel, total > 0);
            setText(pageLabel, "Page " + (page + 1) + " of " + Std.int(Math.max(1, Math.ceil(total / FightHistory.PAGE_SIZE))));
        }
        lastRefresh = -1;
    }
    static function entryDate(entry:HistoryEntry):String return FightHistory.dateLabel(entry.startedAt)
        + (entry.playerName == "" ? "" : "  ·  " + entry.playerName);
    static function entryDetail(entry:HistoryEntry):String return entry == null ? "" : FightHistory.durationLabel(entry.duration)
        + "  ·  " + FightHistory.dpsLabel(entry.personalDps);

    function build(ui:Dynamic):Void {
        owner = ui;
        constructing = true;
        try window = G.create("ui.win.TitleWindow", ["Options", null])
        catch (e:Dynamic) { constructing = false; throw e; }
        constructing = false;
        G.call("ui.win.BaseWindow", "set_windowFlags", window, [8192]);
        root = G.field(ui, "root");
        G.call("h2d.Flow", "addChildAt", root, [window, G.call("h2d.Object", "get_numChildren", root)]);
        absolute(root, window);
        var dom = G.field(window, "dom");
        content = G.field(dom, "contentRoot");
        for (child in children(window)) if (G.field(child, "bgMask") != null) { frame = child; absolute(window, frame); break; }
        G.set(dom, "component", G.staticCall("domkit.Component", "get", ["options-window", null]));
        header = G.field(window, "header");
        G.set(header, "headText", "Fight History");
        title = G.field(header, "headerTitle"); setText(title, "Fight History");
        show(title, true); absolute(header, title);
        close = G.field(header, "closeBtn"); show(close, true); absolute(header, close);
        G.call("ui.UIElement", "set_onClick", close, [() -> dispose()]);
        body = node("options-content", dom, [0], "dpsHistoryBody");
        var bodyObject = G.field(body, "obj");
        container = prepareChartBody(body);
        var options = G.field(bodyObject, "optionsList");
        wrappers = [bodyObject, options, container];
        panel = node("flow", G.field(container, "dom"), [], "dpsHistoryPanel", "vertical");
        for (object in [window, frame, content, header, bodyObject, options, container, G.field(panel, "obj")]) {
            if (object == null) continue;
            padding(object, 0);
            var limit = G.enumeration("h2d.FlowOverflow", "Limit");
            G.call("h2d.Flow", "set_overflow", object, [limit]); style(object, "overflow", limit);
        }
        absolute(window, header); absolute(window, content); absolute(content, bodyObject);
        absolute(bodyObject, options); absolute(options, container); absolute(container, G.field(panel, "obj"));
        back = button(panel, "Back", "dpsHistoryBack", goBack);
        heading = label(panel, ""); detail = label(panel, ""); dateInfo = label(panel, ""); empty = label(panel, "");
        list = node("flow", panel, [], "dpsHistoryList", "vertical");
        padding(G.field(list, "obj"), 0); flow(list, "set_verticalSpacing", 8); style(G.field(list, "obj"), "vspacing", 8);
        var scroll = G.enumeration("h2d.FlowOverflow", "Scroll");
        flow(list, "set_overflow", scroll); style(G.field(list, "obj"), "overflow", scroll);
        for (i in 0...FightHistory.PAGE_SIZE) makeRow(i);
        chartPanel = node("flow", panel, [], "dpsHistoryChart", "vertical");
        padding(G.field(chartPanel, "obj"), 0);
        chart = new NativeDamageChart(chartPanel, "dpsHistoryRows", "No damage recorded");
        previous = button(panel, "Previous", "dpsHistoryPrevious", () -> navigate(mode, group, page - 1));
        next = button(panel, "Next", "dpsHistoryNext", () -> navigate(mode, group, page + 1));
        pageLabel = label(panel, ""); footer = label(panel, "");
        for (object in [back, heading, detail, dateInfo, empty, G.field(list, "obj"), G.field(chartPanel, "obj"), previous, next, pageLabel, footer])
            absolute(G.field(panel, "obj"), object);
        for (text in [title, heading, detail, dateInfo, empty, pageLabel, footer]) {
            var left = G.enumeration("h2d.Align", "Left");
            G.call("h2d.Text", "set_textAlign", text, [left]); style(text, "text-align", left);
            G.call("ui.comp.FmtText", "set_useEllipsis", text, [true]);
        }
        width = 0; height = 0; layout();
    }
    function makeRow(i:Int):Void {
        var row:Dynamic = {obj: null, name: null, detail: null, entry: null, group: "", caption: "", description: "", width: 0};
        row.obj = button(list, "", "dpsHistoryEntry" + i, () -> {
            if (pending) return;
            if (row.entry != null) navigate("chart", group, page, row.entry);
            else navigate("fights", row.group, 0);
        });
        padding(row.obj, 0);
        row.name = label(G.field(row.obj, "dom"), "");
        row.detail = label(G.field(row.obj, "dom"), "");
        for (text in [row.name, row.detail]) {
            absolute(row.obj, text);
            var left = G.enumeration("h2d.Align", "Left");
            G.call("h2d.Text", "set_textAlign", text, [left]); style(text, "text-align", left);
            G.call("ui.comp.FmtText", "set_useEllipsis", text, [true]);
        }
        rows.push(row);
    }
    function layout():Void {
        var scene = G.field(owner, "s2d");
        var top = localPoint(0, 0);
        var bottom = localPoint(G.number(G.field(scene, "width"), 1920), G.number(G.field(scene, "height"), 1080));
        var w = Std.int(Math.max(300, Math.min(900, bottom.x - top.x - 40)));
        var h = Std.int(Math.max(320, Math.min(820, bottom.y - top.y - 60)));
        if (w != width || h != height) {
            width = w; height = h;
            size(window, w, h); if (frame != null) { size(frame, w, h); position(frame, 0, 0); }
            size(header, w - 2, 60); position(header, 0, 0);
            size(close, 36, 36); position(close, w - 52, 12);
            var inner = w - 48; var bodyHeight = h - 76;
            size(content, w - 16, h - 68); position(content, 8, 60);
            for (object in wrappers) { size(object, w - 16, h - 68); position(object, 0, 0); }
            size(G.field(panel, "obj"), inner, bodyHeight); position(G.field(panel, "obj"), 16, 8);
            size(back, 84, 34); position(back, 0, 0);
            G.call("ui.comp.FmtText", "set_maxWidthText", heading, [inner - 100]);
            setText(heading, mode == "groups" ? "Choose an encounter" : group);
            position(heading, 100, 4);
            G.call("ui.comp.FmtText", "set_maxWidthText", detail, [inner]); position(detail, 0, 46);
            G.call("ui.comp.FmtText", "set_maxWidthText", dateInfo, [inner]); position(dateInfo, 0, 74);
            G.call("ui.comp.FmtText", "set_maxWidthText", empty, [inner]); position(empty, 0, 92);
            var chartHeight = Std.int(Math.max(30, bodyHeight - 194));
            for (object in [G.field(list, "obj"), G.field(chartPanel, "obj")]) { size(object, inner, chartHeight); position(object, 0, 110); }
            chart.resize(inner, chartHeight);
            size(previous, 108, 34); position(previous, 0, bodyHeight - 70);
            size(next, 108, 34); position(next, inner - 108, bodyHeight - 70);
            G.call("ui.comp.FmtText", "set_maxWidthText", pageLabel, [Std.int(Math.max(1, inner - 236))]);
            G.call("ui.comp.FmtText", "set_maxWidthText", footer, [inner]); position(footer, 0, bodyHeight - 24);
            G.call("ui.comp.FmtText", "set_maxWidthText", title, [w - 112]);
            lastRefresh = -1;
        }
        position(window, top.x + (bottom.x - top.x - width) / 2, top.y + (bottom.y - top.y - height) / 2);
    }
    function alignLabels():Void {
        position(title, (width - textWidth(title)) / 2, (60 - textHeight(title)) / 2);
        position(pageLabel, (width - 48 - textWidth(pageLabel)) / 2, height - 76 - 66);
        var inner = G.integer(G.call("h2d.Flow", "get_innerWidth", G.field(list, "obj")), width - 48);
        var scrollbar = G.field(G.field(list, "obj"), "scrollBar");
        if (scrollbar != null && G.field(scrollbar, "visible") == true)
            inner -= G.integer(G.call("h2d.Flow", "get_outerWidth", scrollbar)) + 4;
        for (row in rows) {
            if (row.width == inner) continue;
            row.width = inner;
            size(row.obj, Std.int(Math.max(1, inner)), 66);
            for (text in [row.name, row.detail]) G.call("ui.comp.FmtText", "set_maxWidthText", text, [Std.int(Math.max(1, inner - 24))]);
            setText(row.name, row.caption); setText(row.detail, row.description);
            position(row.name, 12, 7); position(row.detail, 12, 35);
        }
    }
    static function textWidth(text:Dynamic):Float {
        G.call("ui.comp.FmtText", "updateScale", text);
        return G.number(G.call("h2d.Text", "get_textWidth", text)) * G.number(G.field(text, "scaleX"), 1);
    }
    static function textHeight(text:Dynamic):Float return G.number(G.call("h2d.Text", "get_textHeight", text)) * G.number(G.field(text, "scaleY"), 1);
    function localPoint(x:Float, y:Float):{x:Float, y:Float} {
        var point = HlxRuntime.allocInstance(HlxRuntime.resolveType("h2d.col.PointImpl"));
        G.set(point, "x", x); G.set(point, "y", y);
        var local = G.call("h2d.Object", "globalToLocal", root, [point]);
        return {x: G.number(G.field(local, "x")), y: G.number(G.field(local, "y"))};
    }
    public function dispose():Void {
        requested = false; serial++;
        if (window != null) { var old = window; window = null; G.call("h2d.Object", "remove", old); }
        owner = null; rows = []; wrappers = []; frame = null; body = null; container = null;
        chart = null; fight = null; width = 0; height = 0;
    }
}
