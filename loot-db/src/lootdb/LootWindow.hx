package lootdb;

import lootdb.Catalog.CreatureRecord;
import lootdb.Catalog.InstanceRecord;
import lootdb.Catalog.ItemRecord;
import lootdb.Catalog.ScaleStep;
import lootdb.Catalog.PinRecord;
import lootdb.Catalog.SearchHit;
import lootdb.Catalog.SkillLine;
import lootdb.GameAccess as G;
import lootdb.NativeUi.*;
import sys.FileSystem;
import sys.io.File;

private typedef DetailBlock = {text:String, html:Bool, muted:Bool};
private typedef DetailLink = {
    label:String, subtitle:String, kind:String, iconName:String, category:String,
    hit:Null<SearchHit>, open:Void->Void
};

/** Native browser for instances, bosses, items, weapons, and the overworld map. */
class LootWindow {
    public static var constructing:Bool = false;
    public var searchFocused:Bool = false;
    static inline var PAGE:Int = 12;
    static inline var HEADER:Int = 56;
    static inline var DROPS:Int = 40;
    static inline var DATABASE = "hlx/mods/loot-db/database.json";
    var requested:Bool = false;
    var window:Dynamic;
    var owner:Dynamic;
    var root:Dynamic;
    var content:Dynamic;
    var frame:Dynamic;
    var header:Dynamic;
    var headerFill:Dynamic;
    var headerRaised:Bool = false;
    var cardSentBack:Bool = false;
    var hoverRow:Dynamic = null;
    var hoverDrop:Dynamic = null;
    var tippedRow:Dynamic = null;
    var tippedKey:String = "";
    var pendingSelect:SearchHit = null;
    var pendingOpen:Void->Void = null;
    var title:Dynamic;
    var close:Dynamic;
    var body:Dynamic;
    var container:Dynamic;
    var wrappers:Array<Dynamic> = [];
    var panel:Dynamic;
    var tabs:Array<Dynamic> = [];
    var searchInput:Dynamic;
    var list:Dynamic;
    var rows:Array<Dynamic> = [];
    var previous:Dynamic;
    var next:Dynamic;
    var pageLabel:Dynamic;
    var detailTitle:Dynamic;
    var detailLines:Array<Dynamic> = [];
    var dropList:Dynamic;
    var dropHeading:Dynamic;
    var dropRows:Array<Dynamic> = [];
    var iconBitmap:Dynamic;
    var iconHolder:Dynamic;
    var uiFont:Dynamic;
    var listColumn:Float = 344;
    var tabY:Float = 0;
    var detailCard:Dynamic;
    var detailX:Float = 0;
    var detailTop:Float = 0;
    var detailW:Float = 0;
    var detailBottom:Float = 0;
    var innerWidth:Float = 0;
    var listBottom:Float = 0;
    var mapButton:Dynamic;
    var mapFilters:Array<Dynamic> = [];
    var map:LootMap;
    var empty:Dynamic;
    var mapStatus:Dynamic;
    var catalog:Catalog;
    var tab:String = "instances";
    var query:String = "";
    var page:Int = 0;
    var hits:Array<SearchHit> = [];
    var selected:SearchHit = null;
    var width:Int = 0;
    var height:Int = 0;
    var showDungeons:Bool = true;
    var showWorldBosses:Bool = true;
    var showSearchHits:Bool = true;
    var classPicks:Array<String> = [];
    var slotPicks:Array<String> = [];
    var categoryPicks:Array<String> = [];
    var dropPicks:Array<String> = [];
    var lootDrop:Dynamic;
    var scaleDrop:Dynamic;
    var stepDrop:Dynamic;
    var scaleMode:String = "normal";
    var scaleKey:String = "";
    var maxToggle:Dynamic;
    var maxLegendary:Bool = false;
    var scaledDef:Dynamic = null;
    var savedLevel:Dynamic = null;
    var savedILevel:Dynamic = null;
    var savedRarity:Dynamic = null;
    var classDrop:Dynamic;
    var categoryDrop:Dynamic;
    var slotDrop:Dynamic;
    var markerDrop:Dynamic;
    var openMenu:String = "";
    var pageSize:Int = 6;
    var nativeTip:Dynamic = null;
    var tipButton:Dynamic = null;
    var tipRoot:Dynamic;
    var tipBg:Dynamic;
    var tipIcon:Dynamic;
    var tipLines:Array<Dynamic> = [];
    var status:String = "";
    static var CLASSES = ["Warrior", "Priest", "Mage", "Rogue"];
    static var ITEM_CATEGORIES = ["armor", "jewellery", "materials", "consumables", "augments", "recipes", "runes", "mounts", "gliders", "tools"];

    public function new() {}
    public function open():Void requested = true;
    public function toggle():Void {
        if (requested || (window != null && G.field(window, "removed") != true && G.field(window, "parent") != null)) dispose();
        else open();
    }
    public function update(app:Dynamic, active:Bool, now:Float):Void {
        var ui = G.current("ui.BaseUI", "current");
        if (!active || ui == null) { dispose(); return; }
        if (owner != null && owner != ui) dispose();
        if (window != null && (G.field(window, "removed") == true || !bodyIntact(body, container))) dispose();
        if (requested) {
            requested = false;
            if (window == null) {
                catalog = loadCatalog();
                build(ui);
                refresh();
            }
        }
        if (window == null) return;
        readSearch();
        runPending();
        layout();
        placeChrome();
        placeDetail();
        placeWindow();
        placeNativeTip();
        if (tab == "map" && map != null) {
            map.setPins(mapPins());
            map.update(app);
            show(mapStatus, !map.hasTiles);
            setText(mapStatus, map.hasTiles ? "" : "Overworld tiles appear after you enter Siagarta.");
        }
    }
    public function closeFromEscape(ui:Dynamic):Bool {
        if (window == null || owner != ui || G.field(window, "removed") == true || G.field(window, "parent") == null) return false;
        if (searchOwnsFocus(ui)) { blurSearch(); return true; }
        dispose();
        return true;
    }
    public function dispose():Void {
        requested = false;
        searchFocused = false;
        if (window != null) {
            var old = window; window = null;
            if (owner != null) G.call("ui.BaseUI", "removeWindow", owner, [old]);
            else G.call("h2d.Object", "remove", old);
        }
        owner = null; rows = []; tabs = []; detailLines = []; dropRows = []; mapFilters = []; wrappers = [];
        tipLines = []; tipRoot = null;
        classDrop = null; categoryDrop = null; slotDrop = null; markerDrop = null; lootDrop = null;
        scaleDrop = null; stepDrop = null; scaleMode = "normal"; scaleKey = "";
        maxToggle = null; maxLegendary = false;
        restoreScaledDef();
        detailCard = null;
        classPicks = []; slotPicks = []; categoryPicks = []; openMenu = "";
        frame = null; body = null; container = null; panel = null; list = null; dropList = null;
        searchInput = null; map = null; iconBitmap = null; iconHolder = null; width = 0; height = 0;
        headerRaised = false; cardSentBack = false; headerFill = null; uiFont = null;
        hoverRow = null; hoverDrop = null; tippedRow = null; tippedKey = ""; pendingSelect = null; pendingOpen = null;
        nativeTip = null; tipButton = null;
    }

    function loadCatalog():Catalog {
        if (!FileSystem.exists(DATABASE)) {
            status = "database.json is not beside the mod. Run tools/export.py, then copy the file into hlx/mods/loot-db/.";
            return Catalog.parse('{"items":[],"creatures":[],"instances":[],"pins":[],"droppedBy":{},"bossInstance":{}}');
        }
        status = "";
        return Catalog.parse(File.getContent(DATABASE));
    }

    function build(ui:Dynamic):Void {
        owner = ui;
        tabs = []; detailLines = []; dropRows = []; rows = []; mapFilters = [];
        classPicks = []; slotPicks = []; categoryPicks = []; openMenu = "";
        tipLines = [];
        constructing = true;
        try window = G.create("ui.win.TitleWindow", ["Options", null])
        catch (e:Dynamic) { constructing = false; throw e; }
        constructing = false;
        var freeCursor = G.enumeration("ui.win.WindowFlags", "FreeCursor");
        if (freeCursor == null) throw "The loot window's cursor flag is unavailable.";
        G.call("ui.win.BaseWindow", "set_windowFlags", window, [8192 | (1 << Type.enumIndex(freeCursor))]);
        root = G.field(ui, "root");
        G.call("h2d.Flow", "addChildAt", root, [window, G.call("h2d.Object", "get_numChildren", root)]);
        G.call("ui.BaseUI", "displayWindow", ui, [window, null]);
        absolute(root, window);
        var dom = G.field(window, "dom");
        content = G.field(dom, "contentRoot");
        for (child in children(window)) if (G.field(child, "bgMask") != null) { frame = child; absolute(window, frame); break; }
        G.set(dom, "component", G.staticCall("domkit.Component", "get", ["options-window", null]));
        header = G.field(window, "header");
        G.set(header, "headText", "");
        title = G.field(header, "headerTitle"); setText(title, "");
        show(title, false); absolute(header, title);
        try G.call("h2d.Text", "set_textColor", title, [0xfff6ee]) catch (_:Dynamic) {}
        headerFill = G.create("h2d.Graphics", [header]);
        absolute(header, headerFill);
        close = G.field(header, "closeBtn"); show(close, true); absolute(header, close);
        G.call("ui.UIElement", "set_onClick", close, [() -> dispose()]);
        body = node("options-content", dom, [0], "lootDbBody");
        var bodyObject = G.field(body, "obj");
        container = prepareBody(body);
        var options = G.field(bodyObject, "optionsList");
        wrappers = [bodyObject, options, container];
        panel = node("flow", G.field(container, "dom"), [], "lootDbPanel", "vertical");
        for (object in [window, frame, content, header, bodyObject, options, container, G.field(panel, "obj")]) {
            if (object == null) continue;
            padding(object, 0);
            var limit = G.enumeration("h2d.FlowOverflow", "Limit");
            G.call("h2d.Flow", "set_overflow", object, [limit]); style(object, "overflow", limit);
        }
        absolute(window, header); absolute(window, content); absolute(content, bodyObject);
        absolute(bodyObject, options); absolute(options, container); absolute(container, G.field(panel, "obj"));
        var probe = label(panel, "");
        uiFont = G.field(probe, "font");
        if (uiFont == null) try uiFont = G.staticCall("h2d.Font", "getDefault", []) catch (_:Dynamic) {}
        show(probe, false);
        var names = ["Instances", "Bosses", "Items", "Weapons", "Map"];
        var ids = ["instances", "bosses", "items", "weapons", "map"];
        for (i in 0...names.length) {
            var id = ids[i];
            var control = face(header, uiFont, names[i], () -> setTab(id));
            control.key = id;
            tabs.push(control);
        }
        try {
            var created = node("fmt-text-input", panel, [""], "lootDbSearch");
            searchInput = G.field(created, "obj");
            absolute(G.field(panel, "obj"), searchInput);
            watchFocus(searchInput);
        } catch (_:Dynamic) {
            try {
                var hint = label(panel, "");
                searchInput = G.create("h2d.TextInput", [G.field(hint, "font"), G.field(panel, "obj")]);
                G.call("h2d.Text", "set_textColor", searchInput, [0x3a2a22]);
                absolute(G.field(panel, "obj"), searchInput);
                watchFocus(searchInput);
                show(hint, false);
            } catch (_:Dynamic) searchInput = null;
        }
        list = node("flow", panel, [], "lootDbList", "vertical");
        padding(G.field(list, "obj"), 0);
        var limit = G.enumeration("h2d.FlowOverflow", "Limit");
        flow(list, "set_overflow", limit); style(G.field(list, "obj"), "overflow", limit);
        try G.set(G.field(list, "obj"), "verticalSpacing", 4) catch (_:Dynamic) {}
        for (i in 0...PAGE) makeRow(i);
        previous = face(panel, uiFont, "Previous", () -> { if (page > 0) { page--; refresh(); } });
        next = face(panel, uiFont, "Next", () -> { page++; refresh(); });
        pageLabel = label(panel, "");
        detailTitle = label(panel, "");
        mapButton = face(panel, uiFont, "Show on map", () -> pendingOpen = showSelectedOnMap);
        maxToggle = face(panel, uiFont, "Legendary", () -> {
            maxLegendary = !maxLegendary;
            resetScale();
            refresh();
        });
        for (i in 0...16) detailLines.push(label(panel, ""));
        dropHeading = label(panel, "");
        dropList = node("flow", panel, [], "lootDbDrops", "vertical");
        padding(G.field(dropList, "obj"), 0);
        flow(dropList, "set_overflow", limit); style(G.field(dropList, "obj"), "overflow", limit);
        try G.set(G.field(dropList, "obj"), "verticalSpacing", 6) catch (_:Dynamic) {}
        for (i in 0...DROPS) makeDrop(i);
        classDrop = makeDropdown("class", "Class");
        categoryDrop = makeDropdown("category", "Category");
        slotDrop = makeDropdown("slot", "Slot");
        markerDrop = makeDropdown("markers", "Markers");
        lootDrop = makeDropdown("loot", "Type");
        scaleDrop = makeDropdown("scale", "Normal");
        stepDrop = makeDropdown("step", "Step");
        map = new LootMap(G.field(panel, "obj"), openPin);
        absolute(G.field(panel, "obj"), map.root);
        empty = label(panel, "");
        mapStatus = label(panel, "");
        detailCard = G.create("h2d.Graphics", [G.field(panel, "obj")]);
        show(detailCard, false);
        tipRoot = G.create("h2d.Object", [G.field(panel, "obj")]);
        tipBg = G.create("h2d.Graphics", [tipRoot]);
        for (i in 0...12) {
            var line = label(panel, "");
            G.call("h2d.Text", "set_textColor", line, [0xf4efe6]);
            tipLines.push(line);
        }
        show(tipRoot, false);
        for (line in tipLines) show(line, false);
        iconHolder = G.create("h2d.Object", [G.field(panel, "obj")]);
        show(iconHolder, false);
        var panelObject = G.field(panel, "obj");
        for (control in tabs) absolute(header, control.obj);
        absolute(panelObject, previous.obj);
        absolute(panelObject, next.obj);
        absolute(panelObject, mapButton.obj);
        absolute(panelObject, maxToggle.obj);
        show(maxToggle.obj, false);
        for (drop in [classDrop, categoryDrop, slotDrop, markerDrop, lootDrop, scaleDrop, stepDrop]) {
            absolute(panelObject, drop.header.obj);
            absolute(panelObject, drop.menu);
        }
        absolute(panelObject, iconHolder);
        for (object in [G.field(list, "obj"), pageLabel, detailTitle, empty, mapStatus, dropHeading, G.field(dropList, "obj"), detailCard, tipRoot].concat(detailLines).concat(tipLines))
            absolute(panelObject, object);
        width = 0; height = 0;
        Log.write("window built");
    }

