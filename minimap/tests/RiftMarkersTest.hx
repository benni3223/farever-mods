import minimap.RiftMarkers;
import minimap.RiftTiming;
import minimap.MinimapGeometry;
import minimap.GameAccess as G;

class RiftMarkersTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, message:String):Void {
        checks++;
        if (actual != expected) throw message + ': expected $expected, got $actual';
    }
    static function definition(id:String, level:String, event:String = "Rift", type:Int = 20):Dynamic {
        var value = {inf: {id: id, props: {event: event}, type: type}, mapId: level,
            prefab: {_41: 100., _42: 200., _43: 30.}};
        G.elements[id] = value;
        return value;
    }

    static function main():Void {
        eq(RiftTiming.caption(494), "08:14", "requested timer format");
        eq(RiftTiming.caption(0), "00:00", "zero is not negative");
        eq(RiftTiming.caption(-1), "00:00", "late samples clamp at zero");
        eq(RiftTiming.caption(59.1), "01:00", "fractional seconds round up");
        eq(RiftTiming.caption(3600), "60:00", "minutes are retained at the hour");
        eq(RiftTiming.caption(Math.NaN), "", "unknown time is not rendered as NaN");
        for (seconds in [-1., 0., 1., 899., 900., 900.01, 901., 3600.])
            eq(RiftTiming.alert(seconds), seconds >= 0 && seconds <= 900, "15 minute boundary is inclusive");
        eq(RiftTiming.alert(Math.NaN), false, "unknown timer cannot activate alerts");
        eq(RiftTiming.untilNext(7200, 3600), 3600, "new cycle starts at boundary");
        eq(RiftTiming.untilNext(7201, 1800), 1799, "native period is not hardcoded to an hour");
        eq(Math.isNaN(RiftTiming.untilNext(10, 0)), true, "invalid cadence is unavailable");

        var inf = {rate: {seconds: 1800.}};
        G.events["Rift"] = inf;
        var clock = {serverStart: 3600., serverNow: 100.};
        var layer:Dynamic = {_time: {_time: clock, serverNow: 99999.}, worldEvents: {}};
        var other = definition("OtherMap", "Elsewhere");
        var first = definition("First", "World");
        var second = definition("Second", "World");
        G.elementList = [other, first, definition("Decoration", "World", "Rift", 0),
            definition("OtherEvent", "World", "Festival"), first, second];
        G.randomIndex = 1;
        var rifts = new RiftMarkers("World");
        rifts.update(layer, 0);
        eq(rifts.remaining, 1700., "native cadence and synchronized clock drive timer before announcement");
        eq(rifts.upcoming.id, "First", "upcoming location uses native selection order");
        eq(rifts.upcoming.kind, "upcomingRift", "unopened portal uses demon marker");
        eq(G.randomSeeds[0], 5400, "next expected event time seeds an isolated native RNG");
        eq(G.randomCounts[0], 3, "other maps count; duplicates and non-portals do not");
        eq(rifts.points.length, 1, "only chosen upcoming portal is visible");
        for (i in 1...100) rifts.update(layer, i / 1000);
        eq(G.riftReads, 1, "native event sampling is bounded, not per frame");
        clock.serverNow = 200;
        rifts.update(layer, 1);
        eq(rifts.remaining, 1600., "timer follows synchronized clock advances");
        eq(G.randomSeeds.length, 1, "same cycle reuses selection");
        eq(G.elementReads, 1, "portal definitions cached between refreshes");

        G.riftEvent = {inf: inf, activeRift: "Second", state: "pending", countdown: 494., openRemaining: 0.};
        rifts.update(layer, 2);
        eq(rifts.remaining, 494., "replicated native event timer overrides derived timing");
        eq(rifts.upcoming.id, "Second", "replicated portal overrides prediction");
        eq(rifts.points[0].kind, "upcomingRift", "pending event does not draw an open portal");

        G.riftEvent.state = "open";
        G.riftEvent.countdown = 1750.;
        G.riftEvent.openRemaining = 130.;
        clock.serverNow = 1850.;
        G.randomIndex = 2;
        rifts.update(layer, 3);
        eq(rifts.points[0].kind, "riftPortal", "open state swaps to portal marker");
        eq(rifts.points[0].id, "Second", "open portal remains at announced location");
        eq(rifts.points.length, 1, "same location next cycle does not duplicate the open marker");
        eq(G.randomSeeds[1], 7200, "next cycle advances prediction seed");
        eq(rifts.remaining, 1750., "open event still counts down to the next Rift");
        G.riftEvent.openRemaining = 0.;
        rifts.update(layer, 4);
        eq(rifts.points[0].kind, "upcomingRift", "expired open state cannot leave a stale portal marker");
        G.riftEvent.state = "closed";
        rifts.update(layer, 5);
        eq(rifts.points[0].kind, "upcomingRift", "closed event cannot draw a portal");

        // A reloaded native definition table invalidates both selection and position caches.
        G.elements = G.elements.copy();
        G.randomIndex = 1;
        G.riftEvent.state = "open";
        G.riftEvent.openRemaining = 130.;
        rifts.update(layer, 5.3);
        eq(rifts.points.length, 2, "different current and upcoming locations both appear");
        eq(rifts.points[0].id, "Second", "open marker stays at current event");
        eq(rifts.points[1].id, "First", "next marker appears at future event");
        eq(G.elementReads, 2, "definition reload rebuilds the candidate cache");
        G.riftEvent.state = "closed";
        rifts.update(layer, 5.6);
        eq(rifts.points.length, 1, "closing a portal removes only its current marker");
        eq(rifts.points[0].id, "First", "upcoming marker survives current portal closure");

        G.riftEvent = null;
        G.randomIndex = 0;
        clock.serverNow = 3650.;
        rifts.update(layer, 6);
        eq(rifts.points.length, 0, "portals on another map are not projected onto this map");
        eq(rifts.upcoming, null, "another map cannot produce a misleading edge arrow");
        rifts.update({_time: {_time: {serverStart: 3600., serverNow: 200.}}, worldEvents: {}}, 6.01);
        eq(rifts.remaining, 1600., "layer switch refreshes immediately within throttle window");

        G.riftLookupUnavailable = true;
        var alternate = new RiftMarkers("World");
        alternate.update(layer, 0);
        eq(alternate.remaining, 1750., "missing event API still uses available native schedule and clock");
        G.riftLookupUnavailable = false;
        G.durationUnavailable = true;
        G.riftEvent = {inf: inf, activeRift: "Second", state: "pending", countdown: 494., openRemaining: 0.};
        alternate = new RiftMarkers("World");
        alternate.update({worldEvents: {}}, 0);
        eq(alternate.remaining, 494., "direct native timer survives unavailable cadence and clock");
        eq(alternate.upcoming.id, "Second", "replicated location does not require prediction metadata");
        G.durationUnavailable = false;
        G.riftEvent = null;

        G.events = [];
        var unavailable = new RiftMarkers("World");
        unavailable.update({worldEvents: {}}, 0);
        eq(unavailable.remaining > 0 && unavailable.remaining <= 3600, true, "missing native time allows hour fallback");
        eq(unavailable.upcoming, null, "fallback never guesses a portal position");

        for (circular in [false, true]) {
            eq(MinimapGeometry.showAlert(true, 0, 0, 250, circular, 10), false, "visible Rift hides arrow");
            eq(MinimapGeometry.showAlert(true, 130, 0, 250, circular, 10), false, "partly visible Rift hides arrow");
            eq(MinimapGeometry.showAlert(true, 150, 0, 250, circular, 10), true, "offscreen Rift shows arrow");
            eq(MinimapGeometry.showAlert(false, 30, 0, 250, circular, 10), true, "hidden activity markers do not suppress alert");
        }
        Sys.println('Rift marker tests passed ($checks checks)');
    }
}
