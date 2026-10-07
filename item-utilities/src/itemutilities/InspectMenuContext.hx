package itemutilities;

typedef InspectTarget = {
    var ui:Dynamic;
    var uid:String;
    var name:String;
    @:optional var fromSocialWindow:Bool;
}

/** Only the context menu built inside the player's social menu may be extended. */
class InspectMenuContext {
    var pending:InspectTarget;
    public function new() {}
    public function begin(ui:Dynamic, uid:String, name:String, enabled:Bool, fromSocialWindow:Bool = false):Void {
        pending = enabled && ui != null && uid != null && uid != ""
            ? {ui: ui, uid: uid, name: name, fromSocialWindow: fromSocialWindow} : null;
    }
    public function take(ui:Dynamic):InspectTarget {
        if (pending == null || pending.ui != ui) return null;
        var target = pending;
        pending = null;
        return target;
    }
    public function clear():Void pending = null;
    public static function insertionIndex(labels:Array<String>, sendMessage:String, fromSocialWindow:Bool = false):Int {
        // Compare the game's localized label, never an English translation.
        if (sendMessage == null || sendMessage == "") return -1;
        var index = labels.indexOf(sendMessage);
        // Offline/ignored player cards omit Send message. Their confirmed
        // player menu still gets Inspect so choosing it can explain failure.
        return index < 0 ? (fromSocialWindow ? 0 : -1) : index + 1;
    }
}
