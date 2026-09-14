package dpsmeter;

import dpsmeter.CombatModel.SkillStats;

typedef SkillColumn = {key:String, title:String, x:Int, width:Int};
typedef SkillValues = {damage:Float, percent:Float, casts:Int, avgCast:Float, hits:Int, avgHit:Float, crit:Float, dps:Float};

class SkillBreakdown {
    public static function values(skill:SkillStats, total:Float, duration:Float):SkillValues return {
        damage: skill.damage, percent: total > 0 ? skill.damage * 100 / total : 0,
        casts: skill.casts, avgCast: skill.casts > 0 ? skill.damage / skill.casts : 0,
        hits: skill.hits, avgHit: skill.hits > 0 ? skill.damage / skill.hits : 0,
        crit: skill.hits > 0 ? skill.crits * 100 / skill.hits : 0,
        // Match the player chart: each ability uses the whole fight's duration.
        dps: skill.damage / Math.max(1, duration)
    };
    public static function columns(width:Int):Array<SkillColumn> {
        // Keep names, total damage, share, and DPS legible in the small live
        // meter too. Wide history windows show every statistic in its own cell.
        var keys = width >= 800 ? ["ability", "damage", "casts", "avgCast", "hits", "avgHit", "crit", "dps"]
            : width >= 580 ? ["ability", "damage", "casts", "hits", "crit", "dps"] : ["ability", "damage", "dps"];
        var ratios = width >= 800 ? [.24, .28, .06, .09, .055, .085, .09, .10]
            : width >= 580 ? [.31, .31, .09, .08, .11, .10] : [.43, .40, .17];
        var titles = ["ability" => "Ability", "damage" => "Damage (%)", "casts" => "Casts", "avgCast" => "Avg cast",
            "hits" => "Hits", "avgHit" => "Avg hit", "crit" => "Crit %", "dps" => "DPS"];
        var result:Array<SkillColumn> = [];
        var x = 0; var ratio = 0.0;
        for (i in 0...keys.length) {
            ratio += ratios[i];
            var end = i == keys.length - 1 ? width : Std.int(width * ratio);
            result.push({key: keys[i], title: titles[keys[i]], x: x, width: end - x});
            x = end;
        }
        return result;
    }
}
