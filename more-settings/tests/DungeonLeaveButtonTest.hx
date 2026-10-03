import moresettings.DungeonLeaveButton;
import moresettings.GameAccess as G;
import moresettings.SettingsData;

class DungeonLeaveButtonTest {
    static var checks = 0;
    static function eq(actual:Bool, expected:Bool, message:String):Void {
        checks++;
        if (actual != expected) throw message;
    }

    static function main():Void {
        eq(SettingsData.defaults().leaveDungeonButton, true, "enabled by default");
        var hero:Dynamic = {isInCombat: false};
        var layer:Dynamic = {mainActivity: {types: ["st.activity.Dungeon"]}};
        var player:Dynamic = {hero: hero, layer: layer};
        G.data = {player: player};
        var button:Dynamic = {visible: false};
        var hud:Dynamic = {leaveBtn: button, removed: false};
        DungeonLeaveButton.attach(hud);
        eq(DungeonLeaveButton.visibility(button, false), true, "exit portal no longer hides the button outside combat");
        eq(DungeonLeaveButton.visibility(button, true), true, "native shown button stays shown");
        hero.isInCombat = true;
        eq(DungeonLeaveButton.visibility(button, true), false, "combat hides even a natively shown button");
        eq(DungeonLeaveButton.visibility(button, false), false, "combat keeps a hidden button hidden");
        hero.isInCombat = false;
        eq(DungeonLeaveButton.visibility(button, false), true, "leaving combat restores the button");
        player.hero = null;
        eq(DungeonLeaveButton.visibility(button, true), false, "missing hero cannot expose a stale button");
        player.hero = hero;
        for (activity in [null, {types: ["st.activity.Rift"]}, {types: ["st.Activity"]}]) {
            layer.mainActivity = activity;
            for (nativeValue in [false, true])
                eq(DungeonLeaveButton.visibility(button, nativeValue), nativeValue, "non-dungeon visibility stays native");
        }
        layer.mainActivity = {types: ["st.activity.Dungeon"]};
        DungeonLeaveButton.enabled = false;
        eq(DungeonLeaveButton.visibility(button, false), false, "disable restores the native portal rule");
        DungeonLeaveButton.enabled = true;
        eq(DungeonLeaveButton.visibility(button, false), true, "reenable needs no HUD rebuild");
        eq(DungeonLeaveButton.visibility({visible: false}, false), false, "other UI stays untouched");
        hud.removed = true;
        eq(DungeonLeaveButton.visibility(button, false), false, "removed HUD stays native");
        hud.removed = false;
        var replacement:Dynamic = {visible: false};
        DungeonLeaveButton.attach({leaveBtn: replacement, removed: false});
        eq(DungeonLeaveButton.visibility(button, false), false, "old button released on rebuild");
        eq(DungeonLeaveButton.visibility(replacement, false), true, "replacement button uses current setting");
        DungeonLeaveButton.clear();
        eq(DungeonLeaveButton.visibility(replacement, false), false, "world disposal releases the HUD");
        Sys.println('Dungeon leave button: $checks checks passed.');
    }
}
