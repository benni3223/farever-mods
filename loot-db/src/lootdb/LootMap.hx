package lootdb;

import lootdb.Catalog.PinRecord;
import lootdb.GameAccess as G;
import lootdb.NativeUi.*;

private typedef MapTile = {x:Int, y:Int, resolution:Int, path:String, tile:Dynamic, lastUsed:Int};
private typedef MapSprite = {
    bitmap:Dynamic, tile:Dynamic, baseX:Float, baseY:Float, tw:Float, th:Float, wx:Float, wy:Float
};

/** Pannable overworld using Farever's own minimap tiles. */
class LootMap {
    static inline var LEVEL = "World/W1_Siagarta";
    static inline var DIRECTORY = "Level/" + LEVEL + ".dat/minimap";
    public var root:Dynamic;
    var tiles:Dynamic;
    var marks:Dynamic;
    var input:Dynamic;
    var index:Map<String, MapTile> = [];
    var sprites:Map<String, MapSprite> = [];
    var wanted:Array<MapTile> = [];
    var generation:Int = 0;
    var bounds:String = "";
    var loader:Dynamic;
    var tileWorldWidth:Float = 0;
    var originX:Float = 0;
    var originY:Float = 0;
    var mapScale:Float = 1;
    var framed:Bool = false;
    var viewWidth:Float = 1;
    var viewHeight:Float = 1;
    var cameraX:Float = 0;
    var cameraY:Float = 0;
    var zoom:Float = 0.08;
    var dragX:Float = 0;
    var dragY:Float = 0;
    var dragCameraX:Float = 0;
    var dragCameraY:Float = 0;
    var dragging:Bool = false;
    var moved:Bool = false;
    public var activities:Array<PinRecord> = [];
    var pins:Array<PinRecord> = [];
    var onPin:(PinRecord) -> Void;
    public var hasTiles:Bool = false;
    var indexed:Bool = false;

    public function new(parent:Dynamic, onPin:(PinRecord) -> Void) {
        this.onPin = onPin;
        root = G.create("h2d.Object", [parent]);
        tiles = G.create("h2d.Object", [root]);
        marks = G.create("h2d.Graphics", [root]);
        input = G.create("h2d.Interactive", [10.0, 10.0, root, null]);
        G.set(input, "onPush", (event:Dynamic) -> { keep(event); beginDrag(event); });
        G.set(input, "onRelease", (event:Dynamic) -> { keep(event); endDrag(); });
        G.set(input, "onClick", (event:Dynamic) -> keep(event));
        G.set(input, "onMove", (event:Dynamic) -> drag(event));
        G.set(input, "onWheel", (event:Dynamic) -> {
            keep(event);
            var delta = G.number(G.field(event, "wheelDelta"));
            if (delta == 0) return;
            // Match the game minimap: a negative wheel delta zooms in.
            var next = zoom * (delta < 0 ? 1.15 : 1 / 1.15);
            zoom = Math.max(0.01, Math.min(0.6, next));
            bounds = "";
        });
    }

    public function setActive(active:Bool):Void {
        show(root, active);
    }

    public function resize(width:Float, height:Float):Void {
        viewWidth = Math.max(1, width);
        viewHeight = Math.max(1, height);
        G.set(input, "width", viewWidth);
        G.set(input, "height", viewHeight);
        bounds = "";
    }

    public function center(x:Float, y:Float):Void {
        var point = placed(x, y, false);
        cameraX = point.x; cameraY = point.y; bounds = "";
    }

    public function setPins(pins:Array<PinRecord>):Void {
        this.pins = pins;
    }

    public function update(app:Dynamic):Void {
        ensureIndex(app);
        position(tiles, viewWidth / 2 - cameraX * zoom, viewHeight / 2 - cameraY * zoom);
        G.call("h2d.Object", "setScale", tiles, [zoom]);
        if (tileWorldWidth > 0) {
            var reach = Math.max(viewWidth, viewHeight) / 2 / zoom;
            selectTiles(cameraX, cameraY, reach);
            loadNextTile();
            clipSprites();
        }
        drawPins();
    }

