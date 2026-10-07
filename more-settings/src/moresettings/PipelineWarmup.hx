package moresettings;

import moresettings.GameAccess as G;
import sys.thread.Mutex;
import sys.thread.Thread;

private typedef PipelineReplay = {
    var cache:Dynamic;
    var shader:Dynamic;
    var variants:Dynamic;
    var cursor:Int;
}

/** Incremental replay of optional DX12 cache entries, never a replacement for drawing. */
class PipelineWarmup {
    static inline var MAX_PENDING = 128;
    static inline var QUIET_SECONDS = 2.0;
    var mainThread:Null<Thread>;
    var driver:Dynamic;
    var active:Bool = false;
    var replaying:Bool = false;
    var quietAfter:Float = 0;
    var pending:Array<PipelineReplay> = [];
    var proxy:Dynamic;
    var clock:Void->Float;

    public function new(?clock:Void->Float) this.clock = clock == null ? haxe.Timer.stamp : clock;

    public function clear():Void {
        pending = [];
        proxy = null;
        driver = null;
        active = false;
    }

    public function invalidate(value:Dynamic):Void {
        if (onMainThread() && driver == value) clear();
    }

    function onMainThread():Bool return mainThread != null && Thread.current() == mainThread;

    /** Called only from GameApp.update, before rendering. */
    public function update(app:Dynamic, enabled:Bool, dt:Float):Void {
        if (mainThread == null) mainThread = Thread.current();
        var next = G.field(G.field(app, "engine"), "driver");
        if (!enabled || next != driver) {
            clear();
            quietAfter = clock() + QUIET_SECONDS;
        }
        if (!enabled) return;
        driver = next;
        // Do not change startup/loading-screen shader warm-up or other renderers.
        active = driver != null && G.field(driver, "psoConfigCache") != null
            && G.call("GameApp", "get_isLoading", app) != true;
        var hero = G.field(app, "hero");
        if (!active || hero == null || G.field(hero, "isInCombat") != false || dt > 0.025 || dt <= 0) {
            quietAfter = clock() + QUIET_SECONDS;
            return;
        }
        if (clock() >= quietAfter && pending.length > 0) step();
    }

    /** Background shader-loader calls continue untouched. No reflection off-thread. */
    public function defer(cache:Dynamic, shader:Dynamic):Bool {
        if (!onMainThread() || !active || replaying || cache != G.field(driver, "psoConfigCache")) return false;
        for (entry in pending) if (entry.shader == shader) return true;
        // Optional work can be dropped under pressure: flushPipeline still creates
        // every pipeline required by a real draw, using the game's normal cache.
        if (pending.length < MAX_PENDING)
            pending.push({cache: cache, shader: shader, variants: null, cursor: 0});
        return true;
    }

    function step():Void {
        var entry = pending[0];
        var runtime = G.field(entry.shader, "shader");
        var compileLock = G.mutex(G.field(driver, "compileMutex"));
        if (!compileLock.tryAcquire()) return;
        var compiled:Dynamic;
        try compiled = G.call("haxe.ds.IntMap", "get", G.field(driver, "compiledShaders"), [G.field(runtime, "id")])
        catch (error:Dynamic) { compileLock.release(); throw error; }
        compileLock.release();
        if (compiled != entry.shader || entry.cache != G.field(driver, "psoConfigCache")) {
            pending.shift();
            return;
        }
        var signature = G.field(runtime, "signature");
        if (entry.variants == null) {
            var lock = G.mutex(G.field(entry.cache, "mutex"));
            // A background loader may own this lock. Never wait for it here.
            if (!lock.tryAcquire()) return;
            try {
                var variants = G.call("haxe.ds.StringMap", "get", G.field(entry.cache, "configs"), [signature]);
                if (variants != null) entry.variants = G.call("hl.types.ArrayObj", "copy", variants);
            } catch (error:Dynamic) {
                lock.release();
                throw error;
            }
            lock.release();
        }
        if (entry.cursor >= G.integer(G.field(entry.variants, "length"))) {
            pending.shift();
            return;
        }
        // The native mutex is recursive. Avoid waiting on background compilation;
        // native resolveConfig takes this same lock again around makePipeline.
        var pipelineLock = G.mutex(G.field(entry.shader, "pipelineMutex"));
        if (!pipelineLock.tryAcquire()) return;
        replaying = true;
        try {
            if (proxy == null) {
                proxy = G.create("h3d.impl.PSOConfigCache", ["", ""]);
                G.set(proxy, "configs", G.create("haxe.ds.StringMap", []));
            }
            var configs = G.field(proxy, "configs");
            var one = G.call("hl.types.ArrayObj", "slice", entry.variants, [entry.cursor, entry.cursor + 1]);
            G.call("haxe.ds.StringMap", "set", configs, [signature, one]);
            // Use the native signature decoder, input-count validation, dedup,
            // invalid-config handling and pipeline creation without copying them.
            G.call("h3d.impl.PSOConfigCache", "resolveConfig", proxy, [entry.shader]);
            G.call("haxe.ds.StringMap", "remove", configs, [signature]);
            entry.cursor++;
        } catch (error:Dynamic) {
            replaying = false;
            pipelineLock.release();
            throw error;
        }
        replaying = false;
        pipelineLock.release();
        if (entry.cursor >= G.integer(G.field(entry.variants, "length"))) pending.shift();
    }
}
