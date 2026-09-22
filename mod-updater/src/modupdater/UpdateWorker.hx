package modupdater;

import sys.thread.Deque;
import sys.thread.Mutex;
import modupdater.UpdateModel.InstalledMod;
import modupdater.UpdateModel.AvailableUpdate;

typedef CheckResult = {
    var updates:Array<AvailableUpdate>;
    var dismissed:Map<String,String>;
    var notes:Array<String>;
}

class UpdateWorker {
    public final results=new Deque<CheckResult>();
    public final saves=new Deque<Map<String,String>>();
    final mutex=new Mutex();
    var cancelled=false;
    final root:String;
    final state:String;
    public function new(root:String) {
        this.root=root;
        state=haxe.io.Path.join([root,"hlx","config","mod-updater","reminders.json"]);
    }
    public function stop():Void { mutex.acquire(); cancelled=true; mutex.release(); }
    function stopped():Bool { mutex.acquire(); var result=cancelled; mutex.release(); return result; }
    public function run():Void {
        var result:CheckResult={updates:[],dismissed:ReminderStore.load(state),notes:[]};
        try {
            var inventory=new InstalledMods();
            inventory.scan(root);
            result.notes=inventory.diagnostics;
            var client=new NexusClient(stopped);
            var installed=inventory.manual.copy();
            for (entry in inventory.deployed) {
                if (stopped()) return;
                var info=entry.metadata;
                if (info==null) {
                    var candidate=InstalledMods.archiveCandidate(entry.source);
                    if (candidate!=null) for (domain in ["farever","site"]) {
                        var remote=client.fetch(domain,candidate.id);
                        if (remote==null) continue;
                        var version=NexusClient.archiveVersion(candidate.archive,candidate.id,remote.files);
                        if (version!=null) {
                            info={name:remote.name,version:version,domain:domain,modId:candidate.id};
                            break;
                        }
                    }
                }
                if (info!=null) installed.push(info);
                else result.notes.push("Could not identify installed version: "+entry.source);
            }
            // Multiple modules/optional files may belong to one Nexus page. Use the newest
            // installed version so an older optional file cannot create a false update.
            var unique:Map<String,InstalledMod>=[];
            for (mod in installed) {
                var key=UpdateModel.identity(mod.domain,mod.modId), old=unique.get(key);
                if (old==null || UpdateModel.compare(mod.version,old.version)==1) unique.set(key,mod);
            }
            for (mod in unique) {
                if (stopped()) return;
                var latest=client.fetch(mod.domain,mod.modId);
                if (latest==null) { result.notes.push("Nexus metadata unavailable: "+mod.name); continue; }
                var comparison=UpdateModel.compare(latest.version,mod.version);
                if (comparison==null) result.notes.push("Unrecognized version format: "+mod.name);
                if (comparison==1 && NexusClient.hasDownload(latest))
                    result.updates.push({name:latest.name,domain:mod.domain,modId:mod.modId,current:mod.version,latest:latest.version});
            }
            result.updates.sort((a,b)->Reflect.compare(a.name.toLowerCase(),b.name.toLowerCase()));
        } catch (_:Dynamic) result.notes.push("Update check incomplete: network or local metadata unavailable. Will retry next launch.");
        if (stopped()) return;
        results.add(result);
        // Keep disk writes off the game thread; one worker for the game process.
        while (true) {
            var pending=saves.pop(false);
            if (pending!=null) try ReminderStore.save(state,pending) catch (_:Dynamic)
                trace("[Mod Updater] Could not save reminder preferences.");
            if (stopped() && pending==null) break;
            Sys.sleep(0.1);
        }
    }
}
