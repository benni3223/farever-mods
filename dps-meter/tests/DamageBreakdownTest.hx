import dpsmeter.CombatModel;
import dpsmeter.DamageBreakdown;
import dpsmeter.FightHistory;
import haxe.Json;

class DamageBreakdownTest {
    static var checks = 0;
    static function check(value:Bool, message:String):Void {
        checks++;
        if (!value) throw message;
    }
    static function profile(id:String = "me"):PlayerInfo return {
        uid: id, name: id == "me" ? "Wink" : "Ally", isMe: id == "me", className: "mage",
        weapon: null, classSkills: [], weaponSkills: []
    };
    static function hit(amount:Float, type:String, affinity:String, critical:Bool = false, skill:String = "Mixed"):DamageEvent return {
        time: 2, source: "me", amount: amount, critical: critical, kill: false, effect: 0, skill: skill,
        target: "boss", bossKind: "Boss", bossFlags: 16, bossLevel: 1, bossFoeId: 1,
        damageType: type, affinity: affinity
    };
    static function main():Void {
        check(DamageBreakdown.classify(true, false) == "physical", "Native physical flag");
        check(DamageBreakdown.classify(false, true) == "magical", "Native magic flag");
        for (flags in [[false, false], [true, true], [null, true], [false, null]])
            check(DamageBreakdown.classify(flags[0], flags[1]) == "unclassified", "Unavailable/ambiguous flags never guess a type");

        var fight = new Fight(1); fight.me = "me"; fight.outcome = "Victory";
        fight.add(hit(60, "physical", "TestPhysical"), profile());
        fight.add(hit(30, "magical", "TestFire", true), profile());
        fight.add(hit(10, "magical", "TestIce"), profile());
        var healing = hit(900, "physical", "TestPhysical", true); healing.effect = 1;
        fight.add(healing, profile());
        var ally = hit(1000, "magical", "TestFire"); ally.source = "ally";
        fight.add(ally, profile("ally"));
        var player = fight.players["me"];
        var data:Dynamic = player.damageBreakdown.json(player.damage);
        check(player.damage == 100 && player.heal == 900, "Damage/healing totals retain existing behavior");
        check(data.physical.damage == 60 && data.magical.damage == 40 && data.unclassified.damage == 0,
            "Damage buckets use actual amounts and exclude healing");
        check(data.physical.percent == 60 && data.magical.percent == 40, "Percentages are per-player, not party damage or hit counts");
        check(data.physical.hits == 1 && data.physical.crits == 0 && data.magical.hits == 2 && data.magical.crits == 1,
            "Separate type hit/crit counts exclude healing");
        check(data.magical.critical_damage == 30 && data.physical.critical_damage == 0, "Critical damage is retained separately");
        check((cast data.affinities:Array<Dynamic>).length == 3, "Raw per-hit affinities are preserved");
        var fire = [for (a in (cast data.affinities:Array<Dynamic>)) if (a.affinity == "TestFire") a][0];
        check(fire.type == "magical" && fire.damage == 30 && fire.percent == 30 && fire.crits == 1,
            "Affinity details include type, amount, contribution, and critical hits");
        var skill:Dynamic = player.skills["Mixed"].json("Mixed", 1).damage_breakdown;
        check(skill.physical.damage == 60 && skill.magical.damage == 40 && skill.magical.percent == 40,
            "The same ability can deal both types; it is not assigned one fixed type");

        var record = Json.parse(Json.stringify(FightHistory.encode(fight, "mixed")));
        var restored = FightHistory.decode(record);
        check(Json.stringify(restored.players["me"].damageBreakdown.json(100)) == Json.stringify(data), "Player breakdown survives archive JSON roundtrip");
        check(restored.players["me"].skills["Mixed"].damageBreakdown.json(100).magical.critical_damage == 30,
            "Ability detail survives archive JSON roundtrip");
        var summary = FightHistory.chartDetail(FightHistory.entry(record));
        check(StringTools.endsWith(summary, "Victory  ·  Physical: 60%  ·  Magical: 40%") && summary.indexOf("\n") < 0,
            "The named player's split follows the outcome in the same chart/snapshot summary row");
        check(FightHistory.attemptHeading(FightHistory.entry(record)).indexOf("Physical") < 0, "Attempt-list headings stay compact");

        var report = fight.json("time", 1);
        var me = [for (p in (cast report.players:Array<Dynamic>)) if (p.is_me) p][0];
        check(me.damage_breakdown.magical.percent == 40 && me.skills[0].damage_breakdown.physical.damage == 60,
            "Uploader log includes player and ability breakdowns");
        var imported = FightHistory.legacy(Json.parse(Json.stringify(report)), fight.startedAt + 1000, "imported");
        check(FightHistory.entry(imported).damageTypeSummary == "Physical: 60%  ·  Magical: 40%", "Report import preserves new breakdowns");

        var frozen = fight.copy();
        fight.add(hit(100, "magical", "TestFire"), profile());
        check(frozen.players["me"].damageBreakdown.json(100).magical.damage == 40
            && frozen.players["me"].skills["Mixed"].damageBreakdown.json(100).magical.damage == 40,
            "Completed player and skill copies never change when live hits arrive");
        check(me.damage_breakdown.magical.damage == 40 && me.skills[0].damage_breakdown.magical.damage == 40
            && record.players[1].damageBreakdown.magical.damage == 40, "Worker-bound reports and archives are detached");
        data.magical.damage = 999;
        fire.damage = 999;
        check(player.damageBreakdown.json(200).magical.damage == 140, "Serialized data does not mutate live buckets");

        for (p in (cast record.players:Array<Dynamic>)) {
            Reflect.deleteField(p, "damageBreakdown");
            for (s in (cast p.skills:Array<Dynamic>)) Reflect.deleteField(s, "damageBreakdown");
        }
        var old = FightHistory.decode(record);
        check(old.players["me"].damage == 100 && old.players["me"].skills["Mixed"].damage == 100, "Old charts retain all damage");
        check(old.players["me"].damageBreakdown.json(100) == null && old.players["me"].skills["Mixed"].damageBreakdown.json(100) == null,
            "Missing historical types remain unavailable");
        check(StringTools.endsWith(FightHistory.chartDetail(FightHistory.entry(record)), "Victory"), "Old chart summaries do not fabricate percentages");
        for (p in (cast report.players:Array<Dynamic>)) {
            Reflect.deleteField(p, "damage_breakdown");
            for (s in (cast p.skills:Array<Dynamic>)) Reflect.deleteField(s, "damage_breakdown");
        }
        check(FightHistory.entry(FightHistory.legacy(report, fight.startedAt + 1000, "old")).damageTypeSummary == "",
            "Original uploader reports still import without type data");

        var unknown = hit(100, "unclassified", "", false, "");
        frozen.add(unknown, profile());
        check(frozen.players["me"].damageBreakdown.summary(200) == "Physical: 30%  ·  Magical: 20%  ·  Unclassified: 50%",
            "Unsupported and unattributed hits stay in the denominator and show as unclassified");
        check(frozen.players["me"].damageBreakdown.json(200).unclassified.hits == 1, "Unattributed hits still have player-level details");
        check(DamageBreakdown.percent(1, 3) == 33.3 && DamageBreakdown.percent(0, 0) == 0, "Rounded percentages and zero denominator");
        var zero = new PlayerStats(profile()); zero.add(hit(0, "physical", ""), profile());
        check(zero.damageBreakdown.summary(0) == "" && zero.damageBreakdown.json(0).physical.percent == 0,
            "Zero-damage fights have finite data and no misleading split");

        var gates = new Fight(1); gates.me = "me"; gates.add(hit(100, "physical", "TestPhysical"), profile());
        var boss = new Fight(3); boss.me = "me"; boss.outcome = "Defeat"; boss.add(hit(300, "magical", "TestFire"), profile());
        check(StringTools.endsWith(FightHistory.recapDetail({gate: gates, boss: boss}), "Defeat  ·  Physical: 25%  ·  Magical: 75%"),
            "Recap combines both phases by damage, not an average of percentages");
        check(StringTools.endsWith(FightHistory.recapDetail({gate: null, boss: boss}), "Defeat  ·  Physical: 0%  ·  Magical: 100%"),
            "Boss-only recap has its own split");
        check(StringTools.endsWith(FightHistory.recapDetail({gate: old, boss: boss}), "Physical: 0%  ·  Magical: 75%  ·  Unclassified: 25%"),
            "A phase without recorded types cannot inflate a recap's known shares");
        Sys.println('Damage breakdown: $checks checks passed');
    }
}
