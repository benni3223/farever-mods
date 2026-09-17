import minimap.WorldEventAccess;
import minimap.GameAccess as G;

class WorldEventAccessTest {
    static var checks = 0;
    static function check(ok:Bool, message:String):Void {
        checks++;
        if (!ok) throw message;
    }
    static function main():Void {
        // Include mixed capabilities: the two APIs must be detected independently.
        for (owner in ["Config", "HData"]) for (args in [1, 3]) {
            G.statusOwner = owner; G.eventArguments = args;
            var access = new WorldEventAccess();
            check(access.checkStatus(null), "default release status remains visible");
            check(access.checkStatus(1), "released content remains visible");
            check(!access.checkStatus(0), "unreleased content remains hidden");
            var events = {disabled: "Portal_Element"};
            check(access.elementStatus(events, "Portal_Element").status == "Disabled", "element ID reaches the correct argument");
            check(access.elementStatus(events, "Other_Element").status == "Active", "active element remains visible");
        }
        G.eventArguments = 2;
        var before = G.eventStatusCalls;
        var rejected = false;
        try new WorldEventAccess().elementStatus({}, "Portal_Element") catch (_:Dynamic) rejected = true;
        check(rejected && G.eventStatusCalls == before, "unsupported signature is rejected before native invocation");
        Sys.println('Client event compatibility: $checks checks passed.');
    }
}