    function makeRow(index:Int):Void {
        var row:Dynamic = {obj: null, bg: null, title: null, subtitle: null, hit: null, frame: null, icon: null, hot: false};
        var built = face(list, uiFont, "", () -> {
            if (row.hit == null) return;
            pendingSelect = row.hit;
            Log.write("click " + row.hit.kind + " " + row.hit.id + " " + row.hit.title);
        });
        row.obj = built.obj; row.bg = built.bg; row.title = built.title;
        row.subtitle = G.create("h2d.Text", [uiFont, row.obj]);
        G.call("h2d.Text", "set_textColor", row.subtitle, [0x8a7364]);
        row.frame = G.create("h2d.Graphics", [row.obj]);
        position(row.frame, 6, 8);
        paintSlot(row.frame, 36, 36);
        show(row.frame, false);
        G.set(row.obj, "onOver", (_:Dynamic) -> hoverRow = row);
        G.set(row.obj, "onOut", (_:Dynamic) -> { if (hoverRow == row) hoverRow = null; });
        rows.push(row);
    }

    function makeDrop(index:Int):Void {
        var row:Dynamic = {obj: null, bg: null, title: null, subtitle: null, open: null, hit: null, frame: null, icon: null, hot: false};
        var built = face(dropList, uiFont, "", () -> { if (row.open != null) pendingOpen = row.open; });
        row.obj = built.obj; row.bg = built.bg; row.title = built.title;
        row.subtitle = G.create("h2d.Text", [uiFont, row.obj]);
        G.call("h2d.Text", "set_textColor", row.subtitle, [0x8a7364]);
        row.frame = G.create("h2d.Graphics", [row.obj]);
        position(row.frame, 8, 8);
        paintSlot(row.frame, 36, 36);
        show(row.frame, false);
        G.set(row.obj, "onOver", (_:Dynamic) -> hoverDrop = row);
        G.set(row.obj, "onOut", (_:Dynamic) -> { if (hoverDrop == row) hoverDrop = null; });
        dropRows.push(row);
    }

    function setTab(next:String):Void {
        tab = next; page = 0; selected = null;
        resetScale();
        clearPicks();
        hideTip();
        refresh();
    }

    function clearPicks():Void {
        classPicks = []; slotPicks = []; categoryPicks = []; dropPicks = [];
        openMenu = "";
    }

    function makeDropdown(id:String, caption:String):Dynamic {
        var options:Array<Dynamic> = [];
        var header = face(panel, uiFont, caption, () -> toggleMenu(id));
        var menu = G.create("h2d.Object", [G.field(panel, "obj")]);
        var menuBg = G.create("h2d.Graphics", [menu]);
        show(menu, false);
        return {id: id, caption: caption, header: header, menu: menu, menuBg: menuBg, options: options, signature: ""};
    }

    function toggleMenu(id:String):Void {
        openMenu = openMenu == id ? "" : id;
        refresh();
    }

    function togglePick(id:String, key:String):Void {
        if (id == "scale") {
            scaleMode = key;
            scaleKey = "";
            openMenu = "";
            refresh();
            return;
        }
        if (id == "step") {
            scaleKey = key;
            openMenu = "";
            refresh();
            return;
        }
        if (id == "markers") {
            if (key == "") { showDungeons = true; showWorldBosses = true; showSearchHits = true; }
            else if (key == "dungeon") showDungeons = !showDungeons;
            else if (key == "world") showWorldBosses = !showWorldBosses;
            else showSearchHits = !showSearchHits;
            refresh();
            return;
        }
        var picks = picksFor(id);
        if (key == "") picks.splice(0, picks.length);
        else {
            var index = picks.indexOf(key);
            if (index >= 0) picks.splice(index, 1) else picks.push(key);
        }
        if (id == "category") pruneSlots();
        if (id != "loot") page = 0;
        refresh();
    }

    function picksFor(id:String):Array<String> {
        return switch (id) {
            case "class": classPicks;
            case "slot": slotPicks;
            case "category": categoryPicks;
            case "loot": dropPicks;
            default: [];
        };
    }

    function pruneSlots():Void {
        var allowed = allowedSlots();
        var kept = [];
        for (slot in slotPicks) if (allowed.indexOf(slot) >= 0) kept.push(slot);
        slotPicks = kept;
    }

    function allowedSlots():Array<String> {
        if (catalog == null) return [];
        if (tab == "weapons") return catalog.slotsFor("weapons");
        var slots:Array<String> = [];
        var cats = categoryPicks.length == 0 ? ITEM_CATEGORIES : categoryPicks;
        for (cat in cats) for (slot in catalog.slotsFor(cat)) if (slots.indexOf(slot) < 0) slots.push(slot);
        return slots;
    }

    function dropVisible(id:String):Bool {
        return switch (id) {
            case "class": tab == "weapons" || tab == "items";
            case "category": tab == "items";
            case "slot": tab == "weapons" || (tab == "items" && categoryPicks.length > 0);
            case "markers": tab == "map";
            default: false;
        };
    }

    function choicesFor(id:String):Array<{key:String, label:String}> {
        if (id == "scale") return [
            {key: "normal", label: "Normal"},
            {key: "max", label: "Max level"},
            {key: "heroic", label: "Heroic"}
        ];
        if (id == "step") return stepChoices();
        var choices:Array<{key:String, label:String}> = [{key: "", label: "All"}];
        switch (id) {
            case "class": for (name in CLASSES) choices.push({key: name, label: name});
            case "category": for (name in ITEM_CATEGORIES) choices.push({key: name, label: categoryLabel(name)});
            case "slot": for (slot in allowedSlots()) choices.push({key: slot, label: Catalog.prettySlot(slot)});
            case "markers":
                choices.push({key: "dungeon", label: "Dungeons"});
                choices.push({key: "world", label: "World bosses"});
                choices.push({key: "search", label: "Search"});
            case "loot":
                choices.push({key: "weapons", label: "Weapons"});
                choices.push({key: "armor", label: "Armor"});
                choices.push({key: "jewellery", label: "Jewellery"});
                choices.push({key: "materials", label: "Materials"});
                choices.push({key: "consumables", label: "Consumables"});
                choices.push({key: "other", label: "Other"});
            default:
        }
        return choices;
    }

    function pickedOn(id:String, key:String):Bool {
        if (id == "scale") return key == scaleMode;
        if (id == "step") return key == stepKey(activeStep(selectedItem()));
        if (id == "markers") {
            if (key == "") return showDungeons && showWorldBosses && showSearchHits;
            if (key == "dungeon") return showDungeons;
            if (key == "world") return showWorldBosses;
            return showSearchHits;
        }
        var picks = picksFor(id);
        return key == "" ? picks.length == 0 : picks.indexOf(key) >= 0;
    }

    function headerText(id:String):String {
        if (id == "scale") return scaleLabel(scaleMode);
        if (id == "step") {
            var step = activeStep(selectedItem());
            return step == null ? "Step" : stepLabel(step, stepsFor(selectedItem(), scaleMode));
        }
        var caption = id == "slot" ? (tab == "weapons" ? "Type" : "Slot") : switch (id) {
            case "class": "Class"; case "category": "Category"; case "markers": "Markers"; case "loot": "Type"; default: "Filter";
        };
        if (id == "markers") {
            var count = (showDungeons ? 1 : 0) + (showWorldBosses ? 1 : 0) + (showSearchHits ? 1 : 0);
            return count == 0 || count == 3 ? caption : caption + ": " + count;
        }
        var picks = picksFor(id);
        if (picks.length == 0) return caption;
        if (picks.length == 1) {
            for (choice in choicesFor(id)) if (choice.key == picks[0]) return choice.label;
        }
        return caption + ": " + picks.length;
    }

    function paintTabs():Void {
        var x = 12.0;
        var y = 11.0;
        for (control in tabs) {
            var on = control.key == tab;
            var textWidth = G.number(G.call("h2d.Text", "get_textWidth", control.title), 48);
            var w = Math.ceil(textWidth + 34);
            paintRaisedTab(control, w, 34, on);
            pin(control.obj, x, on ? y - 1 : y);
            x += w + 8;
        }
    }

