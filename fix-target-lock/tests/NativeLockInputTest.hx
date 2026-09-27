import fixtargetlock.NativeLockInput;

class NativeLockInputTest {
    static function main():Void {
        var live = new NativeLockInput();
        live.begin();
        live.observe("SavePos");
        live.observe("LoadPos");
        live.end();
        live.observe("LockTarget"); // The mod's own postfix query.
        if (live.handled) throw "Live client lost its legacy repair";

        var ptr = new NativeLockInput();
        ptr.begin();
        ptr.observe("LockTarget"); // The native update checks this even when unpressed.
        ptr.end();
        if (!ptr.handled) throw "PTR would process LockTarget a second time";
        ptr.begin(); ptr.end();
        if (!ptr.handled) throw "Native ownership must persist beyond one frame";
        Sys.println("Live/PTR target-lock ownership checks passed");
    }
}
