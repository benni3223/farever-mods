package moresettings;

import moresettings.GameAccess as G;
import moresettings.AppearanceUi.*;

/** Creation-screen thumbnails, rendered with a separate skin and UnitView. */
class AppearancePortraits {
    var view:Dynamic;
    var skin:Dynamic;
    var emptyShapes:Dynamic;
    var resource:Dynamic;
    var buttons:Array<Dynamic> = [];
    var pending:Array<{button:Dynamic, size:Int, hideHair:Bool, hideBeard:Bool}> = [];

    public function new(ui:Dynamic, source:Dynamic, model:Dynamic) {
        emptyShapes = G.call("hl.types.ArrayObj", "slice", G.field(ui, "windows"), [0, 0]);
        skin = AppearanceDraft.copy(source);
        view = G.create("client.UnitView", [null, 0.0, false]);
        G.call("client.UnitView", "setUnit", view, [null, model, skin, null, 1.0]);
        var file = G.staticCall("hxd.Res", "load", ["Items/MenuPortraitScene.prefab"]);
        resource = G.call("hxd.res.Any", "toPrefab", file);
    }

    public function add(parent:Dynamic, component:String, value:Dynamic, x:Int, y:Int, width:Int,
            selected:Bool, enabled:Void->Bool, pick:Void->Void):Void {
        var button = G.field(node(component, G.field(parent, "dom"), [value, view, null, null],
            "moreSettingsAppearancePortrait"), "obj");
        buttons.push(button);
        absolute(parent, button); padding(button, 0); size(button, width, width); position(button, x, y);
        var icon = G.field(button, "icon");
        var iconRoot = G.field(icon, "parent");
        absolute(button, iconRoot); padding(iconRoot, 0); size(iconRoot, width - 8, width - 8); position(iconRoot, 4, 4);
        absolute(iconRoot, icon); position(icon, 0, 0);
        // This is a DOMKit Bitmap, whose width/height styles run again on
        // initial layout, hover and selection. A one-off Bitmap setter is
        // overwritten by those styles (including the first thumbnail's delayed
        // initial layout). Pin the dimensions in the style system as well.
        style(icon, "width", 1.0 * (width - 8));
        style(icon, "height", 1.0 * (width - 8));
        G.call("ui.UIElement", "set_selected", button, [selected]);
        G.call("ui.UIElement", "set_checkEnable", button, [enabled]);
        G.call("ui.UIElement", "set_onClick", button, [pick]);
        var shape = component == "blend-shape-pick-button";
        var partType = component == "body-part-pick-button" ? G.integer(G.field(value, "type"), -1) : -1;
        pending.push({button: button, size: width - 8, hideHair: shape || partType == 2 || partType == 3, hideBeard: shape});
    }

    public function prepare(source:Dynamic, model:Dynamic):Void {
        clear();
        G.staticCall("data.UnitSkinData", "copySkinData", [source, skin]);
        G.call("client.UnitView", "setUnit", view, [null, model, skin, null, 1.0]);
    }

    public function update(source:Dynamic):Void {
        if (pending.length == 0 || G.call("client.UnitView", "isReady", view) != true) return;
        // Native shape buttons temporarily change shapes, and their restoration
        // of a default shape is incomplete. Reset our private copy before EACH
        // thumbnail, never letting those temporary choices touch the draft.
        G.staticCall("data.UnitSkinData", "copySkinData", [source, skin]);
        if (G.field(skin, "shapes") == null)
            G.set(skin, "shapes", G.call("hl.types.ArrayObj", "slice", emptyShapes, [0, 0]));
        var next = pending.shift();
        if (next.hideHair) G.set(skin, "hair", null);
        if (next.hideBeard) G.set(skin, "facialHair", null);
        var previousScene = G.current("gfx.PortraitGen", "scene");
        var previousPrefab = G.current("gfx.PortraitGen", "prefab");
        var error:Dynamic = null;
        try {
            G.staticCall("gfx.PortraitGen", "initRenderContext", [resource]);
            var scene = G.staticCall("gfx.PortraitGen", "get_renderScene", []);
            G.call("h3d.scene.Object", "addChild", scene, [view]);
            // Same GPU render-to-texture path as character creation. No
            // Texture.capturePixels, staging buffers or direct driver calls.
            G.call("ui.comp.BodyPreviewButton", "refreshPortrait", next.button);
            var icon = G.field(next.button, "icon");
            G.call("h2d.Bitmap", "set_width", icon, [1.0 * next.size]);
            G.call("h2d.Bitmap", "set_height", icon, [1.0 * next.size]);
        } catch (e:Dynamic) error = e;
        try {
            G.call("h3d.scene.Object", "remove", view);
            if (G.current("gfx.PortraitGen", "scene") != previousScene)
                G.staticCall("gfx.PortraitGen", "clearRenderContext", []);
        } catch (e:Dynamic) { if (error == null) error = e; }
        G.setCurrent("gfx.PortraitGen", "scene", previousScene);
        G.setCurrent("gfx.PortraitGen", "prefab", previousPrefab);
        if (error != null) throw error;
    }

    public function clear():Void {
        pending = [];
        for (button in buttons) {
            // BodyPreviewButton owns its texture but does not dispose it on
            // removal. Drop the reallocation closure as well as the GPU texture.
            var texture = G.field(button, "tex");
            if (texture != null) {
                G.set(texture, "realloc", null);
                G.call("h3d.mat.Texture", "dispose", texture);
                G.set(button, "tex", null);
            }
        }
        buttons = [];
    }

    public function dispose():Void {
        clear();
        if (view != null) G.call("h3d.scene.Object", "remove", view);
        view = null; skin = null; emptyShapes = null; resource = null;
    }
}
