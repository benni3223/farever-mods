package lootdb;

import hlx.runtime.Bus;
import hlx.runtime.ModConfig;
import modconfig.ConfigMigration;
import hlx.runtime.HlxPrefixResult;
import lootdb.GameAccess as G;
import lootdb.NativeUi;

typedef LootSettings = {
    var enabled:Bool;
    var hotkey:Int;
    var anchorRight:Bool;
    var buttonX:Float;
    var buttonY:Float;
};

@:build(hlx.runtime.Mod.build())
class LootDbMod {
    static inline var BUTTON_W = 34;
    static inline var BUTTON_H = 30;
    @:hlx.config
    static var config:LootSettings = {enabled: true, hotkey: 0, anchorRight: true, buttonX: 16, buttonY: 72};
    static var view:LootWindow;
    static var hud:Dynamic;
    static var hudOwner:Dynamic;

    static function main():Void {
        if (ConfigMigration.importLegacy()) reload();
        try config.save() catch (_:Dynamic) {}
        view = new LootWindow();
        Bus.subscribe("better-mod-settings/config-changed/" + HlxRuntime.moduleName(), (_:Dynamic) -> reload());
    }

    static function reload():Void {
        var loaded = ModConfig.load(HlxRuntime.moduleName(), config);
        for (key in Reflect.fields(loaded)) Reflect.setField(config, key, Reflect.field(loaded, key));
        placeHud();
    }

    @:hlx.prefix(ui.win.BaseWindow.autoDisplay)
    static function suppressAutoDisplay(instance:Dynamic):HlxPrefixResult<Void> {
        return LootWindow.constructing ? Skip : Continue;
    }

    @:hlx.prefix(ui.BaseUI.closeFirstClosableUI)
    static function closeOnEscape(instance:Dynamic, onlyEscapeClosable:Null<Bool>):HlxPrefixResult<Bool> {
        return view != null && view.closeFromEscape(instance) ? SkipWith(true) : Continue;
    }

    @:hlx.postfix(GameApp.update)
    static function update(instance:Dynamic, dt:Float, result:Void):Void {
        if (view == null) return;
        var now = haxe.Timer.stamp();
        var hero = G.field(instance, "hero");
        try {
            if (config.hotkey > 0 && G.staticCall("hxd.Key", "isPressed", [config.hotkey]) == true) {
                var ui = G.current("ui.BaseUI", "current");
                var typing = view.searchFocused || (ui != null && G.call("ui.BaseUI", "getFocusedTextInput", ui) != null);
                if (!typing) view.toggle();
            }
            if (config.enabled && hero != null) ensureHud(G.current("ui.BaseUI", "current"));
            else removeHud();
        } catch (_:Dynamic) {}
        try view.update(instance, config.enabled && hero != null, now) catch (e:Dynamic) {
            Log.write("update failed: " + Log.problem(e));
            view.dispose();
        }
    }

    static function ensureHud(ui:Dynamic):Void {
        if (ui == null) return;
        if (hud != null && hudOwner == ui && G.field(hud, "removed") != true) {
            placeHud();
            return;
        }
        removeHud();
        var root = G.field(ui, "root");
        var dom = G.field(root, "dom");
        if (dom == null) return;
        hud = NativeUi.chestButton(dom, () -> view.toggle());
        NativeUi.absolute(root, hud);
        hudOwner = ui;
        placeHud();
    }

    /** Flow reflow places an absolute child from its offsets, so slider and anchor changes must rewrite them. */
    static function placeHud():Void {
        if (hud == null || hudOwner == null) return;
        var root = G.field(hudOwner, "root");
        if (root == null) return;
        var insetX = Math.max(0, config.buttonX);
        var y = Math.max(0, config.buttonY);
        var x = insetX;
        if (config.anchorRight) {
            var width = G.number(G.call("h2d.Flow", "get_innerWidth", root));
            if (width <= 0) width = G.number(G.field(root, "innerWidth"));
            if (width <= 0) width = G.number(G.field(G.field(hudOwner, "s2d"), "width"), 1920);
            x = Math.max(0, width - BUTTON_W - insetX);
        }
        var properties = G.call("h2d.Flow", "getProperties", root, [hud]);
        if (properties != null) {
            G.call("h2d.FlowProperties", "set_isAbsolute", properties, [true]);
            G.set(properties, "offsetX", x);
            G.set(properties, "offsetY", y);
        }
        var dom = G.field(hud, "dom");
        if (dom != null) {
            G.call("domkit.Properties", "initStyle", dom, ["position", true]);
            G.call("domkit.Properties", "initStyle", dom, ["offset-x", x]);
            G.call("domkit.Properties", "initStyle", dom, ["offset-y", y]);
        }
        NativeUi.position(hud, x, y);
    }

    static function removeHud():Void {
        if (hud != null) G.call("h2d.Object", "remove", hud);
        hud = null; hudOwner = null;
    }
}
