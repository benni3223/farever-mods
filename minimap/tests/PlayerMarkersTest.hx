import minimap.PlayerMarkers;

class PlayerMarkersTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, message:String):Void {
        checks++;
        if (actual != expected) throw message + ': expected $expected, got $actual';
    }

    static function main():Void {
        var markers = new PlayerMarkers();
        var self = {__uid: "me", posx: 0, posy: 0};
        var ally = {__uid: "ally", posx: 10, posy: 20, posz: 4};
        var far = {__uid: "far", posx: 1000, posy: -500};
        var origin = {__uid: "origin", posx: 0, posy: 0};
        var blank = {__uid: "", posx: 8, posy: 9};
        var nowhere = {__uid: "nowhere"};
        var gone = {__uid: "gone", removed: true, posx: 1, posy: 2};
        var dying = {__uid: "dying", dying: true, posx: 3, posy: 4};
        var me = {isMe: true, hero: self};
        var player = {group: {players: {array: [
            me,
            {hero: self},
            {hero: ally},
            {hero: ally},
            {hero: far},
            {hero: origin},
            {hero: blank},
            {hero: nowhere},
            {hero: gone},
            {hero: dying},
            {hero: null},
            {isMe: true, hero: {__uid: "other-client", posx: 5, posy: 5}}
        ]}}};

        var roster = markers.roster(player, self);
        eq(roster.length, 7, "local hero, duplicates, and empty entries are omitted");
        eq(markers.inParty(ally, roster), true, "the roster hero object is in the party");
        eq(markers.inParty({__uid: "ally"}, roster), true, "a replicated hero matches the roster by uid");
        eq(markers.inParty({__uid: "stranger", posx: 1, posy: 1}, roster), false, "a stranger is not in the party");
        eq(markers.inParty({__uid: ""}, roster), false, "a blank uid does not match another blank uid");
        eq(markers.inParty(self, roster), false, "the local hero is not treated as another party member");
        eq(markers.inParty(null, roster), false, "a missing unit is not in the party");

        var empty = markers.roster({group: null}, self);
        eq(empty.length, 0, "a missing group has no party");
        eq(markers.inParty(ally, empty), false, "nobody is in a party without a group");
        eq(markers.roster({group: {players: null}}, self).length, 0, "a missing roster is empty");

        eq(PlayerMarkers.visible(true, false, false), true, "strangers stay visible until the filter is on");
        eq(PlayerMarkers.visible(true, false, true), true, "party members stay visible with everyone else");
        eq(PlayerMarkers.visible(true, true, false), false, "the filter hides players outside the party");
        eq(PlayerMarkers.visible(true, true, true), true, "the filter keeps party members");
        eq(PlayerMarkers.visible(false, false, true), false, "hiding other players hides party markers too");
        eq(PlayerMarkers.visible(false, true, true), false, "both player options off leaves no on-map marker");
        eq(PlayerMarkers.kind(true), "party", "party members use their own marker kind");
        eq(PlayerMarkers.kind(false), "player", "other players keep the existing marker kind");

        var directions = markers.directions(roster);
        eq(directions.length, 4, "only living roster heroes with a position can guide");
        eq(directions.indexOf(ally) >= 0 && directions.indexOf(far) >= 0 && directions.indexOf(origin) >= 0
            && directions.indexOf(blank) >= 0, true, "near, far, origin, and unnamed heroes all qualify");
        eq(directions.indexOf(nowhere) < 0 && directions.indexOf(gone) < 0 && directions.indexOf(dying) < 0,
            true, "missing positions, removed heroes, and dying heroes are skipped");

        trace("PlayerMarkersTest passed (" + checks + " checks)");
    }
}
