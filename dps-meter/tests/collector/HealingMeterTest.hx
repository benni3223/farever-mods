import dpsmeter.Collector;
import dpsmeter.MeterConfig;
import dpsmeter.FightHistory;
import dpsmeter.RiftRecapHistory;
import haxe.Json;

@:access(dpsmeter.Collector)
class HealingMeterTest {
    static var checks = 0;
    static function check(value:Bool, message:String):Void {
        checks++;
        if (!value) throw message;
    }
    static function hero(layer:Dynamic):Dynamic return {
        __uid: "me", name: "Psy", layer: layer, health: 800., maxHealth: 1000.,
        player: {isMe: true, heroData: {kind: "rogue"}}
    };
    static function cleric(layer:Dynamic):Dynamic return {
        __uid: "cleric", name: "Radius", layer: layer,
        player: {isMe: false, heroData: {kind: "Priest"}}
    };
    static function main():Void {
        var layer:Dynamic = {isRift: false};
        var me = hero(layer);
        var healer = cleric(layer);
        var collector = new Collector(MeterConfig.defaults());
        collector.hero = me; collector.layer = layer;
        collector.model.me = "me";
        collector.model.party["me"] = true;
        collector.model.party["cleric"] = true;
        collector.combatEnter("me", 10);
        var foe:Dynamic = {__uid: "foe", kind: "Dummy", name: "Dummy", inf: {flags: 0}, _level: 1, foeId: 1};
        collector.damage(foe, {_amount: 100., source: me, weakSource: "me", skill: {kind: "Rogue_Attack"},
            _critical: false, _kill: false}, 10);
        var heal:Dynamic = {_amount: 400., _critical: true, source: healer, skill: {kind: "Priest_Prayer_Heal"}, targetUnit: me};
        collector.receivedHeal(heal, 11);
        collector.receivedHeal(heal, 11.01);
        collector.displayedHeal({dmg: heal}, 11.02);
        var fight = collector.model.displayedFight();
        check(fight != null && fight.players["me"].damage == 100, "Healing stays out of the damage total");
        check(fight.players.exists("cleric") && fight.players["cleric"].heal == 400, "A received heal is credited to its caster");
        check(fight.players["cleric"].healSkills["Priest_Prayer_Heal"].damage == 400, "The healing chart keeps the spell");
        check(fight.rankedByHeal().length == 1 && fight.rankedByHeal()[0].info.name == "Radius", "Healing mode lists the healer");
        check(fight.players["me"].heal == 0, "Receiving a heal does not count as healing done");
        collector.deathLog.observe(true, 12);
        check(collector.deathLog.lastReport != null && collector.deathLog.lastReport.healing == 400,
            "The death recap keeps the same heal");

        var ally:Dynamic = {__uid: "ally", name: "Awbee", layer: layer, health: 500., maxHealth: 900.,
            player: {isMe: false, heroData: {kind: "Priest"}}};
        collector.model.party["ally"] = true;
        collector.displayedHeal({dmg: {_amount: 250., source: healer, skill: {kind: "Priest_BeaconOfHope"}, targetUnit: ally}}, 13);
        check(fight.players["cleric"].heal == 650, "A floating heal on someone else counts for the caster");
        var allyLog = collector.buffer("ally");
        allyLog.observe(true, 14);
        check(allyLog.lastReport != null && allyLog.lastReport.healing == 250, "That heal is on the other player's death recap");

        var hiddenHeal:Dynamic = {_amount: 200., source: healer, skill: {kind: "Priest_BeaconOfHope"}, targetUnit: ally};
        collector.healingNumber(hiddenHeal, 15);
        check(fight.players["cleric"].heal == 850, "Suppressed floating numbers still contribute healing without a display widget");
        collector.displayedHeal({dmg:hiddenHeal}, 15.01);
        check(fight.players["cleric"].heal == 850, "An actual display widget does not count the same heal twice");
        collector.healingNumber({_amount: 100., source: healer, skill: {kind: "Priest_Prayer_Heal"}, targetUnit: me}, 16);
        check(fight.players["cleric"].heal == 850, "Local floating numbers stay on the received-heal feed");

        var riftLayer:Dynamic = {isRift: true};
        var riftHero = hero(riftLayer);
        var riftHealer = cleric(riftLayer);
        var rift = new Collector(MeterConfig.defaults());
        rift.hero = riftHero; rift.layer = riftLayer;
        rift.model.me = "me";
        rift.model.party["me"] = true;
        rift.model.party["cleric"] = true;
        rift.model.enableRift();
        rift.model.updateRiftState(20, true, false, "DemonSuperElite");
        var boss:Dynamic = {__uid: "boss", kind: "DemonSuperElite", name: "Nightking Maat Demon",
            inf: {flags: 0x10, id: "DemonSuperElite"}, _level: 30, foeId: 7};
        rift.damage(boss, {_amount: 80., source: riftHero, weakSource: "me", skill: {kind: "Rogue_Attack"},
            _critical: false, _kill: false}, 21);
        rift.receivedHeal({_amount: 500., source: riftHealer, skill: {kind: "Priest_Prayer_Heal"}, targetUnit: riftHero}, 22);
        var bossFight = rift.model.displayedFight();
        check(bossFight != null && bossFight.phase == "Rift: Nightking Maat Demon", "The rift boss fight is the live chart");
        check(bossFight.players["me"].damage == 80 && bossFight.players["cleric"].heal == 500,
            "Rift healing is stored on the boss fight separately from damage");
        check(bossFight.rankedByHeal().length == 1, "The rift healing chart is not empty");
        rift.noteDeath(riftHero, 23);
        check(bossFight.deaths.length == 1 && bossFight.deaths[0].report.healing == 500,
            "Rift deaths retain the incoming healing timeline");
        var saved = Json.parse(Json.stringify(FightHistory.encode(bossFight, "merged_boss")));
        var restored = FightHistory.decode(saved);
        check(restored.players["cleric"].heal == 500 && restored.players["me"].damage == 80,
            "History round-trip keeps healing and damage separate");
        check(restored.players["cleric"].healSkills["Priest_Prayer_Heal"].damage == 500,
            "History round-trip retains the healer's skill breakdown");
        check(restored.deaths.length == 1 && restored.deaths[0].report.healing == 500,
            "History round-trip retains the death recap");
        var entry = FightHistory.entry(saved);
        check(FightHistory.chartDetail(entry, restored.players["cleric"], "healing").indexOf("HPS: 500") >= 0,
            "The new selected-player summary shows healing per second in Healing mode");
        check(FightHistory.chartDetail(entry, restored.players["me"]).indexOf("DPS: 80") >= 0,
            "Damage mode retains the upstream selected-player DPS summary");
        check(FightHistory.chartDetail(entry, restored.players["cleric"], "deaths").indexOf("DPS:") < 0,
            "Death timelines do not display a damage rate for the selected player");
        var gate = bossFight.copy();
        gate.phase = "Rift: Gates";
        gate.players["cleric"].heal = 125;
        gate.players["cleric"].healSkills["Priest_Prayer_Heal"].damage = 125;
        gate.deaths = [];
        var recap = RiftRecapHistory.decode(Json.parse(Json.stringify(RiftRecapHistory.encode(
            {gate:gate, boss:bossFight}, "merged_recap"))));
        check(recap.gate.players["cleric"].heal == 125 && recap.boss.players["cleric"].heal == 500,
            "Combined upstream rift recaps preserve each phase's local healing totals");
        check(recap.gate.deaths.length == 0 && recap.boss.deaths.length == 1,
            "Combined rift recaps preserve deaths on the correct phase");
        check(recap.boss.healingView(recap.boss.players["cleric"]).skills["Priest_Prayer_Heal"].damage == 500,
            "A reopened combined recap can display the healing ability table");
        Sys.println("Healing meter: " + checks + " checks passed");
    }
}