    function ensureIndex(app:Dynamic):Void {
        if (tileWorldWidth <= 0) {
            var world = G.field(app, "world");
            var data = G.field(G.field(world, "terrain"), "data");
            var settings = G.current("Const", "UI");
            var width = G.number(G.field(data, "chunkWidth")) * G.integer(G.field(settings, "MapTileChunksPerSide"));
            if (width > 0 && G.text(G.field(world, "level")) == LEVEL) tileWorldWidth = width;
        }
        if (indexed || tileWorldWidth <= 0) return;
        loader = G.current("hxd.res.Loader", "currentInstance");
        if (loader == null || G.call("hxd.res.Loader", "exists", loader, [DIRECTORY]) != true) return;
        var settings = G.current("Const", "UI");
        var resolutions = G.array(G.field(settings, "MapTileResolutions"));
        var preferred = resolutions.length == 0 ? 512 : G.integer(resolutions[0], 512);
        for (resource in G.array(G.call("hxd.res.Loader", "dir", loader, [DIRECTORY]))) {
            var name = G.text(G.field(G.field(resource, "entry"), "name"));
            if (!StringTools.endsWith(name, ".png")) continue;
            var parts = name.substr(0, name.length - 4).split("_");
            if (parts.length != 3) continue;
            var x = Std.parseInt(parts[0]);
            var y = Std.parseInt(parts[1]);
            var resolution = Std.parseInt(parts[2]);
            if (x == null || y == null || resolution == null) continue;
            var key = x + ":" + y;
            var previous = index[key];
            if (previous != null && Math.abs(previous.resolution - preferred) <= Math.abs(resolution - preferred)) continue;
            index[key] = {x: x, y: y, resolution: resolution, path: DIRECTORY + "/" + name, tile: null, lastUsed: 0};
        }
        indexed = index.iterator().hasNext();
        hasTiles = indexed;
        if (indexed) frameToTiles();
        refreshActivities();
    }

    function frameToTiles():Void {
        var minX = 0, minY = 0, maxX = 0, maxY = 0, first = true;
        for (entry in index) {
            if (first || entry.x < minX) minX = entry.x;
            if (first || entry.y < minY) minY = entry.y;
            if (first || entry.x > maxX) maxX = entry.x;
            if (first || entry.y > maxY) maxY = entry.y;
            first = false;
        }
        // Metaforge plots the whole overworld as the square [0, 11264]. Tile files start at a negative index.
        var span = Math.max(maxX - minX + 1, maxY - minY + 1) * tileWorldWidth;
        originX = minX * tileWorldWidth;
        originY = minY * tileWorldWidth;
        mapScale = span > 0 ? span / 11264 : 1;
        if (framed) return;
        framed = true;
        cameraX = (minX + maxX + 1) * tileWorldWidth / 2;
        cameraY = (minY + maxY + 1) * tileWorldWidth / 2;
        if (span > 0) zoom = Math.max(0.01, Math.min(0.6, Math.min(viewWidth, viewHeight) / span * 0.92));
    }

    public function refreshActivities():Void {
        activities = [];
        var source = G.current("HActivity", "allActivities");
        if (source == null) return;
        for (definition in G.array(G.staticCall("HActivity", "allFiltered", [LEVEL]))) {
            var inf = G.field(definition, "inf");
            if (inf == null || G.staticCall("HActivity", "isOfType", [inf, "Rift"]) == true) continue;
            var position = G.staticCall("HActivity", "getPos", [definition]);
            if (position == null) continue;
            var id = G.text(G.field(inf, "id"));
            var name = "";
            try name = G.text(G.staticCall("HText", "activity", [id])) catch (_:Dynamic) {}
            if (name == "") name = id;
            var dungeon = G.staticCall("HActivity", "isOfType", [inf, "Dungeon"]) == true;
            activities.push({
                id: "activity:" + id, x: G.number(G.field(position, "x")), y: G.number(G.field(position, "y")),
                kind: dungeon ? "dungeon" : "activity", label: name, instanceId: "", creatureId: ""
            });
        }
    }

    function selectTiles(x:Float, y:Float, radius:Float):Void {
        var minX = Math.floor((x - radius) / tileWorldWidth);
        var maxX = Math.floor((x + radius) / tileWorldWidth);
        var minY = Math.floor((y - radius) / tileWorldWidth);
        var maxY = Math.floor((y + radius) / tileWorldWidth);
        var next = minX + ":" + maxX + ":" + minY + ":" + maxY;
        if (bounds == next) return;
        bounds = next;
        generation++;
        wanted = [];
        var keep:Map<String, Bool> = [];
        for (tx in minX...maxX + 1) for (ty in minY...maxY + 1) {
            var key = tx + ":" + ty;
            var entry = index[key];
            if (entry == null) continue;
            keep[key] = true;
            entry.lastUsed = generation;
            wanted.push(entry);
        }
        for (key in [for (key in sprites.keys()) key]) if (!keep.exists(key)) {
            G.call("h2d.Object", "remove", sprites[key].bitmap);
            sprites.remove(key);
        }
    }

    function loadNextTile():Void {
        for (entry in wanted) {
            var key = entry.x + ":" + entry.y;
            if (sprites.exists(key)) continue;
            if (entry.tile == null) {
                var resource = G.call("hxd.res.Loader", "load", loader, [entry.path]);
                entry.tile = G.call("h2d.Tile", "clone", G.call("hxd.res.Any", "toTile", resource));
                G.set(entry.tile, "dx", 0.0);
                G.set(entry.tile, "dy", 0.0);
            }
            var tw = G.number(G.field(entry.tile, "width"), 0);
            var th = G.number(G.field(entry.tile, "height"), 0);
            if (tw < 1 || th < 1) continue;
            var viewTile = G.call("h2d.Tile", "clone", entry.tile);
            var bitmap = G.create("h2d.Bitmap", [viewTile, tiles]);
            sprites[key] = {
                bitmap: bitmap, tile: viewTile,
                baseX: G.number(G.field(viewTile, "x"), 0), baseY: G.number(G.field(viewTile, "y"), 0),
                tw: tw, th: th, wx: entry.x * tileWorldWidth, wy: entry.y * tileWorldWidth
            };
            return;
        }
    }

