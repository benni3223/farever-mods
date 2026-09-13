import bettermodsettings.KeyCaptureState;

class KeyCaptureTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, message:String):Void {
        checks++;
        if (actual != expected) throw message + ": expected " + expected + ", got " + actual;
    }

    static function main():Void {
        var state = new KeyCaptureState();
        eq(state.blocking, false, "normal gameplay input is available");
        state.update(0, true);
        eq(state.blocking, false, "ordinary input never starts capture protection");

        state.begin();
        eq(state.capturing, true, "capture starts immediately on button click");
        eq(state.blocking, true, "all hotkey paths are blocked before a key is selected");
        state.update(1, false);
        state.update(2, false);
        eq(state.blocking, true, "waiting for a key keeps input blocked");

        // Selection and configuration-change notifications happen in this frame.
        state.finish();
        eq(state.capturing, false, "assignment exits the picker");
        eq(state.blocking, true, "saving a new key cannot activate its hotkey");
        for (frame in 3...63) state.update(frame, true);
        eq(state.blocking, true, "holding or repeating assigned input stays suppressed");
        state.update(63, true); // release event is still input activity
        eq(state.blocking, true, "release-triggered actions are suppressed too");
        state.update(64, false);
        eq(state.blocking, true, "first quiet frame drains pending input");
        state.update(64, false);
        eq(state.blocking, true, "two updates in one frame cannot unblock early");
        state.update(65, false);
        eq(state.blocking, false, "a subsequent deliberate key press may activate normally");
        state.update(66, true);
        eq(state.blocking, false, "new input after capture is not swallowed");

        // Escape or closing the window uses the same finish path as assignment.
        state.begin(); state.finish(); state.update(70, true);
        eq(state.blocking, true, "cancel key cannot close menus or trigger an action");
        state.update(71, false); state.update(72, false);
        eq(state.blocking, false, "cancellation releases input normally");

        state.begin(); state.finish(); state.update(80, false);
        state.update(81, true); // another held key or modifier is still active
        state.update(82, false);
        eq(state.blocking, true, "additional key activity restarts the quiet-frame wait");
        state.update(83, false);
        eq(state.blocking, false, "all chord keys must settle before gameplay resumes");

        state.begin(); state.finish(); state.update(90, false); state.begin();
        state.update(91, false);
        eq(state.blocking, true, "starting another assignment keeps input suppressed");
        eq(state.capturing, true, "second picker remains active");
        state.reset();
        eq(state.blocking, false, "leaving the game cannot leave controls blocked");
        eq(state.capturing, false, "dispose clears the pending assignment");

        // Lost focus clears native key states; no release notification is required.
        state.begin(); state.finish(); state.update(100, false); state.update(101, false);
        eq(state.blocking, false, "focus loss with cleared input cannot strand the guard");
        state.begin(); state.finish(); state.update(-2147483648, false); state.update(-2147483647, false);
        eq(state.blocking, false, "frame counter rollover is safe");
        Sys.println('Better Mod Settings: $checks capture checks passed.');
    }
}
