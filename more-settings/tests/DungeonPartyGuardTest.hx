import moresettings.DungeonPartyGuard;
import moresettings.SettingsData;

enum LobbyState {
    WaitPlayers;
    AllPlayersReady;
    DelayStarting(time:Float);
    Starting;
}

class DungeonPartyGuardTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, message:String):Void {
        checks++;
        if (actual != expected) throw message + ': expected $expected, got $actual';
    }

    static function main():Void {
        eq(SettingsData.defaults().waitForParty, true, "enabled for new and migrated configs");
        var owner = {uid: "owner"};
        var friend = {uid: "friend"};
        var other = {uid: "other"};
        var party:Array<Dynamic> = [owner, friend];
        var participants:Array<Dynamic> = [{player: owner, ready: false}];
        var button:Dynamic = {text: "Start", enable: true, checkEnable: () -> true};
        var lobby:Dynamic = {group: {players: {array: party}}, players: {array: participants},
            state: AllPlayersReady, removed: false};
        var screen:Dynamic = {instanceLobby: lobby, startBtn: button, isOwner: true};
        DungeonPartyGuard.enabled = true;
        DungeonPartyGuard.update(screen);
        eq(button.enable, false, "missing teammate disables Start immediately");
        eq(button.text, "Waiting for party members", "exact requested waiting label");
        eq(button.checkEnable, null, "test adapter models the native label rebuild clearing callbacks");
        eq(DungeonPartyGuard.waiting(screen), true, "activation also blocks a missing teammate");

        participants.push({player: other, ready: true});
        eq(DungeonPartyGuard.waiting(screen), true, "matching counts cannot replace a missing party member");
        participants.pop();
        participants.push({player: friend, ready: false});
        lobby.state = WaitPlayers;
        eq(DungeonPartyGuard.waiting(screen), true, "party members must also be ready");
        screen.isOwner = false;
        eq(DungeonPartyGuard.waiting(screen), false, "teammates can still press Ready");
        button.text = "Ready"; button.enable = true;
        DungeonPartyGuard.update(screen);
        eq(button.enable, true, "teammate Ready button stays available");
        eq(button.text, "Ready", "teammate Ready label stays native");
        screen.isOwner = true;
        participants[1].ready = true;
        lobby.state = AllPlayersReady;
        eq(DungeonPartyGuard.waiting(screen), false, "full ready party can start; owner needs no Ready flag");
        button.enable = false;
        DungeonPartyGuard.update(screen);
        eq(button.enable, false, "full party does not override native disabled state");

        // The native window writes its label/state before the mod's postfix.
        button.text = "Localized start"; button.enable = true;
        DungeonPartyGuard.update(screen);
        eq(button.text, "Localized start", "normal label returns when the party is complete");
        eq(button.enable, true, "normal enabled state returns when the party is complete");
        participants.pop();
        eq(DungeonPartyGuard.waiting(screen), true, "activation rechecks a teammate leaving after the last frame");
        DungeonPartyGuard.update(screen);
        eq(button.enable, false, "leaving the menu blocks the next update");
        DungeonPartyGuard.enabled = false;
        button.text = "Localized start"; button.enable = true;
        DungeonPartyGuard.update(screen);
        eq(button.text, "Localized start", "disabling restores the game's label without reopening");
        eq(button.enable, true, "disabling leaves the native enabled state intact");
        eq(DungeonPartyGuard.waiting(screen), false, "disabled guard permits the original start action");
        DungeonPartyGuard.enabled = true;
        eq(DungeonPartyGuard.waiting(screen), true, "reenabling takes effect on an already-open menu");

        for (state in [DelayStarting(123), Starting]) {
            lobby.state = state;
            button.text = "Cancel or loading"; button.enable = true;
            DungeonPartyGuard.update(screen);
            eq(DungeonPartyGuard.waiting(screen), false, "countdown cancel and loading are unaffected");
            eq(button.text, "Cancel or loading", "preserve native countdown/loading text");
        }
        lobby.state = AllPlayersReady;
        party.pop();
        eq(DungeonPartyGuard.waiting(screen), false, "leaving the party permits solo entry");
        party.push(friend);
        eq(DungeonPartyGuard.waiting(screen), true, "new party member must join the menu");
        lobby.removed = true;
        eq(DungeonPartyGuard.waiting(screen), false, "removed lobby is left to native lifecycle");
        lobby.removed = false;
        screen.instanceLobby = null;
        eq(DungeonPartyGuard.waiting(screen), false, "missing lobby is harmless");
        eq(DungeonPartyGuard.waiting(null), false, "missing screen is harmless");
        Sys.println('Dungeon party guard: $checks checks passed.');
    }
}
