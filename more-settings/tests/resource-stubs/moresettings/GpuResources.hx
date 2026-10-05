package moresettings;

import sys.thread.Lock;
import sys.thread.Mutex;
import sys.thread.Thread;

typedef GpuResource = Dynamic;

class GpuResources {
    static final mutex = new Mutex();
    public static var released:Array<Dynamic> = [];
    public static var failId:Int = -1;
    public static var mainThread:Thread;
    public static function resolve(value:Dynamic):Dynamic {
        if (value.id == failId) throw "abstract conversion failed";
        return value;
    }
    public static function releaseRetired(value:Dynamic):Void release(value);
    public static function release(value:Dynamic):Void {
        if (!value.ready) throw "released before native fence checkpoint";
        var entered:Lock = value.entered;
        var gate:Lock = value.gate;
        if (entered != null) entered.release();
        if (gate != null && !gate.wait(5)) throw "release blocked its producer or failed to shut down";
        mutex.acquire();
        if (value.releases != 0) throw "double release";
        value.releases++;
        value.worker = !(Thread.current() == mainThread);
        released.push(value);
        mutex.release();
    }
}
