package dpsmeter;

import dpsmeter.CombatModel;

typedef SnapshotRow = {name:String, className:String, damage:Float, dps:Float, percent:Float};
typedef SnapshotPlan = {width:Int, height:Int, rowHeight:Int, rows:Array<SnapshotRow>};

class FightSnapshot {
    /** Always the complete ranking, independent of selected player or scroll position. */
    public static function plan(fight:Fight):SnapshotPlan {
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
        var height = 140 + Std.int(Math.max(1, rows.length)) * rowHeight + 24;
        if (height * 900.0 * 4 > 128 * 1024 * 1024) throw "This fight is too large to copy as one image.";
        return {width: 900, height: height, rowHeight: rowHeight, rows: rows};
    }
}
