package dpsmeter;

typedef IncomingHit = {
    time:Float,
    amount:Float,
    heal:Bool,
    critical:Bool,
    kill:Bool,
    skill:String,
    ?skillId:String,
    source:String,
    ?className:String,
    ?hp:Float,
    ?maxHp:Float,
    ?hpSample:Bool,
    ?hpBefore:Float
};

/** One row in the death timeline, oldest first. The final row is the death itself. */
typedef DeathEvent = {
    ago:Float,
    timeText:String,
    hp:Float,
    amountText:String,
    heal:Bool,
    death:Bool,
    spell:String,
    skillId:String,
    source:String,
    className:String,
    ?lethal:Bool,
    ?critical:Bool,
    ?hpSample:Bool,
    ?amount:Float,
    ?hpBefore:Float
};

typedef DeathReport = {
    at:Float,
    damage:Float,
    healing:Float,
    healthScale:Float,
    rows:Array<DeathEvent>
};

typedef PartyDeath = {
    uid:String,
    name:String,
    className:String,
    report:DeathReport
};

/** Incoming damage and healing on a player, kept until that player dies. */
class DeathLog {
    public static inline var WINDOW:Float = 10;
    public static inline var SETTLE:Float = 0.5;

    var events:Array<IncomingHit> = [];
    var alive:Bool = true;
    var pending:Null<DeathReport>;
    public var lastReport(default, null):Null<DeathReport>;
    var delivered:Bool = false;
    var sampledHealth:Float = Math.NaN;
    var healthPending:Array<IncomingHit> = [];

    public function new() {}

    public function record(hit:IncomingHit):Void {
        if (hit == null || !Math.isFinite(hit.time) || !Math.isFinite(hit.amount)) return;
        if (!(hit.amount > 0) && !hit.kill) return;
        // Death and damage RPCs can arrive in either order. Keep the same
        // report during the bounded grace period used by encounter snapshots.
        if (!alive && (lastReport == null || delivered || hit.time > lastReport.at + SETTLE)) return;
        var sourceName = hit.source == null || StringTools.trim(hit.source) == "" ? "Unknown" : StringTools.trim(hit.source);
        var skillName = hit.skill == null ? "" : hit.skill;
        var amount = hit.amount > 0 ? hit.amount : 0;
        var stored:IncomingHit = {
            time: hit.time,
            amount: amount,
            heal: hit.heal,
            critical: hit.critical,
            kill: hit.kill && !hit.heal && hit.amount >= 0,
            skill: skillName,
            skillId: hit.skillId == null ? "" : hit.skillId,
            source: sourceName,
            className: hit.className == null ? "" : hit.className,
            hp: hit.kill && !hit.heal ? 0 : hit.hp != null && Math.isFinite(hit.hp) ? hit.hp : Math.NaN,
            hpSample: hit.hpSample == true && !hit.kill,
            hpBefore: hit.hpBefore,
            maxHp: hit.maxHp != null && Math.isFinite(hit.maxHp) ? hit.maxHp : Math.NaN
        };
        events.push(stored);
        if (stored.hpSample || stored.kill) healthPending.push(stored);
        var newest = hit.time;
        while (events.length > 0 && (events[0].time < newest - WINDOW - 1 || events.length > 500)) events.shift();
        refreshReport();
    }

    /** Validate a batch against replicated HP before assigning exact HP after
        each hit. Shields, unobserved events and replication gaps stay samples. */
    public function sampleHealth(hp:Float, maxHp:Float, now:Float):Void {
        if (!Math.isFinite(hp) || hp < 0) return;
        if (healthPending.length > 0 && Math.isFinite(sampledHealth)) {
            var cursor = sampledHealth;
            var states = [for (hit in healthPending) {
                var before = cursor;
                cursor = healthAfter(cursor, maxHp, hit.amount, hit.heal);
                {before: before, after: cursor};
            }];
            if (Math.abs(cursor - hp) < 0.01) {
                for (i in 0...healthPending.length) {
                    var hit = healthPending[i];
                    hit.hpBefore = states[i].before; hit.hp = states[i].after;
                    hit.hpSample = false; hit.maxHp = maxHp;
                }
                healthPending = [];
                refreshReport();
            } else if (now <= healthPending[0].time + SETTLE) return;
        }
        healthPending = [];
        sampledHealth = hp;
    }
    function refreshReport():Void {
        if (alive || lastReport == null || delivered) return;
        var updated = build(lastReport.at);
        lastReport.damage = updated.damage; lastReport.healing = updated.healing;
        lastReport.healthScale = updated.healthScale; lastReport.rows = updated.rows;
    }

    public function resume(now:Float):Void {
        if (!alive) observe(false, now);
    }

    /** First transition to dead snapshots the window. Returns true when the player is alive again. */
    public function observe(dead:Bool, now:Float):Bool {
        if (dead) {
            if (!alive) return false;
            alive = false;
            delivered = false;
            lastReport = build(now);
            pending = lastReport;
            return false;
        }
        if (!alive) {
            alive = true;
            events = [];
            healthPending = []; sampledHealth = Math.NaN;
            return true;
        }
        return false;
    }

