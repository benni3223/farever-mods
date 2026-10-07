import itemutilities.SkillPresetPlan;
import itemutilities.SkillPresetPlan.SkillPresetState;
import itemutilities.SkillPresetPlan.SkillPresetRules;
import itemutilities.SkillPresetTransfer;

class SparkmasterPresetTest {
    static var checks = 0;
    static function check(value:Bool, why:String):Void { checks++; if (!value) throw why; }
    static function rejects(action:Void->Void, why:String):Void {
        var rejected=false; try action() catch (_:Dynamic) rejected=true; check(rejected,why);
    }
    static function main():Void {
        var rules:SkillPresetRules={skills:["A"=>["A1"]],unlockedSlots:[true,true,true,true],maxRunes:1};
        var owners:Map<String,String>=["A1"=>"A"];
        var state:SkillPresetState = {slots:["A", null, null, null], runes:["A1"],
            conduits:["Mage_Conduit_Projectile", null, "Mage_Conduit_Power"]};
        var saved = SkillPresetPlan.savedConduits(state);
        var target = SkillPresetPlan.decodeConduits(haxe.Json.parse(haxe.Json.stringify(saved)), 3);
        check(target.join(",") == state.conduits.join(","), "Sparkmaster choices, order and empty slots survive JSON");
        target = ["Mage_Conduit_Power", "Mage_Conduit_Projectile", null];
        var slots = SkillPresetPlan.saved(state, owners);
        var plan = SkillPresetPlan.build(state, slots, rules, owners, null, target);
        check(plan.length == 3, "conduit-only preset does not change skills or runes");
        for (i in 0...plan.length) {
            check(plan[i].slot == -2 && plan[i].conduitIndex == i, "each choice targets its original conduit slot");
            check(plan[i].after.slots.join(",") == state.slots.join(",") && plan[i].after.runes[0] == "A1",
                "conduit application preserves skill slots and runes");
        }
        check(plan[2].skill == null && !plan[2].enable, "saved empty conduit is explicitly cleared");
        check(state.conduits[0] == "Mage_Conduit_Projectile", "planning does not modify current choices");
        check(SkillPresetPlan.build(state, slots, rules, owners).length == 0, "old presets leave Sparkmaster choices unchanged");
        check(SkillPresetPlan.build(plan[2].after, slots, rules, owners, null, target).length == 0,
            "already selected conduits send no requests");
        rejects(() -> SkillPresetPlan.decodeConduits(["A"], 3), "wrong conduit slot count is rejected");
        rejects(() -> SkillPresetPlan.decodeConduits([{},null,null], 3), "broken cross-module string data is rejected");
        var transfer = new SkillPresetTransfer(), context = {};
        transfer.start(context, state, plan);
        check(transfer.next(context, 0, state) == plan[0], "conduit request begins");
        check(transfer.next(context, 0.1, plan[0].after) == null, "conduit replication without acknowledgement cannot advance");
        transfer.acknowledge(transfer.requestId, true);
        check(transfer.next(context, 0.2, state) == null, "conduit acknowledgement without replication cannot advance");
        check(transfer.next(context, 0.3, plan[0].after) == plan[1], "confirmed conduit advances");
        transfer.acknowledge(transfer.requestId, false);
        check(!transfer.active && transfer.error != "", "rejected conduit stops preset");
        transfer.start(context, state, plan); transfer.next(context, 1, state);
        transfer.acknowledge(transfer.requestId, true);
        var edited = SkillPresetPlan.copy(state); edited.conduits[1] = "Other";
        transfer.next(context, 1.1, edited);
        check(!transfer.active, "concurrent manual Sparkmaster change cancels application");
        trace('Sparkmaster presets: $checks checks passed');
    }
}
