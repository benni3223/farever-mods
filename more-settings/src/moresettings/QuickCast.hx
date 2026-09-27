package moresettings;

import moresettings.GameAccess as G;

/** Confirm native ground aiming when its bound action is released. */
class QuickCast {
    public var enabled(default, set):Bool = false;
    var controller:Dynamic;
    var updates:Array<Dynamic> = [];
    var aim:Null<{controller:Dynamic, key:String, released:Bool}>;

    public function new() {}

    function set_enabled(value:Bool):Bool {
        if (!value) aim = null;
        return enabled = value;
    }

    public function observeController(instance:Dynamic):Void {
        if (controller != instance) aim = null;
        controller = instance;
    }

    public function start(instance:Dynamic, input:Dynamic):Void {
        if (!enabled || instance != controller || !Std.isOfType(input, String)) return;
        var key:String = cast input;
        if (key != "") aim = {controller: instance, key: key, released: false};
    }

    public function beginUpdate(instance:Dynamic):Void updates.push(instance);

    public function endUpdate(instance:Dynamic):Void {
        updates.pop();
        // The native job skips confirmation on its first frame. Latch a quick
        // tap here so the next aiming update still sees the release.
        if (aim != null && aim.controller == instance) readRelease();
    }

    public function stop(instance:Dynamic):Void {
        if (aim != null && aim.controller == instance) aim = null;
    }

    public function confirm(key:String):Null<Bool> {
        if (aim == null || updates.length == 0 || aim.controller != updates[updates.length - 1]
            || aim.key != key) return null;
        readRelease();
        return aim == null ? null : aim.released;
    }

    function readRelease():Void {
        if (!enabled || aim.controller != controller || G.field(controller, "ended") == true) {
            aim = null;
            return;
        }
        // Preserve the game's focus/UI gate, keyboard/gamepad bindings and
        // modifiers. Only bypass the input mode that ground aiming itself blocks.
        // checkActive is a replaceable native closure; read the current value
        // rather than binding the default always-true implementation.
        var checkActive = G.current("lib.Input", "checkActive");
        if (checkActive == null || Reflect.callMethod(null, checkActive, [null]) != true) {
            aim.released = false;
            return;
        }
        if (aim.released) return;
        var previous = G.current("lib.Input", "_noCheckMode");
        G.setCurrent("lib.Input", "_noCheckMode", true);
        var released:Dynamic;
        try released = G.staticCall("lib.Input", "isReleased", [aim.key]) catch (error:Dynamic) {
            G.setCurrent("lib.Input", "_noCheckMode", previous);
            aim = null;
            throw error;
        }
        G.setCurrent("lib.Input", "_noCheckMode", previous);
        aim.released = released == true;
    }

    public function reset():Void {
        aim = null;
        updates = [];
        controller = null;
    }

    public function beginFrame():Void {
        // Recover the scope if a native update threw before its postfix ran.
        if (updates.length > 0) { updates = []; aim = null; }
    }
}
