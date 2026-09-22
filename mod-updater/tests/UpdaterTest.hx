import modupdater.UpdateModel;
import modupdater.UpdateModel.AvailableUpdate;
import modupdater.InstalledMods;
import modupdater.NexusClient;
import modupdater.ReminderStore;
import modupdater.PopupRetry;
import sys.io.File;
import sys.FileSystem;

class UpdaterTest {
    static var checks=0;
    static function eq(a:Dynamic,b:Dynamic):Void {checks++;if(a!=b)throw 'Expected $b, got $a';}
    static function u(id:Int,a:String,b:String):AvailableUpdate
        return {name:"Mod "+id,domain:"farever",modId:id,current:a,latest:b};
    static function main():Void {
        for(p in [["1.10.0","1.9.0"],["2","1.99.99"],["1.0.0","1.0.0-rc.1"],["1.0.0-rc.10","1.0.0-rc.2"]]) {
            eq(UpdateModel.compare(p[0],p[1]),1);eq(UpdateModel.compare(p[1],p[0]),-1);
        }
        for(p in [["v1.0.0","1"],["1.2.0+build","1.2"]])eq(UpdateModel.compare(p[0],p[1]),0);
        for(v in ["","latest","1.2 broken","999999999999999999999"])eq(UpdateModel.compare(v,"1"),null);
        var ignored:Map<String,String>=[];
        var list=[u(1,"1","2"),u(2,"2","3")];
        eq(UpdateModel.needsReminder(list,ignored),true);
        UpdateModel.dismiss(list,ignored);
        eq(UpdateModel.needsReminder(list,ignored),false);
        eq(UpdateModel.needsReminder([list[1],list[0]],ignored),false);
        eq(UpdateModel.needsReminder([list[0]],ignored),false);
        eq(UpdateModel.needsReminder([],ignored),false);
        eq(UpdateModel.needsReminder([u(1,"1","3"),list[1]],ignored),true);
        eq(UpdateModel.needsReminder([list[0],list[1],u(3,"1","2")],ignored),true);
        eq(UpdateModel.needsReminder([u(1,"0","1")],ignored),false);
        UpdateModel.dismiss([u(1,"1","3")],ignored);
        eq(ignored.get("farever/2"),"3");
        eq(UpdateModel.needsReminder([u(1,"1","2")],ignored),false);
        eq(UpdateModel.needsReminder([u(1,"2","3")],ignored),false);
        for(p in ["../x","C:/x","/x","a/../../x","a\\..\\x"])eq(InstalledMods.safeRelative(p),false);
        eq(InstalledMods.safeRelative("hlx/mods/foo/foo.hl"),true);
        var record:Dynamic={state:"installed",attributes:{source:"nexus",modId:15,version:"1.5.0",name:"Minimap",game:["farever"]}};
        eq(InstalledMods.fromVortex(record).version,"1.5.0");
        record.attributes.downloadGame="site";eq(InstalledMods.fromVortex(record).domain,"site");
        record.attributes.source="other";eq(InstalledMods.fromVortex(record),null);
        var files:Array<Dynamic>=[{version:"1.5.1",date:1789696451,categoryId:7},{version:"1.6.0",date:1789890908,categoryId:1}];
        var source="Minimap-15-1-5-1-1789696451";
        eq(InstalledMods.archiveCandidate(source).id,15);
        eq(NexusClient.archiveVersion(source,15,files),"1.5.1");
        eq(NexusClient.archiveVersion(source+".zip",15,files),"1.5.1");
        eq(NexusClient.archiveVersion("Minimap-15-9-9-9-1789696451",15,files),null);
        eq(NexusClient.archiveVersion(source,16,files),null);
        eq(InstalledMods.archiveCandidate("renamed"),null);
        // Exact modern filename reported by a Vortex user, verified against
        // Nexus file 104; the preceding file on the same page has another SQID.
        var modern="game-version-driver 16 0.0.1 2026-09-20T20-28Z FgeIvI3Az";
        var modernFiles:Array<Dynamic>=[{fileId:103,sqid:"5nZDPD4Hh",version:"0.0.1",date:1789932988,categoryId:7},
            {fileId:104,sqid:"FgeIvI3Az",version:"0.0.1",date:1789936115,categoryId:1}];
        eq(InstalledMods.archiveCandidate(modern).id,16);
        eq(InstalledMods.archiveCandidate(modern+".ZIP").id,16);
        eq(NexusClient.archiveVersion(modern,16,modernFiles),"0.0.1");
        eq(NexusClient.archiveVersion(modern+".ZIP",16,modernFiles),"0.0.1");
        eq(NexusClient.archiveVersion(modern,17,modernFiles),null);
        eq(NexusClient.archiveVersion(StringTools.replace(modern,"0.0.1","9.9.9"),16,modernFiles),null);
        eq(NexusClient.archiveVersion(StringTools.replace(modern,"20-28Z","20-29Z"),16,modernFiles),null);
        eq(NexusClient.archiveVersion(StringTools.replace(modern,"FgeIvI3Az","5nZDPD4Hh"),16,modernFiles),null);
        eq(NexusClient.archiveVersion(modern,16,[{version:"0.0.1",date:1789936115}]),null);
        eq(InstalledMods.archiveCandidate("mod 16 0.0.1 2026-09-20T20-28Z"),null);

        var retry=new PopupRetry(), menu:Dynamic={}, game:Dynamic={};
        eq(retry.ready(menu,0),true);
        eq(retry.failed(0,"building header: not ready"),true);
        eq(retry.ready(menu,4),false); eq(retry.ready(menu,5),true);
        eq(retry.failed(5,"building header: not ready"),false); // No duplicate log spam.
        eq(retry.ready(menu,14),false); eq(retry.ready(menu,15),true);
        eq(retry.failed(15,"building header: not ready"),false);
        eq(retry.ready(menu,34),false); eq(retry.ready(menu,35),true); // The old three-attempt cutoff.
        retry.failed(35,"building header: not ready");
        eq(retry.ready(game,36),true); // Menu -> game resets the backoff immediately.
        eq(retry.failed(36,"building header: not ready"),true);
        eq(retry.ready(game,40),false); eq(retry.ready(game,41),true);
        eq(retry.failed(41,"building checkbox: failure"),true); // A different error is reported.
        retry.succeeded(); eq(retry.ready(game,41),true);
        for(i in 0...10) {
            retry.failed(i*100,"temporarily unavailable");
            eq(retry.ready(game,i*100+60),true); // Delays are bounded, attempts are not.
        }
        eq(NexusClient.hasDownload({name:"Minimap",version:"1.6.0",files:files}),true);
        eq(NexusClient.hasDownload({name:"Minimap",version:"1.5.1",files:files}),false);
        var root="tests/tmp-"+Std.random(10000000);
        try {
            var base=root+"/game/hlx/mods/example";
            FileSystem.createDirectory(base);File.saveContent(base+"/example.hl","fixture");
            var state=root+"/state/reminders.json";
            ReminderStore.save(state,ignored);eq(ReminderStore.load(state).get("farever/1"),"3");
            UpdateModel.dismiss([u(1,"1","4")],ignored);
            ReminderStore.save(state,ignored);eq(ReminderStore.load(state).get("farever/1"),"4");
            File.saveContent(state,"broken");eq(ReminderStore.load(state).get("farever/1"),"3");
            FileSystem.deleteFile(state+".bak");
            eq([for(k in ReminderStore.load(state).keys())k].length,0);
            var manifest:Dynamic={version:1,gameId:"farever",files:[
                {relPath:"hlx/mods/example/example.hl",source:source,time:FileSystem.stat(base+"/example.hl").mtime.getTime()},
                {relPath:"removed.hl",source:"removed",time:0}]};
            File.saveContent(root+"/game/vortex.deployment.json",haxe.Json.stringify(manifest));
            var scan=new InstalledMods();scan.scan(root+"/game",root+"/empty");
            eq(scan.deployed.length,1);eq(scan.deployed[0].source,source);eq(scan.deployed[0].metadata,null);
            var backup=root+"/vortex/temp/state_backups_full";FileSystem.createDirectory(backup);
            record.attributes.source="nexus";record.attributes.downloadGame="farever";
            var mods:Dynamic={};Reflect.setField(mods,source,record);
            File.saveContent(backup+"/hourly.json",haxe.Json.stringify({persistent:{mods:{farever:mods}}}));
            scan=new InstalledMods();scan.scan(root+"/game",root+"/vortex");eq(scan.deployed[0].metadata.version,"1.5.0");
            manifest.files[0].time=0;
            File.saveContent(root+"/game/vortex.deployment.json",haxe.Json.stringify(manifest));
            scan=new InstalledMods();scan.scan(root+"/game",root+"/vortex");eq(scan.deployed.length,0);
            // A changed test build must not hide other verified deployed mods.
            FileSystem.createDirectory(root+"/game/hlx/mods/driver");
            var driver=root+"/game/hlx/mods/driver/driver.hl";File.saveContent(driver,"driver fixture");
            manifest.files.push({relPath:"hlx/mods/driver/driver.hl",source:modern,time:FileSystem.stat(driver).mtime.getTime()});
            File.saveContent(root+"/game/vortex.deployment.json",haxe.Json.stringify(manifest));
            scan=new InstalledMods();scan.scan(root+"/game",root+"/vortex");
            eq(scan.deployed.length,1);eq(scan.deployed[0].source,modern);
            var info:Dynamic={name:"Example",modId:15,domain:"farever",version:"1.2.3",binary:"example.hl",sha256:haxe.crypto.Sha256.make(File.getBytes(base+"/example.hl")).toHex()};
            File.saveContent(base+"/update-info.json",haxe.Json.stringify(info));
            scan=new InstalledMods();scan.scan(root+"/game",root+"/empty");eq(scan.manual.length,1);
            File.saveContent(base+"/example.hl","replaced");
            scan=new InstalledMods();scan.scan(root+"/game",root+"/empty");eq(scan.manual.length,0);
        }catch(e:Dynamic){remove(root);throw e;}
        remove(root);Sys.println('Mod Updater: $checks checks passed.');
    }
    static function remove(p:String):Void {
        if(!FileSystem.exists(p))return;
        if(FileSystem.isDirectory(p)){for(n in FileSystem.readDirectory(p))remove(p+"/"+n);FileSystem.deleteDirectory(p);}
        else FileSystem.deleteFile(p);
    }
}
