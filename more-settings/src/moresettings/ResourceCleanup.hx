package moresettings;

import moresettings.GameAccess as G;
import sys.thread.Thread;

private typedef RetiredResources = {
    var resources:Dynamic;
    var since:Float;
}

/** Only accepts resources at the native, fence-safe beginFrame release point. */
class ResourceCleanup {
    public static inline var MAX_PER_FRAME = 64;
    public static inline var BUDGET_SECONDS = 0.002;
    public static inline var MAX_PENDING = 4096;
    public static inline var MAX_AGE_SECONDS = 2.0;
    public static inline var MIN_FREE_BYTES = 512.0 * 1024 * 1024;

    var mainThread:Null<Thread>;
    var driver:Dynamic;
    var active = false;
    var failed = false;
    var scope:Dynamic;
    var depth = 0;
    var handled = false;
    var batches:Array<RetiredResources> = [];
    var pending = 0;
    var clock:Void->Float;

    public function new(?clock:Void->Float) this.clock = clock == null ? haxe.Timer.stamp : clock;
    function onMainThread():Bool return mainThread != null && Thread.current() == mainThread;

    public function update(app:Dynamic, enabled:Bool):Void {
        if (mainThread == null) mainThread = Thread.current();
        if (!onMainThread()) return;
        // A native exception can omit beginFrame's postfix. No queue is borrowed
        // temporarily, so clearing this scope cannot lose an owned resource.
        scope = null; depth = 0;
        var next = G.field(G.field(app, "engine"), "driver");
        var gameplay = enabled && !failed && next != null && G.field(app, "hero") != null
            && G.call("GameApp", "get_isLoading", app) == false;
        if (next != driver || !gameplay) {
            drainAll();
            driver = next;
        }
        active = gameplay;
    }

    public function beginFrame(value:Dynamic):Void {
        if (!onMainThread() || value != driver || !active) return;
        if (depth++ == 0) { scope = value; handled = false; }
    }

    public function endFrame(value:Dynamic):Void {
        if (!onMainThread() || value != scope || depth == 0) return;
        if (--depth == 0) scope = null;
    }

    /** Called after BufferAllocator.reset, before the native resource-release loop. */
    public function recycle(allocator:Dynamic):Void {
        if (!onMainThread() || !active || depth != 1 || handled || scope != driver) return;
        var frame = G.field(driver, "frame");
        if (frame == null || allocator != G.field(frame, "bufferAllocator")) return;
        handled = true;
        var resources = G.field(frame, "toRelease");
        var count = length(resources);
        if (pending == 0 && count <= MAX_PER_FRAME) return;

        var now = clock();
        // A count/age limit bounds backlog; the DXGI budget check also accounts
        // for large resources, whose byte sizes aren't stored in this queue.
        if (pending + count > MAX_PENDING || (batches.length > 0 && now - batches[0].since >= MAX_AGE_SECONDS)
                || !hasHeadroom()) {
            drainAll();
            return; // The current native queue is still intact and drains normally.
        }

        if (count > 0) {
            // Both arrays belong to the game module. Allocate everything before
            // the field swap; the game gets a new queue for future, unsafe frees.
            var empty = G.call("hl.types.ArrayObj", "slice", resources, [0, 0]);
            var batch:RetiredResources = {resources: resources, since: now};
            batches.push(batch);
            try G.set(frame, "toRelease", empty) catch (error:Dynamic) {
                batches.pop();
                throw error;
            }
            pending += count;
        }
        var started = clock();
        var released = 0;
        while (pending > 0) {
            releaseOne();
            if (++released >= MAX_PER_FRAME || clock() - started >= BUDGET_SECONDS) break;
        }
    }

    function hasHeadroom():Bool {
        var usage = G.call("h3d.impl.DX12Driver", "getMemoryUsage", driver);
        var total = G.number(G.field(usage, "total"), Math.NaN);
        var free = G.number(G.field(usage, "free"), Math.NaN);
        return Math.isFinite(total) && Math.isFinite(free) && total > 0
            && free >= Math.max(MIN_FREE_BYTES, total * 0.10);
    }

    static function length(value:Dynamic):Int return G.integer(G.field(value, "length"));

    function releaseOne():Void {
        var batch = batches[0];
        var index = length(batch.resources) - 1;
        // Conversion can fail; do it before taking ownership out of the queue.
        var resource = GpuResources.resolve(G.call("hl.types.ArrayObj", "getDyn", batch.resources, [index]));
        // Match native ordering: remove from the queue before IUnknown::Release.
        // No fallible reflection follows the release that could retry a freed ptr.
        G.call("hl.types.ArrayObj", "pop", batch.resources);
        pending--;
        if (index == 0) batches.shift();
        GpuResources.release(resource);
    }

    function drainAll():Void {
        while (pending > 0) releaseOne();
    }

    /** These resources already passed their original frame's fence. */
    public function suspend():Void {
        if (!onMainThread()) return;
        active = false; scope = null; depth = 0;
        drainAll();
    }

    public function invalidate(value:Dynamic):Void {
        if (!onMainThread() || value != driver) return;
        suspend();
        driver = null;
    }

    /** Stop deferring on incompatibility; hand remaining ownership back to the game. */
    public function fail(error:Dynamic):Void {
        active = false; scope = null; depth = 0;
        var first = !failed;
        failed = true;
        var target = G.field(G.field(driver, "frame"), "toRelease");
        if (pending > 0 && target != null) {
            while (pending > 0) {
                var batch = batches[0];
                var index = length(batch.resources) - 1;
                var resource = G.call("hl.types.ArrayObj", "getDyn", batch.resources, [index]);
                G.call("hl.types.ArrayObj", "push", target, [resource]);
                G.call("hl.types.ArrayObj", "pop", batch.resources);
                pending--;
                if (index == 0) batches.shift();
            }
        }
        if (first) trace("[More Settings] Incremental GPU cleanup disabled: " + Std.string(error));
    }
}
