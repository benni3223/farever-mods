package moresettings;

import moresettings.GameAccess as G;

/** Opens on the next frame, outside Better Mod Settings' action dispatch. */
class AppearanceEditor {
    static var requested = false;
    static var popup:AppearanceWindow;

    public static function request():Void requested = true;

    public static function update(app:Dynamic):Void {
        if (!requested && popup == null) return;
        try {
            var ui = G.current("ui.BaseUI", "current");
            var hero = G.field(app, "hero");
            if (requested) {
                requested = false;
                if (popup != null && popup.update(ui, hero)) return;
                close();
                var draft = new AppearanceDraft(hero);
                popup = new AppearanceWindow();
                popup.open(ui, draft);
            }
            if (popup != null && !popup.update(ui, hero)) close();
        } catch (error:Dynamic) {
            close();
            report(error);
        }
    }

    public static function report(error:Dynamic):Void {
        trace("[More Settings] Appearance: " + Std.string(error));
        try {
            var ui = G.current("ui.BaseUI", "current");
            if (ui == null) return;
            AppearanceUi.message(ui, "Change Appearance", Std.string(error));
        } catch (_:Dynamic) {}
    }

    public static function close():Void {
        requested = false;
        var old = popup; popup = null;
        if (old != null) old.dispose();
    }
}
