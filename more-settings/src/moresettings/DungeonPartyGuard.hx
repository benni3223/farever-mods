package moresettings;

import moresettings.GameAccess as G;

/** Require the full party in the instance lobby before its owner can start. */
class DungeonPartyGuard {
    public static var enabled:Bool = true;
    static inline var WAITING_TEXT = "Waiting for party members";
    static var reportedError:Bool = false;

    public static function waiting(screen:Dynamic):Bool {
        if (!enabled || screen == null) return false;
        try {
            var lobby = G.field(screen, "instanceLobby");
            if (lobby == null || G.field(lobby, "removed") == true) return false;
            var state = G.field(lobby, "state");
            if (state == null) return false;
            var phase = Type.enumConstructor(state);
            // During the countdown the same action cancels the launch. Other
            // members use it to toggle Ready; neither action should be blocked.
            if (phase != "WaitPlayers" && phase != "AllPlayersReady") return false;
            if (G.call("ui.win.element.InstanceSelectScreen", "isOwner", screen) != true) return false;
            var group = G.call("st.player.InstanceLobby", "get_group", lobby);
            var party = G.array(G.field(group, "players"), true);
            if (party.length <= 1) return false;
            for (player in party) {
                // Use native player lookup: lobby entries contain weak IDs,
                // using their native representation.
                if (player == null || G.call("st.player.InstanceLobby", "getPlayerInfo", lobby, [player]) == null)
                    return true;
            }
            return G.call("st.player.InstanceLobby", "hasAllPlayersReady", lobby) != true;
        } catch (e:Dynamic) {
            reportError(e);
            return false;
        }
    }

    public static function update(screen:Dynamic):Void {
        // Native update writes the normal label and enabled state first, which
        // also restores both when everyone joins or this setting is switched off.
        if (!waiting(screen)) return;
        var button = G.field(screen, "startBtn");
        if (button == null) return;
        if (G.text(G.field(button, "text")) != WAITING_TEXT)
            G.call("ui.comp.Button", "setText", button, [WAITING_TEXT]);
        // setText rebuilds the button and clears checkEnable.
        // Disable after rebuilding; guard startAction separately for stale clicks.
        G.call("ui.UIElement", "set_enable", button, [false]);
    }

    public static function reportError(error:Dynamic):Void {
        if (reportedError) return;
        reportedError = true;
        trace("[More Settings] Dungeon party check: " + Std.string(error));
    }
}
