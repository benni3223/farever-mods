package modupdater;

import modupdater.UpdateModel.InstalledMod;

typedef NexusMod = {
    var name:String;
    var version:String;
    var files:Array<Dynamic>;
}

/** Anonymous, read-only public metadata. No downloads, credentials, or browser scraping. */
class NexusClient {
    var games:Map<String,String> = [];
    var cache:Map<String,Null<NexusMod>> = [];
    final stopped:Void->Bool;
    final deadline:Float;
    var nextRequest:Float=0;
    public function new(stopped:Void->Bool) {
        this.stopped = stopped;
        deadline = haxe.Timer.stamp() + 180;
    }
    function progress():Void {
        if (stopped()) throw "Update check cancelled";
        if (haxe.Timer.stamp() > deadline) throw "Update check time budget exhausted";
    }
    function query(query:String, variables:Dynamic):Dynamic {
        progress();
        var delay=nextRequest-haxe.Timer.stamp();
        if(delay>0) Sys.sleep(delay);
        nextRequest=haxe.Timer.stamp()+0.35;
        var request = new sys.Http("https://api.nexusmods.com/v2/graphql");
        request.cnxTimeout = 15;
        request.noShutdown = true;
        request.setHeader("Content-Type", "application/json");
        request.setHeader("User-Agent", "Farever-Mod-Updater/1.0");
        request.setPostData(haxe.Json.stringify({query:query,variables:variables}));
        var status=0, error="";
        request.onStatus = value -> status=value;
        request.onError = value -> error=value;
        var output=new haxe.io.BytesOutput();
        #if hl
        var socket=new MetadataSocket(true,progress);
        #else
        var socket=new sys.ssl.Socket();
        socket.verifyCert=true;
        socket.setTimeout(15);
        #end
        try request.customRequest(true,output,socket,"POST")
        catch (e:Dynamic) { socket.close(); throw e; }
        socket.close();
        if (status != 200 || error != "") throw "Nexus metadata request failed (HTTP " + status + ")";
        var response:Dynamic=haxe.Json.parse(output.getBytes().toString());
        if (Reflect.field(response,"errors") != null) {
            // Do not log entire server replies or local inventory.
            return null;
        }
        return Reflect.field(response,"data");
    }
    public function fetch(domain:String, modId:Int):Null<NexusMod> {
        progress();
        var key=UpdateModel.identity(domain,modId);
        if (cache.exists(key)) return cache.get(key);
        if (!games.exists(domain)) {
            var data=query("query($domain:String!){game(domainName:$domain){id}}",{domain:domain});
            var game=data==null?null:Reflect.field(data,"game");
            if (game==null) { cache.set(key,null); return null; }
            games.set(domain,Std.string(Reflect.field(game,"id")));
        }
        var data=query("query($game:ID!,$mod:ID!){mod(gameId:$game,modId:$mod){name version} modFiles(gameId:$game,modId:$mod){fileId name version date categoryId}}",
            {game:games.get(domain),mod:Std.string(modId)});
        if (data==null) { cache.set(key,null); return null; }
        var info:Dynamic=Reflect.field(data,"mod");
        var files:Dynamic=Reflect.field(data,"modFiles");
        if (info==null || !Std.isOfType(files,Array)) { cache.set(key,null); return null; }
        var result:NexusMod={name:InstalledMods.text(info,"name"),version:InstalledMods.text(info,"version"),files:cast files};
        cache.set(key,result);
        return result;
    }

    /** Verify encoded archive identity against Nexus's actual mod/version/upload time. */
    public static function archiveVersion(source:String, modId:Int, files:Array<Dynamic>):Null<String> {
        var stem=source;
        for (extension in [".zip",".7z",".rar"]) if (StringTools.endsWith(stem.toLowerCase(),extension))
            stem=stem.substr(0,stem.length-extension.length);
        var matched:Null<String>=null;
        for (file in files) {
            var version=InstalledMods.text(file,"version");
            // Upload timestamps exceed the bounded mod-ID parser.
            var stamp=Std.string(Reflect.field(file,"date"));
            if (!~/^[0-9]{10}$/.match(stamp) || version=="") continue;
            var encoded=~/[^a-zA-Z0-9]/g.replace(version,"-");
            var ending="-"+modId+"-"+encoded+"-"+stamp;
            if (!StringTools.endsWith(stem,ending)) continue;
            if (matched!=null && matched!=version) return null;
            matched=version;
        }
        return matched;
    }

    public static function hasDownload(info:NexusMod):Bool {
        for (file in info.files) if ((Reflect.field(file,"categoryId")==1 || Reflect.field(file,"categoryId")==2)
            && UpdateModel.compare(InstalledMods.text(file,"version"),info.version)==0) return true;
        return false;
    }
}