    /** Raised tab: darker lip underneath, lighter edge on top, active tab in cream. */
    function paintRaisedTab(control:Dynamic, w:Float, h:Float, on:Bool):Void {
        if (control == null) return;
        G.set(control.obj, "width", w);
        G.set(control.obj, "height", h);
        var bg = control.bg;
        G.call("h2d.Graphics", "clear", bg);
        G.call("h2d.Graphics", "beginFill", bg, [on ? 0xb7a894 : 0x14596a, 1.0]);
        G.call("h2d.Graphics", "drawRect", bg, [0, 3, w, h - 2]);
        G.call("h2d.Graphics", "endFill", bg);
        G.call("h2d.Graphics", "beginFill", bg, [on ? 0xfff8f1 : 0x1c7892, 1.0]);
        G.call("h2d.Graphics", "drawRect", bg, [0, 0, w, h - 3]);
        G.call("h2d.Graphics", "endFill", bg);
        G.call("h2d.Graphics", "beginFill", bg, [on ? 0xffffff : 0x5ec0d0, 1.0]);
        G.call("h2d.Graphics", "drawRect", bg, [0, 0, w, 3]);
        G.call("h2d.Graphics", "endFill", bg);
        G.call("h2d.Text", "set_textColor", control.title, [on ? 0x16343c : 0xf4fbfd]);
        var tw = G.number(G.call("h2d.Text", "get_textWidth", control.title), 0);
        var th = G.number(G.call("h2d.Text", "get_textHeight", control.title), 14);
        position(control.title, Math.max(8, (w - tw) / 2), Math.max(4, (h - th) / 2));
    }

    function paintPager():Void {
        paintFace(previous, 96, 28, 0xe6dfd6, 0x5c5148);
        paintFace(next, 96, 28, 0xe6dfd6, 0x5c5148);
        paintFace(mapButton, 148, 28, 0x2f8eaa, 0xfff8ef);
    }

    function placeDropdowns():Void {
        if (classDrop == null) return;
        var shown:Array<Dynamic> = [];
        for (drop in [classDrop, categoryDrop, slotDrop, markerDrop]) if (dropVisible(drop.id)) shown.push(drop);
        var gap = 8.0;
        var toggleW = tab == "weapons" ? 112.0 : 0.0;
        var usable = 360 - (toggleW > 0 ? toggleW + gap : 0);
        var width = shown.length <= 1 ? usable : (usable - gap * (shown.length - 1)) / shown.length;
        var x = 0.0;
        for (drop in [classDrop, categoryDrop, slotDrop, markerDrop]) {
            var visible = dropVisible(drop.id);
            show(drop.header.obj, visible);
            if (!visible) { show(drop.menu, false); continue; }
            var open = openMenu == drop.id;
            setPlain(drop.header.title, headerText(drop.id));
            try G.set(drop.header.title, "maxWidth", width - 16) catch (_:Dynamic) {}
            paintFace(drop.header, width, 30, open ? 0xf7f4ef : 0xe6dfd6, 0x2f2924);
            pin(drop.header.obj, x, 4);
            show(drop.menu, open);
            if (open && drop.raised != true) {
                drop.raised = true;
                var host = G.field(panel, "obj");
                G.call("h2d.Object", "addChild", host, [drop.menu]);
                if (tipRoot != null) G.call("h2d.Object", "addChild", host, [tipRoot]);
            }
            if (!open) drop.raised = false;
            if (open) placeMenu(drop, x, 36, width);
            x += width + gap;
        }
        if (maxToggle != null) {
            show(maxToggle.obj, tab == "weapons");
            if (tab == "weapons") {
                paintFace(maxToggle, toggleW, 30, maxLegendary ? 0xc48a3a : 0xe6dfd6, maxLegendary ? 0xfff8ef : 0x2f2924);
                pin(maxToggle.obj, x, 4);
            }
        }
    }

    function placeMenu(drop:Dynamic, x:Float, y:Float, headerWidth:Float):Void {
        var choices = choicesFor(drop.id);
        var signature = "";
        for (choice in choices) signature += choice.key + "|";
        if (drop.signature != signature) {
            drop.signature = signature;
            var old:Array<Dynamic> = cast drop.options;
            for (opt in old) G.call("h2d.Object", "remove", opt.obj);
            var built:Array<Dynamic> = [];
            for (choice in choices) {
                var key = choice.key;
                var id = drop.id;
                var opt = face(drop.menu, uiFont, choice.label, () -> togglePick(id, key));
                opt.key = key;
                opt.box = G.create("h2d.Graphics", [opt.obj]);
                built.push(opt);
            }
            drop.options = built;
        }
        var rowH = 28.0;
        var colW = Math.max(168.0, headerWidth);
        var room = Math.max(rowH * 4, tabY - y - 8);
        var maxRows = Std.int(room / rowH);
        if (maxRows < 4) maxRows = 4;
        var options:Array<Dynamic> = cast drop.options;
        var count = options.length;
        var cols = Std.int(Math.ceil(count / maxRows));
        if (cols < 1) cols = 1;
        var rows = Std.int(Math.ceil(count / cols));
        var menuW = cols * colW;
        var menuX = x;
        if (menuX + menuW > innerWidth - 8) menuX = Math.max(0, innerWidth - 8 - menuW);
        pin(drop.menu, menuX, y);
        G.call("h2d.Graphics", "clear", drop.menuBg);
        G.call("h2d.Graphics", "beginFill", drop.menuBg, [0xfbf8f4, 1.0]);
        G.call("h2d.Graphics", "drawRect", drop.menuBg, [0, 0, menuW, rows * rowH + 4]);
        G.call("h2d.Graphics", "endFill", drop.menuBg);
        for (i in 0...count) {
            var opt = options[i];
            var on = pickedOn(drop.id, opt.key);
            var col = Std.int(i / rows);
            var row = i - col * rows;
            position(opt.obj, col * colW + 2, row * rowH + 2);
            paintFace(opt, colW - 4, rowH - 2, on ? 0xe7f3f6 : 0xfbf8f4, on ? 0x1a6a7a : 0x3a2a22, 26);
            paintCheck(opt.box, on);
        }
    }

    function paintCheck(box:Dynamic, on:Bool):Void {
        if (box == null) return;
        position(box, 8, 7);
        G.call("h2d.Graphics", "clear", box);
        G.call("h2d.Graphics", "beginFill", box, [on ? 0x1a6a7a : 0xfbf8f4, 1.0]);
        G.call("h2d.Graphics", "drawRect", box, [0, 0, 12, 12]);
        G.call("h2d.Graphics", "endFill", box);
        if (!on) {
            G.call("h2d.Graphics", "lineStyle", box, [1, 0xc8bfb4, 1.0]);
            G.call("h2d.Graphics", "drawRect", box, [0.5, 0.5, 11, 11]);
        }
    }

    function paintRow(row:Dynamic):Void {
        var on = selected != null && row.hit != null && selected.id == row.hit.id && selected.kind == row.hit.kind;
        var fill = on ? 0xd7eef3 : row.hot == true ? 0xf6e7d4 : 0xfffcf8;
        paintFace(row, listColumn, 52, fill, 0x2a241e, 50);
        reserve(row.obj, listColumn, 52);
        position(row.title, 50, 6);
        position(row.subtitle, 50, 26);
        G.call("h2d.Text", "set_textColor", row.subtitle, [0x8a7364]);
        if (row.edge == null) row.edge = G.create("h2d.Graphics", [row.obj]);
        G.call("h2d.Graphics", "clear", row.edge);
        G.call("h2d.Graphics", "beginFill", row.edge, [on ? 0x2f8eaa : 0xe7d9c8, 1.0]);
        G.call("h2d.Graphics", "drawRect", row.edge, [0, 0, 4, 52]);
        G.call("h2d.Graphics", "endFill", row.edge);
    }

    function paintDrop(row:Dynamic):Void {
        var hot = row.hot == true;
        var w = Math.max(160, detailW - 16);
        var h = 52.0;
        if (row.paintedW == w && row.paintedHot == hot) return;
        row.paintedW = w;
        row.paintedHot = hot;
        paintFace(row, w, h, hot ? 0xd7eef3 : 0xfffcf8, 0x2a241e, 52);
        reserve(row.obj, w, h);
        position(row.title, 52, 6);
        if (row.subtitle != null) {
            position(row.subtitle, 52, 26);
            G.call("h2d.Text", "set_textColor", row.subtitle, [0x8a7364]);
        }
        if (row.edge == null) row.edge = G.create("h2d.Graphics", [row.obj]);
        G.call("h2d.Graphics", "clear", row.edge);
        G.call("h2d.Graphics", "beginFill", row.edge, [hot ? 0x2f8eaa : 0xe7d9c8, 1.0]);
        G.call("h2d.Graphics", "drawRect", row.edge, [0, 0, 4, h]);
        G.call("h2d.Graphics", "endFill", row.edge);
        if (row.mark == null) {
            row.mark = G.create("h2d.Text", [uiFont, row.obj]);
            setPlain(row.mark, ">");
        }
        G.call("h2d.Text", "set_textColor", row.mark, [0x2f8eaa]);
        position(row.mark, w - 18, 16);
        try G.set(row.title, "maxWidth", w - 78) catch (_:Dynamic) {}
        if (row.subtitle != null) try G.set(row.subtitle, "maxWidth", w - 78) catch (_:Dynamic) {}
    }

    function markRow(row:Dynamic):Void {
        var on = selected != null && row.hit != null && selected.id == row.hit.id && selected.kind == row.hit.kind;
        try G.call("h2d.Text", "set_textColor", row.title, [on ? 0x0f6f8a : 0x3a2a22]) catch (_:Dynamic) {}
    }

    function reserve(child:Dynamic, w:Float, h:Float):Void {
        try {
            var host = child == null ? null : G.field(child, "parent");
            if (host == null) return;
            var props = G.call("h2d.Flow", "getProperties", host, [child]);
            G.set(props, "minWidth", w);
            G.set(props, "minHeight", h);
        } catch (_:Dynamic) {}
    }

    /** Flow reflow copies offsetX/offsetY over setPosition, so absolute controls store both. */
    function pin(child:Dynamic, x:Float, y:Float):Void {
        if (child == null) return;
        position(child, x, y);
        try {
            var host = G.field(child, "parent");
            if (host == null) return;
            var props = G.call("h2d.Flow", "getProperties", host, [child]);
            G.set(props, "isAbsolute", true);
            G.set(props, "offsetX", x);
            G.set(props, "offsetY", y);
        } catch (_:Dynamic) {}
    }

    static function categoryLabel(name:String):String {
        return name == "jewellery" ? "Jewellery" : name.charAt(0).toUpperCase() + name.substr(1);
    }

    function watchFocus(input:Dynamic):Void {
        var interactive = G.field(input, "interactive");
        if (interactive == null) interactive = G.field(G.field(input, "input"), "interactive");
        if (interactive == null) return;
        G.set(interactive, "onFocus", (_:Dynamic) -> searchFocused = true);
        G.set(interactive, "onFocusLost", (_:Dynamic) -> searchFocused = false);
    }

    function searchOwnsFocus(ui:Dynamic):Bool {
        if (searchFocused) return true;
        if (searchInput == null || ui == null) return false;
        var focused = G.call("ui.BaseUI", "getFocusedTextInput", ui);
        return focused != null && (focused == searchInput || focused == G.field(searchInput, "input"));
    }

