import dpsmeter.DeathLog;
import dpsmeter.NativeDeathTimeline;
import dpsmeter.GameAccess as G;

class TimelineRenderTest {
    static var checks = 0;
    static function check(ok:Bool, message:String):Void { checks++; if (!ok) throw message; }
    static function flatten(node:Dynamic, x:Float = 0, y:Float = 0):Array<Dynamic> {
        var values:Array<Dynamic> = [];
        x += G.number(node.x); y += G.number(node.y);
        if (node.type == "h2d.Text") values.push({kind: "text", text: node.text, x: x, y: y, color: node.color, width: node.text.length * 7.});
        for (shape in (cast node.shapes:Array<Dynamic>)) values.push({kind: "rect", x: x + shape.x, y: y + shape.y,
            width: shape.width, height: shape.height, color: shape.color, alpha: shape.alpha});
        for (child in (cast node.children:Array<Dynamic>)) values = values.concat(flatten(child, x, y));
        return values;
    }
    static function main():Void {
        G.globals["timelineDrawing"] = true;
        var log = new DeathLog();
        for (hit in [
            {time: 18., amount: 150., hp: 350., hpBefore: 500., heal: false, critical: false, kill: false,
                skill: "Demon's very long attack name", source: "A very long enemy name", className: "", hpSample: false},
            {time: 19., amount: 75., hp: 425., hpBefore: 350., heal: true, critical: true, kill: false,
                skill: "Prayer of healing", source: "Radius", className: "cleric", hpSample: false},
            {time: 20., amount: 600., hp: 0., hpBefore: 425., heal: false, critical: false, kill: true,
                skill: "Final slam", source: "Rift boss", className: "", hpSample: false}
        ]) log.record({time: hit.time, amount: hit.amount, heal: hit.heal, critical: hit.critical, kill: hit.kill,
            skill: hit.skill, source: hit.source, className: hit.className, hp: hit.hp, hpBefore: hit.hpBefore, maxHp: 1000., hpSample: hit.hpSample});
        log.observe(true, 20);
        var report = log.take(), captures:Array<Dynamic> = [];
        for (width in [360, 434, 590, 600, 728, 892]) for (flow in [true, false]) {
            var root:Dynamic = {type: flow ? "h2d.Flow" : "h2d.Object", children: [], shapes: [], x: 0., y: 0.};
            var height = NativeDeathTimeline.render(root, null, report, width, 0, flow);
            var items = flatten(root), red = 0, dark = 0;
            for (item in items) {
                check(item.x >= 0 && item.x + item.width <= width + .01 && item.y >= 0 && item.y < height,
                    "Every timeline element fits the " + width + "-unit viewport");
                if (item.kind == "rect" && item.height == 8 && item.color == 0xd9655a) red++;
                if (item.kind == "rect" && item.height == 8 && item.color == 0x852629) dark++;
            }
            check(red == 2 && dark == 2, "Remaining HP and removed damage use separate red tones; heals add no damage segment");
            if (!flow && (width == 434 || width == 728)) captures.push({width: width, height: height, items: items});
        }
        sys.FileSystem.createDirectory("build/recap-check");
        sys.io.File.saveContent("build/recap-check/timeline-render.json", haxe.Json.stringify(captures));
        Sys.println("Native death timeline rendering: " + checks + " checks passed");
    }
}
