package modupdatealerts;

import sys.io.File;
import sys.FileSystem;

class ReminderStore {
    public static function loadForRoot(root:String):Map<String,String> {
        var path = haxe.io.Path.join([root,"hlx","config","mod-update-alerts","reminders.json"]);
        if (FileSystem.exists(path) || FileSystem.exists(path+".bak")) return load(path);
        // Keep existing choices when upgrading the renamed mod. New writes use
        // the new directory; an intentionally empty new file takes precedence.
        return load(haxe.io.Path.join([root,"hlx","config","mod-updater","reminders.json"]));
    }
    public static function load(path:String):Map<String,String> {
        for (candidate in [path,path+".bak"]) try {
            if (!FileSystem.exists(candidate) || FileSystem.stat(candidate).size>262144) continue;
            var data:Dynamic=haxe.Json.parse(File.getContent(candidate));
            var values:Dynamic=Reflect.field(data,"dismissed");
            if(values==null) continue;
            var result:Map<String,String>=[];
            for(key in Reflect.fields(values)) {
                var value:Dynamic=Reflect.field(values,key);
                if(Std.isOfType(value,String)) result.set(key,value);
            }
            return result;
        }catch(_:Dynamic){}
        return [];
    }
    public static function save(path:String,values:Map<String,String>):Void {
        FileSystem.createDirectory(haxe.io.Path.directory(path));
        var data:Dynamic={};
        for(key=>value in values)Reflect.setField(data,key,value);
        File.saveContent(path+".tmp",haxe.Json.stringify({schemaVersion:1,dismissed:data}));
        // HashLink uses Windows _wrename, which cannot overwrite an existing file.
        // Rotate the committed copy first; load can recover it if the game exits
        // between the two renames.
        if(FileSystem.exists(path)) {
            if(FileSystem.exists(path+".bak"))FileSystem.deleteFile(path+".bak");
            FileSystem.rename(path,path+".bak");
        }
        FileSystem.rename(path+".tmp",path);
    }
}
