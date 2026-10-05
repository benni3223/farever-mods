package moresettings;

import haxe.ds.ObjectMap;
import moresettings.GameAccess as G;
import moresettings.AppearanceUi as Ui;

private typedef BarberEntry = { var button:Dynamic; var parent:Dynamic; var helmet:Dynamic; }

/** Native button on the character appearance page; no overlay/plugin dependency. */
class BarbershopButton {
    static inline var WIDTH = 140;
    static inline var HEIGHT = 34;
    static var entries:ObjectMap<Dynamic, BarberEntry> = new ObjectMap();

    public static function attach(page:Dynamic):Void {
        var previous = entries.get(page);
        if (previous != null && G.field(previous.button, "parent") != null)
            G.call("h2d.Object", "remove", previous.button);
        entries.remove(page);
        var hero = G.staticCall("GameApp", "getMyHero", []);
        if (hero == null || G.field(page, "unit") != hero) return;
        var parent = G.field(G.field(page, "scene"), "parent");
        var helmet:Dynamic = null;
        for (slot in G.array(G.field(page, "buttons")))
            if (G.text(G.field(slot, "slot")) == "Slot_Head") { helmet = slot; break; }
        if (parent == null || helmet == null) throw "Character appearance layout is unavailable";
        var button = G.field(Ui.node("button", G.field(parent, "dom"), ["Barbershop"], "moreSettingsBarbershop"), "obj");
        Ui.absolute(parent, button);
        Ui.size(button, WIDTH, HEIGHT);
        Ui.show(button, false); // Wait for the native slot layout before positioning.
        var entry:BarberEntry = {button: button, parent: parent, helmet: helmet};
        entries.set(page, entry);
        G.call("ui.UIElement", "set_onClick", button, [() -> {
            if (entries.get(page) == entry && G.field(page, "unit") == G.staticCall("GameApp", "getMyHero", []))
                AppearanceEditor.request();
        }]);
        G.call("ui.UIElement", "bindUpdate", page, [(_:Float) -> {
            if (entries.get(page) == entry) try layout(page, entry) catch (error:Dynamic) {
                entries.remove(page);
                Ui.show(button, false);
                AppearanceEditor.report(error);
            }
        }]);
    }

    static function layout(page:Dynamic, entry:BarberEntry):Void {
        var local = G.field(page, "unit") == G.staticCall("GameApp", "getMyHero", []);
        if (!local || G.field(page, "removed") == true || G.field(entry.helmet, "parent") == null) {
            Ui.show(entry.button, false);
            return;
        }
        // Bounds are in this native panel's coordinates, so UI scale and moving
        // the character window do not change the anchor or require screen pixels.
        var bounds = G.call("h2d.Object", "getBounds", entry.helmet, [entry.parent, null]);
        var left = G.number(G.field(bounds, "xMin"));
        var right = G.number(G.field(bounds, "xMax"));
        var top = G.number(G.field(bounds, "yMin"));
        if (right <= left || top < HEIGHT + 16) {
            if (G.field(entry.button, "visible") == true) Ui.show(entry.button, false);
            return;
        }
        var x = Math.max(12, (left + right - WIDTH) / 2);
        var y = Math.max(12, top - HEIGHT - 24);
        if (G.field(entry.button, "x") != x || G.field(entry.button, "y") != y) Ui.position(entry.button, x, y);
        if (G.field(entry.button, "visible") != true) Ui.show(entry.button, true);
    }

    public static function forget(page:Dynamic):Void entries.remove(page);
    public static function clear():Void entries = new ObjectMap();
}
