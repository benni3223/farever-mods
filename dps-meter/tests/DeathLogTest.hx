import dpsmeter.DeathLog;
import dpsmeter.MeterConfig;
import dpsmeter.DeathTimeline;
import dpsmeter.SkillBreakdown;

class DeathLogTest {
    static var checks = 0;
    static function check(value:Bool, message:String):Void {
        checks++;
        if (!value) throw message;
    }
    static function hit(time:Float, amount:Float, source:String, skill:String, heal:Bool = false, kill:Bool = false,
        hp:Float = 100, maxHp:Float = 1000, className:String = ""):IncomingHit {
        return {time: time, amount: amount, heal: heal, critical: false, kill: kill, skill: skill, skillId: skill,
            source: source, className: className, hp: hp, maxHp: maxHp};
    }
    static function main():Void {
        check(DeathLog.isHeal("Heal", 3), "A Heal result is healing even when its index is not 1");
        check(DeathLog.isHeal("1", 1), "Effect 1 stays healing when the value prints as a number");
        check(DeathLog.isHeal("HoT", 0), "Heal over time is healing");
        check(!DeathLog.isHeal("Damage", 0), "Ordinary damage is not healing");
        check(DeathLog.shownHeal(500, 1) == 500, "A displayed heal keeps its amount");
        check(DeathLog.shownHeal(2, 2) == 4, "Healing uses the game's scaled amount");
        check(DeathLog.shownHeal(0.4, 1) == 0, "Heals the native feed suppresses are not logged");
        check(!DeathLog.isHeal("Damage", 3), "A damage result is not a heal just because another number is positive");
        check(DeathLog.amount(1840) == "1,840", "Amounts use thousands separators");
        check(DeathLog.signed(1506, true) == "+1,506", "Healing is a positive amount");
        check(DeathLog.signed(11786, false) == "-11,786", "Damage is a negative amount");
        check(DeathLog.timeText(8.16) == "-8.2 s", "Times are tenths of a second before death");
        check(DeathLog.timeText(0) == "0.0 s", "The moment of death reads zero");
        check(DeathLog.timeText(10) == "-10.0 s", "A whole second keeps one decimal");
        check(DeathLog.healthText(178.6) == "179", "Health left is the remaining health, rounded");
        check(DeathLog.healthText(12345) == "12,345", "Health left uses the same grouping as amounts");
        check(DeathLog.healthText(0) == "0", "Death leaves zero health");
        check(DeathLog.healthText(Math.NaN) == "", "A missing health sample stays blank");
        check(DeathLog.healthAfter(1000, 5000, 400, false) == 600, "Damage is removed from health before the hit lands");
        check(DeathLog.healthAfter(100, 5000, 800, false) == 0, "Damage cannot push health below zero");
        check(DeathLog.healthAfter(1800, 2000, 500, true) == 2000, "Healing cannot raise health above the maximum");
        check(DeathLog.fraction(600, 5000) == 0.12, "The life bar uses health remaining over the maximum");
        check(DeathLog.fraction(Math.NaN, 5000) == 0, "Missing health draws an empty bar");

        var log = new DeathLog();
        log.record(hit(-0.01, 500, "Wolf", "Bite", false, false, 900));
        log.record(hit(9, 100, "The Guardian", "Slam", false, false, 800));
        log.record(hit(9.5, 40, "You", "Regeneration", true, false, 840, 1000, "cleric"));
        log.record(hit(10, 1840, "The Guardian", "Slam", false, true, 0));
        log.record(hit(10, 0, "Ignored", "Zero"));
        log.record(hit(10, 20, "  ", "Bash", false, false, 0));
        log.observe(true, 10);
        var report = log.take();
        check(report != null, "Dying publishes one report");
        check(log.take() == null, "The report is delivered once");
        check(report.damage == 1960, "Damage is only the last 10 seconds, including the killing hit");
        check(report.healing == 40, "Healing is totaled separately from damage");
        check(report.rows.length == 5, "Each hit stays on its own row, followed by death");
        check(report.rows[0].timeText == "-1.0 s" && report.rows[0].amountText == "-100"
            && report.rows[0].spell == "Slam" && report.rows[0].source == "The Guardian" && report.rows[0].hp == 800,
            "Older hits lead the history with health at that moment");
        check(report.rows[1].timeText == "-0.5 s" && report.rows[1].amountText == "+40" && report.rows[1].heal
            && report.rows[1].className == "cleric", "Heals keep their sign, spell, and healer class");
        check(report.rows[2].timeText == "0.0 s" && report.rows[2].amountText == "-1,840" && report.rows[2].spell == "Slam",
            "The killing hit stays a damage row at the moment of death");
        check(report.rows[3].source == "Unknown" && report.rows[3].spell == "Bash", "A blank attacker name is shown as Unknown");
        var death = report.rows[report.rows.length - 1];
        check(death.death && death.timeText == "0.0 s" && death.amountText == "Death" && death.hp == 0,
            "The history ends on a death row");
        check(report.healthScale == 1000, "Bars share the highest known maximum health");

        log.observe(true, 12);
        check(log.take() == null, "Staying dead does not open another log");
        log.record(hit(12.2, 80, "Wolf", "Bite"));
        check(log.observe(false, 13), "Coming back to life closes the dialog");
        check(!log.observe(false, 13.5), "Staying alive does not ask to close the dialog again");
        check(log.reset() == false, "Resetting a living player leaves the dialog alone");
        log.observe(true, 30);
        check(log.reset(), "Replacing a dead hero counts as living again");
        log.record(hit(20, 15, "Wolf", "Bite"));
        log.observe(true, 21);
        report = log.take();
        check(report != null && report.damage == 15 && report.rows.length == 2,
            "Reviving starts a fresh window and drops hits taken while dead");

        log = new DeathLog();
        log.record(hit(0, 5, "Old", "Hit", false, false, 50));
        log.record(hit(10.6, 7, "Edge", "Hit"));
        log.observe(true, 10);
        report = log.take();
        check(report.damage == 5 && report.rows[0].source == "Old" && report.rows[0].timeText == "-10.0 s",
            "A hit outside the final-RPC grace period is excluded");

        log = new DeathLog();
        for (i in 0...9) log.record(hit(9 + i * 0.1, 100 - i, "Add " + i, "Swipe", false, false, 500 - i * 10));
        log.observe(true, 10);
        report = log.take();
        check(report.rows.length == 10 && report.rows[0].source == "Add 0" && report.rows[8].source == "Add 8",
            "Every hit in the window stays in time order");

        log = new DeathLog();
        log.observe(true, 4);
        report = log.take();
        check(report.damage == 0 && report.healing == 0 && report.rows.length == 1 && report.rows[0].death,
            "A death with no hits still ends the history");

        log = new DeathLog();
        log.record(hit(8, 900, "The Guardian", "Unknown ability", false, false, 400));
        log.record(hit(9.6, 200, "The Guardian", "Slam", false, true, 0));
        log.observe(true, 10);
        report = log.take();
        check(report.rows[0].timeText == "-2.0 s" && report.rows[0].spell == "Unknown ability",
            "An unresolved skill name is still shown in the spell column");
        check(report.rows[1].timeText == "-0.4 s" && report.rows[1].amountText == "-200",
            "The killing blow is placed by how long before death it landed");

        log = new DeathLog();
        log.record(hit(49, 50, "Boss", "Swipe", false, false, 350));
        log.observe(true, 50);
        var liveReport = log.lastReport;
        check(log.take(50.1) == null, "Wait for late damage before presenting the death popup");
        log.record(hit(50.2, 150, "Boss", "Finisher", false, true, 350));
        report = log.take(50.6);
        check(report == liveReport && report.damage == 200 && report.rows.length == 3,
            "A death-first RPC sequence updates the same recap with the final hit");
        check(report.rows[1].hp == 0 && report.rows[1].lethal && report.rows[1].ago == 0,
            "The authoritative lethal flag overrides stale 350 HP and clamps late timestamps");
        log.record(hit(50.3, 999, "Boss", "Late duplicate"));
        check(report.damage == 200, "A delivered report is frozen");
        log = new DeathLog();
        log.record(hit(60, 25, "Cleric", "Regen", true));
        log.record(hit(60, 25, "Cleric", "Regen", true));
        log.observe(true, 61);
        check(log.take().healing == 50, "Distinct identical healing ticks are retained");

        log = new DeathLog();
        log.sampleHealth(500, 1000, 70);
        var observed = hit(71, 150, "Boss", "Hit", false, false, 350);
        observed.hpSample = true;
        log.record(observed);
        log.sampleHealth(350, 1000, 71.1);
        log.observe(true, 72);
        report = log.take();
        var segment = DeathTimeline.bar(report.rows[0], report.healthScale);
        check(report.rows[0].hp == 350 && report.rows[0].hpBefore == 500 && !report.rows[0].hpSample,
            "Matching before/after samples validate exact HP after the hit");
        check(segment.remaining == .35 && segment.removed == .15 && !segment.estimated,
            "Two red segments show 350 HP remaining and 150 HP removed on the same maximum");
        log = new DeathLog();
        log.sampleHealth(100, 1000, 80);
        log.record(hit(81, 400, "Boss", "Overkill", false, true, 0));
        log.sampleHealth(0, 1000, 81.1); log.observe(true, 82);
        segment = DeathTimeline.bar(log.take().rows[0], 1000);
        check(segment.remaining == 0 && segment.removed == .1 && !segment.estimated,
            "Overkill paints the 100 HP actually removed, not the 400 reported hit");
        log = new DeathLog();
        log.sampleHealth(500, 1000, 90);
        observed = hit(91, 150, "Boss", "Shielded", false, false, 480); observed.hpSample = true;
        log.record(observed); log.sampleHealth(480, 1000, 91.1); log.observe(true, 92);
        report = log.take(); segment = DeathTimeline.bar(report.rows[0], 1000);
        check(report.rows[0].hpSample && segment.estimated && DeathTimeline.health(report.rows[0]) == "~480",
            "Shield/replication mismatches are labelled as samples instead of invented exact HP");
        log = new DeathLog(); log.sampleHealth(500, 1000, 100);
        for (event in [hit(101, 200, "Boss", "Hit", false, false, 500), hit(101.01, 50, "Cleric", "Heal", true),
            hit(101.02, 150, "Boss", "Hit", false, false, 200)]) {
            event.hpSample = true; log.record(event);
        }
        log.sampleHealth(200, 1000, 101.1); log.observe(true, 102); report = log.take();
        check(report.rows[0].hp == 300 && report.rows[1].hp == 350 && report.rows[2].hp == 200,
            "Damage and healing delivered in one frame are reconciled against the whole batch");
        check(DeathTimeline.summary(report).indexOf("Cleric") < 0,
            "A healer is never displayed as the cause of death");
        for (width in [360, 434, 700, 892]) for (recap in [true, false]) {
            var columns = SkillBreakdown.columns(width, recap, true);
            check([for (column in columns) column.title].indexOf("HPS") >= 0
                && [for (column in columns) column.title].indexOf("Healing") >= 0
                && [for (column in columns) column.key].indexOf("distribution") < 0,
                "Healing tables use healing units and omit physical/magic/raw damage splits");
        }

        Sys.println('Death log: $checks checks passed');
    }
}
