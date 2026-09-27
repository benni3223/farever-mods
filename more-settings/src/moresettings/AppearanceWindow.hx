package moresettings;

import moresettings.GameAccess as G;
import moresettings.AppearanceUi.*;

/** A normal native window with its own render-to-texture scene and skin draft. */
class AppearanceWindow {
    static inline var WIDTH = 860;
    static inline var HEIGHT = 750;
    static inline var PANEL_X = 372;
    static inline var PANEL_W = 440;
    var ui:Dynamic;
    var draft:AppearanceDraft;
    var window:Dynamic;
    var root:Dynamic;
    var body:Dynamic;
    var container:Dynamic;
    var controls:Dynamic;
    var title:Dynamic;
    var headingStyle:Dynamic;
    var preview:Dynamic;
    var view:Dynamic;
    var baseHero:Dynamic;
    var models:Array<Dynamic>;
    var parts:Array<Dynamic>;
    var gradients:Array<Dynamic>;
    var colorPages:Map<String, Int> = [];
    var tab = "Body";
    var tabButtons:Map<String, Dynamic> = [];
    var status:Dynamic;
    var saveButton:Dynamic;
    var initialized = false;
    var ready = false;
    var refreshVisuals = false;
    var fitPreview = false;
    var rebuildControls = true;

    public function new() {}

    public function open(ui:Dynamic, draft:AppearanceDraft):Void {
        this.ui = ui;
        this.draft = draft;
        if (ui == null) throw "The appearance window is unavailable right now.";
        var unit = G.current("Data", "unit");
        baseHero = G.call("haxe.ds.StringMap", "get", G.field(unit, "byId"), ["BaseHero"]);
        models = G.array(G.field(baseHero, "models"));
        if (models.length < 3) throw "Character customization models are unavailable.";
        parts = G.array(G.field(G.current("Data", "bodyPart"), "all"));
        gradients = G.array(G.field(G.current("Data", "gradient"), "all"));
        window = G.create("ui.win.TitleWindow", ["Options", null]);
        var flags = 0;
        for (name in ["PreventCloseOther", "FreeCursor", "AutoRegisterLayer", "BlockInputs", "BlockSkills", "NeedLayer"])
            flags |= 1 << Type.enumIndex(G.enumeration("ui.win.WindowFlags", name));
        G.call("ui.win.BaseWindow", "set_windowFlags", window, [flags]);
        G.call("ui.win.BaseWindow", "rebuild", window);
        root = G.field(ui, "root");
        G.call("h2d.Flow", "addChildAt", root, [window, G.call("h2d.Object", "get_numChildren", root)]);
        G.call("ui.BaseUI", "displayWindow", ui, [window, null]);
        absolute(root, window); padding(window, 0); size(window, WIDTH, HEIGHT);
        for (child in children(window)) if (G.field(child, "bgMask") != null) {
            absolute(window, child); padding(child, 0); size(child, WIDTH, HEIGHT); position(child, 0, 0);
        }
        var dom = G.field(window, "dom");
        G.set(dom, "component", G.staticCall("domkit.Component", "get", ["options-window", null]));
        var content = G.field(dom, "contentRoot");
        if (content == null) throw "The appearance window could not be initialized.";
        var header = G.field(window, "header");
        padding(header, 0); absolute(window, header); size(header, WIDTH - 2, 60); position(header, 0, 0);
        show(G.field(header, "headerTitle"), false);
        var close = G.field(header, "closeBtn");
        show(close, true); absolute(header, close); size(close, 36, 36); position(close, WIDTH - 52, 12);
        G.call("ui.UIElement", "set_onClick", close, [dispose]);
        padding(content, 0); absolute(window, content); size(content, WIDTH - 16, HEIGHT - 68); position(content, 8, 60);
        body = node("options-content", dom, [0], "moreSettingsAppearanceBody");
        var bodyObject = G.field(body, "obj");
        container = prepareBody(body);
        var options = G.field(bodyObject, "optionsList");
        for (object in [bodyObject, options, container]) {
            padding(object, 0); size(object, WIDTH - 16, HEIGHT - 68);
            var limit = G.enumeration("h2d.FlowOverflow", "Limit");
            G.call("h2d.Flow", "set_overflow", object, [limit]); style(object, "overflow", limit);
        }
        absolute(content, bodyObject); position(bodyObject, 0, 0);
        absolute(bodyObject, options); position(options, 0, 0);
        absolute(options, container); position(container, 0, 0);
        var parent = G.field(container, "dom");
        headingStyle = label(parent, "");
        G.call("domkit.Properties", "addClass", G.field(headingStyle, "dom"), ["bold-14"]);
        show(headingStyle, false);
        title = G.create("h2d.Text", [G.field(headingStyle, "font"), header]);
        absolute(header, title);
        G.call("h2d.Text", "set_text", title, ["Change Appearance"]);
        G.call("h2d.Text", "set_textColor", title, [0x8A5F46]);
        G.call("h2d.Text", "set_lineBreak", title, [false]);

        // No game object is passed: even the animation player and gear are private.
        preview = G.field(node("unit-scene", parent, [null, baseHero], "moreSettingsAppearancePreview"), "obj");
        absolute(container, preview); padding(preview, 0); size(preview, 340, 560); position(preview, 12, 14);
        G.set(preview, "autoFit", true); style(preview, "auto-fit", true);
        G.set(preview, "viewPadding", 0.12); style(preview, "view-padding", 0.12);
        var scene = G.field(preview, "unitScene");
        absolute(preview, scene); padding(scene, 0); size(scene, 340, 560); position(scene, 0, 0);
        textAt(container, "Drag the preview to rotate", 48, 580, 288);
        textAt(container, "Changes apply only when you Save.", 30, 612, 322);
        var names = ["Body", "Face", "Hair"];
        for (i in 0...names.length) {
            var name = names[i];
            var button = buttonAt(container, name, PANEL_X + i * 148, 16, 140, () -> {
                tab = name; rebuildControls = true;
            });
            tabButtons[name] = button;
        }
        controls = G.field(node("flow", parent, [], "moreSettingsAppearanceControls"), "obj");
        absolute(container, controls); padding(controls, 0); size(controls, PANEL_W, 526); position(controls, PANEL_X, 70);
        status = textAt(container, "Loading character preview...", PANEL_X, 590, PANEL_W);
        buttonAt(container, "Cancel", PANEL_X + 140, 632, 140, dispose, false);
        saveButton = buttonAt(container, "Save", PANEL_X + 292, 632, 148, save);
    }

