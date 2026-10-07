import minimap.SecretOrbMarkers as S;
import minimap.GameAccess as G;

class SecretOrbMarkersTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, message:String):Void {
        checks++;
        if (actual != expected) throw message + ': expected $expected, got $actual';
    }
    static function main():Void {
        var reads = 0;
        G.nativeCall = function(type, name, progress, args) {
            if (type != "st.player.Progress" || name != "hasElementCompleted" || args.length != 1)
                throw "Secret orbs must use the read-only native completion query";
            reads++;
            // Native hasElementDiscovered only tests entry existence; native
            // hasElementCompleted also requires a nonnegative completion time.
            var completed:Null<Float> = (cast progress:Map<String, Float>).get(args[0]);
            return completed != null && completed >= 0;
        };
        var id = "Temple_Secret_Orb";
        var progress:Map<String, Float> = [];
        eq(S.collected(progress, id), false, "unseen orb remains on map");
        eq(progress.exists(id), false, "displaying an orb does not create progress");
        progress[id] = -1;
        eq(S.collected(progress, id), false, "discovered but uncollected orb remains on map");
        eq(progress[id], -1., "displaying a discovered orb does not complete it");
        progress[id] = 0;
        eq(S.collected(progress, id), true, "collection at timestamp zero hides marker");
        progress[id] = 12345;
        eq(S.collected(progress, id), true, "collected orb hides marker");
        eq(S.collected(progress, "Other_Orb"), false, "collection only hides the matching orb");
        var otherCharacter:Map<String, Float> = [];
        eq(S.collected(otherCharacter, id), false, "collection is character-specific");
        progress[id] = -1;
        eq(S.collected(progress, id), false, "refreshed progress restores uncollected marker");
        var before = reads;
        eq(S.collected(null, id), false, "missing progress cannot prove collection");
        eq(S.collected(progress, ""), false, "missing ID cannot prove collection");
        eq(S.collected(progress, null), false, "null ID cannot prove collection");
        eq(reads, before, "missing inputs do not call the game");
        G.nativeCall = null;
        Sys.println('Secret orb markers: $checks checks passed.');
    }
}
