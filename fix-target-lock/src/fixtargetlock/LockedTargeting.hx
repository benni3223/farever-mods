package fixtargetlock;

/** Pin instant skill targeting only while the native startSkillAim call runs. */
class LockedTargeting {
    var frames:Array<{controller:Dynamic, target:Dynamic, previous:Dynamic}> = [];

    public function new() {}

    public function begin(controller:Dynamic, target:Dynamic):Void {
        var previous = GameAccess.field(controller, "autoTarget");
        frames.push({controller: controller, target: target, previous: previous});
        // Skills without needTarget or melee targeting submit the existing
        // autoTarget. Manual ground aim still builds its native Point target.
        if (target != null) GameAccess.set(controller, "autoTarget", target);
    }

    public function target(controller:Dynamic):Dynamic {
        if (frames.length == 0) return null;
        var frame = frames[frames.length - 1];
        return frame.controller == controller ? frame.target : null;
    }

    public function end():Void {
        var frame = frames.pop();
        if (frame != null && frame.target != null)
            GameAccess.set(frame.controller, "autoTarget", frame.previous);
    }

    public function reset():Void {
        while (frames.length > 0) end();
    }
}