    function blurSearch():Void {
        searchFocused = false;
        var interactive = searchInput == null ? null : G.field(searchInput, "interactive");
        if (interactive == null && searchInput != null) interactive = G.field(G.field(searchInput, "input"), "interactive");
        if (interactive != null) G.call("h2d.Interactive", "blur", interactive);
    }

    function readSearch():Void {
        if (searchInput == null) return;
        var source = G.field(searchInput, "text") != null ? searchInput : G.field(searchInput, "input");
        var next = G.text(G.field(source, "text"));
        if (next == query) return;
        query = next; page = 0; refresh();
    }

    function refresh():Void {
        if (catalog == null || list == null) return;
        var classes = tab == "weapons" || tab == "items" ? classPicks : [];
        var slots = tab == "weapons" || tab == "items" ? slotPicks : [];
        var categories = tab == "items" ? categoryPicks : [];
        hits = catalog.searchFiltered(tab == "map" ? "instances" : tab, query, classes, slots, categories);
        paintPager();
        var count = pageSize < 1 ? 1 : pageSize;
        var pages = Std.int(Math.max(1, Math.ceil(hits.length / count)));
        if (page >= pages) page = pages - 1;
        if (page < 0) page = 0;
        var start = page * count;
        for (i in 0...rows.length) {
            var row = rows[i];
            var hit = i < count && start + i < hits.length ? hits[start + i] : null;
            row.hit = hit;
            show(row.obj, hit != null && tab != "map");
            if (hit == null) continue;
            var title = hit.title;
            if (hit.kind == "item") {
                var local = GameItems.displayName(GameItems.idFor(hit.title));
                if (local != "") title = local;
            }
            setPlain(row.title, title);
            setPlain(row.subtitle, maxLegendary && hit.kind == "item" ? legendarySubtitle(hit) : hit.subtitle);
            paintRow(row);
            paintRowIcon(row, hit.kind == "item" ? GameItems.icon(GameItems.idFor(hit.title)) : null);
        }
        show(G.field(list, "obj"), tab != "map");
        show(previous.obj, tab != "map" && page > 0);
        show(next.obj, tab != "map" && start + count < hits.length);
        show(pageLabel, tab != "map" && hits.length > count);
        setText(pageLabel, (page + 1) + " / " + pages);
        if (map != null) map.setActive(tab == "map");
        show(mapStatus, false);
        show(empty, tab != "map" && hits.length == 0);
        setText(empty, status != "" ? status : "Nothing matches.");
        paintDetail();
    }

    function runPending():Void {
        var hovered = hoverRow;
        for (row in rows) {
            var hot = row == hovered;
            if (row.hot == hot) continue;
            row.hot = hot;
            if (row.hit != null) markRow(row);
        }
        for (row in dropRows) {
            var hot = row == hoverDrop && (row.open != null || row.hit != null);
            if (row.hot == hot) continue;
            row.hot = hot;
            row.paintedW = -1;
            paintDrop(row);
        }
        var tipHit:SearchHit = hoverDrop != null && hoverDrop.hit != null ? hoverDrop.hit : (hovered != null ? hovered.hit : null);
        var tipKey = tipHit == null ? "" : tipHit.kind + ":" + tipHit.id;
        if (tipKey != tippedKey) {
            tippedKey = tipKey;
            tippedRow = hovered;
            try {
                if (tipHit != null) showTip(tipHit) else hideTip();
            } catch (error:Dynamic) Log.once("tip failed: " + Log.problem(error));
        }
        if (pendingSelect != null) {
            var hit = pendingSelect;
            pendingSelect = null;
            select(hit);
        }
        if (pendingOpen != null) {
            var open = pendingOpen;
            pendingOpen = null;
            try open() catch (error:Dynamic) Log.write("open failed: " + Log.problem(error));
        }
    }

    function select(hit:SearchHit):Void {
        Log.write("select " + hit.kind + " " + hit.id + " from " + tab);
        openMenu = "";
        try {
            var leavingMap = tab == "map";
            if (selected == null || selected.kind != hit.kind || selected.id != hit.id) resetScale();
            selected = hit;
            if (leavingMap) {
                tab = hit.kind == "creature" ? "bosses" : hit.kind == "item" ? "items" : "instances";
                if (map != null) map.setActive(false);
                Log.write("map mask removed");
                refresh();
            } else {
            paintDetail();
            for (row in rows) if (row.hit != null) markRow(row);
            }
            Log.write("select finished");
        } catch (error:Dynamic) Log.write("select failed: " + Log.problem(error));
    }

    function openPin(pin:PinRecord):Void {
        var instance = resolvePin(pin);
        if (instance == null) {
            Log.write("pin missed " + pin.label);
            return;
        }
        pendingSelect = {id: instance.id, title: instance.name, subtitle: "", kind: "instance"};
        Log.write("pin " + instance.id);
    }

    function showSelectedOnMap():Void {
        var instance = selectedInstance();
        if (instance == null || instance.pinX == null || instance.pinY == null || map == null) return;
        tab = "map";
        map.center(instance.pinX, instance.pinY);
        refresh();
    }

    function selectedInstance():Null<InstanceRecord> {
        if (selected == null || catalog == null) return null;
        if (selected.kind == "instance") return catalog.instanceById(selected.id);
        if (selected.kind == "creature") return catalog.instanceOfBoss(selected.id);
        return null;
    }

    function resolvePin(pin:PinRecord):Null<InstanceRecord> {
        if (catalog == null) return null;
        var direct = catalog.instanceById(pin.instanceId);
        if (direct != null) return direct;
        var label = pin.label.toLowerCase();
        for (instance in catalog.instances) {
            if (instance.kind == "location") continue;
            if (instance.name.toLowerCase() == label) return instance;
            for (name in instance.names) if (name.toLowerCase() == label) return instance;
        }
        return null;
    }

    function mapPins():Array<PinRecord> {
        var pins = catalog.pinsFor(query, showDungeons, showWorldBosses, showSearchHits);
        if (map == null) return pins;
        for (activity in map.activities) {
            var instance = resolvePin(activity);
            if (instance == null) continue;
            var allowed = (showDungeons && (instance.kind == "dungeon" || instance.kind == "rift"))
                || (showWorldBosses && instance.kind == "world-boss");
            if (showSearchHits && query != "" && instance.name.toLowerCase().indexOf(query.toLowerCase()) >= 0) allowed = true;
            if (!allowed) continue;
            pins.push({
                id: activity.id, x: activity.x, y: activity.y, kind: instance.kind, label: activity.label,
                instanceId: instance.id, creatureId: ""
            });
        }
        return pins;
    }

    function paintDetail():Void {
        var lines = detailBlocks();
        var links = detailLinks();
        var hasPin = selectedInstance() != null && selectedInstance().pinX != null;
        show(detailTitle, tab != "map" && lines.length > 0);
        show(mapButton.obj, tab != "map" && hasPin);
        paintBlock(detailTitle, lines.length == 0 ? null : lines[0]);
        var extra = lines.length - 1 > detailLines.length;
        for (i in 0...detailLines.length) {
            var block = extra && i == detailLines.length - 1 ? {text: "More lines are omitted.", html: false, muted: true}
                : (i + 1 < lines.length ? lines[i + 1] : null);
            show(detailLines[i], tab != "map" && block != null && block.text != "");
            paintBlock(detailLines[i], block);
        }
        showIcon();
        links = shownLinks(links);
        var hasSkills = false;
        for (link in links) if (link.kind == "skill") { hasSkills = true; break; }
        var heading = hasSkills ? "Skills" : (selected != null && selected.kind == "item" ? "Dropped by" : "Drops");
        show(dropHeading, tab != "map" && links.length > 0);
        setText(dropHeading, heading);
        show(G.field(dropList, "obj"), tab != "map" && links.length > 0);
        for (i in 0...dropRows.length) {
            var row = dropRows[i];
            var link = i < links.length ? links[i] : null;
            row.open = link == null ? null : link.open;
            row.hit = link == null ? null : link.hit;
            show(row.obj, link != null && tab != "map");
            if (link == null) continue;
            var title = link.label;
            if (link.kind == "item") {
                var local = GameItems.displayName(GameItems.idFor(link.iconName));
                if (local != "") title = local;
            } else if (link.kind == "skill") {
                var skillName = GameItems.skillName(link.iconName);
                if (skillName != "") title = skillName;
            }
            setPlain(row.title, title);
            setPlain(row.subtitle, link.subtitle);
            row.paintedW = -1;
            paintDrop(row);
            if (row.mark != null) show(row.mark, link.open != null);
            var tile = link.kind == "item" ? GameItems.icon(GameItems.idFor(link.iconName))
                : link.kind == "skill" ? GameItems.skillIcon(link.iconName) : null;
            paintRowIcon(row, tile);
        }
        var shown = 0;
        for (link in links) if (link != null) shown++;
        Log.once("detail " + (selected == null ? "none" : selected.kind + " " + selected.id) + " lines=" + lines.length + " links=" + shown + " w=" + detailW);
    }

    function paintBlock(target:Dynamic, block:Null<DetailBlock>):Void {
        if (block == null) return;
        if (block.html) setHtml(target, block.text) else {
            setText(target, block.text);
            var color = block.muted ? 0x7a675c : rarityColor(block.text);
            try G.call("h2d.Text", "set_textColor", target, [color]) catch (_:Dynamic) {}
        }
    }

    static function rarityColor(text:String):Int {
        if (text.indexOf(" / ") >= 0) return 0x5b4334;
        var key = text.toLowerCase();
        if (key.indexOf("legendary") >= 0) return 0xb8860b;
        if (key.indexOf("epic") >= 0) return 0x7a4ea3;
        if (key.indexOf("rare") >= 0) return 0x2f6fad;
        if (key.indexOf("uncommon") >= 0) return 0x2f7d46;
        return 0x5b4334;
    }

    static function rarityFill(text:String):Int {
        var key = text.toLowerCase();
        if (key.indexOf("legendary") >= 0) return 0xc48a3a;
        if (key.indexOf("epic") >= 0) return 0x7a4ea3;
        if (key.indexOf("rare") >= 0) return 0x3a6ea5;
        if (key.indexOf("uncommon") >= 0) return 0x3d8f4a;
        return 0xc4b5a4;
    }

    function detailBlocks():Array<DetailBlock> {
        if (catalog == null || selected == null) return status == "" ? [] : [plain(status)];
        if (selected.kind == "instance") return instanceBlocks(catalog.instanceById(selected.id));
        if (selected.kind == "creature") return creatureBlocks(catalog.creature(selected.id));
        return itemBlocks(catalog.item(selected.id));
    }

    function detailLinks():Array<DetailLink> {
        if (catalog == null || selected == null || tab == "map") return [];
        if (selected.kind == "instance") return instanceLinks(catalog.instanceById(selected.id));
        if (selected.kind == "creature") return creatureLinks(catalog.creature(selected.id));
        return itemLinks(catalog.item(selected.id));
    }

    function instanceBlocks(instance:Null<InstanceRecord>):Array<DetailBlock> {
        if (instance == null) return [];
        var bosses = [for (id in instance.bosses) if (catalog.creature(id) != null) catalog.creature(id).name];
        var lines = [plain(instance.name), plain(kindLabel(instance.kind))];
        if (bosses.length > 0) lines.push(plain(bosses.join(", ")));
        return lines;
    }

