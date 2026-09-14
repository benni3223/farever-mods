import dpsmeter.CombatModel;
import dpsmeter.FightHistory;
import dpsmeter.FightHistoryStore;
import dpsmeter.LogUploader;
import dpsmeter.HistoryCatalog;
import dpsmeter.SkillBreakdown;
import dpsmeter.NativeCombatMetadata;
import dpsmeter.GameAccess;
import dpsmeter.HistoryRequests;
import dpsmeter.FightSnapshot;
import dpsmeter.SnapshotTexture;
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
        lifecycle(); snapshots(); storage(); uploader(); categories(); metadata(); breakdown(); encounterDetails(); historyActions(); snapshotTextures();
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
        check(HistoryCategory.fromObjectives(true, true, true, true) == "World Bosses", "Rifts take priority over clearing objectives");
        check(HistoryCategory.fromObjectives(false, true, true, false) == "Boss Dungeons", "Boss target with no clearing phase is a boss dungeon");
        check(HistoryCategory.fromObjectives(false, true, true, true) == "Classic Dungeons", "Clearing phase makes a classic dungeon");
        check(HistoryCategory.fromObjectives(false, true, false, false) == "Other", "Do not classify partially replicated objectives as an arena");
        check(HistoryCategory.fromObjectives(false, false, true, true) == "Other", "World activities cannot become dungeons through objectives alone");
        var catalog:HistoryCatalog = {activities: ["FutureArena" => "Boss Dungeons", "FutureDungeon" => "Classic Dungeons", "FutureRift" => "World Bosses"],
            names: ["FutureGuardian" => "The Future Guardian"], bosses: ["FutureGuardian" => true, "Crimson_Z3W_Caster_E" => false]};
        var old:Dynamic = {name: "FutureGuardian", activityId: "FutureArena", bossKind: "FutureGuardian"};
        check(HistoryCategory.resolve(old, catalog) == "Boss Dungeons", "Legacy activity ID uses running-game definitions, not a boss allowlist");
        check(HistoryCategory.displayName(old, catalog) == "The Future Guardian", "Native localized name replaces legacy data ID");
        check(HistoryCategory.resolve({name: "FutureGuardian"}, catalog) == "Other", "A boss name alone does not invent missing historical context");
        check(HistoryCategory.resolve({name: "Rift: Gates"}, catalog) == "World Bosses", "Older rift gates recognizable without activity metadata");
        check(HistoryCategory.resolve({name: "Rift: FutureGuardian"}, catalog) == "World Bosses", "Older rift boss recognizable without activity metadata");
        check(HistoryCategory.displayName({name: "Rift: FutureGuardian"}, catalog) == "Rift: The Future Guardian", "Rift prefix preserved with localized name");
        check(HistoryCategory.resolve({category: "Other", categoryVersion: 2, activityId: "FutureArena", bossKind: "Crimson_Z3W_Caster_E"}, catalog) == "Other", "Recorded nonboss context isn't promoted by a later catalog");
        check(HistoryCategory.resolve({category: "Classic Dungeons", activityId: "Unknown", bossKind: "Ratsar"}, catalog) == "Boss Dungeons", "Correct old Ratsar misclassification");
        check(HistoryCategory.resolve({category: "Classic Dungeons", activityId: "Unknown", bossKind: "Phrixes"}, catalog) == "Boss Dungeons", "Chakram uses its actual internal ID");
        check(HistoryCategory.resolve({activityId: "Unknown", bossKind: "RobinHoof"}, catalog) == "Classic Dungeons", "Robin Hoof has a clearing phase");
        check(HistoryCategory.resolve({category: "Classic Dungeons", activityId: "Unknown", bossKind: "FutureGuardian"}, catalog) == "Other", "Unverified old inheritance label is not treated as evidence");
        check(HistoryCategory.resolve({phase: "Rift: Boss", activityId: "Unknown", bossKind: "Ratsar"}, catalog) == "World Bosses", "Rift instances override legacy boss fallback");
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
            req = request("fights", groups.groups[0].name); req.category = category;
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
        check(groups.groups.length == 2 && groups.groups[0].name == "The Future Guardian - Unknown difficulty", "Original imported logs recover category and name without inventing missing difficulty");
        var original:Dynamic = Json.parse(File.getContent(root + "/history/" + legacy.id + ".json"));
        check(!Reflect.hasField(original, "activityId"), "Metadata recovery leaves the existing archive file untouched");
        remove(root);
        root = temp("learned"); store = new FightHistoryStore(root, _ -> {});
        var oldRecord = FightHistory.encode(sample(), "old");
        oldRecord.category = "Classic Dungeons"; oldRecord.categoryVersion = 0;
        oldRecord.activityId = "NewArena"; oldRecord.bossKind = "NewBoss";
        store.save(oldRecord);
        req = request("groups"); req.category = "Other";
        check(store.query(req).groups[0].count == 1, "Unobserved legacy activity starts unclassified");
        var observed = sample(); observed.category = "Boss Dungeons"; observed.activityId = "NewArena"; observed.bossKind = "NewBoss";
        store.save(FightHistory.encode(observed, "observed"));
        reopened = new FightHistoryStore(root, _ -> {});
        req = request("groups"); req.category = "Boss Dungeons";
        req.catalog = {activities: [], names: [], bosses: []};
        check(reopened.query(req).groups[0].count == 2, "Saved objective evidence reclassifies older logs after restart");
        check(Json.parse(File.getContent(root + "/history/old.json")).category == "Classic Dungeons", "Reclassification never rewrites old damage logs");
        remove(root);
    }
    static function metadata():Void {
        var definitions:Map<String, Dynamic> = [
            "Warrior_Rage_Strike" => {texts: {name: "Raging Smash"}},
            "GA_Craft_FinalCombo" => {texts: {name: "Brutal Frenzy"}},
            "Warrior_Hemorrhage_Status" => {texts: {name: "Hemorrhage"}},
            "GA_Craft_Skill1" => {texts: {name: "Rampage"}},
            "GA_Base_Attack" => {type: 0, texts: {}}, "GA_Base_Attack2" => {type: 1, texts: {}},
            "RefEffect" => {texts: {refs: {ref: "GA_Craft_Skill1"}}},
            "Bracket" => {texts: {name: "[GA_Craft_FinalCombo]"}},
            "CycleA" => {texts: {refs: {ref: "CycleB"}}}, "CycleB" => {texts: {refs: {ref: "CycleA"}}}
        ];
        GameAccess.globals["Data.skill"] = {byId: definitions};
        // This native field is a formatter, not a label. Reproduce that shape
        // so turning it into a function address cannot regress unnoticed.
        GameAccess.globals["Texts.item_weapon_base_attack"] = (_:Dynamic) -> "Weapon damage description";
        GameAccess.globals["skillRefs"] = ["ChildEffect" => {id: "GA_Craft_Skill1"}];
        for (id => expected in ["Warrior_Rage_Strike" => "Raging Smash", "GA_Craft_FinalCombo" => "Brutal Frenzy",
            "Warrior_Hemorrhage_Status" => "Hemorrhage", "GA_Craft_Skill1" => "Rampage",
            "GA_Base_Attack" => "Base Attack", "GA_Base_Attack2" => "Base Attack 2",
            "RefEffect" => "Rampage", "Bracket" => "Brutal Frenzy", "ChildEffect" => "Rampage"])
            check(NativeCombatMetadata.skillName(id) == expected, "Native display-name metadata: " + id);
        check(NativeCombatMetadata.skillName("CycleA") == "CycleA", "Cyclic name references terminate safely");
        check(NativeCombatMetadata.skillName("Removed_Skill") == "Removed Skill", "Removed skills keep a readable fallback");
        GameAccess.globals["activities"] = ["TestArena" => {types: ["Dungeon"]}, "TestClassic" => {types: ["Boss", "Dungeon"]}];
        var activity:Dynamic = {};
        var player:Dynamic = {context: {objectives: {array: []}}};
        check(NativeCombatMetadata.activityCategory("TestArena", false, player, activity) == "Other", "Wait for native objective replication");
        player.context.objectives.array = [{kind: "KillBoss", target: TestObjectiveTarget.Unit("NewBoss")}];
        check(NativeCombatMetadata.activityCategory("TestArena", false, player, activity) == "Boss Dungeons", "Dungeon implementation can be a boss-only arena");
        player.context.objectives.array = [{kind: "KillBoss", target: TestObjectiveTarget.Unit("NewBoss")}, {kind: "KillAllDungeonFoes", completed: true}];
        check(NativeCombatMetadata.activityCategory("TestClassic", false, player, activity) == "Classic Dungeons", "Completed clearing objective still identifies a classic dungeon despite Boss inheritance");
        check(NativeCombatMetadata.activityCategory("TestClassic", true, player, activity) == "World Bosses", "Native rift override");
        var icons:Map<String, Dynamic> = ["Dungeon_Default" => {name: "Normal"}, "Dungeon_LevelMax" => {name: "Hard"}, "Dungeon_Heroic" => {name: "Heroic"}];
        GameAccess.globals["Data.icon"] = {byId: icons};
        var catalog = NativeCombatMetadata.catalog();
        check(catalog.difficulties[0] == "Normal" && catalog.difficulties[1] == "Hard" && catalog.difficulties[2] == "Heroic", "Difficulty values use the native selection-screen icon names");
    }
    static function encounterDetails():Void {
        var root = temp("difficulties"); var store = new FightHistoryStore(root, _ -> {});
        for (difficulty in [0, 1, 2, -1]) {
            var f = sample(); f.category = "Boss Dungeons"; f.bossName = "King Ratsar";
            f.bossKind = "Ratsar"; f.activityId = "Arena"; f.difficulty = difficulty; f.partySize = 5;
            var record = FightHistory.encode(f.copy(), "diff_" + (difficulty + 1));
            store.save(record);
            var restored = FightHistory.decode(Json.parse(Json.stringify(record)));
            check(restored.difficulty == difficulty && restored.partySize == 5, "Difficulty and roster size survive copied and saved fights " + difficulty);
        }
        var req = request("groups"); req.category = "Boss Dungeons";
        var groups = store.query(req).groups;
        check(groups.length == 4, "One boss produces distinct Normal, Hard, Heroic, and unknown encounter choices");
        for (name in ["Normal", "Hard", "Heroic", "Unknown difficulty"]) {
            var req = request("fights", "King Ratsar - " + name); req.category = "Boss Dungeons";
            check(store.query(req).entries.length == 1, "Selecting " + name + " only lists that difficulty");
        }
        var f = sample(); f.partySize = 5;
        var entry = FightHistory.entry(FightHistory.encode(f, "details"));
        check(FightHistory.attemptHeading(entry) == FightHistory.dateLabel(f.startedAt) + "  ·  Shawn  ·  Party: 5", "Attempt button starts with date, character, and complete roster size");
        check(FightHistory.attemptDetail(entry) == "10 sec  ·  Your DPS: 35", "Attempt button second line has duration then DPS");
        check(FightHistory.chartDetail(entry) == FightHistory.dateLabel(f.startedAt) + "  ·  Shawn  ·  Your DPS: 35  ·  10 sec", "Chart summary has date, character, DPS, duration in one row");
        var old = FightHistory.encode(sample(), "old"); Reflect.deleteField(old, "difficulty"); Reflect.deleteField(old, "partySize");
        entry = FightHistory.entry(old);
        check(entry.difficulty == -1 && entry.partySize == 0 && entry.recordedPlayers == 2, "Old logs preserve unknown difficulty and only a lower bound on party size");
        check(StringTools.endsWith(FightHistory.attemptHeading(entry), "Party: ≥2"), "Old logs cannot mistake damage contributors for the whole party");
        var m = model(); m.party["passive"] = true;
        m.onCombatEnter("me", 10); m.record(hit(10, 20)); m.onCombatExit("me", 12); m.update(13, false);
        check(m.history[0].partySize == 3 && Lambda.count(m.history[0].players) == 1, "Party size includes members who never deal damage");
        m = model(); m.party["passive"] = true; m.enableRift(); m.record(hit(10, 20)); m.reset(12);
        check(m.history[0].partySize == 3, "Rift archive keeps the present-player roster size too");
        // Previous history versions retained activity IDs but dropped difficulty.
        // The original uploader report is matched by its exact session ID.
        f = sample(); f.bossKind = "Ratsar"; f.activityId = "Arena"; f.difficulty = 2;
        var report = f.json("20260914-132030", 8);
        var legacy = FightHistory.legacy(report, f.startedAt + 10000, "legacy_" + haxe.crypto.Md5.encode(report.session_id));
        Reflect.deleteField(legacy, "difficulty"); store.save(legacy);
        FileSystem.createDirectory(root + "/logs/sent");
        File.saveContent(root + "/logs/sent/run_20260914-132030_8.json", Json.stringify(report));
        var reopened = new FightHistoryStore(root, _ -> {});
        var recovered = reopened.query(request("chart", "", 0, legacy.id)).record;
        check(recovered.difficulty == 2, "Recover missing difficulty even when legacy activity metadata already exists");
        check(Json.parse(File.getContent(root + "/history/" + legacy.id + ".json")).difficulty == null, "Difficulty recovery never rewrites the old log");
        check(HistoryCategory.encounterName({name: "Boss", difficulty: 7}, null) == "Boss - Difficulty 7", "Unrecognized future difficulty remains distinct");
        remove(root);
    }
    static function historyActions():Void {
        var root = temp("recycle");
        var recycled:Array<String> = [];
        FileSystem.createDirectory(root + "/Recycle Bin");
        var store = new FightHistoryStore(root, _ -> {}, path -> {
            recycled.push(path);
            FileSystem.rename(path, root + "/Recycle Bin/" + haxe.io.Path.withoutDirectory(path));
        });
        var source = FightHistory.encode(sample(), "chosen");
        store.save(source); store.save(FightHistory.encode(sample(), "keep"));
        store.query(request("delete", "", 0, "chosen"));
        check(recycled.length == 1 && recycled[0] == FileSystem.fullPath(root + "/history") + "/chosen.json", "Only the selected archive file is passed to the recycler by absolute path");
        check(File.getContent(root + "/Recycle Bin/chosen.json") == Json.stringify(source), "The recycled log keeps its full original contents for recovery");
        check(store.query(request("fights", "The Guardian")).entries.length == 1, "Successful recycling removes the fight from the index immediately");
        check(FileSystem.exists(root + "/history/keep.json"), "Other combat logs are untouched");
        var reopened = new FightHistoryStore(root, _ -> {});
        check(reopened.query(request("fights", "The Guardian")).entries.length == 1, "Deleted chart stays absent after restarting the archive");
        var failing = new FightHistoryStore(root, _ -> {}, _ -> { throw "Recycle unavailable"; });
        var failed = false;
        try failing.query(request("delete", "", 0, "keep")) catch (_:Dynamic) failed = true;
        check(failed && FileSystem.exists(root + "/history/keep.json") && failing.query(request("fights", "The Guardian")).entries.length == 1,
            "Recycle failure preserves the file and index instead of permanently deleting");
        var noOp = new FightHistoryStore(root, _ -> {}, _ -> {});
        failed = false;
        try noOp.query(request("delete", "", 0, "keep")) catch (_:Dynamic) failed = true;
        check(failed && noOp.query(request("fights", "The Guardian")).entries.length == 1, "A recycler reporting success without moving the file cannot hide it");
        var unexpectedlyDestructive = new FightHistoryStore(root, _ -> {}, path -> { FileSystem.deleteFile(path); throw "Shell could not confirm recycling"; });
        var retainedContent = File.getContent(root + "/history/keep.json");
        failed = false;
        try unexpectedlyDestructive.query(request("delete", "", 0, "keep")) catch (_:Dynamic) failed = true;
        check(failed && File.getContent(root + "/history/keep.json") == retainedContent,
            "An unexpected destructive shell failure restores the complete log from its recovery backup");
        check(!FileSystem.exists(root + "/history/chosen.json.tmp") && !FileSystem.exists(root + "/history/keep.json.tmp"),
            "Completed and rolled-back deletion leave no draft that could resurrect or replace a chart later");
        failed = false;
        try store.query(request("delete", "", 0, "../keep")) catch (_:Dynamic) failed = true;
        check(failed && recycled.length == 1, "Invalid or unindexed IDs never reach the filesystem recycler");
        var queue = HistoryRequests.coalesce([request("groups"), request("fights"), request("delete", "", 0, "keep"), request("chart"), request("categories")]);
        check([for (r in queue) r.action].join(",") == "fights,delete,categories", "Navigation coalescing preserves every explicit deletion in order");
        queue = HistoryRequests.coalesce([request("delete", "", 0, "a"), request("delete", "", 0, "b")]);
        check(queue.length == 2 && queue[0].fightId == "a" && queue[1].fightId == "b", "Consecutive mutations cannot supersede one another");
        // Exercise the actual worker's navigation queue, not just its coalescer.
        var worker = new LogUploader(root);
        var failedDelete = request("delete", "", 0, "keep"); failedDelete.id = 100;
        var followup = request("categories"); followup.id = 101;
        worker.requestHistory(failedDelete); worker.requestHistory(followup); worker.browseHistory();
        var result = worker.receiveHistory();
        check(result.id == 100 && result.error != "", "Worker reports the deletion result even when navigation arrives immediately after it");
        check(worker.receiveHistory().id == 101 && FileSystem.exists(root + "/history/keep.json"), "Worker then services navigation; missing native bridge never deletes permanently");
        remove(root);

        var f = sample(); var plan = FightSnapshot.plan(f);
        check(plan.rows.length == 2 && plan.rows[0].name == "1. Ally" && plan.rows[0].dps == 50, "Snapshot uses the full ranked party and archived fight duration");
        check(Math.abs(plan.rows[0].percent + plan.rows[1].percent - 100) < .000001, "Snapshot contributions use all players' total damage");
        var original = Json.stringify(FightHistory.encode(f, "unchanged"));
        FightSnapshot.plan(f);
        check(Json.stringify(FightHistory.encode(f, "unchanged")) == original, "Snapshot planning does not mutate the saved chart");
        for (i in 0...120) { var uid = "player_" + i; f.add(hit(12, i + 1, false, false, uid), profile(uid, false)); }
        plan = FightSnapshot.plan(f);
        check(plan.rows.length == 122 && plan.height > 5800 && plan.height >= 140 + 122 * plan.rowHeight,
            "Large rift snapshots grow tall enough for every row beyond the visible viewport");
        var instant = new Fight(10); instant.add(hit(10, 7), profile()); instant.closed = 10;
        check(FightSnapshot.plan(instant).rows[0].dps == 7, "Snapshot DPS uses the same one-second floor for instant fights");
        plan = FightSnapshot.plan(new Fight(1));
        check(plan.rows.length == 0 && plan.height > 140, "Empty snapshots reserve readable empty-state space");
    }
    static function snapshotTextures():Void {
        GameAccess.globals["hxd.PixelFormat.RGBA"] = "RGBA";
        GameAccess.globals["hxd.PixelFormat.BGRA"] = "BGRA";
        var flags = ["Target"];
        var texture = SnapshotTexture.create(2, 1, flags);
        check(texture.format == "RGBA" && texture.width == 2 && texture.height == 1 && texture.flags == flags,
            "Snapshot allocates a DX12-supported RGBA target with the requested dimensions and flags");
        var pixels:Dynamic = {format: "RGBA", bytes: haxe.io.Bytes.ofHex("ff0000ff0000ffff"), disposed: false};
        GameAccess.globals["capturedPixels"] = pixels;
        check(SnapshotTexture.readBgra(texture) == pixels && pixels.format == "BGRA"
            && (cast pixels.bytes:haxe.io.Bytes).toHex() == "0000ffffff0000ff",
            "Readback converts red and blue pixels to the clipboard's channel order");
        check(texture.format == "RGBA" && !pixels.disposed, "Conversion leaves the GPU target unchanged and readback alive for copying");
        GameAccess.globals["failPixelConversion"] = true;
        var failed = false;
        try SnapshotTexture.readBgra(texture) catch (_:Dynamic) failed = true;
        check(failed && pixels.disposed, "Failed CPU conversion releases the captured pixel buffer");
        GameAccess.globals.remove("failPixelConversion");
        GameAccess.globals.remove("capturedPixels");
        failed = false;
        try SnapshotTexture.readBgra(texture) catch (_:Dynamic) failed = true;
        check(failed, "Failed GPU readback reports an error instead of accessing a null pixel buffer");
    }
    static function breakdown():Void {
        var skill = new SkillStats(); skill.damage = 4500; skill.casts = 13; skill.hits = 15; skill.crits = 7;
        var values = SkillBreakdown.values(skill, 25000, 82);
        check(values.damage == 4500 && values.percent == 18 && Math.abs(values.dps - 54.87804878) < .00001, "Ability damage/share/DPS use player damage and whole-fight duration");
        check(values.avgCast == 4500 / 13 && values.avgHit == 300 && values.crit == 700 / 15, "Separate cast/hit averages and hit-based crit percentage");
        var empty = SkillBreakdown.values(new SkillStats(), 0, 0);
        check(empty.percent == 0 && empty.dps == 0 && empty.avgCast == 0 && empty.avgHit == 0 && empty.crit == 0, "Empty charts have finite statistics");
        check(SkillBreakdown.values(skill, 4500, .001).dps == 4500, "Instant-fight DPS matches the player chart's one-second floor");
        var f = sample(); var roundtrip = FightHistory.decode(Json.parse(Json.stringify(FightHistory.encode(f, "table"))));
        var totalDps = 0.0; var totalPercent = 0.0;
        for (s in roundtrip.players["me"].skills) {
            var v = SkillBreakdown.values(s, roundtrip.players["me"].damage, roundtrip.duration(9999));
            totalDps += v.dps; totalPercent += v.percent;
        }
        check(totalDps == 35.05 && totalPercent == 100, "Reopened ability DPS sums to the archived player's DPS");
        for (width in [280, 360, 579, 580, 799, 800, 828, 852]) {
            var columns = SkillBreakdown.columns(width); var edge = 0;
            for (c in columns) { check(c.x == edge && c.width > 0, "Table columns cannot overlap at width " + width); edge += c.width; }
            check(edge == width && columns[0].key == "ability" && columns[1].key == "damage"
                && columns[columns.length - 1].key == "dps", "Core information fits every supported width " + width);
        }
        check(SkillBreakdown.columns(828).length == 8, "Normal history width shows every reference column");
    }
}

enum TestObjectiveTarget { Unit(id:String); }
