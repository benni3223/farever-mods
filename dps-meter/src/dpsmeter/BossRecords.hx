package dpsmeter;

import dpsmeter.CombatModel;
import dpsmeter.FightHistory;

typedef BossRecordRequest = {
    id:Int, bossKind:String, difficulty:Int, playerName:String, playerClass:String, before:Float
};
typedef BossRecordResponse = {id:Int, best:Null<Float>, error:String};

/** Detached lookup data. The current encounter is never its own prior record. */
class BossRecords {
    public static function request(id:Int, bossKind:String, model:CombatModel, since:Float, wallTime:Float):BossRecordRequest {
        var fight = model.bossRecordFight(bossKind, since);
        var player = model.profiles[model.me];
        return {id: id, bossKind: bossKind, difficulty: fight == null ? model.difficulty : fight.difficulty,
            playerName: player == null ? "" : player.name,
            playerClass: player == null ? "" : player.className.toLowerCase(),
            before: fight == null ? wallTime : fight.startedAt};
    }
    public static function best(entries:Iterator<HistoryEntry>, request:BossRecordRequest):Null<Float> {
        var best:Null<Float> = null;
        for (entry in entries) if (entry.bossKind == request.bossKind && entry.difficulty == request.difficulty
            && entry.playerName == request.playerName && entry.playerClass == request.playerClass
            && entry.outcome == "Victory" && entry.phase != RiftTracker.GATES_PHASE
            && entry.startedAt < request.before && Math.isFinite(entry.duration) && entry.duration > 0
            && (best == null || entry.duration < best)) best = entry.duration;
        return best;
    }
    public static function label(result:BossRecordResponse):String {
        // Only the earlier record is displayed. Its label and value do not
        // depend on combat exit, late damage, or the current fight's outcome.
        return "Best: " + (result.error != "" ? "unavailable" : result.best == null ? "none" : duration(result.best));
    }
    public static function duration(seconds:Float):String {
        if (seconds < .01) return "<0.01 sec";
        // Retain hundredths so small improvements are visible, including a
        // rounded carry into the next minute (59.999 -> 1 min 00.00 sec).
        var hundredths = Math.round(seconds * 100);
        var minutes = Std.int(hundredths / 6000);
        var remainder = hundredths % 6000;
        var fraction = StringTools.lpad(Std.string(remainder % 100), "0", 2);
        var secs = Std.string(Std.int(remainder / 100));
        return (minutes > 0 ? minutes + " min " + StringTools.lpad(secs, "0", 2) : secs) + "." + fraction + " sec";
    }
}