    function creatureBlocks(creature:Null<CreatureRecord>):Array<DetailBlock> {
        if (creature == null) return [];
        var lines = [plain(creature.name)];
        var meta = [];
        if (creature.level != null) meta.push("Level " + creature.level);
        if (creature.faction != "") meta.push(creature.faction);
        if (creature.subcategory != "") meta.push(creature.subcategory);
        if (meta.length > 0) lines.push(plain(meta.join(" · ")));
        var instance = catalog.instanceOfBoss(creature.id);
        if (instance != null) lines.push(plain(kindLabel(instance.kind) + ": " + instance.name));
        if (creature.description != "") lines.push(soft(creature.description));
        if (creature.skills.length > 0) {
            lines.push(plain("Skills"));
            for (skill in creature.skills) lines.push(plain(skillLine(skill)));
        }
        return lines;
    }

    function itemBlocks(item:Null<ItemRecord>):Array<DetailBlock> {
        if (item == null) return [];
        var gameId = GameItems.idFor(item.name);
        var title = GameItems.displayName(gameId);
        if (title == "") title = item.name;
        var slot = GameItems.slotName(gameId);
        if (slot == "") slot = item.subcategory;
        var step = activeStep(item);
        var lines = [title.indexOf("<") >= 0 ? rich(title) : plain(title)];
        if (slot != "") lines.push(plain(Catalog.prettySlot(slot)));
        var level = step != null && step.level != null ? step.level : item.level;
        if (level != null) lines.push(plain("Level " + level + (item.scales.length > 0 ? " · " + scaleLabel(scaleMode) : "")));
        var rarity = step != null && step.rarity != "" ? step.rarity : item.rarity;
        if (rarity != "") lines.push(plain(rarity));
        if (item.classes.length > 0) lines.push(plain(item.classes.join(", ")));
        if (item.description != "") lines.push(plain(item.description));
        if (item.recipe != "" && item.recipe != item.description) lines.push(plain(item.recipe));
        if (scaleMode == "heroic" && step == null) lines.push(soft("Heroic scaling is not in this patch yet."));
        else if (scaleMode == "max" && step == null && item.scales.length > 0) lines.push(soft("This piece has no max-level scaling."));
        else {
            var stats = step != null ? step.stats : item.stats;
            for (stat in stats) lines.push(rich("<good>" + LiteralText.escape(stat.value + " " + stat.label) + "</good>"));
        }
        return lines;
    }

    function instanceLinks(instance:Null<InstanceRecord>):Array<DetailLink> {
        if (instance == null) return [];
        var links:Array<DetailLink> = [];
        for (id in instance.bosses) {
            var creature = catalog.creature(id);
            if (creature == null) continue;
            var bossId = creature.id;
            links.push(linkRow(creature.name, "Boss", "creature", creature.name, "", null, () -> openCreature(bossId)));
            for (link in creatureLinks(creature)) links.push(link);
        }
        return links;
    }

    function creatureLinks(creature:Null<CreatureRecord>):Array<DetailLink> {
        if (creature == null) return [];
        var links:Array<DetailLink> = [];
        for (group in ["boss", "unit", "faction", "world"]) {
            var drops = creature.drops[group];
            if (drops == null) continue;
            for (drop in drops) {
                var slug = drop.slug;
                var name = drop.name;
                var item = catalogItem(slug, name);
                var category = item == null || item.category == "" ? "other" : item.category;
                var bits = [];
                if (group != "boss") bits.push(groupLabel(group));
                if (item != null && item.subcategory != "") bits.push(Catalog.prettySlot(item.subcategory));
                if (item != null && item.level != null) bits.push("Level " + item.level);
                if (drop.chance != "") bits.push(drop.chance);
                var hit:SearchHit = {id: item != null ? item.slug : slug, title: item != null ? item.name : name, subtitle: "", kind: "item"};
                links.push(linkRow(name, bits.join(" · "), "item", item != null ? item.name : name, category, hit, () -> openItem(slug, name)));
            }
        }
        return links;
    }

    function itemLinks(item:Null<ItemRecord>):Array<DetailLink> {
        if (item == null) return [];
        var sources = catalog.droppedBy(item.slug);
        if (sources.length == 0) sources = catalog.droppedBy(item.name);
        var links:Array<DetailLink> = [];
        for (skill in item.skills) {
            if (skill.name == "" && skill.id == "") continue;
            var cooldown = skill.cooldown != null && skill.cooldown > 0 ? skill.cooldown + "s" : "";
            var skillId = skill.id;
            var skillTitle = skill.name;
            var hit:SearchHit = {id: skillId != "" ? skillId : skillTitle, title: skillTitle, subtitle: cooldown, kind: "skill"};
            links.push(linkRow(skillTitle, cooldown, "skill", skillId, "", hit, null));
        }
        for (source in sources) {
            var creatureId = source.creatureId;
            var place = source.instanceId == "" ? null : catalog.instanceById(source.instanceId);
            var where = place == null ? "" : " · " + place.name;
            var chance = source.chance == "" ? "" : "    " + source.chance;
            var note = item.skills.length > 0 ? "Dropped by" : "";
            links.push(linkRow(source.creatureName + chance + where, note, "creature", source.creatureName, "", null, () -> openCreature(creatureId)));
        }
        return links;
    }

    function openItem(slug:String, name:String):Void {
        var item = slug != "" ? catalog.item(slug) : null;
        if (item == null) {
            var key = name.toLowerCase();
            for (candidate in catalog.items) if (candidate.name.toLowerCase() == key) { item = candidate; break; }
        }
        if (item == null) return;
        tab = item.category == "weapons" ? "weapons" : "items";
        resetScale();
        clearPicks();
        page = 0;
        selected = {id: item.slug, title: item.name, subtitle: "", kind: "item"};
        refresh();
    }

    function openCreature(id:String):Void {
        var creature = catalog.creature(id);
        if (creature == null) return;
        tab = "bosses";
        resetScale();
        clearPicks();
        page = 0;
        selected = {id: creature.id, title: creature.name, subtitle: "", kind: "creature"};
        refresh();
    }

    function showIcon():Void {
        try showIconTile() catch (_:Dynamic) { show(iconBitmap, false); show(iconHolder, false); }
    }

    function showIconTile():Void {
        var tile = null;
        var pixels = 48.0;
        if (selected != null && selected.kind == "item" && catalog != null) {
            var item = catalog.item(selected.id);
            tile = item == null ? null : GameItems.icon(GameItems.idFor(item.name));
        } else if (selected != null && selected.kind == "creature" && catalog != null) {
            var creature = catalog.creature(selected.id);
            var skillId = creature != null && creature.skills.length > 0 ? creature.skills[0].id : "";
            tile = creature == null ? null : GameItems.portrait(creature.name, skillId);
            pixels = 72;
        }
        iconBitmap = mountIcon(iconBitmap, iconHolder, tile, pixels);
        var shown = tab != "map" && iconBitmap != null && G.field(iconBitmap, "visible") == true;
        show(iconHolder, shown);
        show(iconBitmap, shown);
    }

    /** Scale a cloned tile onto a bitmap. Never uses Bitmap.set_width, which turns a zero-size tile into an infinite scale and blacks the frame. */
    function mountIcon(current:Dynamic, parent:Dynamic, tile:Dynamic, pixels:Float):Dynamic {
        if (parent == null || tile == null) { show(current, false); return current; }
        var w = G.number(G.field(tile, "width"), 0);
        var h = G.number(G.field(tile, "height"), 0);
        var scale = pixels / Math.max(w, h);
        if (!(w >= 1 && h >= 1 && w <= 2048 && h <= 2048) || !Math.isFinite(scale) || scale <= 0 || scale > 8) {
            show(current, false);
            return current;
        }
        var bitmap = current;
        try {
            if (bitmap == null || G.field(bitmap, "removed") == true || G.field(bitmap, "parent") != parent) {
                if (bitmap != null) try G.call("h2d.Object", "remove", bitmap) catch (_:Dynamic) {}
                bitmap = G.create("h2d.Bitmap", [null, parent]);
            }
            G.call("h2d.Bitmap", "set_tile", bitmap, [tile]);
            G.call("h2d.Object", "setScale", bitmap, [scale]);
            show(bitmap, true);
            return bitmap;
        } catch (_:Dynamic) {
            if (bitmap != null) {
                show(bitmap, false);
                try G.call("h2d.Object", "remove", bitmap) catch (_:Dynamic) {}
            }
            return null;
        }
    }

    static function plain(text:String):DetailBlock return {text: text, html: false, muted: false};
    static function soft(text:String):DetailBlock return {text: text, html: false, muted: true};
    static function rich(text:String):DetailBlock return {text: text, html: true, muted: false};

    static function skillLine(skill:SkillLine):String {
        var parts = [];
        if (skill.duration != null && skill.duration > 0) parts.push(skill.duration + "s");
        if (skill.cooldown != null && skill.cooldown > 0) parts.push(skill.cooldown + "s cooldown");
        if (skill.power != "") parts.push(skill.power);
        return parts.length == 0 ? skill.name : skill.name + "    ·    " + parts.join(" · ");
    }

    function linkRow(label:String, subtitle:String, kind:String, iconName:String, category:String, hit:Null<SearchHit>, open:Void->Void):DetailLink {
        return {label: label, subtitle: subtitle, kind: kind, iconName: iconName, category: category, hit: hit, open: open};
    }

    function catalogItem(slug:String, name:String):Null<ItemRecord> {
        var item = slug != "" ? catalog.item(slug) : null;
        if (item != null) return item;
        var key = name.toLowerCase();
        for (candidate in catalog.items) if (candidate.name.toLowerCase() == key) return candidate;
        return null;
    }

    static function lootGroup(category:String):String {
        return switch (category) {
            case "weapons", "armor", "jewellery", "materials", "consumables": category;
            default: "other";
        };
    }

    function shownLinks(links:Array<DetailLink>):Array<DetailLink> {
        if (dropPicks.length == 0) return links;
        var kept = [];
        for (link in links) if (link.kind != "item" || dropPicks.indexOf(lootGroup(link.category)) >= 0) kept.push(link);
        return kept;
    }

    static function skillDetail(skill:SkillLine):String {
        var parts = [];
        if (skill.cooldown != null) parts.push(skill.cooldown + "s cooldown");
        if (skill.duration != null) parts.push(skill.duration + "s");
        if (skill.power != "") parts.push(skill.power);
        return parts.join(" · ");
    }
    static function groupLabel(group:String):String return switch (group) {
        case "boss": "Boss loot"; case "unit": "Unit loot"; case "faction": "Faction loot"; case "world": "World loot"; default: group;
    };
    static function kindLabel(kind:String):String return switch (kind) {
        case "dungeon": "Dungeon"; case "world-boss": "World boss"; case "rift": "Rift"; default: "Location";
    };

