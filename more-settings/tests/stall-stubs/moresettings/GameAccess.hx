package moresettings;

import sys.thread.Mutex;

/** Native-boundary simulation; production scheduling/lifecycle code is unmodified. */
class GameAccess {
    public static var me:Dynamic = {};
    public static var worker:Dynamic;
    public static var jobs:Array<Void->Void> = [];
    public static var calls:Array<String> = [];
    public static var replayed:Array<Int> = [];
    public static var onAction:String->Void;
    public static var onReady:Void->Void;
    public static var readiness:(Dynamic, Bool)->Bool = (_, value) -> value;
    public static var enqueueFails = false;

    public static function reset():Void {
        me = {}; worker = {}; jobs = []; calls = []; replayed = [];
        onAction = null; onReady = null; enqueueFails = false;
        readiness = (_, value) -> value;
    }
    public static function nativeArray(items:Array<Dynamic>):Dynamic return {items:items, length:items.length};
    public static function field(object:Dynamic, name:String):Dynamic return object == null ? null : Reflect.field(object, name);
    public static function set(object:Dynamic, name:String, value:Dynamic):Void Reflect.setField(object, name, value);
    public static function integer(value:Dynamic, fallback = 0):Int return value == null ? fallback : Std.int(value);
    public static function mutex(value:Dynamic):Mutex return cast value;
    public static function array(value:Dynamic):Array<Dynamic> return value == null ? [] : cast field(value, "items");
    public static function current(type:String, name:String):Dynamic return switch name {
        case "EQUIPMENT_SLOTS": nativeArray(["Head", "Chest", "Feet"]);
        case "OFFHAND_SLOT": 2;
        case "WEAPON_OVERRIDE_SLOT": 3;
        case "MAIN_HEAD_SLOT": "Head";
        default: throw name;
    };
    public static function staticCall(type:String, name:String, args:Array<Dynamic>):Dynamic return switch type + "." + name {
        case "GameApp.getMyHero": me;
        case "lib.Workers.get": worker;
        default: throw type + "." + name;
    };
    public static function create(type:String, args:Array<Dynamic>):Dynamic return switch type {
        case "h3d.impl.PSOConfigCache": {mutex:new Mutex(), configs:null};
        case "haxe.ds.StringMap": new Map<String, Dynamic>();
        default: throw type;
    };
    public static function call(type:String, name:String, object:Dynamic, ?args:Array<Dynamic>):Dynamic {
        if (args == null) args = [];
        switch type {
            case "GameApp": return field(object, "loading");
            case "lib.Workers":
                if (enqueueFails) throw "queue failed";
                if (name != "addJob" || args[1] != false) throw "Visual work must stay on main thread";
                jobs.push(args[0]); return null;
            case "haxe.ds.IntMap":
                var map:Map<Int, Dynamic> = cast object;
                return map.get(args[0]);
            case "haxe.ds.StringMap":
                var map:Map<String, Dynamic> = cast object;
                return switch name {
                    case "get": map.get(args[0]);
                    case "set": map.set(args[0], args[1]); null;
                    case "remove": map.remove(args[0]);
                    default: throw name;
                };
            case "hl.types.ArrayObj":
                var values = array(object);
                return switch name {
                    case "copy": nativeArray(values.copy());
                    case "slice": nativeArray(values.slice(args[0], args[1]));
                    default: throw name;
                };
            case "h3d.impl.PSOConfigCache":
                var shader = args[0];
                var configs:Map<String, Dynamic> = cast field(object, "configs");
                var variants = array(configs.get(field(field(shader, "shader"), "signature")));
                if (variants.length != 1) throw "Bulk replay on a gameplay frame";
                var lock:Mutex = cast field(shader, "pipelineMutex");
                if (!lock.tryAcquire()) throw "Native mutex must support recursive acquisition";
                for (variant in variants) replayed.push(variant);
                lock.release();
                return null;
            case "client.UnitView":
                switch name {
                    case "get_hero": return field(object, "hero");
                    case "get_skinData": return field(object, "skin");
                    case "shouldShowGear": return true;
                    case "getSlotItemDisplayed": return field(object, "item");
                    case "displayGearSlot":
                        // Native displayGearSlot's very first operation is an
                        // isReady guard. A call alone does not mean gear loaded.
                        if (!readiness(object, field(object, "nativeReady") != false)) return null;
                        var attached:Array<String> = cast field(object, "attached");
                        attached.push(args[0]);
                    default:
                }
            case "ent.Entity":
            default: throw type + "." + name;
        }
        var label = name;
        if (name == "displayGearSlot") label += ":" + args[0];
        if (name == "displayWeapon") label += ":" + args[1] + ":" + args[0];
        calls.push(label);
        if (onAction != null) onAction(name);
        if (name == "updateDynamicVisuals") {
            // Native fallback uses the same guarded equipment path.
            for (slot in ["Head", "Chest", "Feet"]) call("client.UnitView", "displayGearSlot", object, [slot]);
        }
        if (name == "checkReady" && onReady != null) onReady();
        return null;
    }
}
