package minimap;

import minimap.GameAccess as G;

/** Resolve capabilities independently: never call a native method with guessed arguments. */
class WorldEventAccess {
    var statusOwner:String;
    var eventArgs:Int = -1;

    public function new() {}

    public function checkStatus(status:Dynamic):Bool {
        if (statusOwner == null)
            statusOwner = G.hasStaticMethod("HData", "checkStatus") ? "HData" : "Config";
        return G.staticCall(statusOwner, "checkStatus", [status]) == true;
    }

    public function elementStatus(events:Dynamic, element:String):Dynamic {
        if (eventArgs < 0) eventArgs = G.argumentCount(events, "getEventStatus");
        // The bound signature excludes the receiver. PTR accepts an activity
        // ID first, an element ID second, then a MapActivity selector.
        var args:Array<Dynamic> = switch eventArgs {
            case 1: [element];
            case 3: [null, element, null];
            default: throw "Unsupported WorldEvents.getEventStatus signature: " + eventArgs;
        };
        return G.call("st.event.WorldEvents", "getEventStatus", events, args);
    }
}
