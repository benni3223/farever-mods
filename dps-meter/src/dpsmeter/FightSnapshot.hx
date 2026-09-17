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
    public static inline var RECAP_SCALE:Int = 2;

    /** Keep both phases and their selected views in one uncropped image. */
    public static function recap(result:RiftRecap, gatePlayer:String = "", bossPlayer:String = ""):RecapSnapshotPlan {
        var gate = plan(result.gate == null ? new Fight(0) : result.gate, result.gate == null ? "" : gatePlayer);
        var boss = plan(result.boss, bossPlayer);
        var gateHeight = gate.height - RECAP_CHART_OFFSET, bossHeight = boss.height - RECAP_CHART_OFFSET;
        // A shared column keeps text readable when the image is pasted into
        // chat, regardless of the recap window's on-screen arrangement.
        var width = Std.int(Math.max(gate.width, boss.width));
        var height = 64 + gateHeight + bossHeight;
        imageSize(width, height, RECAP_SCALE);
        return {width: width, height: height, sections: [
            {x: 0, y: 64, caption: RiftTracker.GATES_PHASE,
                seconds: result.gate == null ? null : result.gate.duration(), chart: gate},
            {x: 0, y: 64 + gateHeight,
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
    /** Validate the actual clipboard allocation before creating GPU resources. */
    public static function imageSize(width:Int, height:Int, scale:Int = 1):{width:Int, height:Int} {
        if (width <= 0 || height <= 0 || scale <= 0) throw "Invalid snapshot dimensions.";
        checkImageSize(width * 1.0 * scale, height * 1.0 * scale);
        return {width: width * scale, height: height * scale};
    }
    static function checkImageSize(width:Float, height:Float):Void {
        if (height * width * 4 > 128 * 1024 * 1024) throw "This fight is too large to copy as one image.";
    }
}
