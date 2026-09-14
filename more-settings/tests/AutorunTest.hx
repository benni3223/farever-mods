import moresettings.Autorun;
import moresettings.SettingsData;
import moresettings.GameAccess as G;

class AutorunTest {
    static var checks = 0;
    static var run:Autorun;
    static var hero:Dynamic;
    static var app:Dynamic;
    static var controller:Dynamic;
    static function eq(actual:Dynamic, expected:Dynamic, message:String):Void {
        checks++;
        if (actual != expected) throw message + ': expected $expected, got $actual';
    }
    static function setup():Void {
        G.data = {current: {textInput: null}};
        G.focused = true; G.cinematicCapture = false; G.keysPressed = [];
        hero = {layer: {}, dead: false, flying: false, vehicle: false, isInFallDeath: false};
        app = {hero: hero};
        controller = {unit: hero, ended: false, blocked: false, overrideController: null, autoForward: false};
        run = new Autorun(); run.configure(82);
    }
    // Native order: Player.update -> updateInputs -> Input.getMove ->
    // Player.getMoveDirection -> jump/skill inputs -> finish update.
    static function frame(pressed:Bool = false, x:Float = 0, y:Float = 0, ?action:String):Dynamic {
        G.keysPressed[82] = pressed;
        run.watch(app); run.begin(controller); run.prepare(controller);
        var point = {x: x, y: y}; run.direction(controller, point);
        if (action != null) eq(run.input(action, true), true, "native action result is preserved");
        run.finish(controller);
        return point;
    }
    static function main():Void {
        var config = SettingsData.defaults();
        eq(config.autorunKey, 0, "autorun defaults to unassigned");
        for (key in [-1, 27, 512, 999]) {
            config.autorunKey = key; SettingsData.normalize(config);
            eq(config.autorunKey, 0, "invalid or reserved key is unassigned");
        }
        for (key in [0, 1, 82, 113, 511]) {
            config.autorunKey = key; SettingsData.normalize(config);
            eq(config.autorunKey, key, "valid BMS key survives normalization");
        }
        setup();
        eq(frame(true).y, 1., "hotkey starts normal forward input");
        eq(run.active, true, "autorun is active");
        eq(frame().y, 1., "releasing key keeps moving");
        eq(frame(false, 0, 0, "Jump").y, 1., "jump gets forward input");
        eq(run.active, true, "jump does not cancel");
        eq(frame().y, 1., "airborne and landing frames keep moving");
        eq(frame(true).y, 0., "second hotkey press stops movement");
        eq(run.active, false, "second press cancels autorun");
        eq(frame().y, 0., "autorun stays cancelled");

        for (action in ["Attack", "Secondary", "Dash", "SignatureSkill", "WeaponSkill1", "WeaponSkill2",
            "WeaponSkill3", "WeaponSkill4", "Skill1", "Skill2", "Skill3", "Skill4", "GroupSkill1", "ContextualSkill"]) {
            setup(); frame(true); frame(false, 0, 0, action);
            eq(run.active, false, "combat input cancels: " + action);
            eq(frame().y, 0., "combat does not restart autorun");
        }
        for (action in ["MoveForward", "MoveBack", "MoveLeft", "MoveRight"]) {
            setup(); frame(true); run.begin(controller); G.keysPressed[82] = false; run.prepare(controller);
            // Opposite rebound keys can sum to zero in the native movement vector.
            eq(run.input(action, true), true, "manual input remains available: " + action);
            var point = {x: 0., y: 0.}; run.direction(controller, point);
            eq(point.y, 0., "opposed direction keys cancel before forward injection");
            eq(run.active, false, "every manual direction cancels");
        }
        for (vector in [{x: 1., y: 0.}, {x: -1., y: 0.}, {x: 0., y: 1.}, {x: 0., y: -1.}, {x: .2, y: .3}]) {
            setup(); frame(true);
            var point = frame(false, vector.x, vector.y);
            eq(run.active, false, "native keyboard/gamepad direction cancels");
            eq(point.x, vector.x, "manual X remains unchanged");
            eq(point.y, vector.y, "manual Y remains unchanged");
        }
        setup(); frame(true);
        for (action in ["Jump", "LockTarget", "FreeCursorRotate", "Sprint"]) {
            frame(false, 0, 0, action);
            eq(run.active, true, "non-cancelling action: " + action);
        }
        run.begin(controller); run.prepare(controller);
        eq(run.input("Attack", false), false, "blocked combat press stays blocked");
        eq(run.active, true, "blocked input cannot cancel");
        run.skill({unit: {}}); eq(run.active, true, "other controller's skill is unrelated");
        run.skill(controller); eq(run.active, false, "queued/contextual local skill cancels");

        for (reason in ["chat", "window", "focus", "cinematic", "death", "fall", "travel", "vehicle", "override", "end", "character", "zone", "skill"]) {
            setup(); frame(true);
            switch reason {
                case "chat": G.data.current.textInput = {};
                case "window": controller.blocked = true;
                case "focus": G.focused = false;
                case "cinematic": G.cinematicCapture = true;
                case "death": hero.dead = true;
                case "fall": hero.isInFallDeath = true;
                case "travel": hero.flying = true;
                case "vehicle": hero.vehicle = true;
                case "override": controller.overrideController = {};
                case "end": controller.ended = true;
                case "character": app.hero = {layer: {}};
                case "zone": hero.layer = {};
                case "skill": hero.activeSkill = {};
            }
            run.watch(app);
            eq(run.active, false, "interrupted control clears autorun: " + reason);
        }
        setup(); controller.blocked = true;
        eq(frame(true).y, 0., "cannot activate through a blocking window");
        eq(run.active, false, "blocked activation stays off");
        setup(); G.data.current.textInput = {};
        frame(true); eq(run.active, false, "typing bound letter does not start movement");
        setup(); hero.activeSkill = {};
        frame(true); eq(run.active, false, "cannot activate in the middle of a skill");
        setup(); frame(true);
        run.begin(controller); run.finish(controller);
        eq(run.active, false, "native frame that skips updateInputs cancels");
        setup(); frame(true);
        run.begin(controller); G.keysPressed[82] = false; run.prepare(controller);
        eq(run.input("ToggleAutoForward", true), false, "native toggle cannot start an independent autorun");
        run.finish(controller);
        eq(run.input("ToggleAutoForward", true), true, "other input contexts stay unchanged");
        var other = {unit: {}};
        run.begin(other); var point = {x: 0., y: 0.}; run.direction(other, point);
        eq(point.y, 0., "never inject input into another controller");
        run.ended(other); eq(run.active, true, "unrelated controller ending does not clear autorun");
        run.ended(controller); eq(run.active, false, "owner disposal clears autorun");

        setup(); frame(true); run.configure(82); eq(run.active, true, "unrelated config changes keep autorun");
        run.configure(83); eq(run.active, false, "rebinding cancels old autorun");
        setup(); frame(true); run.configure(0);
        G.nativeCalls = 0;
        for (_ in 0...100) frame(true);
        eq(run.active, false, "unassigned shortcut cannot activate");
        eq(G.nativeCalls, 0, "unassigned autorun performs no native calls");
        setup(); frame(true); run.reset(); eq(run.active, false, "game disposal clears autorun");
        setup(); frame(true); run.begin(controller); G.keysPressed[82] = false; run.prepare(controller);
        G.nativeCalls = 0;
        for (_ in 0...1000) run.input("Jump", true);
        eq(G.nativeCalls, 0, "observing native input does not repoll bindings or scan entities");
        Sys.println('Autorun: $checks checks passed.');
    }
}
