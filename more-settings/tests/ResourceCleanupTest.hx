import moresettings.ResourceCleanup;
import moresettings.GpuReleaseWorker;
import moresettings.GameAccess as G;
import moresettings.GpuResources as GPU;
import moresettings.StallMetrics;
import moresettings.FrameMetrics as M;
import moresettings.CleanupSample as C;
import sys.thread.Thread;
import sys.thread.Lock;

@:access(moresettings.StallMetrics)
@:access(moresettings.FrameMetrics)
class ResourceCleanupTest {
    static var checks = 0;
    static var serial = 0;
    static function eq(actual:Dynamic, expected:Dynamic, label:String):Void {
        checks++;
        if (actual != expected) throw label + ': expected $expected, got $actual';
    }
    static function objects(count:Int):Array<Dynamic> return [for (_ in 0...count)
        {id:serial++, ready:false, releases:0, worker:false, gate:null, entered:null}];
    static function frame(values:Array<Dynamic>):Dynamic return {
        toRelease:G.queue(values.copy()), bufferAllocator:{}, texHandlesToRelease:{}, bufHandlesToRelease:{}
    };
    static function fixture(count:Int = 100):Dynamic {
        GPU.released = []; GPU.failId = -1;
        GPU.mainThread = Thread.current();
        G.failSlice = false; G.failSwap = false;
        var values = objects(count);
        var d:Dynamic = {frame:frame(values), memory:{total:8e9, free:4e9},
            defaultDepth:{}, currentWidth:1920, currentHeight:1080};
        var app:Dynamic = {engine:{driver:d}, hero:{}, loading:false};
        var cleanup = new ResourceCleanup();
        cleanup.update(app, true);
        return {values:values, driver:d, app:app, cleanup:cleanup};
    }
    static function nativeDrain(queue:Dynamic):Void {
        while (queue.length > 0) GPU.release(G.call("hl.types.ArrayObj", "pop", queue));
    }
    static function checkpoint(f:Dynamic):Void {
        var c:ResourceCleanup = f.cleanup;
        c.beginFrame(f.driver);
        var values:Array<Dynamic> = f.driver.frame.toRelease.items;
        for (v in values) v.ready = true;
        c.recycle(f.driver.frame.bufferAllocator);
        nativeDrain(f.driver.frame.toRelease);
    }
    static function pass(f:Dynamic):Void { checkpoint(f); f.cleanup.endFrame(f.driver); }
    static function allOnce(values:Array<Dynamic>, worker:Bool, label:String):Void {
        for (v in values) {
            eq(v.releases, 1, label + " released once");
            eq(v.worker, worker, label + " correct thread");
        }
    }
    static function block(value:Dynamic):Void {
        value.gate = new Lock(); value.entered = new Lock();
    }
    static function diagnostics():Void {
        var now = 0.0;
        StallMetrics.configure(true);
        var metrics = new M(() -> now, 0);
        StallMetrics.metrics = metrics;
        for (mode in ["offloaded", "empty", "low-memory", "unknown-memory", "queue-limit", "disabled", "failed"]) {
            metrics.endFrame(); StallMetrics.beginFrame();
            var f = fixture(mode == "empty" ? 0 : mode == "queue-limit" ? ResourceCleanup.MAX_PENDING + 1 : 2);
            var c:ResourceCleanup = f.cleanup;
            var calls = 0;
            G.memoryRead = () -> { calls++; now += 1.957; };
            switch mode {
                case "low-memory": f.driver.memory.free = 100e6;
                case "unknown-memory": f.driver.memory = null;
                case "disabled": c.update(f.app, false);
                case "failed": c.fail("simulated failure");
                default:
            }
            pass(f);
            var sample = metrics.cleanup;
            var event = switch mode {
                case "offloaded": C.SUBMITTED;
                case "empty": C.EMPTY;
                case "low-memory": C.LOW_MEMORY;
                case "unknown-memory": C.UNKNOWN_MEMORY;
                case "queue-limit": C.QUEUE_LIMIT;
                case "disabled": C.DISABLED;
                case "failed": C.FAILED;
                default: -1;
            };
            eq((sample.events & (1 << event)) != 0, true, mode + " records its actual outcome");
            eq(sample.staged, mode == "offloaded" ? 2 : 0, mode + " stage count");
            eq(sample.submitted, mode == "offloaded" ? 2 : 0, mode + " published count");
            eq(sample.memoryReads, calls, mode + " adds no memory queries");
            eq(Math.round(metrics.totals[M.CLEANUP_MEMORY] * 1000), calls * 1957, mode + " isolates memory-query delay");
            c.suspend(); allOnce(f.values, mode == "offloaded", mode + " preserves ownership with diagnostics enabled");
        }
        G.memoryRead = null;
        metrics.endFrame(); StallMetrics.beginFrame();
        var f = fixture(1); var c:ResourceCleanup = f.cleanup;
        block(f.values[0]); pass(f);
        eq(f.values[0].entered.wait(3), true, "diagnostic pressure worker entered");
        // Include an empty frame while the worker is busy: pending work must remain visible.
        metrics.endFrame(); StallMetrics.beginFrame(); pass(f);
        eq(metrics.cleanup.pendingMax, 1, "empty current queue still reports an in-flight release");
        var newer = objects(2); f.driver.frame = frame(newer); f.driver.memory.free = 0;
        var gate:Lock = f.values[0].gate;
        Thread.create(() -> { Sys.sleep(0.02); gate.release(); });
        pass(f);
        eq((metrics.cleanup.events & (1 << C.PRESSURE_JOIN)) != 0, true, "blocking fallback records pressure join");
        eq(metrics.counts[M.CLEANUP_JOIN], 1, "worker wait has its own timing scope");
        c.suspend(); allOnce(f.values, true, "diagnostic old ownership"); allOnce(newer, false, "diagnostic native fallback");

        metrics.endFrame(); StallMetrics.beginFrame(); f = fixture(1); c = f.cleanup;
        var values:Array<Dynamic> = f.values; for (v in values) v.ready = true;
        G.memoryRead = () -> { now += 0.7; throw "memory query failed"; };
        c.beginFrame(f.driver);
        try c.recycle(f.driver.frame.bufferAllocator) catch (error:Dynamic) c.fail(error);
        eq(metrics.depth[M.CLEANUP_MEMORY], 0, "failed memory query closes timing scope");
        eq(metrics.depth[M.CLEANUP_HOOK], 0, "failed cleanup closes timing scope");
        eq((metrics.cleanup.events & (1 << C.ERROR)) != 0, true, "failed hook records error");
        nativeDrain(f.driver.frame.toRelease); c.endFrame(f.driver); c.suspend();
        allOnce(values, false, "failed diagnostic query preserves native ownership");
        G.memoryRead = null; StallMetrics.configure(false);
    }
    static function main():Void {
        // Single-resource queues must also move off the main thread. Hold a release
        // open and prove subsequent frames / submissions continue independently.
        var f = fixture(1); var c:ResourceCleanup = f.cleanup;
        block(f.values[0]);
        c.recycle(f.driver.frame.bufferAllocator);
        eq(GPU.released.length, 0, "no work before beginFrame");
        c.beginFrame(f.driver); c.recycle({}); c.endFrame(f.driver);
        eq(GPU.released.length, 0, "unrelated allocator ignored");
        checkpoint(f);
        eq(f.values[0].releases, 0, "staged until native resets finish");
        eq(f.values[0].entered.wait(0), false, "no early worker publication");
        c.endFrame(f.driver);
        eq(f.values[0].entered.wait(3), true, "single expensive release reaches worker");
        eq(f.values[0].releases, 0, "producer returned while release remains blocked");
        c.resize(f.driver, 1920, 1080);
        eq(f.values[0].releases, 0, "no-op resize does not wait for blocked release");
        var second = objects(90); f.driver.frame = frame(second); pass(f);
        eq(second[89].releases, 0, "single consumer preserves FIFO batches");
        var future = objects(1)[0];
        G.call("hl.types.ArrayObj", "push", f.driver.frame.toRelease, [future]);
        f.values[0].gate.release(); c.suspend();
        eq(future.releases, 0, "shutdown does not touch unfenced native queue");
        allOnce(f.values, true, "single blocked release"); allOnce(second, true, "later frame");
        eq(GPU.released[1].id, second[89].id, "native reverse order within batch");

        for (size in [0, 20, 64, 130]) {
            f = fixture(size); c = f.cleanup;
            var original = f.driver.frame.toRelease;
            var tex = f.driver.frame.texHandlesToRelease, buf = f.driver.frame.bufHandlesToRelease;
            pass(f); c.suspend();
            eq(f.driver.frame.toRelease == original, size == 0, "nonempty queues transferred regardless of size");
            eq(f.driver.frame.texHandlesToRelease == tex, true, "texture descriptors stay native");
            eq(f.driver.frame.bufHandlesToRelease == buf, true, "buffer descriptors stay native");
            allOnce(f.values, true, "complete batch");
        }
        for (mode in ["disabled", "loading", "no-hero"]) {
            f = fixture(2); c = f.cleanup;
            if (mode == "loading") f.app.loading = true;
            if (mode == "no-hero") f.app.hero = null;
            c.update(f.app, mode != "disabled"); pass(f); c.suspend();
            allOnce(f.values, false, mode);
        }
        for (mode in ["disable", "load", "world-end", "driver-reset", "driver-replace", "resize"]) {
            f = fixture(20); c = f.cleanup; checkpoint(f); // Include an unpublished batch.
            switch mode {
                case "disable": c.update(f.app, false);
                case "load": f.app.loading = true; c.update(f.app, true);
                case "world-end": c.suspend();
                case "driver-reset": c.invalidate(f.driver);
                case "resize": c.resize(f.driver, 2560, 1440);
                case "driver-replace": f.app.engine.driver = {}; c.update(f.app, true);
            }
            allOnce(f.values, true, mode + " joins accepted ownership");
        }
        for (mode in ["low-free", "low-percent", "unknown", "oversized"]) {
            f = fixture(mode == "oversized" ? ResourceCleanup.MAX_PENDING + 1 : 2); c = f.cleanup;
            switch mode {
                case "low-free": f.driver.memory.free = 100e6;
                case "low-percent": f.driver.memory = {free:600e6, total:16e9};
                case "unknown": f.driver.memory = null;
                default:
            }
            var original = f.driver.frame.toRelease;
            pass(f); c.suspend();
            eq(f.driver.frame.toRelease == original, true, mode + " retains native ownership");
            allOnce(f.values, false, mode);
        }
        // In-flight work counts against the cap. A pressure drain waits for the
        // consumer without holding its mutex, then leaves new work with the game.
        f = fixture(1); c = f.cleanup; block(f.values[0]); pass(f);
        eq(f.values[0].entered.wait(3), true, "pressure test worker entered");
        var newer = objects(ResourceCleanup.MAX_PENDING); f.driver.frame = frame(newer);
        var gate:Lock = f.values[0].gate;
        Thread.create(() -> { Sys.sleep(0.02); gate.release(); });
        pass(f); c.suspend();
        allOnce(f.values, true, "pressure old ownership"); allOnce(newer, false, "pressure new ownership");

        // All interop/allocations precede transfer; even a late pointer conversion
        // failure leaves the full original queue intact and unreleased.
        for (mode in ["slice", "swap", "conversion"]) {
            f = fixture(4); c = f.cleanup;
            var original = f.driver.frame.toRelease;
            var values:Array<Dynamic> = f.values;
            for (v in values) v.ready = true;
            c.beginFrame(f.driver);
            G.failSlice = mode == "slice"; G.failSwap = mode == "swap";
            GPU.failId = mode == "conversion" ? values[3].id : -1;
            var failed = false;
            try c.recycle(f.driver.frame.bufferAllocator) catch (error:Dynamic) {
                failed = true; G.failSlice = false; G.failSwap = false; GPU.failId = -1;
                c.fail(error);
            }
            eq(failed, true, mode + " actually failed");
            eq(f.driver.frame.toRelease == original, true, mode + " preserves queue");
            nativeDrain(original); c.suspend(); allOnce(values, false, mode);
        }
        f = fixture(3); c = f.cleanup;
        c.beginFrame(f.driver); c.beginFrame(f.driver); c.recycle(f.driver.frame.bufferAllocator);
        eq(GPU.released.length, 0, "recursive beginFrame ignored");
        c.endFrame(f.driver); c.endFrame(f.driver);
        checkpoint(f); c.update(f.app, true); c.suspend();
        allOnce(f.values, true, "interrupted postfix recovers staged ownership");
        // Restart after a lifecycle transition and reject unrelated thread hooks.
        var again = objects(2); f.driver.frame = frame(again); c.update(f.app, true);
        var done = new Lock();
        Thread.create(() -> {
            c.beginFrame(f.driver); c.recycle(f.driver.frame.bufferAllocator); c.suspend();
            c.invalidate(f.driver); c.update(f.app, false); done.release();
        });
        eq(done.wait(3), true, "foreign hooks returned");
        eq(again[0].releases, 0, "foreign hooks cannot take ownership");
        pass(f); c.suspend(); allOnce(again, true, "worker restarts");

        // Queue publication itself also has a strong ownership boundary.
        var worker = new GpuReleaseWorker();
        var item = objects(1)[0]; item.ready = true;
        var failed = false;
        try worker.submit([item], () -> { throw "ownership commit failed"; }) catch (_:Dynamic) failed = true;
        eq(failed, true, "failed queue commit detected");
        eq(worker.pending(), 0, "failed commit not counted");
        worker.close(); worker.close();
        eq(item.releases, 0, "failed commit never consumed");
        GPU.release(item);
        diagnostics();
        Sys.println('ResourceCleanupTest: $checks checks passed');
    }
}
