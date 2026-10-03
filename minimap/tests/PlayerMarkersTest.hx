import minimap.PlayerMarkers;
import minimap.GameAccess as G;

class PlayerMarkersTest {
    static var checks = 0;
    static function eq(actual:Bool, expected:Bool, why:String):Void {
        checks++;
        if (actual != expected) throw why;
    }

    static function main():Void {
        var hero:Dynamic = {player: {friendList: {friends: [{uid: "friend-account"}]}}};
        var other:Dynamic = {name: "Friend's first character", player: {uid: "friend-account"}};
        var members:Array<Dynamic> = [];
        G.nativeCall = function(type, name, object, args):Dynamic {
            if (type == "ent.Hero" && name == "isSameGroup") {
                if (object != hero || args.length != 1) throw "Incorrect native group lookup";
                return members.indexOf(args[0]) >= 0 ? true : null;
            }
            if (type == "st.FriendList" && name == "isFriend") {
                if (object != hero.player.friendList || args.length != 1) throw "Incorrect native friend lookup";
                for (friend in (cast object.friends:Array<Dynamic>)) if (friend.uid == args[0]) return true;
                return false;
            }
            throw "Unexpected native call: " + type + "." + name;
        };
        eq(PlayerMarkers.isPartyMember(hero, other), false, "No party handles the native null result");
        eq(PlayerMarkers.isFriend(hero, other), true, "Friend uses account UID");
        other.name = "Friend's other character";
        eq(PlayerMarkers.isFriend(hero, other), true, "Character name does not affect friendship");
        other.player.uid = "unrelated-account";
        eq(PlayerMarkers.isFriend(hero, other), false, "Same character name cannot match a different account");
        members.push(other);
        eq(PlayerMarkers.isPartyMember(hero, other), true, "Joining a party updates membership");
        members.resize(0);
        eq(PlayerMarkers.isPartyMember(hero, other), false, "Leaving a party updates membership");
        other.player.uid = "friend-account";
        hero.player.friendList.friends = [];
        eq(PlayerMarkers.isFriend(hero, other), false, "Removing a friend does not retain a stale highlight");
        hero.player.friendList.friends = [{uid: "friend-account"}];
        eq(PlayerMarkers.isFriend(hero, other), true, "Adding a friend refreshes the highlight");
        hero.player.friendList.friends = null;
        eq(PlayerMarkers.isFriend(hero, other), false, "Uninitialized friend list is safe");
        hero.player.friendList = null;
        eq(PlayerMarkers.isFriend(hero, other), false, "Unavailable friend list is safe");
        eq(PlayerMarkers.isFriend(hero, hero), false, "Local player is not highlighted as a friend");
        eq(PlayerMarkers.isPartyMember(hero, hero), false, "Local player cannot receive a party alert");
        eq(PlayerMarkers.isFriend(null, other), false, "Missing local player is safe");
        eq(PlayerMarkers.isPartyMember(null, other), false, "Missing local player has no group");
        G.nativeCall = null;
        Sys.println('Player markers: $checks checks passed.');
    }
}
