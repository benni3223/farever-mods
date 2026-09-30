import minimap.WorldEventAccess;
import minimap.GameAccess as G;

class WorldEventAccessTest {
    static var checks = 0;
    static function check(ok:Bool, message:String):Void {
        checks++;
        if (!ok) throw message;
    }
    static function main():Void {
        var access = new WorldEventAccess();
        check(access.checkStatus(null), "default release status remains visible");
        check(access.checkStatus(3), "released content remains visible");
        check(!access.checkStatus(0), "unreleased content remains hidden");
        check(!access.checkStatus(1), "work-in-progress content remains hidden");
        check(!access.checkStatus(2), "preview content remains hidden on Live");
        var events = {disabled: "Portal_Element"};
        check(access.elementStatus(events, "Portal_Element").status == "Disabled", "element ID reaches the correct argument");
        check(access.elementStatus(events, "Other_Element").status == "Active", "active element remains visible");
        check(G.eventStatusCalls == 2, "each lookup uses the native event API once");
        Sys.println('Client event compatibility: $checks checks passed.');
    }
}
