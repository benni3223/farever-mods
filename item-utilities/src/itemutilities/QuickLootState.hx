package itemutilities;

// Keep synthetic presses confined to one controller's native tryInteract call.
// This class has no game/runtime dependencies so its scope can be regression-tested.
class QuickLootState {
    public static inline var REPEAT_INTERVAL:Float = 0.05;
    var inputController:Dynamic;
    var repeatController:Dynamic;
    var targetController:Dynamic;
    var pulseController:Dynamic;
    var nextPulseAt:Float = 0;
    var releaseRequired:Bool = false;

    public function new() {}

    public function prepare(controller:Dynamic, enabled:Bool):Void {
        if (!enabled || controller != pulseController) release(pulseController);
        inputController = enabled ? controller : null;
        repeatController = null;
        targetController = null;
    }

    public function takeInput(key:String):Dynamic {
        if (key != "Interact") return null;
        var controller = inputController;
        inputController = null;
        return controller;
    }

    public function repeat(controller:Dynamic):Void {
        repeatController = controller;
    }

    public function recordPress(controller:Dynamic, now:Float):Void {
        pulseController = controller;
        nextPulseAt = now + REPEAT_INTERVAL;
        releaseRequired = true;
    }

    public function allowRepeat(controller:Dynamic, now:Float):Bool {
        if (controller == null || !Math.isFinite(now)) return false;
        if (controller != pulseController) release(pulseController);
        // Native update resets lastInteract on a frame without a press. Give
        // every pulse that release frame, even at low FPS or after a hitch.
        if (releaseRequired) {
            releaseRequired = false;
            return false;
        }
        if (now + 0.000000001 < nextPulseAt) return false;
        // Schedule from now; never catch up missed presses after a stall.
        recordPress(controller, now);
        return true;
    }

    public function release(controller:Dynamic):Void {
        if (controller != pulseController) return;
        pulseController = null;
        nextPulseAt = 0;
        releaseRequired = false;
    }

    public function beginInteraction(controller:Dynamic):Void {
        targetController = controller != null && repeatController == controller
            ? controller : null;
        repeatController = null;
    }

    public function filtersTarget(controller:Dynamic):Bool {
        return controller != null && targetController == controller;
    }

    public function endInteraction(controller:Dynamic):Void {
        if (targetController == controller) targetController = null;
    }

    public function finish(controller:Dynamic):Void {
        if (inputController == controller) inputController = null;
        if (repeatController == controller) repeatController = null;
        endInteraction(controller);
    }
}
