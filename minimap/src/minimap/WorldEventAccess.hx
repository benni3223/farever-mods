package minimap;

import minimap.GameAccess as G;

/** World-event APIs used by the September 30 Live client. */
class WorldEventAccess {
    public function new() {}

    public function checkStatus(status:Dynamic):Bool {
        return G.staticCall("HData", "checkStatus", [status]) == true;
    }

    public function elementStatus(events:Dynamic, element:String):Dynamic {
        return G.call("st.event.WorldEvents", "getEventStatus", events, [null, element, null]);
    }
}
