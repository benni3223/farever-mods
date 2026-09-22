package minimap;

import minimap.GameAccess as G;
import minimap.PinPlacement.PinClick;

/** Double-click on the open world map places the same shared pin. */
class MapPin {
    static var previous:PinClick;
    static var noted = false;
    static var pauseUntil = 0.0;
    static var marker:Dynamic;
    static var host:Dynamic;

    public static function update(app:Dynamic):Void {
        if (haxe.Timer.stamp() < pauseUntil) return;
        try refresh(app) catch (error:Dynamic) {
            pauseUntil = haxe.Timer.stamp() + 5;
            note(Std.string(error));
        }
    }

    static function refresh(app:Dynamic):Void {
        var ui = G.current("ui.BaseUI", "current");
        var window = findMap(ui);
        if (window == null) {
            removeMarker();
            return;
        }
        var local:{x:Float, y:Float} = null;
        var pressed = G.staticCall("hxd.Key", "isPressed", [0]) == true;
        var right = G.staticCall("hxd.Key", "isPressed", [1]) == true;
        if (pressed || right) local = localMouse(ui, window);
        if (local != null && !insideWindow(window, local)) local = null;
        if (pressed && local != null) {
            var now = haxe.Timer.stamp();
            if (PinPlacement.doubleClick(previous, local.x, local.y, now)) {
                var world = worldAt(window, local.x, local.y);
                var zone = G.text(G.field(G.field(app, "world"), "level"));
                if (world != null && zone != "") PartyPin.place(world.x, world.y, zone);
                previous = null;
            } else previous = {x: local.x, y: local.y, time: now};
        }
        if (right && hitsMarker(local)) PartyPin.clear();
        var zone = G.text(G.field(G.field(app, "world"), "level"));
        placeMarker(window, zone);
    }

    static function insideWindow(window:Dynamic, local:{x:Float, y:Float}):Bool {
        var width = span(window, "width", "get_innerWidth");
        var height = span(window, "height", "get_innerHeight");
        if (width <= 0 || height <= 0) return true;
        return local.x >= 0 && local.y >= 0 && local.x <= width && local.y <= height;
    }

    static function span(object:Dynamic, fieldName:String, method:String):Float {
        var value = G.number(G.field(object, fieldName), Math.NaN);
        if (Math.isFinite(value) && value > 0) return value;
        if (spanMissed.exists(method)) return 0;
        try value = G.number(G.call("h2d.Flow", method, object), Math.NaN) catch (_:Dynamic) {
            spanMissed.set(method, true);
            value = Math.NaN;
        }
        return Math.isFinite(value) ? value : 0;
    }

    static function findMap(ui:Dynamic):Dynamic {
        if (ui == null) return null;
        for (window in G.array(G.field(ui, "windows"))) {
            var name = typeName(window);
            if (name.indexOf("MapWindow") >= 0 && G.field(window, "parent") != null) return window;
        }
        return null;
    }

    static var missed = new Map<String, Bool>();
    static var spanMissed = new Map<String, Bool>();

    static function worldAt(window:Dynamic, x:Float, y:Float):{x:Float, y:Float} {
        var point = callPoint(window, ["getCoordinates", "getMouseCoordinates", "viewToWorld", "screenToWorld", "localToWorld", "mouseToWorld"], x, y, true);
        if (point != null) return point;
        note("world map click could not be converted");
        return null;
    }

    static function placeMarker(window:Dynamic, zone:String):Void {
        var pin = PartyPin.current();
        if (pin == null || pin.zone != zone) {
            removeMarker();
            return;
        }
        var at = viewAt(window, pin.x, pin.y);
        if (at == null) {
            removeMarker();
            return;
        }
        var parent = markerHost(window);
        if (marker == null || host != parent || G.field(marker, "parent") == null) {
            removeMarker();
            marker = G.create("h2d.Graphics", [parent]);
            host = parent;
            G.call("h2d.Graphics", "beginFill", marker, [0x143044, 0.95]);
            G.call("h2d.Graphics", "drawCircle", marker, [0.0, 0.0, 9.0, 24]);
            G.call("h2d.Graphics", "endFill", marker);
            G.call("h2d.Graphics", "beginFill", marker, [0x5ec8ff, 1.0]);
            G.call("h2d.Graphics", "drawCircle", marker, [0.0, 0.0, 6.0, 24]);
            G.call("h2d.Graphics", "endFill", marker);
        }
        G.call("h2d.Object", "setPosition", marker, [at.x, at.y]);
        G.call("h2d.Object", "set_visible", marker, [true]);
    }

