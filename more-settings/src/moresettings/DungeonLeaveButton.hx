package moresettings;

import moresettings.GameAccess as G;

/** Adjust only the existing dungeon HUD button; keep its native leave action. */
class DungeonLeaveButton {
    public static var enabled:Bool = true;
    static var hud:Dynamic;
    static var button:Dynamic;
    static var reportedError:Bool = false;

    public static function attach(instance:Dynamic):Void {
        hud = instance;
        button = G.field(instance, "leaveBtn");
        // init's native bindUpdate has already run once. Apply to that initial
        // state too; subsequent updates use the game's existing callback.
        if (button != null)
            G.call("ui.UIElement", "set_visible", button, [G.field(button, "visible") == true]);
    }

    public static function visibility(instance:Dynamic, nativeValue:Bool):Bool {
        // This hook also sees other UI elements; reject those without reflection.
        if (!enabled || button == null || instance != button) return nativeValue;
        if (G.field(hud, "removed") == true) return nativeValue;
        var player = G.call("ui.BaseElement", "get_myPlayer", hud);
        var layer = G.field(player, "layer");
        if (!G.isA(G.field(layer, "mainActivity"), "st.activity.Dungeon")) return nativeValue;
        // Only a confirmed out-of-combat hero can show the override. Loading
        // and missing heroes must not expose a stale leave button.
        return G.field(G.field(player, "hero"), "isInCombat") == false;
    }

    public static function clear():Void {
        hud = null;
        button = null;
    }

    public static function reportError(error:Dynamic):Void {
        if (reportedError) return;
        reportedError = true;
        trace("[More Settings] Leave dungeon button: " + Std.string(error));
    }
}
