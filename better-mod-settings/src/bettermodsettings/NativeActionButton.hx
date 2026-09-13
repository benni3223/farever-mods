package bettermodsettings;

/** Native dialogs and scoped DOMKit rules, resolved once without per-frame styling. */
class NativeActionButton {
    static var baseUIType:hl.Bytes;
    static var displayDialog:hlx.runtime.ResolvedMember;
    static var arrayGet:hlx.runtime.ResolvedMember;
    static var setText:hlx.runtime.ResolvedMember;
    static var parseSheet:hlx.runtime.ResolvedMember;
    static var addStyle:hlx.runtime.ResolvedMember;
    static var addClass:hlx.runtime.ResolvedMember;
    static var styledData:Dynamic;

    static function currentUI():Dynamic {
        if (baseUIType == null) baseUIType = HlxRuntime.resolveType("ui.BaseUI");
        if (baseUIType == null) throw "Native UI is unavailable.";
        var ui = HlxRuntime.resolveStaticField(baseUIType, "current");
        if (ui == null) throw "Native UI is unavailable.";
        return ui;
    }

    public static function isOpen(window:Dynamic):Bool {
        return window != null && HlxRuntime.resolveField(window, "allocated") == true;
    }

    public static function confirm(button:ActionButton, callback:Bool->Void):Dynamic {
        var ui = currentUI();
        if (displayDialog == null)
            displayDialog = member("ui.BaseUI", "displayDialog");
        if (arrayGet == null) arrayGet = member("hl.types.ArrayObj", "getDyn");
        if (setText == null) setText = member("ui.comp.Button", "setText");
        // Use the game's known icon IDs, then set literal labels. Cancel and
        // Escape both report false; no generic close-first-window callback.
        var descriptors:Array<Dynamic> = [
            {ic: "Confirm", input: null, checkEnable: null, onBack: false},
            {ic: "Cancel", input: null, checkEnable: null, onBack: true}
        ];
        var dialog = HlxRuntime.callResolved(displayDialog, [ui, button.label, button.warningText,
            descriptors, function(choice:String):Void callback(choice == "Confirm")]);
        if (dialog == null) throw "Native confirmation dialog could not be opened.";
        var buttons = HlxRuntime.resolveField(dialog, "buttons");
        HlxRuntime.callResolved(setText, [HlxRuntime.callResolved(arrayGet, [buttons, 0]), "Continue"]);
        HlxRuntime.callResolved(setText, [HlxRuntime.callResolved(arrayGet, [buttons, 1]), "Cancel"]);
        return dialog;
    }

    public static function style(properties:Dynamic, colour:String):Void {
        if (colour == "default" || properties == null) return;
        var ui = currentUI();
        var style = HlxRuntime.resolveField(ui, "style");
        var data = HlxRuntime.resolveField(style, "data");
        if (data != styledData) {
            if (parseSheet == null) parseSheet = member("domkit.CssParser", "parseSheet");
            if (addStyle == null) addStyle = member("domkit.CssStyle", "add");
            var parser = HlxRuntime.resolveField(style, "cssParser");
            // Farever's native green/red palette, including hover and press
            // feedback. Only BMS action buttons receive these classes.
            var css = colourRules("green", "#9AC54D") + colourRules("red", "#D75C4E");
            var rules = HlxRuntime.callResolved(parseSheet, [parser, css, "better-mod-settings-actions"]);
            HlxRuntime.callResolved(addStyle, [style, rules]);
            styledData = data;
        }
        if (addClass == null) addClass = member("domkit.Properties", "addClass");
        HlxRuntime.callResolved(addClass, [properties, "bms-action-" + colour]);
    }

    static function colourRules(name:String, colour:String):String {
        var selector = "button.bms-action-" + name;
        return selector + " > #background { background: " + colour + "; }"
            + selector + ":hover > #background { background: darken(" + colour + ", 8%); }"
            + selector + ":active > #background { background: darken(" + colour + ", 15%); }";
    }

    static function member(typeName:String, name:String):hlx.runtime.ResolvedMember {
        var type = HlxRuntime.resolveType(typeName);
        var result = type == null ? null : HlxRuntime.resolveMember(type, name);
        if (result == null) throw "Native member unavailable: " + typeName + "." + name;
        return result;
    }
}
