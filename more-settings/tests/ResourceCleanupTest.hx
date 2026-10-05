import moresettings.ResourceCleanup;
import moresettings.GameAccess as G;
import moresettings.GpuResources as GPU;

class ResourceCleanupTest {
    static var checks = 0;
    static var serial = 0;
    static function eq(actual:Dynamic, expected:Dynamic, label:String):Void {
        checks++;
        if (actual != expected) throw label + ': expected $expected, got $actual';
    }
    static function objects(count:Int):Array<Dynamic> return [for (_ in 0...count) {id:serial++, ready:false, releases:0}];
    static function frame(values:Array<Dynamic>):Dynamic return {
        toRelease:G.queue(values.copy()), bufferAllocator:{}, texHandlesToRelease:{}, bufHandlesToRelease:{}
    };
    static function fixture(count:Int = 100):Dynamic {
        GPU.now = 0; GPU.cost = 0; GPU.released = []; GPU.failId = -1;
        G.failSlice = false; G.failSwap = false;
        var values = objects(count);
        var d:Dynamic = {frame:frame(values), memory:{total:8e9, free:4e9}};
        var app:Dynamic = {engine:{driver:d}, hero:{}, loading:false};
        var cleanup = new ResourceCleanup(() -> GPU.now);
        cleanup.update(app, true);
        return {values:values, driver:d, app:app, cleanup:cleanup};
    }
    static function nativeDrain(queue:Dynamic):Void {
        while (queue.length > 0) GPU.release(G.call("hl.types.ArrayObj", "pop", queue));
    }
    static function pass(f:Dynamic):Void {
        var c:ResourceCleanup = f.cleanup;
        c.beginFrame(f.driver);
        // Native waitForFrame and buffer reset complete before this checkpoint.
        var queue = f.driver.frame.toRelease;
        var items:Array<Dynamic> = queue.items;
        for (value in items) value.ready = true;
        c.recycle(f.driver.frame.bufferAllocator);
        nativeDrain(f.driver.frame.toRelease);
        c.endFrame(f.driver);
    }
    static function allOnce(values:Array<Dynamic>, label:String):Void {
        for (v in values) eq(v.releases, 1, label);
    }
    static function main():Void {
        var f = fixture();
        var c:ResourceCleanup = f.cleanup;
        var original = f.driver.frame.toRelease;
        c.recycle(f.driver.frame.bufferAllocator);
        eq(GPU.released.length, 0, "no work before native beginFrame");
        c.beginFrame(f.driver); c.recycle({}); c.endFrame(f.driver);
        eq(GPU.released.length, 0, "unrelated allocator ignored");
        var tex = f.driver.frame.texHandlesToRelease;
        var buf = f.driver.frame.bufHandlesToRelease;
        pass(f);
        eq(GPU.released.length, ResourceCleanup.MAX_PER_FRAME, "large batch is bounded");
        eq(f.driver.frame.toRelease == original, false, "future disposals use a different native queue");
        eq(f.driver.frame.texHandlesToRelease == tex, true, "texture handles stay native");
        eq(f.driver.frame.bufHandlesToRelease == buf, true, "buffer handles stay native");
        var future = objects(1)[0];
        G.call("hl.types.ArrayObj", "push", f.driver.frame.toRelease, [future]);
        c.suspend(); // Only previously fence-safe work may drain here.
        eq(future.releases, 0, "shutdown never drains newly enqueued unsafe resources");
        allOnce(f.values, "all accepted resources released once");

        f = fixture(20); original = f.driver.frame.toRelease; pass(f);
        eq(f.driver.frame.toRelease == original, true, "small queues stay native");
        allOnce(f.values, "small queue native release");
        f = fixture(); GPU.cost = 0.001; pass(f);
        eq(GPU.released.length, 2, "2 ms budget stops between releases");
        GPU.cost = 0; pass(f); pass(f); allOnce(f.values, "budgeted batch completes");
        f = fixture(); GPU.cost = 0.8; pass(f);
        eq(GPU.released.length, 1, "one blocking native call cannot be preempted");
        GPU.cost = 0; f.cleanup.suspend();

        // Each frame has a separate safety boundary. An old ready batch can be
        // drained on a different frame, but its new native queue cannot.
        f = fixture(130); pass(f);
        var second = objects(90);
        f.driver.frame = frame(second);
        pass(f);
        eq(second[89].releases, 0, "older batches are serviced first");
        pass(f); pass(f);
        allOnce(f.values, "first frame ownership"); allOnce(second, "second frame ownership");

        for (mode in ["disabled", "loading", "no-hero"]) {
            f = fixture(); c = f.cleanup;
            if (mode == "loading") f.app.loading = true;
            if (mode == "no-hero") f.app.hero = null;
            c.update(f.app, mode != "disabled");
            original = f.driver.frame.toRelease;
            pass(f);
            eq(f.driver.frame.toRelease == original, true, mode + " native path");
            allOnce(f.values, mode + " original cleanup");
        }
        for (mode in ["disable", "load", "world-end", "driver-reset", "driver-replace"]) {
            f = fixture(); c = f.cleanup; pass(f);
            switch mode {
                case "disable": c.update(f.app, false);
                case "load": f.app.loading = true; c.update(f.app, true);
                case "world-end": c.suspend();
                case "driver-reset": c.invalidate(f.driver);
                case "driver-replace": f.app.engine.driver = {}; c.update(f.app, true);
            }
            allOnce(f.values, mode + " drains accepted ownership");
        }
        for (mode in ["low-free", "low-percent", "unknown", "age", "count"]) {
            f = fixture(); c = f.cleanup; pass(f);
            var newer = objects(mode == "count" ? ResourceCleanup.MAX_PENDING : 90);
            f.driver.frame = frame(newer);
            original = f.driver.frame.toRelease;
            switch mode {
                case "low-free": f.driver.memory.free = 100e6;
                case "low-percent": f.driver.memory = {free:600e6, total:16e9};
                case "unknown": f.driver.memory = null;
                case "age": GPU.now = ResourceCleanup.MAX_AGE_SECONDS;
                default:
            }
            pass(f);
            eq(f.driver.frame.toRelease == original, true, mode + " stops retaining resources");
            allOnce(f.values, mode + " old backlog drained");
            allOnce(newer, mode + " new queue stays native");
        }

        // Failures before ownership transfer leave the game's queue untouched.
        for (mode in ["slice", "swap"]) {
            f = fixture(); c = f.cleanup; original = f.driver.frame.toRelease;
            var values:Array<Dynamic> = f.values;
            for (v in values) v.ready = true;
            c.beginFrame(f.driver);
            G.failSlice = mode == "slice"; G.failSwap = mode == "swap";
            try { c.recycle(f.driver.frame.bufferAllocator); throw "expected failure"; }
            catch (error:Dynamic) {
                G.failSlice = false; G.failSwap = false;
                c.fail(error);
            }
            eq(f.driver.frame.toRelease == original, true, mode + " preserves queue");
            nativeDrain(original); c.suspend(); allOnce(f.values, mode + " no lost ownership");
        }
        f = fixture(); c = f.cleanup; GPU.failId = f.values[98].id;
        c.beginFrame(f.driver);
        var values:Array<Dynamic> = f.values;
        for (v in values) v.ready = true;
        try c.recycle(f.driver.frame.bufferAllocator) catch (error:Dynamic) c.fail(error);
        GPU.failId = -1;
        eq(GPU.released.length, 1, "failure after partial progress");
        nativeDrain(f.driver.frame.toRelease); c.suspend();
        allOnce(f.values, "failure returns only unconsumed resources to native");

        f = fixture(); c = f.cleanup; c.beginFrame(f.driver); c.beginFrame(f.driver);
        c.recycle(f.driver.frame.bufferAllocator);
        eq(GPU.released.length, 0, "recursive beginFrame is not intercepted");
        c.endFrame(f.driver); c.endFrame(f.driver); pass(f);
        // Simulate missing postfix, then a new update and frame.
        c.beginFrame(f.driver); c.update(f.app, true); pass(f);
        allOnce(f.values, "interrupted scope recovers without losing backlog");
        f = fixture(); c = f.cleanup;
        var finished = new sys.thread.Lock();
        sys.thread.Thread.create(() -> {
            c.beginFrame(f.driver); c.recycle(f.driver.frame.bufferAllocator); c.suspend();
            c.invalidate(f.driver); c.update(f.app, false); finished.release();
        });
        finished.wait();
        eq(GPU.released.length, 0, "background calls do not mutate ownership");
        pass(f); c.suspend(); allOnce(f.values, "main thread still owns cleanup");
        Sys.println('ResourceCleanupTest: $checks checks passed');
    }
}
