package moresettings;

import haxe.ds.ObjectMap;
import moresettings.GameAccess as G;

private typedef MinionBar = { var nativeVisible:Bool; var hidden:Bool; var nextCheck:Float; }

/** Filter health/shield and lifetime bars in overhead summoned-unit widgets. */
class MinionHealthBars {
    static var enabled = false;
    static var bars:ObjectMap<Dynamic, MinionBar> = new ObjectMap();
    static var settingVisibility = false;
    static var reported = false;

    public static function configure(value:Bool):Void {
        enabled = value;
        for (bar in bars.keys()) refresh(bar, true);
    }

    public static function attachLifetime(bar:Dynamic):Void {
        // Temporary summons such as Almaz's imps use a standalone AttributeBar,
        // outside the HealthBar component, to display their remaining lifetime.
        if (G.text(G.field(bar, "atbId")) == "Lifetime") attach(bar);
    }

    public static function attach(bar:Dynamic):Void {
        if (bars.exists(bar)) bars.remove(bar); // Native init/rebuild clears binds.
        var unit = G.field(bar, "unit");
        if (!G.isA(unit, "ent.Foe")) return;
        var parent = G.field(bar, "parent");
        while (parent != null && !G.isA(parent, "ui.hud.FoeWidget")) parent = G.field(parent, "parent");
        if (parent == null) return; // Never hide boss panels, inspect UI or party bars.
        bars.set(bar, {nativeVisible: G.field(bar, "visible") == true, hidden: false, nextCheck: 0});
        // The widget remains active when its health bar is hidden, so ownership
        // or hostility changes can restore the bar without reopening settings.
        G.call("ui.UIElement", "bindUpdate", parent, [(_:Float) -> refresh(bar)]);
    }

    public static function friendlySummon(unit:Dynamic, hero:Dynamic):Bool {
        var owner = G.field(unit, "summonOwner");
        return unit != null && hero != null && G.isA(unit, "ent.Foe")
            && owner != null && owner != hero && G.field(unit, "removed") != true
            && G.field(unit, "layer") != null && G.field(unit, "layer") == G.field(hero, "layer")
            && G.call("ent.GameObject", "isEnemy", unit, [hero]) == false;
    }

    /** Called by the native visibility setter; remember its intended state. */
    public static function intercept(bar:Dynamic, visible:Bool):Bool {
        if (settingVisibility) return false;
        var value = bars.get(bar);
        if (value == null) return false;
        value.nativeVisible = visible;
        if (visible && value.hidden) { setVisible(bar, false); return true; }
        return false;
    }

    static function setVisible(bar:Dynamic, visible:Bool):Void {
        if (G.field(bar, "visible") == visible) return;
        settingVisibility = true;
        try G.call("ui.UIElement", "set_visible", bar, [visible]) catch (error:Dynamic) {
            settingVisibility = false;
            throw error;
        }
        settingVisibility = false;
    }

    static function refresh(bar:Dynamic, force = false):Void {
        var value = bars.get(bar);
        if (value == null || (!enabled && !value.hidden)) return;
        if (G.field(bar, "removed") == true) { bars.remove(bar); return; }
        var now = haxe.Timer.stamp();
        if (!force && now < value.nextCheck) return;
        value.nextCheck = now + 0.2;
        try {
            var hide = enabled && friendlySummon(G.field(bar, "unit"), G.staticCall("GameApp", "getMyHero", []));
            if (hide && !value.hidden) value.nativeVisible = G.field(bar, "visible") == true;
            if (hide || value.hidden) {
                value.hidden = hide;
                setVisible(bar, hide ? false : value.nativeVisible);
            }
        } catch (error:Dynamic) report(error);
    }

    public static function forget(bar:Dynamic):Void bars.remove(bar);
    public static function clear():Void {
        for (bar in bars.keys()) {
            var value = bars.get(bar);
            if (value.hidden) try setVisible(bar, value.nativeVisible) catch (_:Dynamic) {}
        }
        bars = new ObjectMap();
    }
    public static function report(error:Dynamic):Void {
        if (!reported) trace("[More Settings] Minion health bars: " + Std.string(error));
        reported = true;
    }
}
