package bettermodsettings;

/** Descriptor-only actions never read or write a setting value. */
class ActionButton {
    public var topic(default, null):String;
    public var label(default, null):String;
    public var buttonText(default, null):String;
    public var colour(default, null):String;
    public var warningEnabled(default, null):Bool;
    public var warningText(default, null):String;

    public function new(modId:String, definition:Dynamic) {
        var key = text(definition, "key", "");
        topic = "better-mod-settings/action/" + modId + "/" + key;
        label = text(definition, "label", key);
        buttonText = text(definition, "buttonText", label);
        colour = switch (text(definition, "colour", "default")) {
            case "green": "green";
            case "red": "red";
            default: "default";
        };
        var warning:Dynamic = Reflect.field(definition, "warning");
        warningEnabled = warning != null && Reflect.field(warning, "enabled") == true;
        warningText = text(warning, "warningText", "Are you sure you want to continue?");
    }

    static function text(object:Dynamic, key:String, fallback:String):String {
        var value:Dynamic = object == null ? null : Reflect.field(object, key);
        return Std.isOfType(value, String) && StringTools.trim(value).length > 0 ? value : fallback;
    }
}
