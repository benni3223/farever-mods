package minimap;

import minimap.GameAccess as G;

/** Read the same group and account friendship identities as the native UI. */
class PlayerMarkers {
    public static function isPartyMember(hero:Dynamic, other:Dynamic):Bool {
        if (hero == null || other == null || hero == other || G.field(hero, "player") == null) return false;
        return G.call("ent.Hero", "isSameGroup", hero, [other]) == true;
    }

    public static function isFriend(hero:Dynamic, other:Dynamic):Bool {
        if (hero == null || other == null || hero == other) return false;
        var friends = G.field(G.field(hero, "player"), "friendList");
        var uid = G.field(G.field(other, "player"), "uid");
        // Friendship is account-wide, not a character/display-name match.
        // Lists can be unavailable briefly while a character is loading.
        if (friends == null || G.field(friends, "friends") == null || uid == null) return false;
        return G.call("st.FriendList", "isFriend", friends, [uid]) == true;
    }
}
