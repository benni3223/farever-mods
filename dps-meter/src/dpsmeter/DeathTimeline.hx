package dpsmeter;

import dpsmeter.DeathLog;

/** Shared presentation math for both death windows and saved recaps. */
class DeathTimeline {
    public static function health(row:DeathEvent):String {
        var value = DeathLog.healthText(row.hp);
        return value == "" ? "?" : (row.hpSample == true ? "~" : "") + value;
    }
    public static function bar(row:DeathEvent, maxHp:Float):{remaining:Float, removed:Float, estimated:Bool} {
        var remaining = DeathLog.fraction(row.hp, maxHp);
        var exact = row.hpBefore != null && Math.isFinite(row.hpBefore) && row.hpSample != true;
        var removed = row.heal || row.death ? 0.0 : exact ? Math.max(0, row.hpBefore - row.hp)
            : row.amount != null && Math.isFinite(row.amount) ? row.amount : 0;
        return {remaining: remaining, removed: Math.min(1 - remaining, DeathLog.fraction(removed, maxHp)),
            estimated: !exact && !row.death && !row.heal};
    }
    public static function summary(report:DeathReport):String {
        var selected:Null<DeathEvent> = null;
        for (row in report.rows) if (!row.death && !row.heal && (selected == null || row.lethal == true || selected.lethal != true))
            selected = row;
        return selected == null ? "No incoming events received" : selected.amountText + " · " + selected.spell + " · " + selected.source;
    }
    public static function rowHeight(width:Int):Int return width < 600 ? 50 : 30;
}
