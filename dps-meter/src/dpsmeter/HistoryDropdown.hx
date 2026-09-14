package dpsmeter;

import dpsmeter.GameAccess as G;
import dpsmeter.NativeUi.*;

typedef HistoryChoice = {value:String, name:String, ?color:Int};

/** Native dropdown with detached option values and optional class-coloured text. */
class HistoryDropdown {
    public var object(default, null):Dynamic;
    var choices:Array<HistoryChoice> = [];
    var signature:String = "";
    var selected:String;
    public function new(parent:Dynamic, id:String, choices:Array<HistoryChoice>, selected:String, changed:String->Void) {
        object = G.field(node("dropdown", parent, [false, false, "dps-history-options"], id), "obj");
        padding(object, 0);
        // The history window is above gameRoot. Native Dropdown.toggle first
        // registers its list under gameRoot, then honours this parent override.
        // Append the list to the same root as history so it draws above it.
        var popupRoot = G.field(G.current("ui.BaseUI", "current"), "root");
        G.set(object, "getListLayout", () -> popupRoot);
        setChoices(choices, selected);
        G.call("ui.UIElement", "set_onClick", G.field(object, "select"), [() -> {
            G.call("ui.comp.Dropdown", "toggle", object, [null]);
            var popup = G.field(object, "listWindow");
            if (popup != null && G.field(popup, "parent") == popupRoot) absolute(popupRoot, popup);
            refreshColors();
        }]);
        G.set(object, "onValueChanged", (value:Dynamic) -> {
            this.selected = G.text(value);
            refreshColors(); changed(this.selected);
        });
    }
    public function setChoices(values:Array<HistoryChoice>, selected:String):Void {
        this.selected = selected;
        var signature = haxe.Json.stringify(values);
        if (this.signature != signature) {
            this.signature = signature; choices = values;
            // Dropdown requires the game's ArrayObj, never a mod ArrayDyn.
            var windows = G.field(G.current("ui.BaseUI", "current"), "windows");
            var options = G.call("hl.types.ArrayObj", "slice", windows, [0, 0]);
            for (choice in choices) G.call("hl.types.ArrayObj", "pushDyn", options,
                [{name: choice.name, value: choice.value, icon: null, group: null}]);
            G.call("ui.comp.Dropdown", "set_options", object, [options]);
        }
        var index = 0;
        for (i in 0...choices.length) if (choices[i].value == selected) { index = i; break; }
        G.call("ui.comp.Dropdown", "initSelectedIndex", object, [index]);
        refreshColors();
    }
    public function resize(width:Int):Void {
        size(object, width, 34); size(G.field(object, "select"), width, 34);
        G.call("ui.comp.FmtText", "set_maxWidthText", G.field(object, "selectText"), [Std.int(Math.max(1, width - 44))]);
        G.call("ui.comp.FmtText", "set_useEllipsis", G.field(object, "selectText"), [true]);
    }
    public function isOpen():Bool return G.call("ui.comp.Dropdown", "isOpen", object) == true;
    public function close():Void G.call("ui.comp.Dropdown", "close", object, [null]);
    public function refreshColors():Void {
        var index = G.integer(G.field(object, "selectedIndex"));
        color(G.field(object, "selectText"), choiceColor(index));
        if (!isOpen()) return;
        var items = G.array(G.field(object, "items"));
        for (i in 0...items.length) for (child in children(items[i]))
            if (G.field(child, "font") != null) color(child, choiceColor(i));
    }
    function choiceColor(index:Int):Int return index >= 0 && index < choices.length && choices[index].color != null
        ? choices[index].color : 0x5b4334;
    static function color(text:Dynamic, value:Int):Void {
        if (text != null) G.call("h2d.Text", "set_textColor", text, [value]);
    }
}
