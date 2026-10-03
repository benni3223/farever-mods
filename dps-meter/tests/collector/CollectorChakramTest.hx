import dpsmeter.Collector;
import dpsmeter.MeterConfig;
import dpsmeter.GameAccess;

@:access(dpsmeter.Collector)
class CollectorChakramTest {
    static var checks = 0;
    static function check(value:Bool, message:String):Void {
        checks++;
        if (!value) throw message;
    }
    static function main():Void {
        var collector = new Collector(MeterConfig.defaults());
        var layer:Dynamic = {isRift: false};
        var hero:Dynamic = {__uid: "me", name: "Wink", layer: layer, isInCombat: true,
            player: {isMe: true, heroData: {kind: "rogue"}}};
        collector.hero = hero; collector.layer = layer;
        var model = collector.model;
        model.me = "me"; model.party["me"] = true;
        model.activityCategory = "Boss Dungeons";
        collector.combatEnter("me", 10);
        var target:Dynamic = {__uid: "chakram", kind: "Phrixes", name: "High Inquisitor Chakram",
            phase: 1, isInCombat: true, health: 1000., inf: {flags: 0x10}, _level: 30, foeId: 1};
        var damage:Dynamic = {source: hero, weakSource: "me", skill: {kind: "Rogue_Attack"},
            _amount: 100., _critical: false, _kill: false, effect: 0, physical: true, magical: false};
        // Exercise the real Collector.damage/refreshPhrixes path, not only the
        // combat model: isAtDeathDoor must throw here just as it does in-game.
        collector.damage(target, damage, 10);
        var intro = model.displayedFight();
        check(intro != null && intro.closed == 0 && intro.players["me"].damage == 100,
            "Phase-one damage reaches the live chart without server-only calls");
        collector.refreshPhrixes(11);
        damage._amount = 50.; collector.damage(target, damage, 11);
        check(model.displayedFight() == intro && intro.players["me"].damage == 150,
            "Repeated hits and roster refreshes preserve the opening chart");
        check(model.current == null && model.boss == null && model.history.length == 0 && model.completed.length == 0,
            "Opening combat remains live-only");
        target.health = 1.; target.isInCombat = false;
        collector.combatExit("me", 12); collector.refreshPhrixes(14); model.update(14, false);
        check(model.trackingPhrixes("chakram") && model.displayedFight() == intro && intro.closed == 0,
            "Replicated one-health surrender preserves the opening chart through transition");
        target.phase = 2; target.health = 1000.; target.isInCombat = true;
        collector.refreshPhrixes(15);
        check(model.displayedFight() == null, "Surrender clears the temporary chart");
        collector.combatEnter("me", 16);
        damage._amount = 25.; collector.damage(target, damage, 16);
        check(model.current != null && model.current.start == 16 && model.current.players["me"].damage == 25,
            "Post-surrender combat starts with fresh damage and timing");
        check(model.history.length == 0 && model.completed.length == 0,
            "The opening health bar creates no log or upload");
        Sys.println("Chakram client collector: " + checks + " checks passed");
    }
}
