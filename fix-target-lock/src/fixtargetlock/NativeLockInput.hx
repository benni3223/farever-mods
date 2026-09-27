package fixtargetlock;

/** Observe actual native input handling rather than guessing a game version. */
class NativeLockInput {
    public var handled(default, null):Bool = false;
    var checking:Bool = false;

    public function new() {}
    public function begin():Void checking = true;
    public function end():Void checking = false;
    public function observe(input:String):Void {
        // The legacy mod's own isPressed query occurs after end(), so it cannot
        // falsely identify itself as native support. An unpressed native query
        // is sufficient: detection finishes before the player's first lock press.
        if (checking && input == "LockTarget") handled = true;
    }
}
