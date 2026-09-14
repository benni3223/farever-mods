import minimap.CodexMarkers;
import minimap.GameAccess as G;

class CodexMarkersTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, message:String):Void {
        checks++;
        if (actual != expected) throw message + ': expected $expected, got $actual';
    }

    static function main():Void {
        var markers = new CodexMarkers();
        var coyote = {inCodex: true, thresholds: [1., 8., 20.]};
        eq(markers.hidden("Coyote", coyote, 100, false, false, false), false, "disabled filters show enemies");
        eq(G.codexMembershipReads, 0, "disabled filters skip native lookups");
        eq(G.codexThresholdReads, 0, "disabled filters skip thresholds");

        // The reward and full mastery are distinct milestones, with independent toggles.
        for (kills in [0, 7, 8, 19, 20, 21]) {
            eq(markers.hidden("Coyote", coyote, kills, true, false, false), kills >= 8, "XP completion boundary");
            eq(markers.hidden("Coyote", coyote, kills, false, true, false), kills >= 20, "full mastery boundary");
            eq(markers.hidden("Coyote", coyote, kills, true, true, false), kills >= 8, "both filters hide at earlier milestone");
            eq(markers.hidden("Coyote", coyote, kills, false, false, true), false, "Codex entries survive non-Codex filter");
        }
        eq(G.codexMembershipReads, 1, "membership is cached per enemy kind");
        eq(G.codexThresholdReads, 1, "thresholds are cached across kills and setting changes");
        eq(markers.hidden("Coyote", coyote, 0, false, true, true), false, "switching to a fresh character does not reuse old kills");

        // Native threshold arrays can vary by enemy kind and grow with game updates.
        for (fixture in [
            {id: "Large", thresholds: [1., 3., 10.]},
            {id: "Boss", thresholds: [1., 2., 5.]},
            {id: "Future", thresholds: [1., 8., 20., 35.]}
        ]) {
            var inf = {inCodex: true, thresholds: fixture.thresholds};
            var goal = Std.int(fixture.thresholds[fixture.thresholds.length - 1]);
            eq(markers.hidden(fixture.id, inf, goal - 1, false, true, false), false, fixture.id + " before mastery");
            eq(markers.hidden(fixture.id, inf, goal, false, true, false), true, fixture.id + " at native mastery target");
        }

        var before = G.codexThresholdReads;
        var nonCodex = {inCodex: false, thresholds: [1., 8., 20.]};
        for (bits in 0...8) {
            eq(markers.hidden("NonCodex", nonCodex, 100, bits & 1 != 0, bits & 2 != 0, bits & 4 != 0),
                bits & 4 != 0, "non-Codex filter stays independent");
        }
        eq(G.codexThresholdReads, before, "non-Codex enemies do not need threshold lookup");
        eq(markers.hidden("Empty", {inCodex: true, thresholds: []}, 100, true, true, true), false,
            "missing thresholds do not turn a Codex enemy into a non-Codex enemy");
        eq(markers.hidden("Missing", {inCodex: true}, 100, true, true, true), false, "unavailable goals keep marker visible");

        G.codexRewardIndex = 1;
        var changedIndex = new CodexMarkers();
        eq(changedIndex.hidden("Coyote", coyote, 1, true, false, false), true, "native XP index is one-based");
        eq(changedIndex.hidden("Coyote", coyote, 1, false, true, false), false, "XP index does not affect mastery");
        G.codexRewardIndex = 99;
        var invalidIndex = new CodexMarkers();
        eq(invalidIndex.hidden("Coyote", coyote, 20, true, false, false), false, "invalid XP index does not guess a target");
        eq(invalidIndex.hidden("Coyote", coyote, 20, false, true, false), true, "mastery is independent of XP index validity");
        Sys.println('Codex marker tests passed ($checks checks)');
    }
}
