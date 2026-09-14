import dpsmeter.CombatModel;
import dpsmeter.FightHistory;
import dpsmeter.FightHistoryStore;
import dpsmeter.LogUploader;
import dpsmeter.HistoryCatalog;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;

@:access(dpsmeter.LogUploader)
class HistoryTest {
    static var checks = 0;
    static function check(condition:Bool, message:String):Void {
        checks++;
        if (!condition) throw message;
    }
    static function profile(id:String = "me", mine:Bool = true):PlayerInfo return {
        uid: id, name: mine ? "Shawn" : "Ally", isMe: mine, className: mine ? "warrior" : "mage",
        weapon: null, classSkills: [], weaponSkills: []
    };
    static function hit(time:Float, amount:Float, kill:Bool = false, boss:Bool = false, source:String = "me", target:String = "enemy"):DamageEvent return {
        time: time, source: source, amount: amount, critical: false, kill: kill, effect: 0, skill: "Strike",
        target: target, bossKind: boss ? "BossKind" : "", bossName: boss ? "The Guardian" : "",
        bossFlags: boss ? 8 : 0, bossLevel: 25, bossFoeId: 7
    };
    static function model():CombatModel {
        var m = new CombatModel(1); m.me = "me";
        m.profiles["me"] = profile(); m.profiles["ally"] = profile("ally", false);
        m.party["me"] = true; m.party["ally"] = true;
        return m;
    }
    static function sample():Fight {
        var f = new Fight(10); f.startedAt = Date.fromString("2026-09-14 13:20:30").getTime();
        f.me = "me"; f.bossName = "The Guardian";
        f.add(hit(10, 100.5), profile());
        var critical = hit(12, 250, true); critical.critical = true;
        f.add(critical, profile()); f.add(hit(14, 500, false, false, "ally"), profile("ally", false));
        f.last = 20; f.closed = 20; return f;
    }
    static function request(action:String, group:String = "", page:Int = 0, fightId:String = ""):HistoryRequest
        return {id: 17, action: action, group: group, page: page, fightId: fightId};
    static function main():Void {
        lifecycle(); snapshots(); storage(); uploader(); categories();
        Sys.println('Fight history: $checks checks passed');
    }
    static function lifecycle():Void {
        var m = model();
        m.onCombatEnter("me", 10);
        m.record(hit(10, 100, false, true));
        m.record(hit(11, 400, false, false, "ally"));
        m.onCombatExit("me", 12);
        check(m.history.length == 0, "History must wait for late damage");
        m.record(hit(12.1, 200, true, true));
        m.update(12.6, false);
        check(m.history.length == 1, "One completed combat, not a second boss report");
        check(m.completed.length == 1, "Boss upload still queued separately");
        var f = m.history[0];
        check(f.duration() == 2 && f.players["me"].damage == 300, "Final blow included without extending duration");
        check(FightHistory.name(f) == "The Guardian", "Human-readable boss name");
        check(FightHistory.entry(FightHistory.encode(f, "one")).personalDps == 150, "DPS is the local player's total, not the party's");
        m.update(30, false); check(m.history.length == 1, "No repeated archive during idle updates");
        m.onCombatEnter("me", 31); m.record(hit(31, 5)); m.onCombatExit("me", 33); m.update(34, false);
        check(m.history.length == 2 && FightHistory.name(m.history[1]) == "Other combat", "Ordinary combat archived too");
        check(f.players["me"].damage == 300, "A later fight cannot mutate its predecessor");
        m = model(); m.record(hit(10, 50, true)); m.update(10.6, false);
        check(m.history.length == 1 && m.history[0].players["me"].damage == 50, "One-shot with no combat entry retained");
        m = model(); m.record(hit(10, 50, false, false, "ally")); m.update(11, false);
        check(m.history.length == 0, "Remote damage while resting is not a local fight");
        m = model(); m.record(hit(10, 50)); m.onCombatEnter("me", 10.1); m.onCombatExit("me", 12); m.update(13, false);
        check(m.history.length == 1 && m.history[0].start == 10, "Opening damage before combat entry retained once");
        m = model(); m.onCombatEnter("me", 10); m.record(hit(10, 80)); m.reset(20);
        check(m.history.length == 1 && m.history[0].duration() == 10, "Zone changes preserve unfinished fights");
        m.reset(21); check(m.history.length == 1, "Double shutdown does not duplicate a fight");
        m = model(); m.onCombatEnter("me", 10); m.record(hit(10, 80)); m.onCombatExit("me", 11);
        m.onCombatEnter("me", 11.1); m.record(hit(11.1, 40)); m.onCombatExit("me", 12); m.update(13, false);
        check(m.history.length == 2 && m.history[0].players["me"].damage == 80
            && m.history[1].players["me"].damage == 40, "Rapid consecutive fights remain separate");
        m = model(); m.enableRift(); m.updateRiftState(10, false, false, "BossKind");
        m.record(hit(10, 10)); m.updateRiftState(20, true, false, "BossKind");
        m.record(hit(21, 100, false, true)); m.updateRiftState(25, true, true, "BossKind");
        m.record(hit(25.1, 200, true, true)); m.update(26, false);
        check(m.history.length == 2 && m.completed.length == 2 && m.recaps.length == 1, "Both rift phases archived, uploads and recap intact");
        check(FightHistory.name(m.history[0]) == "Rift: Gates" && FightHistory.name(m.history[1]) == "Rift: The Guardian", "Rift grouping names");
        check(m.history[1].players["me"].damage == 300, "Late rift killing blow retained");
        m.update(30, false); m.reset(31);
        check(m.history.length == 2, "Completed rift not archived twice on leaving");
        m = model(); m.enableRift(); m.record(hit(10, 10)); m.reset(15);
        check(m.history.length == 1 && m.completed.length == 0 && m.recaps.length == 0, "Abandoned rift stays local");
        m = model(); m.enableRift(); m.updateRiftState(10, false, false, "BossKind");
        m.record(hit(10, 10)); m.updateRiftState(20, true, false, "BossKind");
        m.record(hit(21, 70, false, true)); m.reset(24);
        check(m.history.length == 2 && m.completed.length == 1, "Leaving during rift boss preserves both charts, only gates uploaded");
        m = model(); m.onCombatEnter("me", 10); m.onCombatExit("me", 12); m.reset(13);
        check(m.history.length == 0, "No empty fights from combat flags alone");
        m = model(); m.onCombatEnter("me", 10); m.record(hit(10, 90, false, false, "ally"));
        m.onCombatExit("me", 12); m.update(13, false);
        var passive = FightHistory.entry(FightHistory.encode(m.history[0], "passive"));
        check(passive.personalDps == 0 && passive.playerName == "Shawn", "A known local player who dealt no damage has zero DPS and keeps their name");
    }
    static function snapshots():Void {
        var f = sample(); var record = FightHistory.encode(f, "snapshot");
        check(FightHistory.entry(record).personalDps == 35.05, "Snapshot retains exact personal DPS");
        var decoded = FightHistory.decode(Json.parse(Json.stringify(record)));
        check(decoded.duration(99999) == 10 && decoded.startedAt == f.startedAt, "Reopened timer frozen independent of game session clock");
        check(decoded.ranked()[0].info.name == "Ally", "Player ranking restored");
        check(decoded.players["me"].damage == 350.5 && decoded.players["me"].skills["Strike"].damage == 350.5, "Exact damage and skill totals round-trip");
        var skill = decoded.players["me"].skills["Strike"];
        check(skill.casts == 2 && skill.hits == 2 && skill.crits == 1 && skill.kills == 1, "Skill breakdown statistics round-trip");
        check(decoded.me == "me" && decoded.players["me"].info.className == "warrior", "Own character and class preserved");
        f.players["me"].damage = 999; f.players["me"].skills["Strike"].damage = 999;
        check(FightHistory.decode(record).players["me"].damage == 350.5, "Handoff is detached from mutable fight");
        check(FightHistory.dpsLabel(12345) == "Your DPS: 12,345", "Readable exact DPS with thousands separators");
        check(FightHistory.dpsLabel(null) == "Your DPS: unavailable", "Missing local player never displays party DPS");
        check(FightHistory.durationLabel(0.001) == "<1 sec" && FightHistory.durationLabel(91) == "1 min 31 sec"
            && FightHistory.durationLabel(3661) == "1 hr 1 min 1 sec", "Readable short and long durations");
        check(FightHistory.dateLabel(f.startedAt) == "Sep 14, 2026 at 13:20:30", "Unambiguous local date/time includes seconds");
        var instant = new Fight(10); instant.add(hit(10, 100), profile()); instant.closed = 10;
        check(FightHistory.entry(FightHistory.encode(instant, "instant")).personalDps == 100, "One-shot DPS matches chart's one-second floor");
        var unknown = new Fight(10); unknown.add(hit(10, 40, false, false, "ally"), profile("ally", false)); unknown.closed = 10;
        check(FightHistory.entry(FightHistory.encode(unknown, "unknown")).personalDps == null, "Unknown personal DPS marked unavailable");
    }
    static function temp(name:String):String {
        var root = "build/history-tests/" + name + "_" + Std.random(0x3fffffff);
        FileSystem.createDirectory(root); return root;
    }
    static function remove(path:String):Void {
        if (FileSystem.isDirectory(path)) { for (name in FileSystem.readDirectory(path)) remove(path + "/" + name); FileSystem.deleteDirectory(path); }
        else FileSystem.deleteFile(path);
    }
    static function storage():Void {
        var root = temp("store"); var errors:Array<String> = [];
        var store = new FightHistoryStore(root, e -> errors.push(e));
        store.initialize();
        check(store.query(request("groups")).total == 0, "Fresh history is empty");
        for (i in 0...19) {
            var f = sample(); f.startedAt += i * 1000;
            store.save(FightHistory.encode(f, "boss_" + i));
        }
        var groups = store.query(request("groups"));
        check(groups.groups.length == 1 && groups.groups[0].count == 19, "Attempts grouped by encounter name");
        var first = store.query(request("fights", "The Guardian"));
        check(first.entries.length == FightHistory.PAGE_SIZE && first.entries[0].id == "boss_18", "Newest-first paged attempts");
        var finalPage = store.query(request("fights", "The Guardian", 999));
        check(finalPage.page == 2 && finalPage.entries.length == 3, "Page clamping and remainder");
        var chart = store.query(request("chart", "", 0, "boss_18"));
        check(FightHistory.decode(chart.record).players["me"].damage == 350.5, "Selected chart loaded from its own file");
        store.save(chart.record);
        check(store.query(request("fights", "The Guardian")).total == 19, "Retrying an archive is idempotent");
        for (i in 0...11) { var f = sample(); f.bossName = "Encounter " + i; store.save(FightHistory.encode(f, "group_" + i)); }
        check(store.query(request("groups")).groups.length == 8 && store.query(request("groups", "", 1)).groups.length == 4, "Encounter names paginate too");
        var old = sample(); old.startedAt = Date.fromString("2020-01-01 00:00:00").getTime();
        store.save(FightHistory.encode(old, "old"));
        File.saveContent(root + "/history/corrupt.json", "{broken");
        var reopened = new FightHistoryStore(root, e -> errors.push(e)); reopened.initialize();
        check(reopened.query(request("fights", "The Guardian")).total == 20, "Restart retains all years of history; a corrupt neighbor is isolated");
        check(FileSystem.exists(root + "/history/old.json") && FileSystem.exists(root + "/history/corrupt.json"), "History initialization never deletes logs");
        var escaped = false; try reopened.query(request("chart", "", 0, "../../secret")) catch (_:Dynamic) escaped = true;
        check(escaped, "Only indexed safe IDs may load a chart");
        var draft = FightHistory.encode(sample(), "draft"); File.saveContent(root + "/history/draft.json.tmp", Json.stringify(draft));
        var recovered = new FightHistoryStore(root, e -> errors.push(e)); recovered.initialize();
        check(recovered.query(request("chart", "", 0, "draft")).record.id == "draft", "Completed draft recovered after interrupted rename");
        remove(root);
    }
    static function uploader():Void {
        var root = temp("uploader");
        for (folder in ["logs", "logs/sent", "logs/rejected"]) FileSystem.createDirectory(root + "/" + folder);
        var old = sample(); old.bossKind = "OldGuardian";
        var report = old.json("20200101-123456", 1);
        for (folder in ["logs", "logs/sent", "logs/rejected"])
            File.saveContent(root + "/" + folder + "/run_20200101-123456_1.json", Json.stringify(report));
        File.saveContent(root + "/uploader.ini", "keep_days=7\n");
        var uploader = new LogUploader(root);
        uploader.loadSettings();
        uploader.archive(FightHistory.encode(sample(), "local_only"));
        uploader.flush();
        check(FileSystem.exists(root + "/history/local_only.json"), "Local history works without queuing an upload");
        check(FileSystem.readDirectory(root + "/logs").length == 3, "Local chart is not submitted to the upload queue");
        var store = new FightHistoryStore(root, _ -> {});
        var all = store.query(request("groups"));
        check(all.groups.length == 2, "Surviving original reports imported alongside local history");
        check(store.query(request("fights", "OldGuardian")).total == 1, "Legacy encounter name retained and queued/sent/rejected copies deduplicated");
        check(FileSystem.exists(root + "/logs/sent/run_20200101-123456_1.json"), "Old sent logs preserved even with keep_days=7");
        var second = new LogUploader(root); second.flush();
        second.requestHistory(request("groups")); second.browseHistory();
        var response = second.receiveHistory();
        check(response.id == 17 && response.error == "", "Background browsing replies to the matching request");
        check(second.history.query(request("fights", "OldGuardian")).total == 1, "Restart does not duplicate legacy migration");
        second.archive(FightHistory.encode(sample(), "shutdown")); second.stop();
        check(FileSystem.exists(root + "/history/shutdown.json"), "Normal shutdown persists pending histories");
        remove(root);
    }
    static function categories():Void {
        check(HistoryCategory.fromTypes(true, true, true) == "World Bosses", "Rifts take priority over dungeon inheritance");
        check(HistoryCategory.fromTypes(false, true, true) == "Boss Dungeons", "Boss subtype takes priority over Dungeon base");
        check(HistoryCategory.fromTypes(false, false, true) == "Classic Dungeons", "Ordinary Dungeon type");
        check(HistoryCategory.fromTypes(false, false, false) == "Other", "Unknown future activity safely belongs to Other");
        var catalog:HistoryCatalog = {activities: ["FutureArena" => "Boss Dungeons", "FutureDungeon" => "Classic Dungeons", "FutureRift" => "World Bosses"],
            names: ["FutureGuardian" => "The Future Guardian"], bosses: ["FutureGuardian" => true, "Crimson_Z3W_Caster_E" => false]};
        var old:Dynamic = {name: "FutureGuardian", activityId: "FutureArena", bossKind: "FutureGuardian"};
        check(HistoryCategory.resolve(old, catalog) == "Boss Dungeons", "Legacy activity ID uses running-game definitions, not a boss allowlist");
        check(HistoryCategory.displayName(old, catalog) == "The Future Guardian", "Native localized name replaces legacy data ID");
        check(HistoryCategory.resolve({name: "FutureGuardian"}, catalog) == "Other", "A boss name alone does not invent missing historical context");
        check(HistoryCategory.resolve({name: "Rift: Gates"}, catalog) == "World Bosses", "Older rift gates recognizable without activity metadata");
        check(HistoryCategory.resolve({name: "Rift: FutureGuardian"}, catalog) == "World Bosses", "Older rift boss recognizable without activity metadata");
        check(HistoryCategory.displayName({name: "Rift: FutureGuardian"}, catalog) == "Rift: The Future Guardian", "Rift prefix preserved with localized name");
        check(HistoryCategory.resolve({category: "Other", activityId: "FutureArena", bossKind: "FutureGuardian"}, catalog) == "Other", "Recorded nonboss context isn't promoted by a later catalog");
        check(HistoryCategory.resolve({activityId: "FutureArena", bossKind: "Crimson_Z3W_Caster_E"}, catalog) == "Other", "Old elite uploads excluded from dungeon-boss filters");
        var m = model(); m.activityId = "FutureArena"; m.activityCategory = "Boss Dungeons";
        m.onCombatEnter("me", 10);
        var boss = hit(10, 100, false, true); boss.bossFlags = 16; m.record(boss);
        var elite = hit(11, 80, true, true, "me", "elite"); elite.bossKind = "Crimson_Z3W_Caster_E"; elite.bossName = elite.bossKind;
        m.record(elite); m.onCombatExit("me", 12); m.update(13, false);
        check(m.history[0].category == "Boss Dungeons", "New boss fight captures its native activity category");
        check(m.history[0].bossName == "The Guardian", "Elite adds cannot replace a real boss's encounter name");
        var encoded = FightHistory.encode(m.history[0], "category");
        check(FightHistory.decode(Json.parse(Json.stringify(encoded))).category == "Boss Dungeons", "Category survives saving/reopening a chart");
        check(encoded.activityId == "FutureArena" && encoded.bossKind == "BossKind", "New history retains source activity and boss identity");
        m = model(); m.activityId = "FutureDungeon"; m.activityCategory = "Classic Dungeons";
        m.onCombatEnter("me", 10); m.record(elite); m.onCombatExit("me", 12); m.update(13, false);
        check(m.history[0].category == "Other", "Dungeon trash and elite fights remain under Other");
        var root = temp("categories"); var store = new FightHistoryStore(root, _ -> {});
        store.initialize();
        for (category in HistoryCategory.all()) {
            var f = sample(); f.category = category; store.save(FightHistory.encode(f, "category_" + category.split(" ").join("_")));
        }
        var req = request("categories"); req.catalog = catalog;
        var categories = store.query(req);
        check(categories.groups.length == 4 && categories.groups[0].name == "Boss Dungeons", "Category menu has the requested order");
        for (category in HistoryCategory.all()) {
            var req = request("groups"); req.category = category;
            var groups = store.query(req);
            check(groups.groups.length == 1 && groups.groups[0].count == 1, "Category filters same-named encounters independently: " + category);
            req = request("fights", "The Guardian"); req.category = category;
            check(store.query(req).entries[0].category == category, "Attempt list retains the selected category: " + category);
        }
        var legacyFight = sample(); legacyFight.bossKind = "FutureGuardian"; legacyFight.activityId = "FutureArena";
        var report = legacyFight.json("20260914-132030", 6);
        var legacy = FightHistory.legacy(report, legacyFight.startedAt + 10000, "legacy_" + haxe.crypto.Md5.encode(report.session_id));
        check(legacy.activityId == "FutureArena" && legacy.bossKind == "FutureGuardian", "New imports preserve classification metadata");
        // Simulate the first history release's omitted metadata, then restore it
        // using the exact legacy session ID, with no destructive file migration.
        for (field in ["activityId", "bossKind", "phase"]) Reflect.deleteField(legacy, field);
        store.save(legacy);
        FileSystem.createDirectory(root + "/logs/sent");
        File.saveContent(root + "/logs/sent/run_20260914-132030_6.json", Json.stringify(report));
        var reopened = new FightHistoryStore(root, _ -> {});
        var req = request("groups"); req.category = "Boss Dungeons"; req.catalog = catalog;
        var groups = reopened.query(req);
        check(groups.groups.length == 2 && groups.groups[0].name == "The Future Guardian", "Original imported logs recover exact category metadata and localized names");
        var original:Dynamic = Json.parse(File.getContent(root + "/history/" + legacy.id + ".json"));
        check(!Reflect.hasField(original, "activityId"), "Metadata recovery leaves the existing archive file untouched");
        remove(root);
    }
}
