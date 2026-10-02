package dpsmeter;

import dpsmeter.GameAccess as G;

/** Only the local hero's current, living party in this instance can prolong a fight. */
class PartyCombat {
    public static function active(hero:Dynamic, leavingUid:String = ""):Bool {
        var layer = G.field(hero, "layer");
        var player = G.field(hero, "player");
        var group = G.field(player, "group");
        if (layer == null || player == null || group == null) return false;
        var hasMe = false;
        var fighting = false;
        for (member in G.array(G.field(group, "players"), true)) {
            if (member == player || G.field(member, "isMe") == true) { hasMe = true; continue; }
            if (G.field(member, "removed") == true) continue;
            var teammate = G.field(member, "hero");
            if (teammate == null || teammate == hero || G.field(teammate, "layer") != layer
                || G.field(teammate, "removed") == true || G.field(teammate, "isInCombat") != true) continue;
            // onLeaveCombat is invoked before the native flag is cleared.
            if (leavingUid != "" && G.uid(teammate) == leavingUid) continue;
            if (G.call("ent.GameObject", "isDead", teammate) != true) fighting = true;
        }
        return hasMe && fighting;
    }
}
