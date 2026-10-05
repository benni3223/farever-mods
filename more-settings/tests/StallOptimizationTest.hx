import moresettings.CharacterVisualJobs;
import moresettings.PipelineWarmup;
import moresettings.GameAccess as G;
import sys.thread.Mutex;
import sys.thread.Thread;
import sys.thread.Lock;

class StallOptimizationTest {
    static function eq(actual:Dynamic, expected:Dynamic, label:String):Void {
        if (actual != expected) throw label + ": expected " + expected + ", got " + actual;
    }
    static function view():Dynamic {
        var hero:Dynamic = {};
        return {async:true, parent:{}, modelObj:null, hero:hero, gameObject:hero, skin:{}, item:"old"};
    }
    static function start(jobs:CharacterVisualJobs, view:Dynamic, enabled = true):Bool {
        jobs.begin(view, enabled);
        view.modelObj = {};
        var deferred = jobs.defer(view, false);
        jobs.end(view);
        return deferred;
    }
    static function drain():Void {
        var count = 0;
        while (G.jobs.length > 0) {
            if (++count > 100) throw "Runaway continuation";
            G.jobs.shift()();
        }
    }
    static function characters():Void {
        G.reset();
        var jobs = new CharacterVisualJobs();
        var v = view();
        eq(start(jobs, v), true, "initial remote model is staged");
        eq(G.calls.length, 0, "no whole appearance in the initial body job");
        eq(jobs.pending(v), true, "readiness held until cosmetics complete");
        eq(G.jobs.length, 1, "only one continuation queued");
        G.jobs.shift()();
        eq(G.calls.join(","), "displayWeapon:0:old", "first budgeted component");
        eq(G.jobs.length, 1, "next component queued separately");
        v.item = "new";
        G.jobs.shift()();
        eq(G.calls[1], "displayWeapon:1:new", "latest gear is read at execution");
        var readyCount = 0;
        G.onReady = () -> { eq(jobs.pending(v), false, "barrier removed before callbacks"); readyCount++; };
        // Disabling the option rejects NEW work but cannot discard accepted work.
        var disabled = view();
        eq(start(jobs, disabled, false), false, "disabled retains native path");
        drain();
        eq(readyCount, 1, "ready callback once after all components");
        eq(G.calls.join(","), "displayWeapon:0:old,displayWeapon:1:new,displayWeapon:2:new,displayWeapon:3:null,"
            + "updateWeaponsVisiblity,refreshFx,displayGear,displayGearSlot:Head,displayGearSlot:Chest,displayGearSlot:Feet,"
            + "displayHair,displayFacialHair,displayEyes,displayEyebrows,updateBlendShapes,updateModelWeapon,checkReady,updateCulling",
            "native component order and every equipment slot preserved");

        G.reset(); jobs = new CharacterVisualJobs();
        for (kind in ["local", "preview", "sync", "existing", "detached", "npc"]) {
            var other = view();
            switch kind {
                case "local": other.hero = G.me;
                case "preview": other.hero = null; other.gameObject = null;
                case "sync": other.async = false;
                case "existing": other.modelObj = {};
                case "detached": other.parent = null;
                case "npc": other.hero = null;
            }
            eq(start(jobs, other), false, kind + " retains synchronous native behavior");
        }
        eq(G.jobs.length, 0, "excluded views add no jobs");

        for (kind in ["remove", "replace", "owner", "dispose", "restart"]) {
            G.reset(); jobs = new CharacterVisualJobs(); v = view(); start(jobs, v);
            switch kind {
                case "remove": v.parent = null; jobs.cancel(v);
                case "replace": v.modelObj = {};
                case "owner": v.gameObject = {};
                case "dispose": jobs.clear();
                case "restart": jobs.begin(v, true); jobs.end(v);
            }
            drain();
            eq(G.calls.length, 0, kind + " stale work does not touch the model");
            eq(jobs.pending(v), false, kind + " releases barrier");
        }
        G.reset(); jobs = new CharacterVisualJobs(); v = view(); start(jobs, v);
        G.onAction = name -> v.modelObj = {};
        drain();
        eq(G.calls.length, 1, "replacement inside a component cancels its continuation");
        eq(jobs.pending(v), false, "reentrant cancellation releases state");

        G.reset(); jobs = new CharacterVisualJobs(); v = view(); start(jobs, v);
        G.onAction = name -> {
            if (name == "displayGearSlot") { G.onAction = null; throw "simulated asset failure"; }
        };
        drain();
        eq(jobs.pending(v), false, "failure releases pending state");
        eq(G.calls.indexOf("updateDynamicVisuals") >= 0, true, "failure restores through native visuals");
        eq(start(jobs, view()), false, "new staged work stops after incompatibility");

        G.reset(); jobs = new CharacterVisualJobs(); v = view(); G.enqueueFails = true;
        var caught = false;
        try start(jobs, v) catch (_:Dynamic) caught = true;
        eq(caught, true, "enqueue failure reaches native fallback hook");
        eq(jobs.pending(v), false, "enqueue failure cannot strand readiness");
    }

