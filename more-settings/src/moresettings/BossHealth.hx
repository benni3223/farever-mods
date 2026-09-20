package moresettings;

import moresettings.GameAccess as G;

/** Adds current HP to the boss HUD's native percentage label. */
class BossHealth {
    public static var enabled:Bool = false;
    static var reportedError:Bool = false;
    static var percentage = ~/^([0-9]+(?:[.,][0-9]+)?\s*%)(.*)$/;

    public static function attach(bar:Dynamic):Void {
        var parent = G.field(bar, "parent");
        while (parent != null && !G.isA(parent, "ui.hud.BossInfo")) parent = G.field(parent, "parent");
        if (parent == null) return;

        // HealthBar.init already bound its native label callback. Both clients
        // run these in insertion order, so decorate the freshly written text.
        // Bind even while disabled: toggling during a fight needs no UI rebuild.
        // The callback belongs to the bar and is cleared by its native lifecycle.
        var refresh = (_:Float) -> {
            try update(bar) catch (e:Dynamic) reportError(e);
        };
        G.call("ui.UIElement", "bindUpdate", bar, [refresh]);
    }

    static function update(bar:Dynamic):Void {
        if (!enabled) return;
        var label = G.field(bar, "txt");
        var gauge = G.field(bar, "healthGauge");
        if (label == null || G.field(label, "visible") != true || G.field(gauge, "usePercents") != true) return;
        var original = G.text(G.field(label, "text"));
        // value is the real Health attribute, not HP inferred from a rounded %.
        var value = G.number(G.field(gauge, "value"), Math.NaN);
        var text = format(original, value);
        if (text != original) G.call("ui.comp.FmtText", "set_text", label, [text]);
    }

    public static function format(original:String, health:Float):String {
        // Keep native percentages/localization and any shield suffix. A numeric
        // label (e.g. PTR's show-resources option) already exposes HP; leave it.
        if (!Math.isFinite(health) || !percentage.match(original)) return original;
        // Match native whole-HP rounding without overflowing a signed 32-bit Int.
        var hp = Std.string(Math.ffloor(Math.max(0, health)));
        var end = hp.length;
        while (end > 3) {
            end -= 3;
            hp = hp.substr(0, end) + "," + hp.substr(end);
        }
        return hp + " (" + percentage.matched(1) + ")" + percentage.matched(2);
    }

    public static function reportError(error:Dynamic):Void {
        if (!reportedError) {
            reportedError = true;
            trace("[More Settings] Boss health: " + Std.string(error));
        }
    }
}