    function layout():Void {
        var scene = G.field(owner, "s2d");
        var screenW = G.number(G.field(scene, "width"), 1920);
        var screenH = G.number(G.field(scene, "height"), 1080);
        var w = Std.int(Math.max(760, Math.min(1180, screenW - 80)));
        var h = Std.int(Math.max(520, Math.min(860, screenH - 80)));
        if (w == width && h == height) return;
        width = w; height = h;
        size(window, w, h); if (frame != null) { size(frame, w, h); position(frame, 0, 0); }
        size(header, w - 2, HEADER); position(header, 0, 0);
        paintHeader(w);
        size(close, 36, 36); position(close, w - 48, 10);
        var contentTop = HEADER;
        var contentHeight = h - contentTop - 8;
        size(content, w - 16, contentHeight); position(content, 8, contentTop);
        for (object in wrappers) { size(object, w - 16, contentHeight); position(object, 0, 0); }
        var panelObject = G.field(panel, "obj");
        size(panelObject, w - 32, contentHeight - 8); position(panelObject, 8, 4);
        var inner = w - 48;
        tabY = contentHeight - 12;
        if (searchInput != null) {
            // FmtTextInput is a text field, not a flow. Flow sizing casts and closes the window.
            try G.set(searchInput, "maxWidth", 220) catch (_:Dynamic) {}
            try G.set(searchInput, "inputWidth", 220) catch (_:Dynamic) {}
        }
        var listWidth = 360;
        var listTop = 40;
        var listHeight = tabY - listTop - 44;
        innerWidth = inner;
        listBottom = listTop + listHeight;
        listColumn = listWidth - 8;
        size(G.field(list, "obj"), listWidth, Std.int(listHeight)); position(G.field(list, "obj"), 0, listTop);
        pin(previous.obj, 0, listTop + listHeight + 8);
        pin(next.obj, 108, listTop + listHeight + 8);
        position(pageLabel, 216, listTop + listHeight + 14);
        detailX = listWidth + 16;
        detailTop = 40;
        detailW = inner - detailX;
        detailBottom = tabY - 8;
        position(detailTitle, detailX, listTop);
        G.call("ui.comp.FmtText", "set_maxWidthText", detailTitle, [detailW - 56]);
        pin(mapButton.obj, detailX + detailW - 148, 4);
        for (i in 0...detailLines.length) {
            position(detailLines[i], detailX, listTop + 28 + i * 18);
            G.call("ui.comp.FmtText", "set_maxWidthText", detailLines[i], [detailW]);
        }
        for (row in dropRows) paintDrop(row);
        position(empty, 8, listTop + 8);
        G.call("ui.comp.FmtText", "set_maxWidthText", empty, [listWidth]);
        position(mapStatus, 8, listTop + 48);
        G.call("ui.comp.FmtText", "set_maxWidthText", mapStatus, [inner]);
        position(map.root, 0, 40);
        map.resize(inner, Math.max(80, tabY - 48));
        placeWindow();
    }

    /** Keep the browser in the middle of the screen so tooltips have room beside it. */
    function placeWindow():Void {
        if (window == null || owner == null || width <= 0) return;
        try {
            var scene = G.field(owner, "s2d");
            if (scene == null) return;
            var screenW = G.number(G.field(scene, "width"), 1920);
            var screenH = G.number(G.field(scene, "height"), 1080);
            var x = (screenW - width) / 2;
            var y = (screenH - height) / 2;
            var parent = G.field(window, "parent");
            var point = parent == null ? null : G.point(x, y);
            if (point != null) {
                var local = G.call("h2d.Object", "globalToLocal", parent, [point]);
                if (local != null) {
                    x = G.number(G.field(local, "x"), x);
                    y = G.number(G.field(local, "y"), y);
                }
            }
            pin(window, x, y);
        } catch (error:Dynamic) Log.once("place window " + Log.problem(error));
    }

    function placeChrome():Void {
        if (classDrop == null || innerWidth <= 0 || list == null) return;
        var listTop = tab == "instances" || tab == "bosses" ? 8.0 : 40.0;
        var pagerY = tabY - 36;
        var listHeight = Math.max(56, pagerY - 8 - listTop);
        var fit = Std.int(Math.floor(listHeight / 56));
        if (fit < 3) fit = 3;
        if (fit > PAGE) fit = PAGE;
        var resized = fit != pageSize;
        pageSize = fit;
        listBottom = listTop + listHeight;
        detailBottom = tabY - 8;
        detailTop = 40;
        size(G.field(list, "obj"), 360, Std.int(listHeight));
        position(G.field(list, "obj"), 0, listTop);
        position(empty, 8, listTop + 8);
        pin(previous.obj, 0, pagerY);
        pin(next.obj, 108, pagerY);
        position(pageLabel, 216, pagerY + 4);
        if (openMenu != "" && openMenu != "loot" && openMenu != "scale" && openMenu != "step" && !dropVisible(openMenu)) openMenu = "";
        paintTabs();
        placeDropdowns();
        var searchW = Std.int(Math.max(100, Math.min(220, detailW - 164)));
        if (searchInput != null) {
            position(searchInput, detailX, 6);
            try G.set(searchInput, "maxWidth", searchW) catch (_:Dynamic) {}
            try G.set(searchInput, "inputWidth", searchW) catch (_:Dynamic) {}
        }
        pin(mapButton.obj, detailX + searchW + 12, 4);
        if (tab == "map" && map != null) {
            position(map.root, 0, 40);
            map.resize(innerWidth, Math.max(80, tabY - 48));
        }
        if (resized) refresh();
    }

    function showTip(hit:SearchHit):Void {
        if (hit == null) return;
        if (hit.kind == "item" && showNativeItemTip(hit)) {
            hideCustomTip();
            return;
        }
        if (hit.kind == "skill" && showNativeSkillTip(hit)) {
            hideCustomTip();
            return;
        }
        hideNativeTip();
        if (tipRoot == null) return;
        try showTipCard(hit) catch (error:Dynamic) {
            Log.once("tip card " + Log.problem(error));
            hideTip();
        }
    }

    /** The game's own item tooltip, the same one inventory slots use. */
    function showNativeItemTip(hit:SearchHit):Bool {
        var item = catalog == null ? null : catalog.item(hit.id);
        var id = GameItems.idFor(item != null ? item.name : hit.title);
        var def = GameItems.definition(id);
        if (def == null || owner == null) return false;
        var step = maxLegendary ? topStep(item) : null;
        if (step == null) restoreScaledDef();
        var tip = step == null ? gameTip(def) : scaledTip(def, step);
        if (tip == null) {
            restoreScaledDef();
            return false;
        }
        if (nativeTip != null) {
            var previous = nativeTip;
            nativeTip = null;
            try G.call("ui.BaseUI", "removeTip", owner, [previous]) catch (_:Dynamic) {}
            try G.call("h2d.Object", "remove", previous) catch (_:Dynamic) {}
        }
        if (!presentTip(tip)) {
            restoreScaledDef();
            return false;
        }
        nativeTip = tip;
        placeNativeTip();
        return true;
    }

    /** The game's skill tooltip, the same one the skill bar uses. */
    function showNativeSkillTip(hit:SearchHit):Bool {
        if (owner == null || hit.id == "") return false;
        var tip = skillTip(hit.id);
        if (tip == null) return false;
        hideNativeTip();
        if (!presentTip(tip)) return false;
        nativeTip = tip;
        placeNativeTip();
        return true;
    }

    function skillTip(id:String):Dynamic {
        var def = GameItems.skillDefinition(id);
        var attempts:Array<Array<Dynamic>> = [];
        if (def != null) {
            attempts.push([def]);
            attempts.push([def, null]);
        }
        try {
            var ref = G.staticCall("HSkill", "getSkillRef", [id]);
            if (ref != null) {
                attempts.push([ref]);
                attempts.push([ref, null]);
            }
        } catch (error:Dynamic) Log.once("skill ref " + Log.problem(error));
        try {
            var inf = def != null ? G.staticCall("HSkill", "makeSkillInf", [def]) : null;
            if (inf != null) attempts.push([inf]);
        } catch (error:Dynamic) Log.once("makeSkillInf " + Log.problem(error));
        for (args in attempts) {
            try {
                var tip = G.staticCall("ui.Tooltip", "fromSkill", args);
                if (tip != null) return tip;
            } catch (error:Dynamic) Log.once("fromSkill " + args.length + " " + Log.problem(error));
        }
        return null;
    }

    /** Build the game tooltip for a max-level rarity instead of the item's base level. */
    function scaledTip(def:Dynamic, step:ScaleStep):Dynamic {
        var generated = generatedItem(def, step);
        if (generated != null) {
            var tip = gameTip(generated);
            if (tip != null) return tip;
        }
        applyScaledDef(def, step);
        return gameTip(def);
    }

    function generatedItem(def:Dynamic, step:ScaleStep):Dynamic {
        var level = step.level == null ? 0 : step.level;
        var rarity = step.rarity;
        var attempts:Array<Array<Dynamic>> = [[def, level, rarity], [def, level, rarity, null]];
        for (args in attempts) {
            try {
                var item = G.staticCall("HItem", "generateItem", args);
                if (item != null) return item;
            } catch (error:Dynamic) Log.once("generateItem " + args.length + " " + Log.problem(error));
        }
        return null;
    }

    function applyScaledDef(def:Dynamic, step:ScaleStep):Void {
        restoreScaledDef();
        savedLevel = G.field(def, "level");
        savedILevel = G.field(def, "iLevel");
        savedRarity = G.field(def, "rarity");
        scaledDef = def;
        if (step.level != null) {
            G.set(def, "level", step.level);
            G.set(def, "iLevel", step.level);
        }
        if (step.rarity != "") G.set(def, "rarity", step.rarity);
    }

    function restoreScaledDef():Void {
        if (scaledDef == null) return;
        G.set(scaledDef, "level", savedLevel);
        G.set(scaledDef, "iLevel", savedILevel);
        G.set(scaledDef, "rarity", savedRarity);
        scaledDef = null;
    }

    function gameTip(def:Dynamic):Dynamic {
        try {
            var tip = G.staticCall("ui.Tooltip", "fromItem", [def]);
            if (tip != null) return tip;
        } catch (error:Dynamic) Log.once("fromItem " + Log.problem(error));
        try {
            var tip = G.staticCall("ui.Tooltip", "fromItem", [def, null]);
            if (tip != null) return tip;
        } catch (error:Dynamic) Log.once("fromItem2 " + Log.problem(error));
        if (tipButton == null) {
            try {
                var created = node("item-button", panel, [], "lootDbTipButton");
                tipButton = G.field(created, "obj");
                absolute(G.field(panel, "obj"), tipButton);
                show(tipButton, false);
            } catch (error:Dynamic) {
                Log.once("item-button " + Log.problem(error));
                tipButton = null;
            }
        }
        if (tipButton == null) return null;
        try G.call("ui.comp.ItemButton", "setItem", tipButton, [def])
        catch (error:Dynamic) {
            Log.once("setItem " + Log.problem(error));
            try G.call("ui.comp.ItemButton", "setItemInf", tipButton, [def])
            catch (error2:Dynamic) {
                Log.once("setItemInf " + Log.problem(error2));
                return null;
            }
        }
        try return G.call("ui.UIElement", "getTip", tipButton)
        catch (error:Dynamic) {
            Log.once("getTip " + Log.problem(error));
            return null;
        }
    }

    function presentTip(tip:Dynamic):Bool {
        try {
            G.call("ui.BaseUI", "setTip", owner, [tip]);
            return true;
        } catch (error:Dynamic) Log.once("setTip " + Log.problem(error));
        var layer = G.field(owner, "rootTips");
        if (layer == null) return false;
        try {
            G.call("h2d.Object", "addChild", layer, [tip]);
            return true;
        } catch (error:Dynamic) {
            Log.once("rootTips " + Log.problem(error));
            return false;
        }
    }

