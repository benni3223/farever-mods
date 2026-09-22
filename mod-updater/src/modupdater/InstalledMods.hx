package modupdater;

import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;
import modupdater.UpdateModel.InstalledMod;

typedef DeployedMod = {
    var source:String;
    var files:Array<String>;
    var metadata:Null<InstalledMod>;
}

/** Read-only discovery. Deployment files select installed mods, never the whole staging library. */
class InstalledMods {
    public var diagnostics:Array<String> = [];
    public var manual:Array<InstalledMod> = [];
    public var deployed:Array<DeployedMod> = [];
    public function new() {}

    public static function text(value:Dynamic, key:String):String {
        var field:Dynamic = value == null ? null : Reflect.field(value, key);
        return Std.isOfType(field, String) ? StringTools.trim(field) : "";
    }
    public static function id(value:Dynamic):Int {
        if (value == null || !~/^[1-9][0-9]{0,8}$/.match(Std.string(value))) return 0;
        return Std.parseInt(Std.string(value));
    }
    public static function safeRelative(value:String):Bool {
        if (value == null || value == "") return false;
        var path = StringTools.replace(value, "\\", "/");
        return !Path.isAbsolute(path) && path.indexOf(":") < 0
            && path.indexOf("\x00") < 0 && path.split("/").indexOf("..") < 0;
    }
    static function read(path:String, limit:Int):Dynamic {
        if (FileSystem.stat(path).size > limit) throw "Metadata file is too large";
        return haxe.Json.parse(File.getContent(path));
    }

    public function scan(root:String, ?vortexPath:String):Void {
        var records:Map<String,Dynamic> = [];
        var backups:Array<String> = [];
        if (vortexPath == null || vortexPath == "") {
            var appData = Sys.getEnv("APPDATA");
            if (appData != null) vortexPath = Path.join([appData, "Vortex"]);
        }
        if (vortexPath != null && vortexPath != "") {
            var folder = Path.join([vortexPath, "temp", "state_backups_full"]);
            if (FileSystem.exists(folder)) for (file in FileSystem.readDirectory(folder))
                if (StringTools.endsWith(file, ".json")) backups.push(Path.join([folder,file]));
        }
        backups.sort((a,b) -> Reflect.compare(FileSystem.stat(b).mtime.getTime(), FileSystem.stat(a).mtime.getTime()));
        // Only the newest valid full backup; never combine conflicting snapshots.
        for (path in backups) try {
            var data = read(path, 32 * 1024 * 1024);
            var persistent = Reflect.field(data, "persistent");
            var mods = persistent == null ? null : Reflect.field(persistent, "mods");
            var farever = mods == null ? null : Reflect.field(mods, "farever");
            if (farever == null) continue;
            for (key in Reflect.fields(farever)) {
                var record=Reflect.field(farever,key);
                records.set(key,record);
                var installedPath=text(record,"installationPath");
                if(installedPath!="") records.set(installedPath,record);
            }
            break;
        } catch (_:Dynamic) {}

        var groups:Map<String,DeployedMod> = [];
        var stale:Map<String,Bool> = [];
        // Vortex writes one deployment manifest per target directory/mod type.
        for (relative in ["", "hlx", "hlx/mods", "hlx/plugins"]) {
            var folder = Path.join([root,relative]);
            if (!FileSystem.exists(folder)) continue;
            for (name in FileSystem.readDirectory(folder)) {
                if (!StringTools.startsWith(name,"vortex.deployment.") || !StringTools.endsWith(name,".json")) continue;
                try {
                    var manifest = read(Path.join([folder,name]), 16 * 1024 * 1024);
                    if (text(manifest,"gameId") != "" && text(manifest,"gameId") != "farever") continue;
                    var files:Dynamic = Reflect.field(manifest,"files");
                    if (!Std.isOfType(files,Array)) continue;
                    for (file in (cast files:Array<Dynamic>)) {
                        var source = text(file,"source"), rel = text(file,"relPath"), target = text(file,"target");
                        if (source == "" || !safeRelative(rel) || (target != "" && !safeRelative(target))) continue;
                        var extension=Path.extension(rel).toLowerCase();
                        if (["hl","dll","hdll","pak"].indexOf(extension)<0) continue;
                        var path = Path.join([folder,target,rel]);
                        if (!FileSystem.exists(path) || FileSystem.isDirectory(path)) {stale.set(source,true);continue;}
                        // Exclude purged/replaced files and stale deployment records.
                        var time:Dynamic = Reflect.field(file,"time");
                        var timestamp = Std.parseFloat(Std.string(time));
                        if (!Math.isFinite(timestamp) || Math.abs(FileSystem.stat(path).mtime.getTime() - timestamp) > 2100) {stale.set(source,true);continue;}
                        var entry = groups.get(source);
                        if (entry == null) {
                            entry = {source:source,files:[],metadata:fromVortex(records.get(source))};
                            groups.set(source,entry);
                        }
                        entry.files.push(path);
                    }
                } catch (_:Dynamic) diagnostics.push("Could not read deployment manifest " + name);
            }
        }
        for (entry in groups) if (!stale.exists(entry.source)) deployed.push(entry);
        for (source in stale.keys()) diagnostics.push("Deployed files changed or missing; cannot verify version: "+source);
        deployed.sort((a,b) -> Reflect.compare(a.source,b.source));

        // Manual installs can opt in with metadata bound to an actual binary hash.
        var modRoot = Path.join([root,"hlx","mods"]);
        if (FileSystem.exists(modRoot)) for (folder in FileSystem.readDirectory(modRoot)) {
            var base = Path.join([modRoot,folder]), path = Path.join([base,"update-info.json"]);
            if (!FileSystem.exists(path)) continue;
            try {
                var info = read(path, 16384);
                var entry = fromInfo(info);
                var binary = text(info,"binary"), hash = text(info,"sha256").toLowerCase();
                if (entry == null || !safeRelative(binary) || !~/^[a-f0-9]{64}$/.match(hash)) continue;
                var binPath = Path.join([base,binary]);
                if (!FileSystem.exists(binPath) || FileSystem.stat(binPath).size > 64 * 1024 * 1024) continue;
                if (haxe.crypto.Sha256.make(File.getBytes(binPath)).toHex() != hash) continue;
                manual.push(entry);
            } catch (_:Dynamic) diagnostics.push("Could not read update metadata for " + folder);
        }
        // Report unidentified HLX modules instead of pretending all were checked.
        if (FileSystem.exists(modRoot)) for (folder in FileSystem.readDirectory(modRoot)) {
            var base = Path.join([modRoot,folder]);
            if (!FileSystem.isDirectory(base)) continue;
            var binaries = [for (name in FileSystem.readDirectory(base)) if (StringTools.endsWith(name,".hl")) Path.join([base,name])];
            if (binaries.length == 0) continue;
            var found = FileSystem.exists(Path.join([base,"update-info.json"]));
            for (entry in deployed) for (binary in binaries) if (entry.files.indexOf(binary) >= 0) found = true;
            if (!found) diagnostics.push("No installed-version metadata for " + folder);
        }
    }