    /** Keep every tile inside the map view. A mask render target blanks the whole frame when tiles change. */
    function clipSprites():Void {
        var inset = 1 / zoom;
        var left = cameraX - viewWidth / 2 / zoom + inset;
        var top = cameraY - viewHeight / 2 / zoom + inset;
        var right = cameraX + viewWidth / 2 / zoom - inset;
        var bottom = cameraY + viewHeight / 2 / zoom - inset;
        for (sprite in sprites) {
            var x0 = Math.max(sprite.wx, left);
            var y0 = Math.max(sprite.wy, top);
            var x1 = Math.min(sprite.wx + tileWorldWidth, right);
            var y1 = Math.min(sprite.wy + tileWorldWidth, bottom);
            if (x1 - x0 < 0.5 || y1 - y0 < 0.5) { show(sprite.bitmap, false); continue; }
            var px = (x0 - sprite.wx) / tileWorldWidth * sprite.tw;
            var py = (y0 - sprite.wy) / tileWorldWidth * sprite.th;
            var pw = (x1 - x0) / tileWorldWidth * sprite.tw;
            var ph = (y1 - y0) / tileWorldWidth * sprite.th;
            if (pw < 1 || ph < 1) { show(sprite.bitmap, false); continue; }
            G.set(sprite.tile, "x", sprite.baseX + px);
            G.set(sprite.tile, "y", sprite.baseY + py);
            G.set(sprite.tile, "width", pw);
            G.set(sprite.tile, "height", ph);
            G.set(sprite.tile, "dx", 0.0);
            G.set(sprite.tile, "dy", 0.0);
            G.set(sprite.bitmap, "scaleX", (x1 - x0) / pw);
            G.set(sprite.bitmap, "scaleY", (y1 - y0) / ph);
            position(sprite.bitmap, x0, y0);
            show(sprite.bitmap, true);
        }
    }

    function drawPins():Void {
        G.call("h2d.Graphics", "clear", marks);
        for (pin in pins) {
            var point = screenPin(pin);
            if (point.x < 6 || point.y < 6 || point.x > viewWidth - 6 || point.y > viewHeight - 6) continue;
            var color = pin.kind == "world-boss" ? 0xc95846 : pin.kind == "dungeon" ? 0x7f3e91 : 0xd9b054;
            G.call("h2d.Graphics", "beginFill", marks, [color, 0.95]);
            G.call("h2d.Graphics", "drawCircle", marks, [point.x, point.y, 5, 16]);
            G.call("h2d.Graphics", "endFill", marks);
        }
    }

    function screen(x:Float, y:Float):{x:Float, y:Float} {
        return {x: viewWidth / 2 + (x - cameraX) * zoom, y: viewHeight / 2 + (y - cameraY) * zoom};
    }

    function screenPin(pin:PinRecord):{x:Float, y:Float} {
        var point = placed(pin.x, pin.y, StringTools.startsWith(pin.id, "activity:"));
        return screen(point.x, point.y);
    }

    /** Catalog coordinates are Metaforge's map space. Activity positions are already game world units. */
    function placed(x:Float, y:Float, gameSpace:Bool):{x:Float, y:Float} {
        if (gameSpace) return {x: x, y: y};
        return {x: originX + x * mapScale, y: originY + y * mapScale};
    }

    static function keep(event:Dynamic):Void {
        G.set(event, "propagate", false);
    }

    function beginDrag(event:Dynamic):Void {
        dragging = true; moved = false;
        dragX = G.number(G.field(event, "relX"));
        dragY = G.number(G.field(event, "relY"));
        dragCameraX = cameraX; dragCameraY = cameraY;
    }

    function drag(event:Dynamic):Void {
        if (!dragging) return;
        var dx = G.number(G.field(event, "relX")) - dragX;
        var dy = G.number(G.field(event, "relY")) - dragY;
        if (dx * dx + dy * dy > 16) moved = true;
        cameraX = dragCameraX - dx / zoom;
        cameraY = dragCameraY - dy / zoom;
        bounds = "";
    }

    function endDrag():Void {
        if (dragging && !moved) click(dragX, dragY);
        dragging = false;
    }

    function click(x:Float, y:Float):Void {
        var best:PinRecord = null;
        var bestDistance = 14.0 * 14.0;
        for (pin in pins) {
            var point = screenPin(pin);
            var dx = point.x - x, dy = point.y - y;
            var distance = dx * dx + dy * dy;
            if (distance < bestDistance) { best = pin; bestDistance = distance; }
        }
        if (best != null) onPin(best);
    }

    static function position(object:Dynamic, x:Float, y:Float):Void G.call("h2d.Object", "setPosition", object, [x, y]);
}