    function placeNativeTip():Void {
        if (nativeTip == null || owner == null) return;
        var layer = G.field(nativeTip, "parent");
        if (layer == null) layer = G.field(owner, "rootTips");
        if (layer == null || G.field(owner, "s2d") == null) return;
        try {
            var scene = G.field(owner, "s2d");
            var sw = G.number(G.field(scene, "width"), 1920);
            var sh = G.number(G.field(scene, "height"), 1080);
            var mx = G.number(G.field(scene, "mouseX"), 0);
            var my = G.number(G.field(scene, "mouseY"), 0);
            moveTipToScene(layer, mx + 18, my + 18);
            try G.call("h2d.Object", "syncPos", nativeTip) catch (_:Dynamic) {}
            var box = tipSceneBox();
            var tipW = box == null ? 440.0 : box.xMax - box.xMin;
            var tipH = box == null ? 420.0 : box.yMax - box.yMin;
            if (tipW < 40) tipW = 440;
            if (tipH < 40) tipH = 420;
            var openRight = (sw - mx) >= (mx) || (sw - mx) >= tipW + 28;
            var sceneX = openRight ? mx + 18 : mx - 18 - tipW;
            var sceneY = my + 18;
            if (sceneY + tipH > sh - 12) sceneY = my - 18 - tipH;
            if (sceneX < 12) sceneX = 12;
            if (sceneY < 12) sceneY = 12;
            if (sceneX + tipW > sw - 12) sceneX = Math.max(12, sw - 12 - tipW);
            if (sceneY + tipH > sh - 12) sceneY = Math.max(12, sh - 12 - tipH);
            if (box != null) {
                var absX = G.number(G.field(nativeTip, "absX"), sceneX);
                var absY = G.number(G.field(nativeTip, "absY"), sceneY);
                moveTipToScene(layer, absX + (sceneX - box.xMin), absY + (sceneY - box.yMin));
            } else moveTipToScene(layer, sceneX, sceneY);
            clampTipToScreen(scene, layer);
        } catch (error:Dynamic) Log.once("place tip " + Log.problem(error));
    }

    function moveTipToScene(layer:Dynamic, sceneX:Float, sceneY:Float):Void {
        var point = layer == null ? null : G.point(sceneX, sceneY);
        if (point == null) { position(nativeTip, sceneX, sceneY); return; }
        var local = G.call("h2d.Object", "globalToLocal", layer, [point]);
        var target = local != null ? local : point;
        position(nativeTip, G.number(G.field(target, "x"), sceneX), G.number(G.field(target, "y"), sceneY));
    }

    function tipSceneBox():{xMin:Float, yMin:Float, xMax:Float, yMax:Float} {
        var bounds = G.call("h2d.Object", "getBounds", nativeTip, [null, null]);
        if (bounds == null) return null;
        var xMin = G.number(G.field(bounds, "xMin"), 0);
        var yMin = G.number(G.field(bounds, "yMin"), 0);
        var xMax = G.number(G.field(bounds, "xMax"), 0);
        var yMax = G.number(G.field(bounds, "yMax"), 0);
        if (xMax - xMin < 8 || yMax - yMin < 8) return null;
        return {xMin: xMin, yMin: yMin, xMax: xMax, yMax: yMax};
    }

    /** Scene coordinates can sit inside the camera while the pixels are off the monitor. */
    function clampTipToScreen(scene:Dynamic, layer:Dynamic):Void {
        try G.call("h2d.Object", "syncPos", nativeTip) catch (_:Dynamic) {}
        var box = tipSceneBox();
        if (box == null) return;
        var p0 = sceneToScreen(scene, box.xMin, box.yMin);
        var p1 = sceneToScreen(scene, box.xMax, box.yMax);
        var left = Math.min(p0.x, p1.x);
        var top = Math.min(p0.y, p1.y);
        var right = Math.max(p0.x, p1.x);
        var bottom = Math.max(p0.y, p1.y);
        var win = G.staticCall("hxd.Window", "getInstance", []);
        var pw = win == null ? right : G.number(G.field(win, "width"), right);
        var ph = win == null ? bottom : G.number(G.field(win, "height"), bottom);
        if (pw < 32 || ph < 32) return;
        var dx = 0.0;
        var dy = 0.0;
        if (right > pw - 8) dx = (pw - 8) - right;
        if (left + dx < 8) dx = 8 - left;
        if (bottom > ph - 8) dy = (ph - 8) - bottom;
        if (top + dy < 8) dy = 8 - top;
        if (dx == 0 && dy == 0) return;
        var scaleX = (p1.x - p0.x) / (box.xMax - box.xMin);
        var scaleY = (p1.y - p0.y) / (box.yMax - box.yMin);
        if (scaleX < 0.01 && scaleX > -0.01) scaleX = 1;
        if (scaleY < 0.01 && scaleY > -0.01) scaleY = 1;
        var absX = G.number(G.field(nativeTip, "absX"), 0);
        var absY = G.number(G.field(nativeTip, "absY"), 0);
        moveTipToScene(layer, absX + dx / scaleX, absY + dy / scaleY);
    }

    function sceneToScreen(scene:Dynamic, x:Float, y:Float):{x:Float, y:Float} {
        var camera = G.field(scene, "camera");
        if (camera == null) return {x: x, y: y};
        try G.call("h2d.Object", "syncPos", camera) catch (_:Dynamic) {}
        var a = G.number(G.field(camera, "matA"), 1);
        var b = G.number(G.field(camera, "matB"), 0);
        var c = G.number(G.field(camera, "matC"), 0);
        var d = G.number(G.field(camera, "matD"), 1);
        var ox = G.number(G.field(camera, "absX"), 0);
        var oy = G.number(G.field(camera, "absY"), 0);
        var sx = G.number(G.field(scene, "viewportScaleX"), 1);
        var sy = G.number(G.field(scene, "viewportScaleY"), 1);
        if (sx == 0) sx = 1;
        if (sy == 0) sy = 1;
        return {
            x: (x * a + y * c + ox) * sx + G.number(G.field(scene, "offsetX"), 0),
            y: (x * b + y * d + oy) * sy + G.number(G.field(scene, "offsetY"), 0)
        };
    }

    function hideNativeTip():Void {
        restoreScaledDef();
        if (nativeTip == null) return;
        var tip = nativeTip;
        nativeTip = null;
        try G.call("ui.BaseUI", "removeTip", owner, [tip]) catch (_:Dynamic) {}
        try G.call("h2d.Object", "remove", tip) catch (_:Dynamic) {}
    }

    function showTipCard(hit:SearchHit):Void {
        var lines = tipText(hit);
        var count = Std.int(Math.min(lines.length, tipLines.length));
        if (count == 0) { hideTip(); return; }
        var itemTip = hit.kind == "item";
        var width = itemTip ? 340.0 : 300.0;
        var headerH = itemTip ? 74.0 : 0.0;
        var bodyLines = itemTip ? Std.int(Math.max(0, count - 2)) : count;
        var height = headerH + 14 + bodyLines * 18;
        G.call("h2d.Graphics", "clear", tipBg);
        G.call("h2d.Graphics", "beginFill", tipBg, [0x1c1814, 1.0]);
        G.call("h2d.Graphics", "drawRect", tipBg, [-1, -1, width + 2, height + 2]);
        G.call("h2d.Graphics", "endFill", tipBg);
        G.call("h2d.Graphics", "beginFill", tipBg, [0x3a342f, 0.98]);
        G.call("h2d.Graphics", "drawRect", tipBg, [0, 0, width, height]);
        G.call("h2d.Graphics", "endFill", tipBg);
        if (itemTip) {
            G.call("h2d.Graphics", "beginFill", tipBg, [0x3d6274, 1.0]);
            G.call("h2d.Graphics", "drawRect", tipBg, [0, 0, width, headerH]);
            G.call("h2d.Graphics", "endFill", tipBg);
        }
        var spot = tipSpot(width, height);
        var x = spot.x;
        var y = spot.y;
        position(tipRoot, x, y);
        var tile = itemTip ? tipIconTile(hit) : null;
        placeTipIcon(tile, 12, 12);
        for (i in 0...tipLines.length) {
            var text = i < count ? lines[i] : "";
            show(tipLines[i], text != "");
            if (text == "") continue;
            var html = StringTools.startsWith(text, "<");
            var klass = StringTools.startsWith(text, "@");
            if (klass) text = text.substr(1);
            if (html) setHtml(tipLines[i], text) else {
                setText(tipLines[i], text);
                var color = i == 0 ? 0xfff8ef : i == 1 && itemTip ? 0x8ec6ef : klass ? 0x8dce73 : 0xf4efe6;
                try G.call("h2d.Text", "set_textColor", tipLines[i], [color]) catch (_:Dynamic) {}
            }
            var textX = tile != null && i < 2 ? 72.0 : 16.0;
            var textY = itemTip && i < 2 ? 16 + i * 26 : headerH + 12 + (itemTip ? i - 2 : i) * 18;
            position(tipLines[i], x + textX, y + textY);
        }
        show(tipRoot, true);
    }

    function tipIconTile(hit:SearchHit):Dynamic {
        if (catalog == null || hit == null) return null;
        var item = catalog.item(hit.id);
        return item == null ? null : GameItems.icon(GameItems.idFor(item.name));
    }

    function placeTipIcon(tile:Dynamic, localX:Float, localY:Float):Void {
        if (tipRoot == null) { show(tipIcon, false); return; }
        tipIcon = mountIcon(tipIcon, tipRoot, tile, 48);
        if (tipIcon != null && G.field(tipIcon, "visible") == true) position(tipIcon, localX, localY);
    }

    function tipSpot(tipW:Float, tipH:Float):{x:Float, y:Float} {
        var x = detailX > 0 ? detailX : 390;
        var y = 80.0;
        try {
            var scene = G.field(owner, "s2d");
            var mx = G.number(G.field(scene, "mouseX"), -1);
            var my = G.number(G.field(scene, "mouseY"), -1);
            if (mx >= 0 && my >= 0) {
                var point = G.point(mx, my);
                if (point != null) {
                    var local = G.call("h2d.Object", "globalToLocal", G.field(panel, "obj"), [point]);
                    var target = local != null ? local : point;
                    x = G.number(G.field(target, "x")) + 18;
                    y = G.number(G.field(target, "y")) + 16;
                }
            }
        } catch (_:Dynamic) {}
        if (innerWidth > tipW && x + tipW > innerWidth - 8) x = x - tipW - 36;
        if (x < 8) x = 8;
        if (listBottom > tipH && y + tipH > listBottom) y = listBottom - tipH;
        if (y < 8) y = 8;
        return {x: x, y: y};
    }

    function hideTip():Void {
        hideNativeTip();
        hideCustomTip();
    }

    function hideCustomTip():Void {
        show(tipRoot, false);
        show(tipIcon, false);
        for (line in tipLines) show(line, false);
    }

    function tipText(hit:SearchHit):Array<String> {
        if (catalog == null || hit == null) return [];
        if (hit.kind == "item") {
            var item = catalog.item(hit.id);
            if (item == null) return [hit.title];
            var id = GameItems.idFor(item.name);
            var name = GameItems.displayName(id);
            if (name == "") name = item.name;
            var slot = GameItems.slotName(id);
            if (slot == "") slot = Catalog.prettySlot(item.subcategory);
            var lines = [name];
            var meta = slot;
            if (item.level != null) meta += (meta == "" ? "" : "    ") + "Level " + item.level;
            lines.push(meta);
            var shown = 0;
            for (stat in item.stats) {
                if (shown++ == 6) break;
                lines.push("<good>" + LiteralText.escape(stat.value + " " + stat.label) + "</good>");
            }
            if (item.classes.length > 0) lines.push("@" + item.classes.join(", "));
            else if (item.skills.length > 0) lines.push(item.skills[0].name + (item.skills[0].cooldown == null ? "" : "  " + item.skills[0].cooldown + "s"));
            return lines;
        }
        if (hit.kind == "creature") {
            var creature = catalog.creature(hit.id);
            if (creature == null) return [hit.title];
            var lines = [creature.name];
            var count = 0;
            for (link in creatureLinks(creature)) {
                if (count++ == 6) break;
                lines.push(link.label);
            }
            return lines;
        }
        return hit.subtitle == "" ? [hit.title] : [hit.title, hit.subtitle];
    }