    public static function fromVortex(record:Dynamic):Null<InstalledMod> {
        if (record == null || text(record,"state") != "installed") return null;
        var a = Reflect.field(record,"attributes");
        if (text(a,"source") != "nexus") return null;
        var domain = text(a,"downloadGame");
        if (domain == "") {
            var games:Dynamic = Reflect.field(a,"game");
            if (Std.isOfType(games,Array) && (cast games:Array<Dynamic>).length == 1) domain = Std.string(games[0]);
        }
        if (domain == "") domain = "farever";
        return fromInfo({name:text(a,"name"),version:text(a,"version"),domain:domain,modId:Reflect.field(a,"modId")});
    }
    public static function fromInfo(info:Dynamic):Null<InstalledMod> {
        var domain=text(info,"domain"), version=text(info,"version"), name=text(info,"name");
        var modId=id(info==null?null:Reflect.field(info,"modId"));
        if (modId==0 || !~/^[a-z0-9_-]{1,64}$/.match(domain) || version=="" || version.length>80) return null;
        return {name:name==""?domain+"/"+modId:name,domain:domain,modId:modId,version:version};
    }

    /** Candidate only. Nexus must match its mod/version/upload-time tuple before using it. */
    public static function archiveCandidate(source:String):Null<{id:Int,archive:String}> {
        var r=~/^.+?-([0-9]+)-.+-[0-9]{10}(?:\.[A-Za-z0-9]+)?$/;
        if (!r.match(source)) {
            r=~/^.+ ([1-9][0-9]*) [^ ]+ [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}-[0-9]{2}Z [A-Za-z0-9]+(?:\.(?:zip|7z|rar))?$/i;
            if(!r.match(source)) return null;
        }
        var modId=id(r.matched(1));
        if (modId==0) return null;
        return {id:modId,archive:source};
    }
}
