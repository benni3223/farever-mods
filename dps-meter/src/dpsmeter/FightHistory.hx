package dpsmeter;

import dpsmeter.CombatModel;

typedef HistoryEntry = {
    id:String, name:String, startedAt:Float, duration:Float, personalDps:Null<Float>, playerName:String,
    category:String, categoryVersion:Int, activityId:String, bossKind:String, phase:String
};
typedef HistoryGroup = {name:String, count:Int};
typedef HistoryRequest = {id:Int, action:String, group:String, page:Int, fightId:String,
    ?category:String, ?catalog:HistoryCatalog};
typedef HistoryResponse = {
    id:Int, page:Int, total:Int, groups:Array<HistoryGroup>, entries:Array<HistoryEntry>, record:Dynamic, error:String
};

/** Detached, versioned chart snapshots. No game types or monotonic clocks on disk. */
class FightHistory {
    public static inline var PAGE_SIZE = 8;
    public static function encode(fight:Fight, id:String):Dynamic {
        var players:Array<Dynamic> = [for (p in fight.ranked()) {
            var skills:Array<Dynamic> = [for (id => s in p.skills) {id: id, damage: s.damage, hits: s.hits,
                crits: s.crits, kills: s.kills, casts: s.casts}];
            {
                uid: p.info.uid, name: p.info.name, isMe: p.info.isMe || p.info.uid == fight.me,
                className: p.info.className, damage: p.damage, heal: p.heal,
                hits: p.hits, crits: p.crits, kills: p.kills,
                skills: skills
            }
        }];
        return {version: 1, id: id, name: name(fight), startedAt: fight.startedAt, duration: fight.duration(),
            me: fight.me, meName: fight.meName, players: players, category: fight.category, categoryVersion: fight.categoryVersion,
            activityId: fight.activityId, bossKind: fight.bossKind, phase: fight.phase};
    }
    public static function name(fight:Fight):String {
        return fight.phase != "" ? fight.phase : fight.bossName != "" ? fight.bossName
            : fight.bossKind != "" ? fight.bossKind : "Other combat";
    }
    public static function entry(record:Dynamic):HistoryEntry {
        validate(record);
        var damage:Null<Float> = text(record.me) == "" ? null : 0;
        var playerName = text(record.meName);
        for (p in array(record.players)) if (p.isMe == true) {
            damage = number(p.damage); playerName = text(p.name); break;
        }
        return {id: record.id, name: record.name, startedAt: record.startedAt, duration: record.duration,
            personalDps: damage == null ? null : damage / Math.max(1, number(record.duration)), playerName: playerName,
            category: text(record.category), categoryVersion: Std.int(number(record.categoryVersion)),
            activityId: text(record.activityId), bossKind: text(record.bossKind), phase: text(record.phase)};
    }
    public static function decode(record:Dynamic):Fight {
        validate(record);
        var fight = new Fight(1);
        fight.startedAt = record.startedAt;
        fight.last = 1 + number(record.duration);
        fight.closed = fight.last;
        fight.bossName = record.name;
        fight.me = text(record.me); fight.meName = text(record.meName);
        fight.category = text(record.category); fight.activityId = text(record.activityId);
        fight.categoryVersion = Std.int(number(record.categoryVersion));
        fight.bossKind = text(record.bossKind); fight.phase = text(record.phase);
        for (p in array(record.players)) {
            var uid = text(p.uid);
            if (uid == "") throw "A history player has no ID.";
            var stats = new PlayerStats({uid: uid, name: text(p.name), isMe: p.isMe == true,
                className: text(p.className), weapon: null, classSkills: [], weaponSkills: []});
            stats.damage = number(p.damage); stats.heal = number(p.heal);
            stats.hits = Std.int(number(p.hits)); stats.crits = Std.int(number(p.crits)); stats.kills = Std.int(number(p.kills));
            for (s in array(p.skills)) {
                var skill = new SkillStats();
                skill.damage = number(s.damage); skill.hits = Std.int(number(s.hits));
                skill.crits = Std.int(number(s.crits)); skill.kills = Std.int(number(s.kills)); skill.casts = Std.int(number(s.casts));
                stats.skills[text(s.id)] = skill;
            }
            fight.players[uid] = stats;
            if (stats.info.isMe) fight.me = uid;
        }
        return fight;
    }
    public static function validate(record:Dynamic):Void {
        if (record == null || record.version != 1 || text(record.id) == "" || text(record.name) == ""
            || number(record.startedAt) <= 0 || number(record.duration) < 0
            || !Std.isOfType(record.players, Array)) throw "Invalid fight history record.";
    }
    /** Import the original uploader's surviving reports, once, without uploading them again. */
    public static function legacy(report:Dynamic, timestamp:Float, id:String):Dynamic {
        if (report == null || !Std.isOfType(report.players, Array)) throw "Invalid legacy combat report.";
        var phase = text(report.phase);
        var name = phase != "" ? phase : text(report.boss_name);
        if (name == "") name = text(report.boss_kind);
        if (name == "") name = "Other combat";
        // Old filenames record export time rather than the first-hit time.
        var duration = number(report.duration_sec);
        var players:Array<Dynamic> = [for (p in array(report.players)) {
            var skills:Array<Dynamic> = [for (s in array(p.skills)) {id: text(s.id), damage: number(s.damage), hits: number(s.hits),
                crits: number(s.crits), kills: number(s.kills), casts: number(s.casts)}];
            {
                uid: text(p.uid), name: text(p.name), isMe: p.is_me == true,
                className: text(Reflect.field(p, "class")), damage: number(p.total_damage), heal: number(p.heal),
                hits: number(p.hits), crits: number(p.crits), kills: number(p.kills),
                skills: skills
            }
        }];
        return {version: 1, id: id, name: name, startedAt: timestamp - duration * 1000, duration: duration, players: players,
            activityId: text(report.activity_id), bossKind: text(report.boss_kind), phase: phase};
    }
    public static function dateLabel(timestamp:Float):String {
        var date = Date.fromTime(timestamp);
        var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        return months[date.getMonth()] + " " + date.getDate() + ", " + date.getFullYear() + " at "
            + StringTools.lpad(Std.string(date.getHours()), "0", 2) + ":"
            + StringTools.lpad(Std.string(date.getMinutes()), "0", 2) + ":"
            + StringTools.lpad(Std.string(date.getSeconds()), "0", 2);
    }
    public static function durationLabel(seconds:Float):String {
        var n = Std.int(seconds);
        return n < 1 ? "<1 sec" : n < 60 ? n + " sec" : n < 3600 ? Std.int(n / 60) + " min " + n % 60 + " sec"
            : Std.int(n / 3600) + " hr " + Std.int(n % 3600 / 60) + " min " + n % 60 + " sec";
    }
    public static function dpsLabel(value:Null<Float>):String {
        if (value == null) return "Your DPS: unavailable";
        var raw = Std.string(Math.fround(value));
        var result = "";
        for (i in 0...raw.length) {
            if (i > 0 && (raw.length - i) % 3 == 0) result += ",";
            result += raw.charAt(i);
        }
        return "Your DPS: " + result;
    }
    public static function array(value:Dynamic):Array<Dynamic> return Std.isOfType(value, Array) ? cast value : [];
    public static function text(value:Dynamic):String return Std.isOfType(value, String) ? cast value : "";
    public static function number(value:Dynamic):Float {
        if (value == null) return 0;
        if ((!Std.isOfType(value, Float) && !Std.isOfType(value, Int)) || !Math.isFinite(value))
            throw "Invalid number in fight history.";
        return value;
    }
}
