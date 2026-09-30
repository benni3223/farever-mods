package bettermodsettings;

/** A dropdown stores the literal option string, never its display index. */
class DropdownSetting {
    public var label(default, null):String;
    public var options(default, null):Array<String>;

    function new(label:String, options:Array<String>) {
        this.label = label;
        this.options = options;
    }

    public static function parse(definition:Dynamic):Null<DropdownSetting> {
        if (definition == null) return null;
        var label:Dynamic = Reflect.field(definition, "label");
        var values:Dynamic = Reflect.field(definition, "options");
        if (!Std.isOfType(label, String) || StringTools.trim(cast label).length == 0
            || !Std.isOfType(values, Array)) return null;
        var options:Array<String> = [];
        for (value in (cast values:Array<Dynamic>)) {
            if (!Std.isOfType(value, String)) return null;
            options.push(cast value);
        }
        return options.length == 0 ? null : new DropdownSetting(cast label, options);
    }

    public function selectedIndex(value:Dynamic):Int {
        var index = Std.isOfType(value, String) ? options.indexOf(cast value) : -1;
        return index < 0 ? 0 : index;
    }

    public function valueAt(index:Dynamic):Null<String> {
        if (!Std.isOfType(index, Int)) return null;
        var i:Int = cast index;
        return i < 0 || i >= options.length ? null : options[i];
    }
}
