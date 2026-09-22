import modupdatealerts.UpdatePopup;
import modupdatealerts.GameAccess;

/** Keep display-tree removal distinct from the game's modal window registry. */
@:access(modupdatealerts.UpdatePopup)
class PopupLifecycleTest {
    static var checks=0;
    static function eq(actual:Dynamic,expected:Dynamic):Void {
        checks++;
        if(actual!=expected) throw 'Expected $expected, got $actual';
    }
    public static function run():Int {
        checks=0;
        var other:Dynamic={parent:{},removed:false};
        var window:Dynamic={parent:{},removed:false};
        var owner:Dynamic={windows:[other,window]};
        var popup=new UpdatePopup(), calls=0, selected=false;
        popup.owner=owner;popup.window=window;popup.ignore=true;
        popup.onDismiss=function(value:Bool):Void {calls++;selected=value;};
        // This is the callback used by both X and the Escape hook.
        popup.dismiss();
        eq(owner.windows.length,1);eq(owner.windows[0],other);
        eq(window.parent,null);eq(other.removed,false);
        eq(popup.owner,null);eq(calls,1);eq(selected,true);
        popup.dismiss();popup.dispose();
        eq(calls,1);eq(owner.windows.length,1);

        // Disconnect/character changes must clean the old owner's registry,
        // even when BaseUI.current already points at a different UI.
        var newWindow:Dynamic={parent:{},removed:false};
        var newUi:Dynamic={windows:[newWindow]};
        GameAccess.currentUi=newUi;
        owner.windows=[window];window.parent={};window.removed=false;
        popup=new UpdatePopup();popup.owner=owner;popup.window=window;
        popup.dispose();
        eq(owner.windows.length,0);eq(newUi.windows.length,1);
        eq(newWindow.removed,false);

        // Construction may fail before an owner/window is fully established.
        popup=new UpdatePopup();popup.window={parent:{},removed:false};
        var partial=popup.window;
        popup.dispose();eq(partial.parent,null);
        popup.dispose();eq(popup.window,null);
        GameAccess.currentUi=null;
        return checks;
    }
}
