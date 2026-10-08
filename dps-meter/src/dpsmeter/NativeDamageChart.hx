package dpsmeter;

import dpsmeter.CombatModel;
import dpsmeter.DeathLog;
import dpsmeter.GameAccess as G;
import dpsmeter.NativeUi.*;

/** The same scrollable player/skill chart in the live meter and phase recaps. */
class NativeDamageChart {
    public var onSelectionChanged:Null<PlayerStats>->Void;
    var root:Dynamic;
    var headerRoot:Dynamic;
    var rowsRoot:Dynamic;
    var rows:Array<Dynamic> = [];
    var id:String;
    var width:Int = 1;
    var height:Int = 1;
    var skillView:Bool = false;
    var viewportWidth:Int = 0;
    var viewportHeight:Int = 0;
    var viewportHeaderHeight:Int = -1;
    var displayed:Null<Fight>;
    var selectedPlayer:String = "";
    var skillTable:NativeSkillTable;
    public var mode(default, null):String = "damage";
    var deathPanel:Dynamic;
    var deathKey:String = "";
    var lastRefresh:Float = -1;
    var empty:Dynamic;
    public function new(parent:Dynamic, id:String, emptyText:String = "", recap:Bool = false) {
        this.id = id;
        root = node("flow", parent, [], id + "Chart", "vertical");
        padding(G.field(root, "obj"), 0);
        flow(root, "set_verticalSpacing", 0); style(G.field(root, "obj"), "vspacing", 0);
        // The header is a sibling of the scrolling body, so native clipping
        // and mouse-wheel scrolling affect only player/skill rows.
        headerRoot = node("flow", root, [], id + "Header", "vertical");
        padding(G.field(headerRoot, "obj"), 0);
        show(G.field(headerRoot, "obj"), false);
        rowsRoot = node("flow", root, [], id, "vertical");
        var object = G.field(rowsRoot, "obj");
        padding(object, 0);
        flow(rowsRoot, "set_verticalSpacing", 12);
        style(object, "vspacing", 12);
        var scroll = G.enumeration("h2d.FlowOverflow", "Scroll");
        flow(rowsRoot, "set_overflow", scroll);
        style(object, "overflow", scroll);
        if (emptyText != "") empty = label(rowsRoot, emptyText);
        skillTable = new NativeSkillTable(rowsRoot, id, () -> selectPlayer(""), headerRoot, recap);
    }
    public function resize(width:Int, height:Int):Void {
        this.width = width; this.height = height;
        size(G.field(root, "obj"), width, height);
        layoutViewport();
        if (empty != null) G.call("ui.comp.FmtText", "set_maxWidthText", empty, [width]);
        for (row in rows) sizeRow(row);
        lastRefresh = -1;
    }
    function layoutViewport():Void {
        var headerHeight = skillView ? skillTable.headerHeight : 0;
        if (viewportWidth == width && viewportHeight == height && viewportHeaderHeight == headerHeight) return;
        viewportWidth = width; viewportHeight = height; viewportHeaderHeight = headerHeight;
        show(G.field(headerRoot, "obj"), skillView);
        size(G.field(headerRoot, "obj"), width, headerHeight);
        size(G.field(rowsRoot, "obj"), width, Std.int(Math.max(1, height - headerHeight)));
    }
    public function snapshotHeight():Int {
        var list = G.field(rowsRoot, "obj");
        NativeFightSnapshot.reflow(list);
        var headerHeight = skillView ? skillTable.headerHeight : 0;
        return Std.int(Math.ceil(Math.max(30, headerHeight + G.number(G.field(list, "contentHeight")))));
    }
    public function snapshotScroll():Float return G.number(G.field(G.field(rowsRoot, "obj"), "scrollPosY"));
    public function restoreScroll(value:Float):Void flow(rowsRoot, "set_scrollPosY", value);
    function resetScroll():Void {
        // Reflow positions the new list at its beginning, including an empty list.
        G.set(G.field(rowsRoot, "obj"), "scrollPosY", 0.0);
        flow(rowsRoot, "set_needReflow", true);
    }
    function selectPlayer(uid:String):Void {
        selectedPlayer = uid;
        deathKey = "";
        skillTable.clear(); resetScroll(); lastRefresh = -1;
        if (onSelectionChanged != null)
            onSelectionChanged(displayed == null ? null : displayed.players[uid]);
    }
    public function setMode(value:String):Void {
        if (mode == value) return;
        mode = value;
        selectPlayer("");
    }
    public function update(fight:Null<Fight>, now:Float):Void {
        if (fight != displayed) {
            displayed = fight;
            selectPlayer("");
        }
        if (now - lastRefresh < 0.20) return;
        lastRefresh = now;
        if (mode == "deaths") { updateDeaths(fight); return; }
        var ranked = fight == null ? [] : mode == "healing" ? fight.rankedByHeal() : fight.ranked();
        var elapsed = fight == null ? 0 : fight.duration(now);
        // A single instant hit should not display thousands of times its damage as DPS.
        var seconds = Math.max(1, elapsed);
        var total = 0.0;
        for (p in ranked) total += mode == "healing" ? p.heal : p.damage;
        var selected = fight == null ? null : fight.players[selectedPlayer];
        if (skillView != (selected != null)) {
            skillView = selected != null;
            layoutViewport();
        }
        if (deathPanel != null) show(G.field(deathPanel, "obj"), false);
        if (selected != null) {
            show(empty, false);
            for (row in rows) show(row.obj, false);
            skillTable.update(mode == "healing" ? fight.healingView(selected) : selected, seconds, availableRowWidth(), mode == "healing");
            layoutViewport();
            return;
        }
        show(skillTable.object, false);
        var count = ranked.length;
        if (empty != null) setText(empty, mode == "healing" ? "No healing recorded" : "No damage recorded");
        show(empty, count == 0);
        while (rows.length < count) rows.push(makeRow(rows.length));
        for (i in 0...rows.length) {
            var row = rows[i]; show(row.obj, i < count);
            if (i >= count) continue;
            var p = ranked[i]; row.uid = p.info.uid;
            var amount = mode == "healing" ? p.heal : p.damage;
            var color = classColor(p.info.className);
            row.caption = (i + 1) + ". " + p.info.name;
            var rate = mode == "healing" ? " HPS" : " DPS";
            setText(row.details, compact(amount) + " (" + compact(amount / seconds) + rate
                + ", " + Std.int(total > 0 ? amount * 100 / total : 0) + "%)");
            sizeRow(row);
            if (row.color != color) {
                row.color = color;
                G.set(row.bar, "color", color); G.set(row.bar, "fullColor", color);
                style(row.bar, "color", color); style(row.bar, "full-color", color);
            }
            G.call("ui.comp.BaseGauge", "set_max", row.bar, [Math.max(1, total)]);
            G.call("ui.comp.BaseGauge", "set_value", row.bar, [amount]);
        }
    }
    function updateDeaths(fight:Null<Fight>):Void {
        show(skillTable.object, false);
        if (skillView) { skillView = false; layoutViewport(); }
        var selected = selectedPlayer != "" && fight != null;
        if (selected) {
            show(empty, false);
            for (row in rows) show(row.obj, false);
            renderDeath(fight, selectedPlayer);
            return;
        }
        if (deathPanel != null) show(G.field(deathPanel, "obj"), false);
        var people = deathPeople(fight);
        if (empty != null) setText(empty, "No deaths recorded");
        show(empty, people.length == 0);
        while (rows.length < people.length) rows.push(makeRow(rows.length));
        for (i in 0...rows.length) {
            var row = rows[i]; show(row.obj, i < people.length);
            if (i >= people.length) continue;
            var person = people[i];
            row.uid = person.uid;
            row.caption = person.name;
            setText(row.details, person.count == 1 ? person.summary : person.count + " deaths");
            sizeRow(row);
            var color = classColor(person.className);
            if (row.color != color) {
                row.color = color;
                G.set(row.bar, "color", color); G.set(row.bar, "fullColor", color);
                style(row.bar, "color", color); style(row.bar, "full-color", color);
            }
            G.call("ui.comp.BaseGauge", "set_max", row.bar, [1]);
            G.call("ui.comp.BaseGauge", "set_value", row.bar, [0]);
        }
    }
    function deathPeople(fight:Null<Fight>):Array<{uid:String, name:String, className:String, count:Int, summary:String}> {
        var people:Array<{uid:String, name:String, className:String, count:Int, summary:String}> = [];
        if (fight == null) return people;
        for (death in fight.deaths) {
            var found = false;
            for (person in people) if (person.uid == death.uid) {
                person.count++;
                person.summary = deathSummary(death.report);
                found = true;
            }
            if (!found) people.push({uid: death.uid, name: death.name, className: death.className,
                count: 1, summary: deathSummary(death.report)});
        }
        people.sort((a, b) -> a.count != b.count ? b.count - a.count : Reflect.compare(a.name, b.name));
        return people;
    }
    static function deathSummary(report:DeathReport):String return DeathTimeline.summary(report);
    function renderDeath(fight:Fight, uid:String):Void {
        var tableWidth = availableRowWidth();
        var key = uid + ":" + fight.deaths.length + ":" + tableWidth;
        for (death in fight.deaths) if (death.uid == uid) key += ":" + death.report.rows.length + ":" + death.report.damage + ":" + death.report.healing
            + ":" + [for (row in death.report.rows) row.hp + "/" + row.hpBefore + "/" + row.hpSample].join(",");
        if (deathPanel != null && deathKey == key) { show(G.field(deathPanel, "obj"), true); return; }
        if (deathPanel != null) G.call("h2d.Object", "remove", G.field(deathPanel, "obj"));
        deathKey = key;
        deathPanel = node("flow", rowsRoot, [], id + "DeathDetail", "vertical");
        var panel = G.field(deathPanel, "obj"); padding(panel, 0);
        var fontParent = label(deathPanel, ""); show(fontParent, false);
        var font = G.field(fontParent, "font");
        var back = button(deathPanel, "Back", id + "DeathBack", () -> selectPlayer(""));
        absolute(panel, back); size(back, 84, 34); position(back, 0, 0);
        var y = 46.0, count = 0;
        for (death in fight.deaths) if (death.uid == uid) {
            count++;
            NativeDeathTimeline.text(panel, font, "Death " + count + " · " + duration(Math.max(0, death.report.at - fight.start)),
                6, y, tableWidth - 12, 0x852629, true);
            NativeDeathTimeline.text(panel, font, "10 s · Damage " + compact(death.report.damage) + " · Healing " + compact(death.report.healing),
                6, y + 24, tableWidth - 12, 0x8a5f46, true);
            y = NativeDeathTimeline.render(panel, font, death.report, tableWidth, y + 54, true) + 18;
        }
        size(panel, tableWidth, Std.int(y + 8));
    }
    function availableRowWidth():Int {
        var list = G.field(rowsRoot, "obj");
        var available = G.integer(G.call("h2d.Flow", "get_innerWidth", list), width);
        var scrollbar = G.field(list, "scrollBar");
        // Use the full body width, reserving room only for a visible scrollbar.
        if (scrollbar != null && G.field(scrollbar, "visible") == true)
            available -= G.integer(G.call("h2d.Flow", "get_outerWidth", scrollbar)) + 4;
        return Std.int(Math.max(1, available));
    }
    function sizeRow(row:Dynamic):Void {
        var rowWidth = availableRowWidth();
        if (row.width != rowWidth) {
            row.width = rowWidth;
            size(row.obj, rowWidth);
            size(row.heading, rowWidth);
            G.call("ui.comp.FmtText", "set_maxWidthText", row.details, [Std.int(Math.max(1, rowWidth - 60))]);
            G.call("ui.comp.BaseGauge", "set_barWidth", row.bar, [rowWidth]);
            size(row.bar, rowWidth, 9);
        }
        alignRow(row);
    }
    function alignRow(row:Dynamic):Void {
        var rowWidth:Int = row.width;
        // Measure native text, not spaces: numbers keep a common right edge.
        G.call("ui.comp.FmtText", "updateScale", row.details);
        var detailWidth = G.number(G.call("h2d.Text", "get_textWidth", row.details)) * G.number(G.field(row.details, "scaleX"), 1);
        G.call("ui.comp.FmtText", "set_maxWidthText", row.name, [Std.int(Math.max(1, rowWidth - detailWidth - 12))]);
        // Restore the full name when widening a previously ellipsized row.
        setText(row.name, row.caption);
        G.call("ui.comp.FmtText", "updateScale", row.name);
        var lineHeight = 0.0;
        for (text in [row.name, row.details]) lineHeight = Math.max(lineHeight,
            G.number(G.call("h2d.Text", "get_textHeight", text)) * G.number(G.field(text, "scaleY"), 1));
        var h = Std.int(Math.ceil(Math.max(18, lineHeight)));
        if (row.lineHeight != h) { row.lineHeight = h; size(row.heading, rowWidth, h); }
        position(row.name, 0, 0);
        position(row.details, rowWidth - detailWidth, 0);
    }
    function makeRow(index:Int):Dynamic {
        var d = node("element", rowsRoot, [], id + "Row" + index, "vertical");
        padding(G.field(d, "obj"), 0);
        flow(d, "set_verticalSpacing", 4);
        style(G.field(d, "obj"), "vspacing", 4);
        var heading = node("flow", d, [], id + "Heading" + index, "horizontal");
        var headingObject = G.field(heading, "obj");
        padding(headingObject, 0);
        var name = label(heading, "");
        var details = label(heading, "");
        for (text in [name, details]) {
            absolute(headingObject, text);
            var left = G.enumeration("h2d.Align", "Left");
            G.call("h2d.Text", "set_textAlign", text, [left]);
            style(text, "text-align", left);
        }
        G.call("ui.comp.FmtText", "set_useEllipsis", name, [true]);
        var barDom = node("base-gauge", d, [], id + "Bar" + index);
        var bar = G.field(barDom, "obj");
        G.call("ui.comp.BaseGauge", "set_barHeight", bar, [7]);
        G.call("ui.comp.BaseGauge", "set_showValues", bar, [false]);
        var obj = G.field(d, "obj");
        var row:Dynamic = {obj: obj, heading: headingObject, name: name, details: details,
            bar: bar, uid: "", caption: "", lineHeight: 0, color: -1, width: 0};
        G.call("ui.UIElement", "set_onClick", obj, [() -> selectPlayer(row.uid)]);
        sizeRow(row);
        return row;
    }
}
