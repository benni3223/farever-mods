import itemutilities.AppearancePresetLayout;
import itemutilities.AppearancePresetPlan;
import itemutilities.AppearancePresetPlan.AppearanceSlotRule;
import itemutilities.AppearancePresetTransfer;
import itemutilities.OverlayRect;
import itemutilities.UiOverlayGeometry;

class AppearancePresetTest {
    static var checks = 0;
    static function check(value:Bool, message:String):Void {
        checks++;
        if (!value) throw message;
    }
    static function near(value:Float, expected:Float, message:String):Void {
        check(Math.abs(value - expected) < 0.00001, message + ': expected $expected, got $value');
    }
    static function rejects(action:Void->Void, message:String):Void {
        var rejected = false;
        try action() catch (_:Dynamic) rejected = true;
        check(rejected, message);
    }
    static function rules():Array<AppearanceSlotRule> {
        // Inventory indices need not be contiguous or match visual order.
        var names = ["Head", "Shoulders", "Chest", "Back", "Hands", "Waist", "Legs", "Feet"];
        return [for (i in 0...names.length) {slot: "Slot_" + names[i], index: i * 2 + 3}];
    }
    static function defaults():Map<String, String> return [for (r in rules()) r.slot => null];

    static function main():Void {
        var slots = rules();
        var current = defaults();
        var target = defaults();
        for (r in slots) target.set(r.slot, "Cosmetic_" + r.slot);
        target.set("Slot_Head", "Hide_Gear");
        target.set("Slot_Back", null);
        var encoded = AppearancePresetPlan.encode(target);
        var decoded = AppearancePresetPlan.decode(haxe.Json.parse(haxe.Json.stringify(encoded)));
        check(AppearancePresetPlan.same(decoded, target), "all eight appearance choices survive config JSON");
        check(decoded.exists("Slot_Back") && decoded.get("Slot_Back") == null, "default appearance is an explicit saved choice");
        check(decoded.get("Slot_Head") == "Hide_Gear", "hidden appearance remains distinct from default");
        check(encoded.length == 8, "save every armour slot in the view");
        var plan = AppearancePresetPlan.build(current, decoded, slots);
        check(plan.length == 7, "only changed appearances make requests");
        var state = current.copy();
        for (change in plan) {
            state.set(change.slot, change.item);
            check(AppearancePresetPlan.same(state, change.after), "expected state agrees with independent server operation");
            check([for (r in slots) if (r.slot == change.slot) r].length == 1, "only visible armour slots change");
        }
        check(AppearancePresetPlan.same(state, target), "plan restores the entire saved appearance");
        check(AppearancePresetPlan.same(current, defaults()), "planning never changes source choices");
        check(AppearancePresetPlan.build(target, target, slots).length == 0, "already-active preset makes no requests");
        var reset = AppearancePresetPlan.build(target, defaults(), slots);
        check(reset.length == 7, "default preset clears cosmetic and hidden overrides");
        check(AppearancePresetPlan.same(reset[reset.length - 1].after, defaults()), "reset means use equipped gear appearance");

        // Cover every directed transition between default, hidden, and two
        // cosmetics, including slots which currently have no equipment item.
        for (rule in slots) {
            for (before in [null, "Hide_Gear", "Cosmetic_A", "Cosmetic_B"]) {
                for (after in [null, "Hide_Gear", "Cosmetic_A", "Cosmetic_B"]) {
                    var source = defaults();
                    var destination = defaults();
                    source.set(rule.slot, before);
                    destination.set(rule.slot, after);
                    var changes = AppearancePresetPlan.build(source, destination, slots);
                    check(changes.length == (before == after ? 0 : 1), "appearance transitions are minimal");
                    if (changes.length > 0) {
                        check(changes[0].slot == rule.slot && changes[0].item == after, "restore the exact override state");
                        check(AppearancePresetPlan.same(changes[0].after, destination), "other appearance slots remain intact");
                    }
                }
            }
        }

        rejects(function() AppearancePresetPlan.decode(null), "missing preset is not a default preset");
        rejects(function() AppearancePresetPlan.decode([{slot: "Slot_Head"}]), "missing item is not an explicit default choice");
        rejects(function() AppearancePresetPlan.decode([{slot: "Slot_Head", item: null}, {slot: "Slot_Head", item: "Hide_Gear"}]), "duplicate slot rejected");
        rejects(function() AppearancePresetPlan.decode([{slot: 1, item: null}]), "non-string slot rejected");
        rejects(function() AppearancePresetPlan.decode([{slot: "Slot_Head", item: 1}]), "non-string cosmetic rejected");
        rejects(function() AppearancePresetPlan.decode([{slot: "Slot_Head", item: ""}]), "empty string is not a default cosmetic");
        var missing = target.copy();
        missing.remove("Slot_Back");
        check(!AppearancePresetPlan.same(missing, target), "missing slot differs from saved null");
        rejects(function() AppearancePresetPlan.build(current, missing, slots), "incomplete preset rejected before any changes");
        rejects(function() AppearancePresetPlan.build(current, AppearancePresetPlan.decode([]), slots), "empty record list cannot clear everything");
        var unknown = target.copy();
        unknown.set("Slot_Weapon", "Cosmetic_Weapon");
        rejects(function() AppearancePresetPlan.build(current, unknown, slots), "non-appearance slot rejected");
        rejects(function() AppearancePresetPlan.build(current, target, []), "unavailable definitions rejected");

        var transfer = new AppearancePresetTransfer();
        var session = {};
        check(transfer.start(session, current, plan), "start appearance sequence");
        var sent = 0;
        var time = 0.0;
        state = current.copy();
        while (transfer.active) {
            var change = transfer.next(session, time, state);
            if (change == null) break;
            sent++;
            check(!transfer.needsState(), "no inventory scans while waiting for reply");
            check(transfer.next(session, time + 0.01, null) == null, "only one request in flight");
            check(transfer.next(session, time + 0.02, change.after) == null, "replication must also have a successful RPC reply");
            transfer.acknowledge(transfer.requestId, true);
            check(transfer.needsState(), "reply enables confirmation read");
            check(transfer.next(session, time + 0.03, state) == null, "reply alone does not advance before replication");
            state = change.after.copy();
            time += 0.1;
        }
        check(sent == plan.length && !transfer.active && transfer.error == "", "complete serialized sequence");
        check(AppearancePresetPlan.same(state, target), "confirmed final appearance matches preset");

        transfer.start(session, current, plan);
        transfer.next(session, 0, current);
        var oldId = transfer.requestId;
        check(!transfer.start(session, current, plan), "repeated hotkey does not overlap changes");
        transfer.acknowledge(oldId, false);
        check(!transfer.active && transfer.error != "", "server rejection stops sequence");
        transfer.start(session, current, plan);
        transfer.next(session, 0, current);
        transfer.acknowledge(oldId, true);
        check(!transfer.needsState(), "old reply cannot acknowledge a new request");
        check(transfer.next(session, 5, null) == null && !transfer.active, "missing reply times out without retries");
        transfer.acknowledge(transfer.requestId, true);
        check(!transfer.active, "late reply cannot restart timed-out work");
        transfer.start(session, current, plan);
        transfer.next(session, 0, current);
        transfer.acknowledge(transfer.requestId, true);
        check(transfer.next(session, 5, current) == null && !transfer.active, "missing replication times out");
        transfer.start(session, current, plan);
        transfer.next(session, 0, current);
        check(transfer.next({}, 0.1, null) == null && !transfer.active, "character/loadout change cancels pending work");
        transfer.start(session, current, plan);
        check(transfer.next(session, 0, target) == null && !transfer.active, "manual appearance change before sending cancels work");
        transfer.start(session, current, plan);
        transfer.next(session, 0, current);
        transfer.acknowledge(transfer.requestId, true);
        check(transfer.next(session, 0.1, target) == null && !transfer.active, "unexpected appearance changes after reply cancel work");
        transfer.start(session, current, plan);
        transfer.cancel();
        check(transfer.next(session, 0, current) == null, "disabled mod sends no further requests");

        for (scale in [0.625, 0.75, 1.0, 1.5, 2.0]) {
            var projection = new UiOverlayGeometry(scale, 0, 0, scale, 100, 50);
            var button = projection.rect(411, 689, 150, 36);
            var panel = projection.rect(8, 120, 1192, 620);
            var controls = projection.rect(0, 0, 254, 36);
            var rect = AppearancePresetLayout.place(button, panel, controls);
            near(rect.left, 100 + 125 * scale, "preset bar sits to the left of Character");
            near(rect.top, 50 + 689 * scale, "same vertical alignment as Character button");
            near(button.left - rect.right, 32 * scale, "matches equipment preset spacing");
            near(rect.width, 254 * scale, "matching preset bar width");
            near(rect.height, 36 * scale, "matching preset button height");
        }
        var narrow = AppearancePresetLayout.place(new OverlayRect(220, 600, 370, 636),
            new OverlayRect(8, 0, 800, 650), new OverlayRect(0, 0, 254, 36));
        check(narrow.left > 8 && narrow.right < 220 && narrow.width < 254, "narrow panel fits without overlap or clipping");
        check(AppearancePresetLayout.place(null, null, null) == null, "missing native anchors hide the bar");
        trace('Appearance presets: $checks checks passed');
    }
}
