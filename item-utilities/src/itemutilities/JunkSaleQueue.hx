package itemutilities;

typedef JunkSaleItem = {
    var item:Dynamic;
    var uid:String;
    var fingerprint:String;
    var count:Int;
}

/** One normal sale at a time, acknowledged AND absent before sending another. */
class JunkSaleQueue {
    public var active(default, null) = false;
    public var requestId(default, null) = 0;
    public var sold(default, null) = 0;
    public var error(default, null) = "";
    public var pending(default, null):JunkSaleItem;
    var context:Dynamic;
    var queue:Array<JunkSaleItem> = [];
    var acknowledged = false;
    var deadline = 0.;
    public function new() {}

    public function start(context:Dynamic, items:Array<JunkSaleItem>):Bool {
        if (active || context == null || items.length == 0) return false;
        this.context = context; queue = items.copy(); pending = null;
        sold = 0; error = ""; active = true;
        return true;
    }

    public function next(context:Dynamic, now:Float, present:JunkSaleItem->Bool,
            eligible:JunkSaleItem->Bool):JunkSaleItem {
        if (!active) return null;
        if (context != this.context) { cancel("Selling junk stopped because the merchant or character changed."); return null; }
        if (pending != null) {
            if (now >= deadline) { cancel("Selling junk stopped while waiting for the server."); return null; }
            if (!acknowledged || present(pending)) return null;
            sold++; pending = null;
        }
        while (queue.length > 0) {
            var item = queue.shift();
            if (!eligible(item)) continue;
            pending = item; acknowledged = false; deadline = now + 5.; requestId++;
            return item;
        }
        cancel();
        return null;
    }

    public function acknowledge(id:Int, success:Bool):Void {
        if (!active || pending == null || id != requestId) return;
        if (!success) cancel("The game rejected a junk sale. Selling stopped.");
        else acknowledged = true;
    }
    public function cancel(message:String = ""):Void {
        active = false; error = message; context = null; queue = []; pending = null;
    }
}
