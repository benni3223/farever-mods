package dpsmeter;

import dpsmeter.CombatModel;
import dpsmeter.RiftTracker.RiftRecap;

typedef SnapshotRow = {name:String, className:String, damage:Float, dps:Float, percent:Float};
typedef SnapshotSkillRow = {id:String, values:SkillBreakdown.SkillValues};
typedef SnapshotPlan = {width:Int, height:Int, rowHeight:Int, rows:Array<SnapshotRow>,
    skills:Array<SnapshotSkillRow>, breakdown:Bool, playerName:String, playerClass:String};
typedef RecapSnapshotSection = {x:Int, y:Int, caption:String, seconds:Null<Float>, chart:SnapshotPlan};
typedef RecapSnapshotPlan = {width:Int, height:Int, sections:Array<RecapSnapshotSection>};

class FightSnapshot {
    public static inline var RECAP_CHART_OFFSET:Int = 48;

    /** Keep both phases and their selected views in one uncropped image. */
    public static function recap(result:RiftRecap, gatePlayer:String = "", bossPlayer:String = "", columns:Bool = true):RecapSnapshotPlan {
        var gate = plan(result.gate == null ? new Fight(0) : result.gate, result.gate == null ? "" : gatePlayer);
        var boss = plan(result.boss, bossPlayer);
        var gateHeight = gate.height - RECAP_CHART_OFFSET, bossHeight = boss.height - RECAP_CHART_OFFSET;
        var width = columns ? gate.width + boss.width : Std.int(Math.max(gate.width, boss.width));
        var height = 64 + (columns ? Std.int(Math.max(gateHeight, bossHeight)) : gateHeight + bossHeight);
        checkImageSize(width, height);
        return {width: width, height: height, sections: [
            {x: 0, y: 64, caption: RiftTracker.GATES_PHASE,
                seconds: result.gate == null ? null : result.gate.duration(), chart: gate},
            {x: columns ? gate.width : 0, y: columns ? 64 : 64 + gateHeight,
                caption: result.boss.phase, seconds: result.boss.duration(), chart: boss}
        ]};
    }

    /** Capture the selected view in full, independent of its scroll position. */
    public static function plan(fight:Fight, playerId:String = ""):SnapshotPlan {
        var player = fight.players[playerId];
        if (playerId != "" && player == null) throw "The selected player's breakdown is unavailable.";
        if (player != null) {
            var ids = [for (id in player.skills.keys()) id];
            ids.sort((a, b) -> {
                var damage = Reflect.compare(player.skills[b].damage, player.skills[a].damage);
                return damage != 0 ? damage : Reflect.compare(a, b);
            });
            var skills = [for (id in ids) {id: id, values: SkillBreakdown.values(player.skills[id], player.damage, fight.duration())}];
            var height = imageHeight(1200, 180, 40, skills.length);
            return {width: 1200, height: height, rowHeight: 40, rows: [], skills: skills,
                breakdown: true, playerName: player.info.name, playerClass: player.info.className};
        }
        var players = fight.ranked();
        var total = 0.0; for (player in players) total += player.damage;
        var seconds = Math.max(1, fight.duration());
        var rows = [for (i in 0...players.length) {
            var player = players[i];
            {name: (i + 1) + ". " + player.info.name, className: player.info.className,
                damage: player.damage, dps: player.damage / seconds,
                percent: total > 0 ? player.damage * 100 / total : 0.0};
        }];
        var rowHeight = 48;
        var height = imageHeight(900, 140, rowHeight, rows.length);
        return {width: 900, height: height, rowHeight: rowHeight, rows: rows, skills: [],
            breakdown: false, playerName: "", playerClass: ""};
    }
    static function imageHeight(width:Int, top:Int, rowHeight:Int, count:Int):Int {
        var height = top + Math.max(1, count) * rowHeight + 24;
        checkImageSize(width, height);
        return Std.int(height);
    }
    static function checkImageSize(width:Int, height:Float):Void {
        if (height * width * 4 > 128 * 1024 * 1024) throw "This fight is too large to copy as one image.";
    }
}