    static function viewAt(window:Dynamic, x:Float, y:Float):{x:Float, y:Float} {
        var point = callPoint(window, ["get2dPos", "worldToView", "worldToScreen", "worldToLocal"], x, y, false);
        if (point != null) return point;
        note("world map pin could not be positioned");
        return null;
    }

    /** A method that misses once is skipped. A method that exists is tried again next frame. */
    static function callPoint(window:Dynamic, names:Array<String>, x:Float, y:Float, allowEmpty:Bool):{x:Float, y:Float} {
        for (name in names) {
            if (missed.exists(name)) continue;
            var count = -1;
            try count = G.argumentCount(window, name) catch (_:Dynamic) count = -1;
            if (count < 0 || count > 3) {
                missed.set(name, true);
                continue;
            }
            if (count == 0 && !allowEmpty) continue;
            var args:Array<Dynamic> = switch count {
                case 0: [];
                case 1: [pointAt(x, y)];
                case 2: [x, y];
                default: [x, y, 0.0];
            };
            if (count == 1 && args[0] == null) continue;
            try {
                var point = G.call("ui.win.MapWindow", name, window, args);
                var px = G.number(G.field(point, "x"), Math.NaN);
                var py = G.number(G.field(point, "y"), Math.NaN);
                if (Math.isFinite(px) && Math.isFinite(py)) return {x: px, y: py};
            } catch (_:Dynamic) {}
        }
        return null;
    }

    static function markerHost(window:Dynamic):Dynamic {
        for (name in ["mapOverlay", "scroll", "scrollContainer", "mapContainer"]) {
            var object = G.field(window, name);
            if (object != null) return object;
        }
        return window;
    }

    static function pointAt(x:Float, y:Float):Dynamic {
        var point = HlxRuntime.allocInstance(HlxRuntime.resolveType("h2d.col.PointImpl"));
        if (point == null) return null;
        G.set(point, "x", x);
        G.set(point, "y", y);
        return point;
    }

    static function localMouse(ui:Dynamic, window:Dynamic):{x:Float, y:Float} {
        var scene = G.field(ui, "s2d");
        if (scene == null) return null;
        var point = HlxRuntime.allocInstance(HlxRuntime.resolveType("h2d.col.PointImpl"));
        if (point == null) return null;
        G.set(point, "x", G.number(G.call("h2d.Scene", "get_mouseX", scene)));
        G.set(point, "y", G.number(G.call("h2d.Scene", "get_mouseY", scene)));
        var local = G.call("h2d.Object", "globalToLocal", window, [point]);
        return {x: G.number(G.field(local, "x")), y: G.number(G.field(local, "y"))};
    }

    static function hitsMarker(local:{x:Float, y:Float}):Bool {
        if (local == null || marker == null) return false;
        var dx = local.x - G.number(G.field(marker, "x"));
        var dy = local.y - G.number(G.field(marker, "y"));
        return dx * dx + dy * dy <= 16 * 16;
    }

    static function removeMarker():Void {
        if (marker != null) {
            try G.call("h2d.Object", "remove", marker) catch (_:Dynamic) {}
        }
        marker = null;
        host = null;
    }

    static function typeName(object:Dynamic):String {
        try return hl.Type.getDynamic(object).getTypeName() catch (_:Dynamic) return "";
    }

    static function note(message:String):Void {
        if (noted) return;
        noted = true;
        trace("[Minimap] " + message);
        try {
            sys.FileSystem.createDirectory("hlx/mods/minimap");
            var file = sys.io.File.append("hlx/mods/minimap/minimap.log", false);
            file.writeString(message + "\n");
            file.close();
        } catch (_:Dynamic) {}
    }
}
