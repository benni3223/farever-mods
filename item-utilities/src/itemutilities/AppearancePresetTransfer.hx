package itemutilities;

import itemutilities.AppearancePresetPlan.AppearanceChange;

/** One normal request at a time; both acknowledgement and replication must arrive. */
class AppearancePresetTransfer {
    public var active(default, null):Bool = false;
    public var error(default, null):String = "";
    public var requestId(default, null):Int = 0;
    var context:Dynamic;
    var changes:Array<AppearanceChange> = [];
    var expected:Map<String, String>;
    var pending:AppearanceChange;
    var acknowledged:Bool = false;
    var deadline:Float = 0;
    var position:Int = 0;
    static inline var TIMEOUT = 5.0;

    public function new() {}

    public function start(context:Dynamic, current:Map<String, String>, changes:Array<AppearanceChange>):Bool {
        if (active || context == null) return false;
        this.context = context;
        this.expected = current.copy();
        this.changes = changes;
        position = 0;
        pending = null;
        acknowledged = false;
        error = "";
        active = changes.length > 0;
        return true;
    }

    public function needsState():Bool return active && (pending == null || acknowledged);

    public function next(context:Dynamic, now:Float, current:Map<String, String>):AppearanceChange {
        if (!active) return null;
        if (context != this.context) {
            cancel("Appearance preset stopped because the character changed.");
            return null;
        }
        if (pending != null) {
            if (now >= deadline) {
                cancel("Appearance preset stopped while waiting for the server.");
                return null;
            }
            if (!acknowledged) return null;
            if (!AppearancePresetPlan.same(current, pending.after)) {
                if (!AppearancePresetPlan.same(current, expected))
                    cancel("Appearance preset stopped because the appearances changed during application.");
                return null;
            }
            expected = pending.after;
            pending = null;
        }
        if (!AppearancePresetPlan.same(current, expected)) {
            cancel("Appearance preset stopped because the appearances changed during application.");
            return null;
        }
        if (position == changes.length) {
            active = false;
            changes = [];
            this.context = null;
            expected = null;
            return null;
        }
        pending = changes[position++];
        acknowledged = false;
        deadline = now + TIMEOUT;
        requestId++;
        return pending;
    }

    public function acknowledge(id:Int, success:Bool):Void {
        if (!active || pending == null || id != requestId) return;
        if (!success) cancel("The game rejected an appearance change. Preset application stopped.");
        else acknowledged = true;
    }

    public function cancel(message:String = ""):Void {
        active = false;
        error = message;
        context = null;
        pending = null;
        changes = [];
        expected = null;
    }
}
