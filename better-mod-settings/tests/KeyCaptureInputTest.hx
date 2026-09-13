import bettermodsettings.KeyCaptureInput;

class KeyCaptureInputTest {
    static var checks = 0;
    static var input:KeyCaptureInput;
    static var published:Map<Int, Int>;
    static var nativeWrites = 0;

    static function eq(actual:Dynamic, expected:Dynamic, message:String):Void {
        checks++;
        if (actual != expected) throw message + ": expected " + expected + ", got " + actual;
    }

    static function fresh():Void {
        input = new KeyCaptureInput();
        published = new Map();
        nativeWrites = 0;
    }

    static function begin():Void {
        var held = [for (key => value in published) if (value > 0) key];
        published = new Map(); // BMS replaces keyPressed with a native empty slice.
        input.begin(held);
    }

    // Models the native key-state writer. No isPressed/isDown/isReleased hooks
    // or cooperative checks in consumers: consumption must happen before writing.
    static function event(kind:String, key:Int, frame:Int):Void {
        if (input.consume(kind, key, frame)) return;
        switch (kind) {
            case "EKeyDown", "EPush", "EWheel":
                published.set(key, frame); nativeWrites++;
            case "EKeyUp", "ERelease":
                published.set(key, -frame); nativeWrites++;
            case "EReleaseOutside": published.clear(); nativeWrites++;
            default:
        }
    }

    static function rawPressed(key:Int, frame:Int):Bool return published.get(key) == frame - 1;
    static function rawReleased(key:Int, frame:Int):Bool return published.get(key) == -(frame - 1);
    static function rawDown(key:Int):Bool {
        var value = published.get(key);
        return value != null && value > 0;
    }

    static function main():Void {
        fresh();
        event("EKeyDown", 49, 10);
        eq(rawPressed(49, 11), true, "ordinary preset key reaches native polling");
        event("EKeyUp", 49, 11);
        eq(rawReleased(49, 12), true, "ordinary release reaches native polling");

        begin();
        nativeWrites = 0;
        event("EKeyDown", 50, 20);
        eq(rawPressed(50, 21), false, "draw before config save cannot see assigned key");
        eq(rawDown(50), false, "direct held-key polling cannot see assigned key");
        var assignedKey = input.takePressedKey();
        eq(assignedKey, 50, "only picker receives the assigned key");
        input.finish();
        eq(rawPressed(assignedKey, 21), false, "draw after live binding reload cannot activate new preset");
        eq(input.takePressedKey(), 0, "assignment is consumed once");
        for (frame in 21...81) {
            event("EKeyDown", 50, frame); // OS key repeat
            input.update(frame);
            eq(rawPressed(50, frame + 1), false, "repeat never reaches another mod");
            eq(input.blocking, true, "holding assignment retains protection");
        }
        event("EKeyUp", 50, 81);
        input.update(81);
        eq(rawReleased(50, 82), false, "release is never published either");
        input.update(82); input.update(82);
        eq(input.blocking, true, "duplicate updates cannot end quiet-frame protection");
        eq(nativeWrites, 0, "no assignment/hold/release event reached native key state");
        input.update(83);
        eq(input.blocking, false, "protection ends after release and quiet frame");
        eq(rawDown(50), false, "ending capture does not replay held input");
        event("EKeyDown", 50, 84);
        eq(rawPressed(50, 85), true, "next deliberate press activates normally");

        fresh();
        event("EKeyDown", 49, 1); event("EPush", 0, 1);
        begin();
        eq(rawDown(49), false, "opening picker consumes an existing held preset key");
        eq(rawDown(0), false, "opening click is not exposed as a held mouse hotkey");
        event("EKeyDown", 49, 2);
        eq(input.takePressedKey(), 0, "repeat of pre-held key cannot assign itself");
        event("EKeyDown", 27, 3);
        eq(input.takePressedKey(), 27, "Escape reaches picker cancellation");
        input.finish();
        event("EKeyUp", 27, 4); event("ERelease", 0, 4);
        input.update(5); input.update(6);
        eq(input.blocking, true, "pre-held key must still be released after cancellation");
        event("EKeyUp", 49, 7);
        input.update(8); input.update(9);
        eq(input.blocking, false, "cancellation cannot leave a stuck native key");

        fresh(); begin();
        event("EKeyDown", 49, 1); input.takePressedKey(); input.finish();
        begin();
        event("EKeyDown", 49, 2);
        eq(input.takePressedKey(), 0, "second picker preserves previously held key tracking");
        event("EKeyUp", 49, 3); event("EKeyDown", 49, 4);
        eq(input.takePressedKey(), 49, "same key can be assigned after a fresh press");
        input.finish();
        event("EReleaseOutside", -1, 5);
        input.update(6); input.update(7);
        eq(input.blocking, false, "native release-outside reset cannot strand capture");

        fresh(); begin();
        event("EKeyDown", 50, 1); event("EFocusLost", -1, 1);
        eq(input.takePressedKey(), 0, "focus loss discards an unfinished key selection");
        input.finish(); input.update(2); input.update(3);
        eq(input.blocking, false, "focus loss clears private held-key tracking");

        fresh(); event("EWheel", 6, 1); begin();
        event("EWheel", 5, 2);
        eq(input.takePressedKey(), 5, "wheel pulse remains assignable");
        input.finish(); input.update(2); input.update(3); input.update(4);
        eq(input.blocking, false, "wheel input never waits for a nonexistent release");
        fresh(); begin();
        event("EPush", 0, 1);
        eq(input.takePressedKey(), 0, "left click remains reserved for Not set");
        event("EPush", 1, 2);
        eq(input.takePressedKey(), 1, "assignable mouse buttons still work");
        eq(input.consume("EMove", 0, 3), false, "mouse movement is not consumed");
        eq(input.consume("ETextInput", 0, 3), false, "text event routing is unchanged");
        input.reset();
        eq(input.blocking, false, "dispose clears capture state for the next character");
        event("EKeyDown", 51, 4);
        eq(rawPressed(51, 5), true, "next session receives fresh input normally");

        fresh(); begin();
        event("EKeyDown", 49, 1); event("EKeyUp", 49, 1);
        eq(input.takePressedKey(), 49, "fast tap before update is still assignable");
        input.finish(); input.update(1);
        eq(input.blocking, true, "fast tap still consumes its entire event frame");
        input.update(2); input.update(3);
        eq(input.blocking, false, "fast tap drains without a held key");
        eq(nativeWrites, 0, "fast tap never leaks to direct polling");
        Sys.println('Better Mod Settings: $checks central input checks passed.');
    }
}
