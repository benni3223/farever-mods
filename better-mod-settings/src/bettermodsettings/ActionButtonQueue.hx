package bettermodsettings;

/** One confirmation at a time; stale or repeated callbacks cannot run an action. */
class ActionButtonQueue {
    public var pending(default, null):Null<{token:Int, button:ActionButton}>;
    var serial:Int = 0;
    var notifications:Array<String> = [];

    public function new() {}

    /** -1: modal already open; 0: queued; positive: confirmation token. */
    public function request(button:ActionButton):Int {
        if (pending != null) return -1;
        if (!button.warningEnabled) {
            notifications.push(button.topic);
            return 0;
        }
        pending = {token: ++serial, button: button};
        return pending.token;
    }

    public function complete(token:Int, confirmed:Bool):Void {
        if (pending == null || pending.token != token) return;
        var button = pending.button;
        pending = null;
        if (confirmed) notifications.push(button.topic);
    }

    public function takeNotifications():Array<String> {
        if (notifications.length == 0) return notifications;
        var result = notifications;
        notifications = [];
        return result;
    }

    public function reset():Void {
        pending = null;
        notifications = [];
        // Keep serial monotonic so a callback from a previous session is stale.
    }
}
