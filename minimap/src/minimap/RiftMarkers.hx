package minimap;

import minimap.GameAccess as G;

typedef RiftPoint = {id:String, kind:String, x:Float, y:Float, z:Float};

/** Read-only native Rift schedule and portal selection, sampled at 5 Hz. */
class RiftMarkers {
    public var remaining(default, null):Float = Math.NaN;
    public var points(default, null):Array<RiftPoint> = [];
    public var upcoming(default, null):Null<RiftPoint>;
    var level:String;
    var layer:Dynamic;
    var nextRefresh:Float = 0;
    var schedule:Dynamic;
    var period:Float = Math.NaN;
    var elementSource:Dynamic;
    var candidates:Array<String> = [];
    var inactive:Array<RiftPoint> = [];
    var locations:Map<String, RiftPoint> = [];
    var predictedSeed:Null<Int>;
    var predictedId:String = "";
    var reportedError:Bool = false;

    public function new(level:String) this.level = level;

    public static function name(kind:String):String return switch kind {
        case "riftPortal": "Rift Portal";
        case "upcomingRift": "Upcoming Rift";
        default: "Inactive Rift";
    };

    public function displayPoints(hideInactive:Bool):Array<RiftPoint> {
        if (hideInactive) return points;
        var result = points.copy();
        for (point in inactive) {
            // Each location gets one state. Active/announced portals replace
            // the cached inactive marker without changing countdown or alerts.
            var occupied = false;
            for (active in points) if (active.id == point.id) { occupied = true; break; }
            if (!occupied) result.push(point);
        }
        return result;
    }

    public function update(nextLayer:Dynamic, now:Float):Void {
        if (nextLayer == layer && now < nextRefresh) return;
        layer = nextLayer;
        nextRefresh = now + 0.2;
        remaining = Math.NaN;
        points = [];
        upcoming = null;
        try sample() catch (error:Dynamic) {
            if (!reportedError) {
                reportedError = true;
                trace("[Minimap] Rift data: " + Std.string(error));
            }
        }
        // Only use the authorized wall-clock fallback if native timing is unavailable.
        // Never infer a portal location from fallback time.
        if (!Math.isFinite(remaining)) remaining = RiftTiming.untilNext(Date.now().getTime() / 1000, 3600);
    }

    function sample():Void {
        if (layer == null) return;
        var event:Dynamic = null;
        if (G.field(layer, "worldEvents") != null)
            try event = G.staticCall("st.event.Rift", "getEvent", [layer]) catch (_:Dynamic) {}
        // Try the direct event timer first, independently of schedule metadata.
        // One missing optional API must not discard other available native time.
        if (event != null)
            try remaining = G.number(G.call("st.event.WorldEvent", "get_teaseTime", event), Math.NaN) catch (_:Dynamic) {}
        var inf = G.field(event, "inf");
        if (inf == null) {
            var definitions = G.field(G.current("Data", "event"), "byId");
            if (definitions != null) inf = G.call("haxe.ds.StringMap", "get", definitions, ["Rift"]);
        }
        if (inf != schedule) {
            schedule = inf;
            period = Math.NaN;
            var rate = G.field(inf, "rate");
            if (rate != null) try period = G.number(G.staticCall("HData", "getDuration",
                [G.staticCall("DateTimeBuilder", "build", [rate])]), Math.NaN) catch (_:Dynamic) {}
        }
        // This is the object returned by GameLayer.get_time. TimeState's own
        // fields only hold the last network sample; Time advances every frame.
        var time = G.field(G.field(layer, "_time"), "_time");
        var serverTime = G.number(G.field(time, "serverStart"), Math.NaN) + G.number(G.field(time, "serverNow"), Math.NaN);
        if (!Math.isFinite(remaining)) remaining = RiftTiming.untilNext(serverTime, period);

        refreshCandidates();
        var activeId = G.text(G.field(event, "activeRift"));
        var pending = event != null && G.call("st.event.WorldEvent", "isPending", event) == true;
        var open = event != null && G.call("st.event.WorldEvent", "isOngoing", event) == true
            && G.number(G.call("st.event.WorldEvent", "get_remainingTime", event)) > 0;
        if (open) {
            var point = locate(activeId, "riftPortal");
            if (point != null) points.push(point);
        }
        if (pending) {
            // Replicated event data always wins over a prediction.
            upcoming = locate(activeId, "upcomingRift");
        } else if (Math.isFinite(serverTime) && Math.isFinite(remaining) && Math.isFinite(period) && period > 0 && candidates.length > 0) {
            // Rift.postInit seeds its own hxd.Rand from get_expectedTime, then
            // chooses from HElement.all() in its original order. Use an isolated
            // native RNG; never advance the event's RNG or construct a game state.
            var nextTime = serverTime + remaining;
            var seed = Math.floor((nextTime + 0.001) / period) * Std.int(period);
            if (predictedSeed != seed) {
                var random = G.create("hxd.Rand", [seed]);
                var index = G.integer(G.call("hxd.Rand", "random", random, [candidates.length]), -1);
                predictedId = index >= 0 && index < candidates.length ? candidates[index] : "";
                predictedSeed = seed;
            }
            upcoming = locate(predictedId, "upcomingRift");
        }
        if (upcoming != null) {
            // The current and next event may pick the same portal. Keep one
            // visible marker, with the open portal taking precedence.
            if (points.length > 0 && points[0].id == upcoming.id) upcoming = points[0];
            else points.push(upcoming);
        }
    }

    function refreshCandidates():Void {
        var source = G.current("HElement", "allElements");
        if (source == elementSource) return;
        elementSource = source;
        candidates = [];
        inactive = [];
        locations = [];
        predictedSeed = null;
        if (source == null) return;
        // Match WorldEvent.postInit and Rift.postInit exactly. Do not sort,
        // filter to this map, or drop off-screen candidates before selection.
        for (definition in G.array(G.staticCall("HElement", "all", []))) {
            var inf = G.field(definition, "inf");
            if (G.text(G.field(G.field(inf, "props"), "event")) != "Rift"
                || G.field(definition, "mapId") == null || G.integer(G.field(inf, "type"), -1) != 20) continue;
            var id = G.text(G.field(inf, "id"));
            if (id != "" && candidates.indexOf(id) < 0) candidates.push(id);
        }
        // Resolve static locations once per definition table, not every frame.
        for (id in candidates) {
            var point = locate(id, "inactiveRift");
            if (point != null) inactive.push(point);
        }
    }

    function locate(id:String, kind:String):Null<RiftPoint> {
        if (id == "" || elementSource == null) return null;
        if (!locations.exists(id)) {
            var definition = G.call("haxe.ds.StringMap", "get", elementSource, [id]);
            if (G.text(G.field(definition, "mapId")) != level) return null;
            var prefab = G.field(definition, "prefab");
            if (prefab == null) return null;
            var matrix = G.call("hrt.prefab.Object3D", "getAbsPos", prefab, [true]);
            var x = G.number(G.field(matrix, "_41"), Math.NaN), y = G.number(G.field(matrix, "_42"), Math.NaN);
            if (!Math.isFinite(x) || !Math.isFinite(y)) return null;
            locations[id] = {id: id, kind: "", x: x, y: y, z: G.number(G.field(matrix, "_43"), Math.NaN)};
        }
        var p = locations[id];
        return {id: id, kind: kind, x: p.x, y: p.y, z: p.z};
    }
}
