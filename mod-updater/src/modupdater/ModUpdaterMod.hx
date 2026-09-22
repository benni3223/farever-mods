package modupdater;

import hlx.runtime.HlxPrefixResult;
import modupdater.UpdateWorker.CheckResult;

@:build(hlx.runtime.Mod.build())
class ModUpdaterMod {
    static var worker:UpdateWorker;
    static var result:CheckResult;
    static var popup:UpdatePopup;
    static var finished=false;
    static var selected=false;
    static var originalDismissed:Map<String,String>;
    static var retryAt:Float=0;
    static var attempts=0;

    static function main():Void {
        trace("[Mod Updater] Loaded; checking starts when the game UI is ready.");
    }

    @:hlx.postfix(ui.BaseUI.update)
    static function update(ui:Dynamic,dt:Float,ignored:Void):Void {
        try {
            if(GameAccess.current("ui.BaseUI","current")!=ui) return;
            // Starting threads during HLX module loading can deadlock the loader.
            if(worker==null) {
                worker=new UpdateWorker(Sys.getCwd());
                sys.thread.Thread.create(worker.run);
            }
            if(result==null) {
                result=worker.results.pop(false);
                if(result!=null) {
                    originalDismissed=result.dismissed.copy();
                    for(note in result.notes) trace("[Mod Updater] "+note);
                    trace("[Mod Updater] "+result.updates.length+" update(s) available.");
                    if(!UpdateModel.needsReminder(result.updates,result.dismissed)) finished=true;
                }
            }
            if(finished || result==null) return;
            if(popup!=null && popup.update(ui)) return;
            if(haxe.Timer.stamp()<retryAt || attempts>=3) return;
            popup=new UpdatePopup();
            attempts++;
            popup.open(ui,result.updates,function(suppress:Bool):Void {
                finished=true;
                popup=null;
            }, function(value:Bool):Void {
                selected=value;
                result.dismissed=originalDismissed.copy();
                if(value) UpdateModel.dismiss(result.updates,result.dismissed);
                worker.saves.add(result.dismissed.copy());
            }, selected);
            attempts=0;
        } catch (_:Dynamic) {
            UpdatePopup.constructing=false;
            if(popup!=null) try popup.dispose() catch (_:Dynamic) {}
            popup=null;retryAt=haxe.Timer.stamp()+10;
            trace("[Mod Updater] Popup not ready; retrying when the UI is available.");
        }
    }

    @:hlx.prefix(ui.win.BaseWindow.autoDisplay)
    static function suppressAutoDisplay(window:Dynamic):HlxPrefixResult<Void> {
        return UpdatePopup.constructing ? Skip : Continue;
    }

    @:hlx.prefix(ui.BaseUI.closeFirstClosableUI)
    static function closeOnEscape(ui:Dynamic,onlyEscapeClosable:Null<Bool>):HlxPrefixResult<Bool> {
        if(popup!=null && popup.owner==ui) {popup.dismiss();return SkipWith(true);}
        return Continue;
    }

    @:hlx.prefix(App.quit)
    static function stop(app:Dynamic):HlxPrefixResult<Void> {
        if(worker!=null) worker.stop();
        return Continue;
    }
}
