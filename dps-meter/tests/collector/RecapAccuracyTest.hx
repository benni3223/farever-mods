import dpsmeter.Collector;
import dpsmeter.CombatModel;
import dpsmeter.DeathLog;
import dpsmeter.FightHistory;
import dpsmeter.MeterConfig;
import haxe.Json;

@:access(dpsmeter.Collector)
class RecapAccuracyTest {
    static var checks = 0;
    static function check(ok:Bool, label:String):Void {
        checks++;
        if (!ok) throw label;
    }
    static function player(uid:String, layer:Dynamic):Dynamic return {
        __uid: uid, name: uid, layer: layer, health: 800., maxHealth: 1000.,
        player: {isMe: uid == "me", heroData: {kind: uid == "healer" ? "Priest" : "Rogue"}}
    };
    static function result(source:Dynamic, target:Dynamic, amount:Float, heal:Bool = false, kill:Bool = false):Dynamic return {
        source: source, weakSource: source.__uid, target: target, _amount: amount,
        effect: heal ? 1 : 0, _kill: kill, _critical: heal, scale: 3.,
        skill: {kind: heal ? "Priest_Prayer_Heal" : "Rogue_Attack"}
    };
    static function main():Void {
        var layer:Dynamic = {isRift: true};
        var me = player("me", layer), healer = player("healer", layer), ally = player("ally", layer);
        var c = new Collector(MeterConfig.defaults());
        c.hero = me; c.layer = layer; c.model.me = "me";
        c.model.party["me"] = true; c.model.party["healer"] = true;
        c.model.enableRift(); c.model.startRiftGates();
        var enemy:Dynamic = {__uid: "enemy", name: "Enemy", kind: "Enemy", inf: {flags: 0}};
        c.damage(enemy, result(me, enemy, 100), 10);
        var gates = c.model.displayedFight();
        ally.health = 650.; // Attribute replication has already applied 150.
        c.damage(ally, result(enemy, ally, 150), 11);
        check(c.model.party.exists("ally"), "A newly arrived rift target is tracked before the roster poll");
        c.noteDeath(ally, 12);
        check(gates.deaths.length == 1, "Remote deaths appear in the gate phase");
        check(gates.deaths[0].report.rows[0].hp == 650 && gates.deaths[0].report.rows[0].hpSample,
            "Replicated HP is sampled and never has damage subtracted a second time");
        c.noteDeath(ally, 12.05);
        check(gates.deaths.length == 1, "Repeated death callbacks do not duplicate deaths");
        ally.dead = true; ally.health = 350.;
        c.damage(ally, result(enemy, ally, 150, false, true), 12.1);
        var report = gates.deaths[0].report;
        check(report.damage == 300 && report.rows.length == 3, "Late killing damage stays on the original gate death");
        check(report.rows[1].hp == 0 && report.rows[1].lethal, "Lethal RPC beats stale positive HP");
        var clone = gates.copy();
        report.rows[0].source = "Changed";
        check(clone.deaths[0].report.rows[0].source == "Enemy", "Archived timelines are detached snapshots");
        var missing = player("missing", layer);
        c.noteDeath(missing, 13);
        check(gates.deaths.length == 2 && gates.deaths[1].report.rows.length == 1,
            "A rift death with no received damage is retained explicitly");
        var heal = result(healer, me, 40, true);
        c.receivedHealing(me, heal, 13.1);
        c.healingNumber(heal, 13.2);
        c.displayedHeal({dmg: heal}, 13.3);
        c.receivedHeal(heal, 13.4);
        check(gates.players["healer"].heal == 40, "Native RPC/feed/display/init notify one heal, counted once");
        c.healingNumber(result(healer, me, 40, true), 13.41);
        c.healingNumber(result(healer, me, 40, true), 13.42);
        check(gates.players["healer"].heal == 120, "Identical rapid heals with distinct results all count");
        check(gates.players["healer"].hits == 0 && gates.players["healer"].crits == 0,
            "Healing crits do not contaminate damage hit/crit statistics");
        check(gates.players["healer"].healSkills["Priest_Prayer_Heal"].crits == 3,
            "Healing retains its own crit and hit statistics");
        c.healingNumber(result(healer, me, .4, true), 13.5);
        check(Math.abs(gates.players["healer"].heal - 120.4) < .0001,
            "Raw healing uses the same units as damage/HP and retains fractional ticks");
        var recipient = player("recipient", layer);
        c.receivedHealing(recipient, result(healer, recipient, 20, true), 13.6);
        check(Math.abs(gates.players["healer"].heal - 140.4) < .0001 && c.model.party.exists("recipient"),
            "Remote-to-remote healing counts without creating a floating-number widget");
        c.model.updateRiftState(14, true, false, "Boss");
        var boss:Dynamic = {__uid: "boss", name: "Boss", kind: "Boss", inf: {flags: 0x10}};
        c.damage(boss, result(me, boss, 100), 14.1);
        c.noteDeath(me, 14.2);
        check(c.model.displayedFight().deaths.length == 1 && gates.deaths.length == 2,
            "Boss deaths are distinct from gate deaths");
        c.model.updateRiftState(15, true, true, "Boss");
        c.model.update(15.6, false);
        check(c.model.recaps.length == 1 && c.model.recaps[0].gate.deaths.length == 2
            && c.model.recaps[0].boss.deaths.length == 1, "Automatic rift recaps keep both phase timelines");
        var encoded:Dynamic = Json.parse(Json.stringify(FightHistory.encode(clone, "test")));
        var restored = FightHistory.decode(encoded);
        check(restored.deaths[0].report.rows[0].hpSample && restored.deaths[0].report.rows[1].lethal,
            "History preserves sampled HP and killing-blow markers");
        clone.deaths[0].report.rows[0].hp = Math.NaN;
        restored = FightHistory.decode(Json.parse(Json.stringify(FightHistory.encode(clone, "test"))));
        check(Math.isNaN(restored.deaths[0].report.rows[0].hp), "Missing HP remains unknown after JSON storage");

        layer = {isRift: false}; me = player("me", layer); healer = player("healer", layer);
        c = new Collector(MeterConfig.defaults()); c.hero = me; c.layer = layer; c.model.me = "me";
        c.model.party["me"] = true; c.model.party["healer"] = true; c.combatEnter("me", 20);
        c.damage(boss, result(me, boss, 100), 20);
        c.healingNumber(result(healer, me, 80, true), 21);
        check(c.model.boss.players["healer"].heal == 80, "A pure healer participates in normal boss reports");
        c.noteDeath(me, 22);
        check(c.model.current.deaths.length == 1 && c.model.boss.deaths.length == 1,
            "Live combat and separate boss report both retain party deaths");
        c.noteDeath(me, 22.1);
        check(c.model.current.deaths.length == 1, "Polling does not republish an old death");
        Sys.println("Recap accuracy: " + checks + " checks passed");
    }
}
