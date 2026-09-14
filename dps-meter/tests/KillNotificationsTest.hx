import dpsmeter.KillNotifications;
import dpsmeter.MeterConfig;
import dpsmeter.GameAccess as G;
import dpsmeter.CombatModel;
import dpsmeter.RunWriter;

@:access(dpsmeter.KillNotifications)
class KillNotificationsTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, message:String):Void {
        checks++;
        if (actual != expected) throw message + ': expected $expected, got $actual';
    }
    static function main():Void {
        var config = MeterConfig.defaults();
        var kills = new KillNotifications(config);
        var model = new CombatModel(1);
        var writer = new RunWriter();
        var units:Map<String, Dynamic> = [
            "Coyote" => {name: "Coyote", flags: 0, inCodex: true, thresholds: [1., 8., 20.]},
            "Large" => {name: "Large", flags: 0, inCodex: true, thresholds: [1., 3., 10.]},
            "Future" => {name: "Future", flags: 0, inCodex: true, thresholds: [1., 8., 20., 35.]},
            "NonCodex" => {name: "NonCodex", flags: 0, inCodex: false, thresholds: [1., 8., 20.]},
            "Empty" => {name: "Empty", flags: 0, inCodex: true, thresholds: []},
            "Missing" => {name: "Missing", flags: 0, inCodex: true},
            "Boss" => {name: "Boss", flags: 8, inCodex: true, thresholds: [1., 2., 5.]}
        ];
        G.globals["Data.unit"] = {byId: units};
        // No Const.Codex XP index exists in this fixture: mastery must not use it.
        for (count in [8, 9, 19, 20, 21]) {
            for (bits in 0...4) {
                config.showIncompleteCodexKills = bits & 1 != 0;
                config.showCompletedCodexKills = bits & 2 != 0;
                kills.popups.clear();
                kills.show("Coyote", count - 1, count, model, writer, 1);
                var show = count <= 20 ? bits & 1 != 0 : bits & 2 != 0;
                eq(kills.popups.rows.length, show ? 1 : 0, "independent mastery toggles at " + count);
                if (show) {
                    var row = kills.popups.rows[0];
                    eq(row.category, count <= 20 ? "unmastered" : "mastered", "category uses final milestone");
                    eq(row.message, "Coyote: " + (count <= 20 ? count + " / 20" : "21") + " kills", "visible counter target");
                    eq(row.goal, 20, "native progress popup also receives full mastery target");
                }
            }
        }
        config.showIncompleteCodexKills = true;
        for (fixture in [{id: "Large", goal: 10}, {id: "Future", goal: 35}]) {
            kills.popups.clear();
            kills.show(fixture.id, fixture.goal - 1, fixture.goal, model, writer, 1);
            eq(kills.popups.rows[0].goal, fixture.goal, "target varies per native threshold array");
            eq(kills.popups.rows[0].category, "unmastered", "finishing kill remains visible in progress");
        }
        for (mastered in [false, true]) {
            config.showCompletedCodexKills = mastered;
            kills.popups.clear();
            kills.show("Coyote", 19, 23, model, writer, 1);
            eq(kills.popups.rows[0].message, mastered ? "Coyote: 23 kills" : "Coyote: 20 / 20 kills", "batched shared kills cross mastery");
        }
        config.showBossKills = false;
        for (id in ["NonCodex", "Empty", "Missing", "Unknown", "Boss"]) {
            kills.popups.clear(); kills.show(id, 19, 20, model, writer, 1);
            eq(kills.popups.rows.length, 0, "skip invalid entries and honor independent boss toggle: " + id);
        }

        var progressMap:Map<String, Dynamic> = ["Coyote" => {killCount: 8}];
        var progress:Dynamic = {unitsProgress: {map: progressMap}};
        var app:Dynamic = {hero: {layer: {}, player: {progress: progress}}};
        kills.update(app, model, writer, 1);
        eq(kills.popups.rows.length, 0, "login establishes baseline without replaying kills");
        progressMap["Coyote"] = {killCount: 9}; kills.synced(progress);
        kills.update(app, model, writer, 2);
        eq(kills.popups.rows[0].message, "Coyote: 9 / 20 kills", "sync after XP completion still shows mastery progress");
        kills.update(app, model, writer, 3);
        eq(kills.popups.rows.length, 1, "unchanged sync does not repeat kill notification");
        progressMap = ["Coyote" => {killCount: 0}];
        progress = {unitsProgress: {map: progressMap}};
        app.hero = {layer: {}, player: {progress: progress}};
        kills.update(app, model, writer, 4);
        eq(kills.popups.rows.length, 0, "new character clears old popup and establishes its own baseline");
        progressMap["Coyote"] = {killCount: 1}; kills.synced(progress);
        kills.update(app, model, writer, 5);
        eq(kills.popups.rows[0].message, "Coyote: 1 / 20 kills", "new character starts from its own kill count");
        Sys.println('Kill notifications: $checks checks passed');
    }
}
