package itemutilities;

import itemutilities.TalentPresetPlan.TalentChange;

/** One normal request at a time; both acknowledgement and replication must arrive. */
class TalentPresetTransfer {
    public var active(default, null):Bool = false;
    public var error(default, null):String = "";
    public var requestId(default, null):Int = 0;
    var context:Dynamic;
    var changes:Array<TalentChange> = [];
    var expected:Map<String, Int>;
    var pending:TalentChange;
    var acknowledged:Bool = false;
    var deadline:Float = 0;
    var position:Int = 0;
    static inline var TIMEOUT = 5.0;

    public function new() {}

    public function start(context:Dynamic, current:Map<String, Int>, changes:Array<TalentChange>):Bool {
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

    public function needsRanks():Bool return active && (pending == null || acknowledged);

    public function next(context:Dynamic, now:Float, current:Map<String, Int>):TalentChange {
        if (!active) return null;
        if (context != this.context) {
            cancel("Talent preset stopped because the character changed.");
            return null;
        }
        if (pending != null) {
            if (now >= deadline) {
                cancel("Talent preset stopped while waiting for the server.");
                return null;
            }
            if (!acknowledged) return null;
            if (!TalentPresetPlan.same(current, pending.after)) {
                if (!TalentPresetPlan.same(current, expected))
                    cancel("Talent preset stopped because the talents changed during application.");
                return null;
            }
            expected = pending.after;
            pending = null;
        }
        if (!TalentPresetPlan.same(current, expected)) {
            cancel("Talent preset stopped because the talents changed during application.");
            return null;
        }
        if (position == changes.length) {
            active = false;
            changes = [];
            this.context = null;
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
        if (!success) cancel("The game rejected a talent change. Preset application stopped.");
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
