import moresettings.GpuResources.GpuResource;
import moresettings.GpuReleaseWorker;

/** Uses the production worker AND blocking wrapper, with a fake dx12 native only. */
class GpuReleaseNativeTest {
    static function check(value:Bool, label:String):Void if (!value) throw label;
    static function main():Void {
        var worker = new GpuReleaseWorker();
        var transferred = false;
        worker.submit([create()], () -> transferred = true);
        check(transferred, "ownership committed on the producer");
        var deadline = haxe.Timer.stamp() + 2;
        while (!waiting() && haxe.Timer.stamp() < deadline) Sys.sleep(0.001);
        check(waiting(), "native release started on the worker");
        check(worker.pending() == 1, "in-flight native reference remains counted");
        // The fake native stays blocked until unblock(), with a 3-second watchdog.
        // GC must finish while it is STILL blocked, not wait for the watchdog.
        hl.Gc.major();
        check(waiting() && released() == 0, "GC progressed during a blocked native release");
        unblock();
        worker.close();
        check(released() == 1 && worker.pending() == 0, "shutdown joined exactly one release");
        check(errors() == 0, "release used another thread with GC blocking enabled");
        check(!isBlocking(), "main thread did not inherit the worker's blocking state");
        Sys.println("GpuReleaseNativeTest: 7 checks passed (production worker, native boundary and concurrent GC)");
    }
    @:hlNative("dx12", "test_create") static function create():GpuResource return null;
    @:hlNative("dx12", "test_waiting") static function waiting():Bool return false;
    @:hlNative("dx12", "test_unblock") static function unblock():Void {}
    @:hlNative("dx12", "test_released") static function released():Int return 0;
    @:hlNative("dx12", "test_errors") static function errors():Int return 0;
    @:hlNative("dx12", "test_blocking") static function isBlocking():Bool return false;
}
