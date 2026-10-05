package moresettings;

import moresettings.GpuResources.GpuResource;
import sys.thread.Lock;
import sys.thread.Mutex;
import sys.thread.Thread;

private typedef ReleaseBatch = {
    var resources:Array<GpuResource>;
    var next:Null<ReleaseBatch>;
}

/** A single consumer of already-retired COM references. Never accesses the game. */
class GpuReleaseWorker {
    final mutex = new Mutex();
    final wake = new Lock();
    final stopped = new Lock();
    var first:Null<ReleaseBatch>;
    var last:Null<ReleaseBatch>;
    var count = 0;
    var closing = false;
    var closed = false;

    public function new() {
        // Creation precedes ownership transfer; failure leaves the game in charge.
        Thread.create(run);
    }

    public function pending():Int {
        mutex.acquire();
        var result = count;
        mutex.release();
        return result;
    }

    /** Main-thread producer: allocate before committing ownership. */
    public function submit(resources:Array<GpuResource>, transfer:Void->Void):Void {
        var batch:ReleaseBatch = {resources:resources, next:null};
        mutex.acquire();
        if (closing) {
            mutex.release();
            throw "GPU cleanup worker is closing";
        }
        try transfer() catch (error:Dynamic) {
            mutex.release();
            throw error;
        }
        // No allocations or fallible interop after the ownership commit.
        if (last == null) first = batch; else last.next = batch;
        last = batch;
        count += resources.length;
        mutex.release();
        wake.release();
    }

    /** Lifecycle/pressure boundary only. Never wait holding the queue mutex. */
    public function close():Void {
        if (closed) return;
        mutex.acquire();
        closing = true;
        mutex.release();
        wake.release();
        stopped.wait();
        closed = true;
    }

    function run():Void {
        while (true) {
            mutex.acquire();
            var batch = first;
            var stop = batch == null && closing;
            if (batch != null) {
                first = batch.next;
                if (first == null) last = null;
            }
            mutex.release();
            if (stop) break;
            if (batch == null) {
                wake.wait();
                continue;
            }
            var size = batch.resources.length;
            // Preserve native pop order. Release holds no queue/lifecycle lock.
            while (batch.resources.length > 0)
                GpuResources.releaseRetired(batch.resources.pop());
            mutex.acquire();
            count -= size; // Includes in-flight releases until the batch finishes.
            mutex.release();
        }
        stopped.release();
    }
}
