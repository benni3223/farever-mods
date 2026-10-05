package moresettings;

import moresettings.GameAccess as G;
import moresettings.GpuResources.GpuResource;
import sys.thread.Thread;

/** Transfers only the native, fence-safe beginFrame retirement queue. */
class ResourceCleanup {
    public static inline var MAX_PENDING = 4096;
    public static inline var MIN_FREE_BYTES = 512.0 * 1024 * 1024;

    var mainThread:Null<Thread>;
    var driver:Dynamic;
    var active = false;
    var failed = false;
    var scope:Dynamic;
    var depth = 0;
    var handled = false;
    var worker:Null<GpuReleaseWorker>;
    var staged:Null<Array<GpuResource>>;

    public function new() {}
    function onMainThread():Bool return mainThread != null && Thread.current() == mainThread;

    public function update(app:Dynamic, enabled:Bool):Void {
        if (mainThread == null) mainThread = Thread.current();
        if (!onMainThread()) return;
        // Recover accepted ownership if a native exception omitted the postfix.
        publish();
        scope = null; depth = 0;
        var next = G.field(G.field(app, "engine"), "driver");
        var gameplay = enabled && !failed && next != null && G.field(app, "hero") != null
            && G.call("GameApp", "get_isLoading", app) == false;
        if (next != driver || !gameplay) {
            finish();
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
        if (--depth == 0) {
            scope = null;
            // Copy-command resets and descriptor retirement have also completed.
            publish();
        }
    }

    /** Called after BufferAllocator.reset, before the native resource-release loop. */
    public function recycle(allocator:Dynamic):Void {
        if (!onMainThread() || !active || depth != 1 || handled || scope != driver) return;
        var frame = G.field(driver, "frame");
        if (frame == null || allocator != G.field(frame, "bufferAllocator")) return;
        handled = true;
        var resources = G.field(frame, "toRelease");
        var count = G.integer(G.field(resources, "length"));
        if (count == 0) return;
        var pending = worker == null ? 0 : worker.pending();
        if (pending + count > MAX_PENDING || !hasHeadroom()) {
            finish();
            return; // Keep the current native queue intact under memory pressure.
        }

        // Resolve every pointer before removing the game's ownership. The worker
        // receives only mod-owned arrays of native references, never game objects.
        var owned:Array<GpuResource> = [];
        for (i in 0...count)
            owned.push(GpuResources.resolve(G.call("hl.types.ArrayObj", "getDyn", resources, [i])));
        var empty = G.call("hl.types.ArrayObj", "slice", resources, [0, 0]);
        if (worker == null) worker = new GpuReleaseWorker();
        G.set(frame, "toRelease", empty);
        staged = owned;
    }

    function hasHeadroom():Bool {
        var usage = G.call("h3d.impl.DX12Driver", "getMemoryUsage", driver);
        var total = G.number(G.field(usage, "total"), Math.NaN);
        var free = G.number(G.field(usage, "free"), Math.NaN);
        return Math.isFinite(total) && Math.isFinite(free) && total > 0
            && free >= Math.max(MIN_FREE_BYTES, total * 0.10);
    }

    function publish():Void {
        if (staged != null) worker.submit(staged, () -> staged = null);
    }

    function finish():Void {
        publish();
        if (worker != null) {
            worker.close();
            worker = null;
        }
    }

    /** Lifecycle waits own only resources that already passed their original fence. */
    public function suspend():Void {
        if (!onMainThread()) return;
        active = false; scope = null; depth = 0;
        finish();
    }

    public function invalidate(value:Dynamic):Void {
        if (!onMainThread() || value != driver) return;
        suspend();
        driver = null;
    }

    public function resize(value:Dynamic, width:Int, height:Int):Void {
        if (!onMainThread() || value != driver || G.field(value, "defaultDepth") == null) return;
        // Match native resize's early return; a no-op must not join a busy worker.
        if (G.integer(G.field(value, "currentWidth")) == Std.int(Math.max(1, width))
                && G.integer(G.field(value, "currentHeight")) == Std.int(Math.max(1, height))) return;
        invalidate(value);
    }

    public function fail(error:Dynamic):Void {
        active = false; scope = null; depth = 0;
        var first = !failed;
        failed = true;
        // Unaccepted references are still native. Accepted references need no
        // fallible game reflection to finish and must not be returned twice.
        finish();
        if (first) trace("[More Settings] Background GPU cleanup disabled: " + Std.string(error));
    }
}
