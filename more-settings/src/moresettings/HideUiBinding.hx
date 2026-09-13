package moresettings;

import moresettings.GameAccess as G;

/** Replaces only ToggleUI's temporary keyboard bindings, inside native input checks. */
class HideUiBinding {
    var keyCode:Int = 113;
    var cached:Array<{source:Dynamic, mode:Dynamic, replacement:Dynamic}> = [];

    public function new() {}

    public function configure(keyCode:Int):Void {
        if (this.keyCode == keyCode) return;
        this.keyCode = keyCode;
        cached = [];
    }

    public function bindings(action:String, result:Dynamic):Dynamic {
        if (action != "ToggleUI" || result == null) return result;
        var length = G.integer(G.field(result, "length"));
        for (i in 0...length) {
            var source = G.call("hl.types.ArrayObj", "getDyn", result, [i]);
            // Gamepad bindings and bindings disabled by the game keep their native behavior.
            if (source == null || G.field(source, "padCode") != null || G.field(source, "code") == null) continue;
            var mode = G.field(source, "mode");
            var replacement:Dynamic = null;
            for (entry in cached) if (entry.source == source && entry.mode == mode) {
                replacement = entry.replacement;
                break;
            }
            if (replacement == null) {
                replacement = {
                    code: (keyCode == 0 ? null : keyCode : Null<Int>),
                    mode: (mode == null ? null : G.integer(mode) : Null<Int>),
                    modifier: (null:Null<Int>),
                    padCode: null
                };
                // Bound the cache even if another mod repeatedly recreates native bindings.
                if (cached.length >= 8) cached = [];
                cached.push({source: source, mode: mode, replacement: replacement});
            }
            // getBindings returns the game's reusable scratch array. Replace the entry,
            // never edit the objects in defaultBinds/userBinds or write input.json.
            G.call("hl.types.ArrayObj", "setDyn", result, [i, replacement]);
        }
        return result;
    }

    public function pressed(action:String, result:Bool):Bool {
        if (action != "ToggleUI" || !result) return result;
        var ui = G.current("ui.BaseUI", "current");
        return ui == null || G.call("ui.BaseUI", "getFocusedTextInput", ui) == null;
    }
}
