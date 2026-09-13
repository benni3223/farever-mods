package bettermodsettings;

/** Captured input stays consumed until all keys are up and a quiet frame has passed. */
class KeyCaptureState {
    public var capturing(default, null):Bool = false;
    public var blocking(default, null):Bool = false;
    var quietFrame:Null<Int> = null;

    public function new() {}

    public function begin():Void {
        capturing = true;
        blocking = true;
        quietFrame = null;
    }

    /** Used for both assignment and cancellation; neither may leak its input. */
    public function finish():Void {
        capturing = false;
        blocking = true;
        quietFrame = null;
    }

    public function update(frame:Int, hasKeyActivity:Bool):Void {
        if (!blocking || capturing) return;
        if (hasKeyActivity) {
            quietFrame = null;
        } else if (quietFrame == null) {
            quietFrame = frame;
        } else if (quietFrame != frame) {
            reset();
        }
    }

    public function reset():Void {
        capturing = false;
        blocking = false;
        quietFrame = null;
    }
}
