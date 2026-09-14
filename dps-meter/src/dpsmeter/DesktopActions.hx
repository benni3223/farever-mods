package dpsmeter;

/** Optional Windows bridge; unavailable OS features fail without touching files. */
class DesktopActions {
    public static function openFolder(path:String):Void {
        #if hl
        var bytes = haxe.io.Bytes.ofString(path);
        check(openFolderNative(bytes, bytes.length), "Could not open the logs folder");
        #else
        throw "Opening the logs folder requires the Windows desktop plugin.";
        #end
    }
    public static function recycle(path:String):Void {
        #if hl
        var bytes = haxe.io.Bytes.ofString(path);
        check(recycleNative(bytes, bytes.length), "Could not move this log to the Recycle Bin; the log was kept");
        #else
        throw "Moving logs to the Recycle Bin requires the Windows desktop plugin.";
        #end
    }
    #if hl
    public static function copyImage(bytes:haxe.io.Bytes, width:Int, height:Int):Void {
        check(copyImageNative(bytes, bytes.length, width, height), "Could not copy the snapshot to the clipboard");
    }
    static function check(code:Int, message:String):Void {
        if (code == -1) throw "Install the complete DPS Meter download, including its desktop plugin, to use this action.";
        if (code != 0) throw message + " (Windows error " + code + ").";
    }
    @:hlNative("?dps_meter_desktop", "open_folder")
    static function openFolderNative(path:hl.Bytes, length:Int):Int return -1;
    @:hlNative("?dps_meter_desktop", "recycle_file")
    static function recycleNative(path:hl.Bytes, length:Int):Int return -1;
    @:hlNative("?dps_meter_desktop", "copy_image")
    static function copyImageNative(pixels:hl.Bytes, length:Int, width:Int, height:Int):Int return -1;
    #end
}