    static function pipelines():Void {
        G.reset();
        var now = 0.0;
        var warm = new PipelineWarmup(() -> now);
        var configs:Map<String, Dynamic> = ["s" => G.nativeArray([11, 22, 33])];
        var cache:Dynamic = {mutex:new Mutex(), configs:configs};
        var shader:Dynamic = {shader:{id:1, signature:"s"}, pipelineMutex:new Mutex()};
        var shaders:Map<Int, Dynamic> = [1 => shader];
        var driver:Dynamic = {psoConfigCache:cache, compiledShaders:shaders, compileMutex:new Mutex()};
        var app:Dynamic = {engine:{driver:driver}, hero:{isInCombat:false}, loading:false};
        eq(warm.defer(cache, shader), false, "no interception before main thread is known");
        warm.update(app, true, 0.016);
        eq(warm.defer(cache, shader), true, "foreground bulk replay is deferred");
        eq(warm.defer(cache, shader), true, "duplicate request coalesces");
        now = 3;
        app.hero.isInCombat = true;
        warm.update(app, true, 0.016);
        eq(G.replayed.length, 0, "no optional pipeline build in combat");
        app.hero.isInCombat = false;
        now = 4;
        warm.update(app, true, 0.016);
        eq(G.replayed.length, 0, "wait for quiet interval after combat");
        now = 6;
        warm.update(app, true, 0.016);
        eq(G.replayed.join(","), "11", "one variant per frame");
        eq(G.array(configs.get("s")).length, 3, "shared cache is not truncated or mutated");
        warm.update(app, true, 0.016);
        eq(G.replayed.join(","), "11,22", "continuation replays the next variant");
        warm.update(app, true, 0.060);
        eq(G.replayed.length, 2, "slow frames postpone optional work");
        now = 9;
        warm.update(app, true, 0.016);
        warm.update(app, true, 0.016);
        eq(G.replayed.join(","), "11,22,33", "coalesced request finishes once");

        var backgroundDone = new Lock();
        var backgroundDeferred = true;
        Thread.create(() -> {
            backgroundDeferred = warm.defer(cache, shader);
            backgroundDone.release();
        });
        eq(backgroundDone.wait(5), true, "background call returns");
        eq(backgroundDeferred, false, "native background warm-up remains native");

        // Contended native locks must postpone work instead of blocking rendering.
        var locks:Array<Mutex> = [cast cache.mutex, cast shader.pipelineMutex, cast driver.compileMutex];
        for (mutex in locks) {
            warm.defer(cache, shader);
            var held = new Lock(), release = new Lock(), done = new Lock();
            Thread.create(() -> {
                mutex.acquire(); held.release(); release.wait(5); mutex.release(); done.release();
            });
            eq(held.wait(5), true, "background lock acquired");
            var before = G.replayed.length;
            warm.update(app, true, 0.016);
            release.release();
            eq(done.wait(5), true, "background lock released");
            eq(G.replayed.length, before, "contended lock does not build a pipeline");
            warm.clear(); warm.update(app, true, 0.016); now += 3;
        }
        warm.defer(cache, shader);
        shaders.remove(1);
        var before = G.replayed.length;
        warm.update(app, true, 0.016);
        eq(G.replayed.length, before, "stale compiled shader rejected");
        shaders.set(1, shader);
        warm.defer(cache, shader);
        warm.invalidate(driver);
        warm.update(app, true, 0.016); now += 3; warm.update(app, true, 0.016);
        eq(G.replayed.length, before, "device reset drops retained graphics objects");
        warm.defer(cache, shader);
        warm.update(app, false, 0.016);
        eq(warm.defer(cache, shader), false, "disabled uses native path");
        warm.update(app, true, 0.016); now += 3; warm.update(app, true, 0.016);
        eq(G.replayed.length, before, "disabled clears optional work");
        app.loading = true; warm.update(app, true, 0.016);
        eq(warm.defer(cache, shader), false, "loading screen retains native bulk warm-up");
    }

    static function main():Void {
        characters();
        pipelines();
        trace("Stall optimization tests passed");
    }
}