    function usable():Bool {
        return ready && window != null && G.field(window, "parent") != null && G.field(window, "allocated") == true
            && draft != null && draft.valid(currentHero()) && G.current("ui.BaseUI", "current") == ui;
    }

    function currentHero():Dynamic {
        var controller = G.current("client.PlayerController", "inst");
        return controller == null ? null : G.call("client.PlayerController", "get_hero", controller);
    }

    function guard(action:Void->Void):Void {
        if (!usable()) return;
        try action() catch (error:Dynamic) {
            ready = false;
            setText(status, "Could not update the preview. Close this window and try again.");
            AppearanceEditor.report(error);
        }
    }

    function buttonAt(parent:Dynamic, text:String, x:Int, y:Int, w:Int, action:Void->Void, edit = true):Dynamic {
        var object = G.field(node("button", G.field(parent, "dom"), [text], "moreSettingsAppearanceButton"), "obj");
        absolute(parent, object); padding(object, 0); size(object, w, 36); position(object, x, y);
        G.call("ui.UIElement", "set_onClick", object, [edit ? () -> guard(action) : action]);
        if (edit) G.call("ui.UIElement", "set_checkEnable", object, [usable]);
        return object;
    }

    function textAt(parent:Dynamic, text:String, x:Int, y:Int, w:Int):Dynamic {
        var object = label(G.field(parent, "dom"), text);
        absolute(parent, object); position(object, x, y);
        G.call("ui.comp.FmtText", "set_maxWidthText", object, [w]);
        return object;
    }

    function changed(model = false):Void {
        ready = false;
        if (model) {
            var index = G.integer(G.field(draft.skin, "template"));
            G.call("client.UnitView", "applyModelInfo", view, [models[index]]);
        }
        refreshVisuals = true;
        rebuildControls = true;
    }

    function cycle(title:String, choices:Array<Dynamic>, selected:Int, y:Int, choose:Dynamic->Void):Void {
        textAt(controls, title, 0, y, PANEL_W);
        textAt(controls, choices.length == 0 ? "Unavailable" : selected < 0 ? "Current" : (selected + 1) + " / " + choices.length,
            176, y + 27, 180);
        if (choices.length == 0) return;
        var pick = (direction:Int) -> {
            var next = selected < 0 ? (direction > 0 ? 0 : choices.length - 1)
                : (selected + direction + choices.length) % choices.length;
            choose(choices[next]);
        };
        buttonAt(controls, "<", 0, y + 22, 56, () -> pick(-1));
        buttonAt(controls, ">", PANEL_W - 56, y + 22, 56, () -> pick(1));
    }

