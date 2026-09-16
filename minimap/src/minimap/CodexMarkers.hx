package minimap;

import minimap.GameAccess as G;

private typedef CodexGoals = {inCodex:Bool, completed:Int, mastered:Int};

/** Cache native goals by enemy kind; always use the current character's kills. */
class CodexMarkers {
    var goals:Map<String, CodexGoals> = [];

    public function new() {}

    public function hidden(id:String, inf:Dynamic, kills:Int, hideCompleted:Bool,
        hideMastered:Bool):Bool {
        if (!hideCompleted && !hideMastered) return false;
        var goal = goals.get(id);
        if (goal == null) {
            goal = {inCodex: G.staticCall("data.CodexData", "isInCodex", [inf]) == true,
                completed: 0, mastered: 0};
            if (goal.inCodex) {
                var thresholds = G.array(G.staticCall("st.player.Progress", "getUnitProgressThreshold", [inf]));
                // The native Codex uses a one-based XP reward index, then the
                // last threshold for maxProgress/full mastery (CodexData.hx).
                var reward = G.integer(G.field(G.current("Const", "Codex"), "FoeXPRewardThresholdIndex")) - 1;
                if (reward >= 0 && reward < thresholds.length) goal.completed = G.integer(thresholds[reward]);
                if (thresholds.length > 0) goal.mastered = G.integer(thresholds[thresholds.length - 1]);
            }
            goals.set(id, goal);
        }
        if (!goal.inCodex) return false;
        return (hideCompleted && goal.completed > 0 && kills >= goal.completed)
            || (hideMastered && goal.mastered > 0 && kills >= goal.mastered);
    }
}
