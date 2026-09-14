package moresettings;

import moresettings.GameAccess as G;

/** Supplies forward input to the local controller's normal movement calculation. */
class Autorun {
    public var active(default, null):Bool = false;
    var keyCode:Int = 0;
    var owner:Dynamic;
    var hero:Dynamic;
    var layer:Dynamic;
    var app:Dynamic;
    var context:Dynamic;
    var prepared:Bool = false;

    public function new() {}

    public function configure(key:Int):Void {
        if (keyCode == key) return;
        reset();
        keyCode = key;
    }

    public function cancel():Void active = false;

    public function reset():Void {
        cancel();
        owner = null; hero = null; layer = null; app = null; context = null;
        prepared = false;
    }

    public function watch(app:Dynamic):Void {
        this.app = app;
        if (active && !allowed()) cancel();
    }

    public function begin(controller:Dynamic):Void {
        context = null; prepared = false;
        if (keyCode == 0 || controller == null) return;
        var nextHero = G.field(app, "hero");
        if (nextHero == null || G.field(controller, "unit") != nextHero) return;
        var nextLayer = G.field(nextHero, "layer");
        if (owner != controller || hero != nextHero || layer != nextLayer) cancel();
        owner = controller; hero = nextHero; layer = nextLayer; context = controller;
        // While this binding is assigned, it owns autorun. The native toggle's
        // weaker cancellation rules must not leave a second autorun active.
        if (G.field(controller, "autoForward") == true) G.set(controller, "autoForward", false);
    }

    /** Called only after native updateInputs, after input modes and window checks. */
    public function prepare(controller:Dynamic):Void {
        if (context != controller || controller == null || prepared) return;
        prepared = true;
        // BMS consumes assignment events centrally before hxd.Key sees them.
        var pressed = G.staticCall("hxd.Key", "isPressed", [keyCode]) == true;
        if (!active && !pressed) return;
        if (!allowed()) { cancel(); return; }
        if (pressed) active = !active;
    }

    public function direction(controller:Dynamic, point:Dynamic):Void {
        if (!active || !prepared || context != controller || point == null) return;
        // Native Input.getMove already applies gamepad deadzones and rebound
        // keyboard controls. Never combine manual movement with autorun.
        if (G.number(G.field(point, "x")) != 0 || G.number(G.field(point, "y")) != 0) { cancel(); return; }
        G.set(point, "y", 1.0);
        // Native getMoveDirection/setMoveDirection retain camera-relative
        // movement, jumping, speed limits, collision and normal replication.
    }

    public function input(action:String, result:Bool):Bool {
        if (context == null) return result;
        if (action == "ToggleAutoForward") return false;
        if (!active || !result) return result;
        switch (action) {
            case "MoveForward", "MoveBack", "MoveLeft", "MoveRight",
                "Attack", "Secondary", "Dash", "SignatureSkill",
                "WeaponSkill1", "WeaponSkill2", "WeaponSkill3", "WeaponSkill4",
                "Skill1", "Skill2", "Skill3", "Skill4", "GroupSkill1", "ContextualSkill",
                "Mount", "Consumable1", "Consumable2", "Consumable3", "Consumable4": cancel();
            default: // Jump and camera/target controls leave autorun active.
        }
        return result;
    }

    /** Also catches queued or contextual skill requests outside normal key polling. */
    public function skill(controller:Dynamic):Void {
        if (controller != null && controller == owner) cancel();
    }

    public function finish(controller:Dynamic):Void {
        if (context != controller || controller == null) return;
        if (!prepared) cancel(); // Native input was blocked this frame.
        context = null; prepared = false;
    }

    public function ended(controller:Dynamic):Void {
        if (controller != null && controller == owner) reset();
    }

    function allowed():Bool {
        if (owner == null || hero == null || layer == null || G.field(app, "hero") != hero
            || G.field(hero, "layer") != layer || G.field(owner, "unit") != hero
            || G.field(owner, "ended") == true || G.field(owner, "overrideController") != null
            || G.field(hero, "isInFallDeath") == true) return false;
        if (G.call("ent.GameObject", "isDead", hero) == true
            || G.call("ent.Unit", "isUsingVehicle", hero) == true
            || G.call("ent.Hero", "isFlyingToObelisk", hero) == true) return false;
        if (G.call("ent.GameObject", "getActiveSkill", hero) != null) return false;
        if (G.call("client.UnitController", "isInputBlocked", owner) != false
            || G.staticCall("lib.Input", "cinematicCapturesKbd", []) == true) return false;
        var ui = G.current("ui.BaseUI", "current");
        if (ui == null || G.call("ui.BaseUI", "getFocusedTextInput", ui) != null) return false;
        var window = G.staticCall("hxd.Window", "getInstance", []);
        return window != null && G.call("hxd.Window", "get_isFocused", window) == true;
    }
}
