package itemutilities;

import itemutilities.SkillPresetPlan.SkillPresetState;
import itemutilities.SkillPresetPlan.SkillPresetChange;

/** Slot RPCs have no callback; rune RPCs require a reply as well as replication. */
class SkillPresetTransfer {
    public var active(default, null):Bool = false;
    public var error(default, null):String = "";
    public var requestId(default, null):Int = 0;
    var context:Dynamic;
    var changes:Array<SkillPresetChange> = [];
    var expected:SkillPresetState;
    var pending:SkillPresetChange;
    var acknowledged:Bool = false;
    var deadline:Float = 0;
    var position:Int = 0;
    static inline var TIMEOUT = 5.0;

    public function new() {}

    public function start(context:Dynamic, current:SkillPresetState, changes:Array<SkillPresetChange>):Bool {
        if (active || context == null) return false;
        this.context = context;
        expected = SkillPresetPlan.copy(current);
        this.changes = changes;
        position = 0;
        pending = null;
        acknowledged = false;
        error = "";
        active = changes.length > 0;
        return true;
    }

    public function needsState():Bool return active && (pending == null || acknowledged);

    public function next(context:Dynamic, now:Float, current:SkillPresetState):SkillPresetChange {
        if (!active) return null;
        if (context != this.context) {
            cancel("Skill preset stopped because the character changed.");
            return null;
        }
        if (pending != null) {
            if (now >= deadline) {
                cancel("Skill preset stopped while waiting for the server.");
                return null;
            }
            if (!acknowledged) return null;
            if (!SkillPresetPlan.same(current, pending.after)) {
                if (!SkillPresetPlan.same(current, expected))
                    cancel("Skill preset stopped because the skills or runes changed during application.");
                return null;
            }
            expected = pending.after;
            pending = null;
        }
        if (!SkillPresetPlan.same(current, expected)) {
            cancel("Skill preset stopped because the skills or runes changed during application.");
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
        acknowledged = pending.slot >= 0;
        deadline = now + TIMEOUT;
        requestId++;
        return pending;
    }

    public function acknowledge(id:Int, success:Bool):Void {
        if (!active || pending == null || pending.slot >= 0 || id != requestId) return;
        if (!success) cancel("The game rejected a rune change. Skill preset application stopped.");
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