    public function take(?now:Float):Null<DeathReport> {
        if (pending != null && now != null && now <= pending.at + SETTLE) return null;
        var report = pending;
        pending = null;
        if (report != null) delivered = true;
        return report;
    }

    public function canResume(now:Float):Bool return alive || lastReport == null || now > lastReport.at + SETTLE;

    /** True when a dead player is dropped, such as when respawn replaces the hero. */
    public function reset():Bool {
        var revived = !alive;
        events = [];
        healthPending = []; sampledHealth = Math.NaN;
        alive = true;
        return revived;
    }

    /** Scaled heal shown by the game. Values below 1 are the ones the native feed suppresses. */
    public static function shownHeal(amount:Float, scale:Float):Float {
        if (!Math.isFinite(amount) || !(amount > 0)) return 0;
        if (!Math.isFinite(scale) || !(scale > 0)) scale = 1;
        var shown = amount * scale;
        return shown >= 1 ? shown : 0;
    }

    /** A damage result is a heal only when the game marks that result as healing. */
    public static function isHeal(effectName:String, effectIndex:Int):Bool {
        var name = effectName == null ? "" : effectName;
        if (name == "Heal" || name == "HoT" || StringTools.endsWith(name, ".Heal")) return true;
        // Damage results still use effect 1 for healing. Std.string of that index is "1".
        return effectIndex == 1 && (name == "" || name == "1");
    }

    /** Arithmetic used only when a batch agrees with observed before/after HP. */
    public static function healthAfter(before:Float, maxHp:Float, amount:Float, heal:Bool):Float {
        if (!Math.isFinite(before)) return Math.NaN;
        var next = heal ? before + amount : before - amount;
        if (next < 0) next = 0;
        if (Math.isFinite(maxHp) && maxHp > 0 && next > maxHp) next = maxHp;
        return next;
    }

    public static function fraction(hp:Float, scale:Float):Float {
        if (!(scale > 0) || !Math.isFinite(hp)) return 0;
        return Math.max(0, Math.min(1, hp / scale));
    }
    public static function copyReport(report:DeathReport):DeathReport return {
        at: report.at, damage: report.damage, healing: report.healing,
        healthScale: report.healthScale, rows: [for (row in report.rows) cast Reflect.copy(row)]
    };

    function build(now:Float):DeathReport {
        var kept:Array<{i:Int, hit:IncomingHit}> = [];
        var damage = 0.0;
        var healing = 0.0;
        var scale = 0.0;
        var index = 0;
        for (hit in events) {
            if (hit.time >= now - WINDOW && hit.time <= now + SETTLE) {
                kept.push({i: index, hit: hit});
                if (hit.heal) healing += hit.amount;
                else damage += hit.amount;
                if (hit.maxHp > scale) scale = hit.maxHp;
                if (hit.hp > scale) scale = hit.hp;
            }
            index++;
        }
        kept.sort((a, b) -> a.hit.time < b.hit.time ? -1 : a.hit.time > b.hit.time ? 1 : a.i - b.i);
        var rows:Array<DeathEvent> = [for (entry in kept) event(entry.hit, now)];
        rows.push({
            ago: 0, timeText: "0.0 s", hp: 0, amountText: "Death", heal: false, death: true,
            spell: "", skillId: "", source: "", className: ""
        });
        return {at: now, damage: damage, healing: healing, healthScale: scale, rows: rows};
    }

    static function event(hit:IncomingHit, now:Float):DeathEvent {
        return {
            ago: Math.max(0, now - hit.time),
            timeText: timeText(now - hit.time),
            hp: hit.hp,
            amountText: signed(hit.amount, hit.heal),
            heal: hit.heal,
            death: false,
            spell: spell(hit.skill),
            skillId: hit.skillId,
            source: hit.source,
            className: hit.className,
            lethal: hit.kill, critical: hit.critical, hpSample: hit.hpSample == true,
            amount: hit.amount, hpBefore: hit.hpBefore
        };
    }

    static function spell(skill:String):String {
        var name = StringTools.trim(skill);
        return name == "" ? "Unknown" : name;
    }

    public static function timeText(secondsBefore:Float):String {
        var tenths = Math.fround(Math.max(0, secondsBefore) * 10) / 10;
        if (tenths < 0.05) return "0.0 s";
        var text = Std.string(-tenths);
        if (text.indexOf(".") < 0) text += ".0";
        else text = text.substr(0, text.indexOf(".") + 2);
        return text + " s";
    }

    public static function signed(value:Float, heal:Bool):String
        return (heal ? "+" : "-") + amount(value);

    /** Health remaining after the hit. Blank when the sample was never recorded. */
    public static function healthText(hp:Float):String {
        if (!Math.isFinite(hp) || hp < 0) return "";
        return amount(hp);
    }

    public static function amount(value:Float):String {
        var n = Std.int(Math.fround(value));
        if (n < 0) n = 0;
        var text = Std.string(n);
        var out = "";
        var count = 0;
        var i = text.length;
        while (i > 0) {
            if (count == 3) { out = "," + out; count = 0; }
            out = text.charAt(--i) + out;
            count++;
        }
        return out;
    }
}