    function part(title:String, field:String, type:Int, y:Int):Void {
        var choices = AppearanceDraft.parts(parts, type);
        var current = G.text(G.field(draft.skin, field));
        var selected = -1;
        for (i in 0...choices.length) if (G.text(G.field(choices[i], "id")) == current) selected = i;
        cycle(title, choices, selected, y, value -> {
            G.set(draft.skin, field, G.field(value, "id"));
            changed();
        });
    }

    function shape(category:String, y:Int):Void {
        var choices:Array<Dynamic> = [null];
        var selected = 0;
        for (value in G.array(G.call("client.UnitView", "getBlendShapes", view))) {
            if (G.call("client.UnitView", "blendShapeHasCategory", view, [value, category]) != true) continue;
            choices.push(value);
            if (G.call("client.UnitView", "isBlendShapeActive", view, [value]) == true) selected = choices.length - 1;
        }
        cycle(category, choices, selected, y, value -> {
            if (value != null) G.call("client.UnitView", "toggleBlendShape", view, [value, 1.0]);
            else if (G.field(draft.skin, "shapes") != null) G.call("client.UnitView", "removeBlendShape", view, [category]);
            changed();
        });
    }

    function palette(title:String, field:String, mask:Int, y:Int):Void {
        var choices = AppearanceDraft.colors(gradients, mask);
        textAt(controls, title, 0, y, PANEL_W);
        var selected = -1;
        for (i in 0...choices.length) if (G.field(choices[i], "id") == G.field(draft.skin, field)) selected = i;
        var pages = Math.ceil(choices.length / 20);
        var page = colorPages.exists(field) ? colorPages[field] : Std.int(Math.max(0, selected) / 20);
        page = Std.int(Math.max(0, Math.min(pages - 1, page)));
        for (i in page * 20...Std.int(Math.min(choices.length, (page + 1) * 20))) {
            var choice = choices[i];
            var swatch = G.field(node("button", G.field(controls, "dom"), [""], "moreSettingsAppearanceColor"), "obj");
            absolute(controls, swatch); padding(swatch, 0); size(swatch, 34, 34);
            position(swatch, ((i - page * 20) % 10) * 43, y + 25 + Std.int((i - page * 20) / 10) * 40);
            AppearanceSwatches.paint(swatch, choice, i == selected);
            G.call("ui.UIElement", "set_selected", swatch, [i == selected]);
            G.call("ui.UIElement", "set_checkEnable", swatch, [usable]);
            G.call("ui.UIElement", "set_onClick", swatch, [() -> guard(() -> {
                G.set(draft.skin, field, G.field(choice, "id"));
                if (field == "hairColor") G.set(draft.skin, "hairColorSecondary", G.field(choice, "id"));
                colorPages[field] = page;
                changed();
            })]);
        }
        if (pages > 1) {
            textAt(controls, (page + 1) + " / " + pages, 190, y + 110, 100);
            buttonAt(controls, "<", 0, y + 104, 56, () -> { colorPages[field] = (page + pages - 1) % pages; rebuildControls = true; });
            buttonAt(controls, ">", PANEL_W - 56, y + 104, 56, () -> { colorPages[field] = (page + 1) % pages; rebuildControls = true; });
        }
    }

    function buildControls():Void {
        for (child in children(controls)) G.call("h2d.Object", "remove", child);
        for (name => button in tabButtons) G.call("ui.UIElement", "set_selected", button, [name == tab]);
        switch tab {
            case "Body":
                // CharacterCreationScreen.getTemplateValues uses these three entries.
                cycle("Body type", [0, 1, 2], G.integer(G.field(draft.skin, "template"), -1), 0, value -> {
                    G.set(draft.skin, "template", value); changed(true);
                });
                palette("Skin color", "skinColor", 4, 90);
            case "Face":
                palette("Eye color", "eyeColor", 2, 0);
                part("Eyebrows", "eyebrows", 2, 150);
                var categories = ["Eyes", "Face", "Nose", "Lips"];
                for (i in 0...categories.length) shape(categories[i], 222 + i * 72);
            case "Hair":
                part("Hair", "hair", 0, 0);
                part("Facial hair", "facialHair", 3, 80);
                palette("Hair color", "hairColor", 1, 172);
        }
        rebuildControls = false;
    }

