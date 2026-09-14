package dpsmeter;

import dpsmeter.FightHistory;
import dpsmeter.HistoryDropdown.HistoryChoice;
import dpsmeter.NativeUi.*;

class NativeHistoryOptions {
    var sort:HistoryDropdown;
    var direction:HistoryDropdown;
    var character:HistoryDropdown;
    public var sortBy(default, null):String = "time";
    public var ascending(default, null):Bool = false;
    public var characterKey(default, null):String = "";
    public function new(parent:Dynamic, changed:Void->Void) {
        sort = new HistoryDropdown(parent, "dpsHistorySort", [
            {value: "time", name: "Sort by time"}, {value: "dps", name: "Sort by your DPS"},
            {value: "duration", name: "Sort by duration"}], sortBy, value -> { sortBy = value; changed(); });
        direction = new HistoryDropdown(parent, "dpsHistoryDirection", [
            {value: "desc", name: "Descending"}, {value: "asc", name: "Ascending"}], "desc",
            value -> { ascending = value == "asc"; changed(); });
        character = new HistoryDropdown(parent, "dpsHistoryCharacter", [{value: "", name: "All characters"}], "",
            value -> { characterKey = value; changed(); });
        for (control in controls()) absolute(dpsmeter.GameAccess.field(parent, "obj"), control.object);
    }
    public function setCharacters(characters:Array<HistoryCharacter>):Void {
        if (characters == null) return;
        var choices:Array<HistoryChoice> = [{value: "", name: "All characters"}];
        var found = characterKey == "";
        for (value in characters) {
            choices.push({value: value.key, name: value.name, color: classColor(value.className)});
            if (value.key == characterKey) found = true;
        }
        // Retain the selected filter after deleting its last log. Returning to
        // All characters is explicit, so deletion cannot silently change scope.
        if (!found) {
            var old:Array<String> = haxe.Json.parse(characterKey);
            choices.push({value: characterKey, name: old[0] == "" ? "Unknown character" : old[0], color: classColor(old[1])});
        }
        character.setChoices(choices, characterKey);
    }
    public function setVisible(visible:Bool):Void {
        close(); for (control in controls()) show(control.object, visible);
    }
    public function layout(width:Int):Int {
        var narrow = width < 620;
        var sortWidth = narrow ? Std.int((width - 12) * .56) : 210;
        var directionWidth = narrow ? width - 12 - sortWidth : 156;
        sort.resize(sortWidth); position(sort.object, 0, 56);
        direction.resize(directionWidth); position(direction.object, sortWidth + 12, 56);
        var characterX = narrow ? 0 : sortWidth + directionWidth + 24;
        character.resize(width - characterX); position(character.object, characterX, narrow ? 98 : 56);
        return narrow ? 144 : 102;
    }
    public function refresh():Void for (control in controls()) control.refreshColors();
    public function closeOpen():Bool {
        var open = false;
        for (control in controls()) if (control.isOpen()) { control.close(); open = true; }
        return open;
    }
    public function close():Void for (control in controls()) control.close();
    function controls():Array<HistoryDropdown> return [sort, direction, character];
}
