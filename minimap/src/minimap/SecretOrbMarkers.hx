package minimap;

import minimap.GameAccess as G;

class SecretOrbMarkers {
    public static function collected(progress:Dynamic, id:String):Bool {
        if (progress == null || id == null || id == "") return false;
        // Discovery only means a progress entry exists; completed=-1 is still
        // uncollected. Use the native read-only completion query instead.
        return G.call("st.player.Progress", "hasElementCompleted", progress, [id]) == true;
    }
}