    public function update(currentUI:Dynamic, hero:Dynamic):Bool {
        if (window == null || ui != currentUI || !draft.valid(hero) || G.field(window, "removed") == true
            || G.field(window, "parent") == null || G.field(window, "allocated") != true || !bodyIntact(body, container)) return false;
        fitWindow();
        view = G.field(preview, "unitView");
        if (view == null || G.call("client.UnitView", "isReady", view) != true) return true;
        if (!initialized) {
            G.set(view, "overrideSkinData", draft.skin);
            var model = G.integer(G.field(draft.skin, "template"));
            if (model < 0 || model >= models.length) throw "This character's body type is unavailable.";
            G.call("client.UnitView", "applyModelInfo", view, [models[model]]);
            initialized = true; refreshVisuals = true;
            return true;
        }
        if (refreshVisuals) {
            G.call("client.UnitView", "updateDynamicVisuals", view, [null]);
            refreshVisuals = false; fitPreview = true;
            return true;
        }
        if (fitPreview) {
            // Recompute bounds after body/part changes, then use the scene's
            // own camera fitting and independent idle animation.
            var rotation = G.call("h3d.scene.Object", "getRotationQuat", view);
            var postInit:Void->Void = G.field(preview, "postInitUnitView");
            postInit();
            // Live's post-init adds viewAngle again; keep the user's rotation.
            G.call("h3d.scene.Object", "setRotationQuat", view, [rotation]);
            fitPreview = false; ready = true;
            setText(status, "");
        }
        if (ready && rebuildControls) buildControls();
        return true;
    }

    function fitWindow():Void {
        var scene = G.field(ui, "s2d");
        var top = point(0, 0), bottom = point(G.number(G.field(scene, "width")), G.number(G.field(scene, "height")));
        var scale = Math.max(0.1, Math.min(1, Math.min((bottom.x - top.x - 32) / WIDTH, (bottom.y - top.y - 32) / HEIGHT)));
        G.call("h2d.Object", "setScale", window, [scale]);
        position(window, top.x + (bottom.x - top.x - WIDTH * scale) / 2, top.y + (bottom.y - top.y - HEIGHT * scale) / 2);
        G.call("ui.comp.FmtText", "updateScale", headingStyle);
        var font = G.field(headingStyle, "font");
        if (font != null && font != G.field(title, "font")) G.call("h2d.Text", "set_font", title, [font]);
        var titleScale = G.number(G.field(headingStyle, "scaleX"), 1) * 1.75;
        G.call("h2d.Object", "setScale", title, [titleScale]);
        position(title, 24, (60 - G.number(G.call("h2d.Text", "get_textHeight", title)) * titleScale) / 2);
    }

    function point(x:Float, y:Float):{x:Float, y:Float} {
        var p = HlxRuntime.allocInstance(HlxRuntime.resolveType("h2d.col.PointImpl"));
        G.set(p, "x", x); G.set(p, "y", y);
        var result = G.call("h2d.Object", "globalToLocal", root, [p]);
        return {x: G.number(G.field(result, "x")), y: G.number(G.field(result, "y"))};
    }

    function save():Void {
        // Commit errors leave the draft open; after commit, a preview refresh
        // error must never claim that the replicated change was cancelled.
        try draft.commit(currentHero()) catch (error:Dynamic) { AppearanceEditor.report(error); return; }
        var hero = draft.hero;
        dispose();
        try {
            AppearanceDraft.refreshHero(hero);
        } catch (error:Dynamic) AppearanceEditor.report("Appearance saved, but the character model could not refresh: " + Std.string(error));
    }

    public function dispose():Void {
        ready = false;
        var old = window; window = null;
        if (old != null && ui != null) G.call("ui.BaseUI", "removeWindow", ui, [old]);
        // UnitScene.onRemove disposes its render texture and scene through the
        // native window lifecycle. No restoration of the live hero is needed.
        preview = null; view = null; draft = null; controls = null; container = null; body = null;
        title = null; headingStyle = null; status = null; saveButton = null; root = null; ui = null;
        parts = []; gradients = []; models = []; baseHero = null; tabButtons = []; colorPages = [];
    }
}
