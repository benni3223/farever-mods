package dpsmeter;

import dpsmeter.FightHistory;
import dpsmeter.HistoryCatalog;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;

/** Worker-owned archive. Only compact summaries stay in memory; charts load on demand. */
class FightHistoryStore {
    final root:String;
    final folder:String;
    final log:String->Void;
    final entries:Map<String, HistoryEntry> = [];
    var initialized:Bool = false;
    var indexed:Bool = false;
    var catalog:HistoryCatalog;
    var legacyMetadata:Map<String, Dynamic>;
    public function new(root:String, log:String->Void) {
        this.root = root; this.folder = root + "/history"; this.log = log;
    }
    public function initialize():Void {
        if (initialized) return;
        FileSystem.createDirectory(folder);
        for (name in FileSystem.readDirectory(folder)) if (StringTools.endsWith(name, ".json.tmp")) {
            var path = folder + "/" + name;
            if (FileSystem.isDirectory(path)) continue;
            var record:Dynamic;
            try {
                record = Json.parse(File.getContent(path));
                FightHistory.validate(record);
                if (path != recordPath(record.id) + ".tmp") throw "Draft filename does not match its ID.";
            } catch (e:Dynamic) { log("Could not recover " + name + ": " + Std.string(e)); continue; }
            var committed = recordPath(record.id);
            if (!FileSystem.exists(committed)) FileSystem.rename(path, committed);
        }
        // Do this before the uploader writes new reports. Stable imported IDs
        // make retries safe if the process exits before committing the marker.
        var marker = folder + "/legacy-imported";
        if (!FileSystem.exists(marker)) {
            for (source in [root + "/logs", root + "/logs/sent", root + "/logs/rejected"])
                if (FileSystem.exists(source)) for (name in FileSystem.readDirectory(source)) {
                    if (!StringTools.startsWith(name, "run_") || !StringTools.endsWith(name, ".json")) continue;
                    var path = source + "/" + name;
                    if (FileSystem.isDirectory(path)) continue;
                    var record:Dynamic;
                    try {
                        var report:Dynamic = Json.parse(File.getContent(path));
                        var key = FightHistory.text(report.session_id);
                        if (key == "") key = name;
                        var timestamp = FileSystem.stat(path).mtime.getTime();
                        var date = ~/^run_([0-9]{4})([0-9]{2})([0-9]{2})-([0-9]{2})([0-9]{2})([0-9]{2})/;
                        if (date.match(name)) timestamp = Date.fromString(date.matched(1) + "-" + date.matched(2) + "-"
                            + date.matched(3) + " " + date.matched(4) + ":" + date.matched(5) + ":" + date.matched(6)).getTime();
                        record = FightHistory.legacy(report, timestamp, "legacy_" + haxe.crypto.Md5.encode(key));
                        FightHistory.validate(record);
                    } catch (e:Dynamic) { log("Could not import " + name + ": " + Std.string(e)); continue; }
                    // A disk failure must not mark unfinished migration complete.
                    save(record);
                }
            File.saveContent(marker, "1\n");
        }
        initialized = true;
    }
    public function save(record:Dynamic):Void {
        var summary = FightHistory.entry(record);
        var path = recordPath(summary.id);
        FileSystem.createDirectory(folder);
        if (!FileSystem.exists(path)) {
            var temp = path + ".tmp";
            File.saveContent(temp, Json.stringify(record));
            FileSystem.rename(temp, path);
        }
        if (indexed) entries[summary.id] = summary;
    }
    function index():Void {
        initialize();
        if (indexed) return;
        for (name in FileSystem.readDirectory(folder)) {
            if (!StringTools.endsWith(name, ".json")) continue;
            var path = folder + "/" + name;
            if (FileSystem.isDirectory(path)) continue;
            try {
                var record:Dynamic = Json.parse(File.getContent(path));
                restoreLegacyMetadata(record);
                var entry = FightHistory.entry(record);
                if (path != recordPath(entry.id)) throw "History filename does not match its ID.";
                entries[entry.id] = entry;
            } catch (e:Dynamic) log("Could not read " + name + ": " + Std.string(e));
        }
        indexed = true;
        legacyMetadata = null;
    }
    public function query(request:HistoryRequest):HistoryResponse {
        if (request.catalog != null) catalog = request.catalog;
        index();
        var response:HistoryResponse = {id: request.id, page: 0, total: 0, groups: [], entries: [], record: null, error: ""};
        if (request.action == "chart") {
            if (!entries.exists(request.fightId)) throw "This fight log could not be found.";
            response.record = Json.parse(File.getContent(recordPath(request.fightId)));
            FightHistory.validate(response.record);
        } else if (request.action == "categories") {
            var counts:Map<String, Int> = [];
            for (entry in entries) {
                var category = HistoryCategory.resolve(entry, catalog);
                counts[category] = counts.exists(category) ? counts[category] + 1 : 1;
            }
            response.groups = [for (name in HistoryCategory.all()) {name: name, count: counts.exists(name) ? counts[name] : 0}];
            response.total = response.groups.length;
        } else if (request.action == "groups") {
            var counts:Map<String, Int> = [];
            for (entry in entries) if (matches(entry, request.category)) {
                var name = HistoryCategory.displayName(entry, catalog);
                counts[name] = counts.exists(name) ? counts[name] + 1 : 1;
            }
            var groups = [for (name => count in counts) {name: name, count: count}];
            groups.sort((a, b) -> Reflect.compare(a.name.toLowerCase(), b.name.toLowerCase()));
            response.total = groups.length;
            response.page = page(request.page, response.total);
            response.groups = groups.slice(response.page * FightHistory.PAGE_SIZE, (response.page + 1) * FightHistory.PAGE_SIZE);
        } else if (request.action == "fights") {
            var fights = [for (entry in entries) if (matches(entry, request.category)
                && HistoryCategory.displayName(entry, catalog) == request.group) entry];
            fights.sort((a, b) -> a.startedAt == b.startedAt ? Reflect.compare(b.id, a.id) : a.startedAt > b.startedAt ? -1 : 1);
            response.total = fights.length;
            response.page = page(request.page, response.total);
            response.entries = fights.slice(response.page * FightHistory.PAGE_SIZE, (response.page + 1) * FightHistory.PAGE_SIZE);
        } else throw "Unknown history action.";
        return response;
    }
    function matches(entry:HistoryEntry, category:Null<String>):Bool
        return category == null || category == "" || HistoryCategory.resolve(entry, catalog) == category;
    function restoreLegacyMetadata(record:Dynamic):Void {
        var id = FightHistory.text(record.id);
        if (!StringTools.startsWith(id, "legacy_") || FightHistory.text(record.activityId) != "") return;
        if (legacyMetadata == null) {
            legacyMetadata = [];
            // The original history release omitted these fields. Its stable
            // legacy ID lets us recover exact metadata from retained reports,
            // without matching by time/name or rewriting any user's log.
            for (source in [root + "/logs", root + "/logs/sent", root + "/logs/rejected"])
                if (FileSystem.exists(source)) for (name in FileSystem.readDirectory(source)) {
                    if (!StringTools.startsWith(name, "run_") || !StringTools.endsWith(name, ".json")) continue;
                    var path = source + "/" + name;
                    if (FileSystem.isDirectory(path)) continue;
                    try {
                        var report:Dynamic = Json.parse(File.getContent(path));
                        var key = FightHistory.text(report.session_id);
                        if (key == "") key = name;
                        legacyMetadata["legacy_" + haxe.crypto.Md5.encode(key)] = {
                            activityId: FightHistory.text(report.activity_id), bossKind: FightHistory.text(report.boss_kind),
                            phase: FightHistory.text(report.phase)
                        };
                    } catch (_:Dynamic) {}
                }
        }
        var metadata = legacyMetadata[id];
        if (metadata != null) for (field in ["activityId", "bossKind", "phase"])
            Reflect.setField(record, field, Reflect.field(metadata, field));
    }
    static function page(requested:Int, total:Int):Int return Std.int(Math.max(0,
        Math.min(requested, Math.max(0, Math.ceil(total / FightHistory.PAGE_SIZE) - 1))));
    function recordPath(id:String):String {
        if (!~/^[A-Za-z0-9_-]+$/.match(id)) throw "Invalid fight log ID.";
        return folder + "/" + id + ".json";
    }
}
