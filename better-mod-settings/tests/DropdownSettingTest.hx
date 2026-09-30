import bettermodsettings.DropdownSetting;
import haxe.Json;

class DropdownSettingTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, message:String):Void {
        checks++;
        if (actual != expected) throw message + ': expected $expected, got $actual';
    }

    static function main():Void {
        for (definition in ([null, {}, {options: ["One"]}, {label: "", options: ["One"]},
            {label: " \t", options: ["One"]}, {label: 7, options: ["One"]},
            {label: "Mode"}, {label: "Mode", options: "One"}, {label: "Mode", options: []},
            {label: "Mode", options: ["One", null]}, {label: "Mode", options: [1, 2]}]:Array<Dynamic>))
            eq(DropdownSetting.parse(definition), null, "Malformed dropdown is skipped");

        var setting = DropdownSetting.parse(Json.parse(
            '{"label":"Show clock/timer","options":["None","Rift timer","Clock"]}'));
        eq(setting.label, "Show clock/timer", "Uses the required label");
        eq(setting.selectedIndex("Clock"), 2, "Stored string selects its option");
        eq(setting.selectedIndex("Rift timer"), 1, "Order matches the descriptor");
        for (value in ([null, "Unknown", 1, true, {bytes: "???", length: 5}]:Array<Dynamic>))
            eq(setting.selectedIndex(value), 0, "Invalid or missing value displays the first option");
        for (index in ([-1, 3, null, "1", 1.5, false]:Array<Dynamic>))
            eq(setting.valueAt(index), null, "Invalid callback index is ignored");

        var values = ["", "000003", "true", "  literal text \t", 'quote " and slash \\', "café 日本語 🎨"];
        var literal = DropdownSetting.parse({label: "Literal strings", options: values});
        for (index in 0...values.length) {
            var selected = literal.valueAt(index);
            eq(selected, values[index], "Selection returns the exact descriptor string");
            var loaded:Dynamic = Json.parse(Json.stringify({mode: selected, unrelated: 42}));
            eq(Std.isOfType(loaded.mode, String), true, "Persist a JSON string, not an index or native String object");
            eq(loaded.mode, values[index], "Special characters and whitespace survive saving");
            eq(loaded.unrelated, 42, "Other values survive saving");
            eq(literal.selectedIndex(loaded.mode), index, "Reopening selects the saved option");
        }
        var saved:Dynamic = Json.parse(Json.stringify({mode: setting.valueAt(2)}));
        var reordered = DropdownSetting.parse({label: "Mode", options: ["Clock", "None", "Rift timer"]});
        eq(reordered.selectedIndex(saved.mode), 0, "Reordering options preserves the user's choice");
        Sys.println('Dropdown settings: $checks checks passed.');
    }
}
