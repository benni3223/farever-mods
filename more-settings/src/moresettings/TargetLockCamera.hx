package moresettings;

import moresettings.GameAccess as G;

/** Suppress only the native lock steering speed, scoped to camera postUpdate. */
class TargetLockCamera {
    public var enabled:Bool = false;
    var frames:Array<Null<{settings:Dynamic, speed:Dynamic}>> = [];

    public function new() {}

    public function begin():Void {
        frames.push(null);
        if (!enabled) return;
        var settings = G.current("Const", "Camera");
        var speed = G.field(settings, "LockRotateSpeed");
        if (!Math.isFinite(G.number(speed, Math.NaN))) return;
        frames[frames.length - 1] = {settings: settings, speed: speed};
        // Both clients multiply yaw/pitch correction by smoothLerp(speed, dt),
        // which is zero at speed 0. TargetLock, the target, locked sensitivity,
        // manual camera input, water avoidance and BaseCamera updates stay native.
        G.set(settings, "LockRotateSpeed", 0.0);
    }

    public function end():Void {
        var frame = frames.pop();
        if (frame != null) G.set(frame.settings, "LockRotateSpeed", frame.speed);
    }

    public function reset():Void {
        // Also called at the next frame/disposal if native postUpdate threw.
        while (frames.length > 0) end();
    }
}
