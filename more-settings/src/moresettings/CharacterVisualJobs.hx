package moresettings;

import moresettings.GameAccess as G;

private typedef VisualBuild = {
    var view:Dynamic;
    var model:Dynamic;
    var owner:Dynamic;
    var worker:Dynamic;
    var steps:Array<Void->Void>;
    var cursor:Int;
}

/** Split initial remote-player cosmetics at native component boundaries. */
class CharacterVisualJobs {
    var candidates:Array<Dynamic> = [];
    var builds:Array<VisualBuild> = [];
    var constructing:VisualBuild;
    var failed:Bool = false;

    public function new() {}

    public function clear():Void {
        candidates = [];
        builds = [];
    }

    public function begin(view:Dynamic, enabled:Bool):Void {
        cancel(view);
        if (!enabled || failed || G.field(view, "async") != true || G.field(view, "modelObj") != null
            || G.field(view, "parent") == null) return;
        var hero = G.call("client.UnitView", "get_hero", view);
        // Keep local input/animation readiness, NPCs, monsters and UI previews native.
        if (hero != null && hero != G.staticCall("GameApp", "getMyHero", [])) candidates.push(view);
    }

    public function end(view:Dynamic):Void candidates.remove(view);

    public function cancel(view:Dynamic):Void {
        candidates.remove(view);
        var value = find(view);
        if (value != null) builds.remove(value);
    }

    function find(view:Dynamic):VisualBuild {
        for (value in builds) if (value.view == view) return value;
        return null;
    }

    public function pending(view:Dynamic):Bool return find(view) != null;

    /** Equipment construction itself calls isReady; only outside observers wait. */
    public function ready(view:Dynamic, nativeReady:Bool):Bool {
        if (!nativeReady) return false;
        var value = find(view);
        return value == null || value == constructing;
    }

    public function defer(view:Dynamic, excludeGear:Bool):Bool {
        if (!candidates.remove(view) || excludeGear || G.field(view, "modelObj") == null
            || G.call("client.UnitView", "shouldShowGear", view) != true) return false;
        var worker = G.staticCall("lib.Workers", "get", []);
        if (worker == null) return false;
        var value:VisualBuild = {view: view, model: G.field(view, "modelObj"), owner: G.field(view, "gameObject"),
            worker: worker, steps: [], cursor: 0};
        function call(name:String, ?args:Array<Dynamic>):Void G.call("client.UnitView", name, view, args);
        function weapon(slot:String, index:Int):Void
            call("displayWeapon", [G.call("client.UnitView", "getSlotItemDisplayed", view, [slot]), index]);
        // Read gear/skin at execution time, so a gear update while loading cannot
        // restore an obsolete item. Preserve the native method order.
        value.steps.push(() -> weapon("Slot_Weapon1", 0));
        value.steps.push(() -> weapon("Slot_Weapon2", 1));
        value.steps.push(() -> weapon("Slot_OffhandWeapon", G.integer(G.current("client.UnitView", "OFFHAND_SLOT"))));
        value.steps.push(() -> call("displayWeapon", [G.field(G.field(view, "weaponOverride"), "inf"),
            G.current("client.UnitView", "WEAPON_OVERRIDE_SLOT")]));
        value.steps.push(() -> { call("updateWeaponsVisiblity"); call("refreshFx"); });
        value.steps.push(() -> call("displayGear", [null, G.current("client.UnitView", "MAIN_HEAD_SLOT")]));
        for (slot in G.array(G.current("DataCache", "EQUIPMENT_SLOTS")))
            value.steps.push(() -> call("displayGearSlot", [slot]));
        for (part in ["displayHair", "displayFacialHair", "displayEyes", "displayEyebrows"])
            value.steps.push(() -> {
                if (G.call("client.UnitView", "get_skinData", view) != null) call(part);
            });
        value.steps.push(() -> call("updateBlendShapes"));
        value.steps.push(() -> call("updateModelWeapon"));
        builds.push(value);
        try enqueue(value) catch (error:Dynamic) {
            builds.remove(value);
            throw error; // Nothing was changed; the hook may safely run native.
        }
        return true;
    }

    function valid(value:VisualBuild):Bool {
        return find(value.view) == value && G.field(value.view, "parent") != null
            && G.field(value.view, "modelObj") == value.model && G.field(value.view, "gameObject") == value.owner;
    }

    function enqueue(value:VisualBuild):Void {
        // Exactly one outstanding continuation per character, on the existing
        // MAIN-thread queue. Its loading budget/isEmpty semantics still apply.
        G.call("lib.Workers", "addJob", value.worker, [() -> step(value), false]);
    }

    function construct(value:VisualBuild, action:Void->Void):Void {
        // displayGearSlot returns immediately when isReady() is false. Preserve
        // the native result inside construction, including native fallback, but
        // keep checkReady completion blocked until all parts finish.
        var previous = constructing;
        constructing = value;
        StallMetrics.begin(FrameMetrics.CHARACTER_PART);
        try action() catch (error:Dynamic) {
            StallMetrics.end(FrameMetrics.CHARACTER_PART);
            constructing = previous;
            throw error;
        }
        StallMetrics.end(FrameMetrics.CHARACTER_PART);
        constructing = previous;
    }

    function step(value:VisualBuild):Void {
        if (!valid(value)) { builds.remove(value); return; }
        try {
            construct(value, value.steps[value.cursor++]);
            if (!valid(value)) { builds.remove(value); return; } // A callback can replace/remove the view.
            if (value.cursor < value.steps.length) enqueue(value);
            else finish(value);
        } catch (error:Dynamic) {
            report(error);
            if (!valid(value)) { builds.remove(value); return; }
            // Restore this live model through the native path on unexpected
            // incompatibility. New builds will no longer be intercepted.
            candidates.remove(value.view);
            try {
                construct(value, () -> G.call("client.UnitView", "updateDynamicVisuals", value.view, [false]));
                finish(value);
            } catch (fallback:Dynamic) {
                builds.remove(value);
                trace("[More Settings] Character visual fallback failed: " + Std.string(fallback));
            }
        }
    }

    function finish(value:VisualBuild):Void {
        // Remove the readiness barrier before invoking native onReady callbacks.
        builds.remove(value);
        G.call("client.UnitView", "checkReady", value.view);
        if (G.field(value.view, "parent") != null && G.field(value.view, "modelObj") == value.model
            && G.field(value.view, "gameObject") == value.owner)
            G.call("ent.Entity", "updateCulling", value.owner);
    }

    public function report(error:Dynamic):Void {
        if (!failed) trace("[More Settings] Staged character loading disabled: " + Std.string(error));
        failed = true;
    }
}