    function placeDetail():Void {
        if (detailW <= 0) return;
        paintCard();
        var portrait = selected != null && selected.kind == "creature" && iconHolder != null && G.field(iconHolder, "visible") == true && tab != "map";
        var hasIcon = iconHolder != null && G.field(iconHolder, "visible") == true && tab != "map";
        if (hasIcon) position(iconHolder, detailX, detailTop);
        var textX = detailX + (portrait ? 84 : hasIcon ? 56 : 0);
        var titleWidth = detailW - (textX - detailX) - 160;
        position(detailTitle, textX, detailTop + (portrait ? 8 : hasIcon ? 8 : 0));
        G.call("ui.comp.FmtText", "set_maxWidthText", detailTitle, [Math.max(80, titleWidth)]);
        pin(mapButton.obj, detailX + detailW - 148, detailTop);
        var scaleY = detailTop + (portrait ? 86 : hasIcon ? 56 : 24);
        var pushed = placeScaleFilters(scaleY);
        var lineBase = portrait ? 86 : (hasIcon && pushed > 0 ? 56 : 28);
        var body = 0;
        var headerLines = portrait ? 2 : 0;
        for (line in detailLines) {
            if (G.field(line, "visible") != true) continue;
            var beside = portrait && body < headerLines;
            var x = beside ? textX : detailX;
            var y = beside ? detailTop + 30 + body * 18 : detailTop + lineBase + pushed + (body - headerLines) * 18;
            position(line, x, y);
            G.call("ui.comp.FmtText", "set_maxWidthText", line, [Math.max(80, detailW - (x - detailX) - 8)]);
            body++;
        }
        var top = detailTop + lineBase + pushed + Math.max(0, body - headerLines) * 18;
        position(dropHeading, detailX, top + 6);
        placeLootFilter(top);
        var listY = top + 32;
        position(G.field(dropList, "obj"), detailX, listY);
        var room = Math.max(52, detailBottom - listY);
        size(G.field(dropList, "obj"), Std.int(Math.max(80, detailW - 8)), Std.int(room));
        var fit = Std.int(Math.max(1, room / 58));
        var shown = 0;
        for (row in dropRows) {
            var want = row.open != null && shown < fit && tab != "map";
            if (want) shown++;
            show(row.obj, want);
        }
    }

    function resetScale():Void {
        scaleMode = maxLegendary ? "max" : "normal";
        scaleKey = "";
    }

    /** Highest max-level step, preferring Legendary. */
    function topStep(item:Null<ItemRecord>):Null<ScaleStep> {
        var steps = stepsFor(item, "max");
        if (steps.length == 0 || item == null) return null;
        var best = steps[0];
        for (step in steps) if (rarityRank(step.rarity) > rarityRank(best.rarity)) best = step;
        return best;
    }

    function rarityRank(rarity:String):Int {
        return switch (rarity) {
            case "Legendary": 5;
            case "Epic": 4;
            case "Rare": 3;
            case "Uncommon": 2;
            case "Common": 1;
            default: 0;
        };
    }

    function legendarySubtitle(hit:SearchHit):String {
        var item = catalog == null ? null : catalog.item(hit.id);
        var step = topStep(item);
        if (item == null || step == null) return hit.subtitle;
        var bits = [];
        if (item.subcategory != "") bits.push(Catalog.prettySlot(item.subcategory));
        if (step.rarity != "") bits.push(step.rarity);
        if (step.level != null) bits.push("Level " + step.level);
        return bits.length == 0 ? hit.subtitle : bits.join(" · ");
    }

    function selectedItem():Null<ItemRecord> {
        if (catalog == null || selected == null || selected.kind != "item") return null;
        return catalog.item(selected.id);
    }

    function scalesVisible():Bool {
        if (tab == "map") return false;
        var item = selectedItem();
        if (item == null) return false;
        return item.scales.length > 0 || item.category == "weapons" || item.category == "armor" || item.category == "jewellery";
    }

    function stepsFor(item:Null<ItemRecord>, mode:String):Array<ScaleStep> {
        var steps:Array<ScaleStep> = [];
        if (item == null) return steps;
        for (step in item.scales) if (step.mode == mode) steps.push(step);
        return steps;
    }

    function stepKey(step:Null<ScaleStep>):String {
        if (step == null) return "";
        return step.rarity + "|" + (step.level == null ? "" : "" + step.level);
    }

    function activeStep(item:Null<ItemRecord>):Null<ScaleStep> {
        var steps = stepsFor(item, scaleMode);
        if (steps.length == 0 || item == null) return null;
        if (scaleKey != "") for (step in steps) if (stepKey(step) == scaleKey) return step;
        if (maxLegendary && scaleMode == "max") {
            var best = steps[0];
            for (step in steps) if (rarityRank(step.rarity) > rarityRank(best.rarity)) best = step;
            return best;
        }
        var want = item.rarity.split(" / ")[0];
        for (step in steps) if (item.level != null && step.level == item.level && (want == "" || step.rarity == want)) return step;
        for (step in steps) if (item.level != null && step.level == item.level) return step;
        for (step in steps) if (want != "" && step.rarity == want) return step;
        return steps[0];
    }

    function stepChoices():Array<{key:String, label:String}> {
        var item = selectedItem();
        var steps = stepsFor(item, scaleMode);
        return [for (step in steps) {key: stepKey(step), label: stepLabel(step, steps)}];
    }

    function stepLabel(step:ScaleStep, steps:Array<ScaleStep>):String {
        var levels = 0;
        var rarities = 0;
        var seenLevel:Array<String> = [];
        var seenRarity:Array<String> = [];
        for (other in steps) {
            var level = other.level == null ? "" : "" + other.level;
            if (seenLevel.indexOf(level) < 0) { seenLevel.push(level); levels++; }
            if (seenRarity.indexOf(other.rarity) < 0) { seenRarity.push(other.rarity); rarities++; }
        }
        var levelText = step.level == null ? "" : "Level " + step.level;
        if (levels > 1 && rarities > 1) return levelText + " · " + step.rarity;
        if (rarities > 1) return step.rarity;
        if (levels > 1) return levelText;
        return step.rarity != "" ? step.rarity : levelText;
    }

    function scaleLabel(mode:String):String {
        return mode == "max" ? "Max level" : mode == "heroic" ? "Heroic" : "Normal";
    }

    /** Height added under the title when the scale controls are showing. */
    function placeScaleFilters(y:Float):Float {
        if (scaleDrop == null || stepDrop == null) return 0;
        var shown = scalesVisible();
        show(scaleDrop.header.obj, shown);
        if (!shown) {
            show(scaleDrop.menu, false);
            show(stepDrop.header.obj, false);
            show(stepDrop.menu, false);
            return 0;
        }
        var steps = stepsFor(selectedItem(), scaleMode);
        var gap = 8.0;
        var scaleW = 148.0;
        var stepW = Math.max(120, detailW - scaleW - gap);
        placeChoice(scaleDrop, detailX, y, scaleW);
        var stepShown = steps.length > 0;
        show(stepDrop.header.obj, stepShown);
        if (stepShown) placeChoice(stepDrop, detailX + scaleW + gap, y, stepW);
        else show(stepDrop.menu, false);
        return 36;
    }

    function placeChoice(drop:Dynamic, x:Float, y:Float, width:Float):Void {
        var open = openMenu == drop.id;
        setPlain(drop.header.title, headerText(drop.id));
        try G.set(drop.header.title, "maxWidth", width - 16) catch (_:Dynamic) {}
        paintFace(drop.header, width, 28, open ? 0xf7f4ef : 0xe6dfd6, 0x2f2924);
        pin(drop.header.obj, x, y);
        show(drop.menu, open);
        if (open && drop.raised != true) {
            drop.raised = true;
            var host = G.field(panel, "obj");
            G.call("h2d.Object", "addChild", host, [drop.menu]);
            if (tipRoot != null) G.call("h2d.Object", "addChild", host, [tipRoot]);
        }
        if (!open) drop.raised = false;
        if (open) placeMenu(drop, x, y + 32, width);
    }

    function placeLootFilter(top:Float):Void {
        if (lootDrop == null) return;
        var itemDrops = false;
        if (catalog != null && selected != null && tab != "map") {
            for (link in detailLinks()) if (link.kind == "item") { itemDrops = true; break; }
        }
        show(lootDrop.header.obj, itemDrops);
        if (!itemDrops) { show(lootDrop.menu, false); return; }
        var width = 132.0;
        var x = detailX + detailW - width;
        setPlain(lootDrop.header.title, headerText("loot"));
        try G.set(lootDrop.header.title, "maxWidth", width - 16) catch (_:Dynamic) {}
        var open = openMenu == "loot";
        paintFace(lootDrop.header, width, 28, open ? 0xf7f4ef : 0xe6dfd6, 0x2f2924);
        pin(lootDrop.header.obj, x, top + 2);
        show(lootDrop.menu, open);
        if (open) placeMenu(lootDrop, x - 36, top + 32, width);
    }

    function paintHeader(w:Int):Void {
        if (headerFill == null) return;
        G.call("h2d.Graphics", "clear", headerFill);
        G.call("h2d.Graphics", "beginFill", headerFill, [0x2f8eaa, 1.0]);
        G.call("h2d.Graphics", "drawRect", headerFill, [0, 0, w - 2, HEADER]);
        G.call("h2d.Graphics", "endFill", headerFill);
        position(headerFill, 0, 0);
        if (!headerRaised) {
            headerRaised = true;
            var parent = G.field(headerFill, "parent");
            if (parent != null) {
                G.call("h2d.Object", "addChild", parent, [headerFill]);
                for (control in tabs) G.call("h2d.Object", "addChild", parent, [control.obj]);
                if (close != null) G.call("h2d.Object", "addChild", parent, [close]);
            }
        }
    }

    function paintSlot(graphics:Dynamic, w:Float, h:Float):Void {
        if (graphics == null) return;
        G.call("h2d.Graphics", "clear", graphics);
        G.call("h2d.Graphics", "beginFill", graphics, [0x6ea4bf, 1.0]);
        G.call("h2d.Graphics", "drawRect", graphics, [0, 0, w, h]);
        G.call("h2d.Graphics", "endFill", graphics);
        G.call("h2d.Graphics", "beginFill", graphics, [0x2c4a5a, 1.0]);
        G.call("h2d.Graphics", "drawRect", graphics, [2, 2, w - 4, h - 4]);
        G.call("h2d.Graphics", "endFill", graphics);
    }

    function paintRowIcon(row:Dynamic, tile:Dynamic):Void {
        if (row == null) return;
        row.icon = mountIcon(row.icon, row.obj, tile, 32);
        var shown = row.icon != null && G.field(row.icon, "visible") == true;
        if (shown) position(row.icon, 8, 10);
        show(row.frame, shown);
    }

    function paintCard():Void {
        try drawCard() catch (error:Dynamic) Log.once("paintCard failed: " + Log.problem(error));
    }

    function drawCard():Void {
        show(detailCard, false);
    }
}
