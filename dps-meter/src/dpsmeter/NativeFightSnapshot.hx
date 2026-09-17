package dpsmeter;

import dpsmeter.CombatModel.Fight;
import dpsmeter.FightHistory.HistoryEntry;
import dpsmeter.FightSnapshot.SnapshotPlan;
import dpsmeter.RiftTracker.RiftRecap;
import dpsmeter.GameAccess as G;
import dpsmeter.NativeUi.*;

/** Offscreen chart or skill table: native fonts and class colours, without viewport cropping. */
class NativeFightSnapshot {
    public static function copy(fight:Fight, entry:HistoryEntry, encounter:String, bodyFont:Dynamic, titleFont:Dynamic, playerId:String = ""):Void {
        if (bodyFont == null || titleFont == null) throw "The chart fonts are not ready. Try again.";
        var plan = FightSnapshot.plan(fight, playerId);
        render(plan.width, plan.height, (root, graphic) -> {
            rect(graphic, 0, 0, plan.width, plan.height, 0xcfbbb0);
            rect(graphic, 0, 0, plan.width, 64, 0xecd5ca);
            text(root, titleFont, encounter, 24, 14, plan.width - 48, 28, 0x815c43);
            text(root, bodyFont, FightHistory.chartDetail(entry), 24, 78, plan.width - 48, 18, 0x5b4334);
            drawChart(root, graphic, plan, bodyFont, titleFont);
        });
    }
    public static function copyRecap(result:RiftRecap, bodyFont:Dynamic, titleFont:Dynamic,
        gatePlayer:String = "", bossPlayer:String = "", columns:Bool = true):Void {
        if (bodyFont == null || titleFont == null) throw "The chart fonts are not ready. Try again.";
        var plan = FightSnapshot.recap(result, gatePlayer, bossPlayer, columns);
        render(plan.width, plan.height, (root, graphic) -> {
            rect(graphic, 0, 0, plan.width, plan.height, 0xcfbbb0);
            rect(graphic, 0, 0, plan.width, 64, 0xecd5ca);
            text(root, titleFont, "Rift Recap", 24, 14, plan.width - 48, 28, 0x815c43);
            for (section in plan.sections) {
                var panel = G.create("h2d.Object", [root]);
                position(panel, section.x, section.y);
                text(panel, titleFont, section.caption, 24, 14, section.chart.width - 192, 26, 0x815c43);
                text(panel, bodyFont, section.seconds == null ? "" : duration(section.seconds),
                    section.chart.width - 152, 18, 128, 20, 0x5b4334, true);
                var chart = G.create("h2d.Object", [panel]);
                position(chart, 0, -FightSnapshot.RECAP_CHART_OFFSET);
                var bars = G.create("h2d.Graphics", [chart]);
                drawChart(chart, bars, section.chart, bodyFont, titleFont);
            }
        });
    }
    static function render(width:Int, height:Int, draw:(Dynamic, Dynamic)->Void):Void {
        var scene = G.create("h2d.Scene", []);
        var root:Dynamic = null;
        var texture:Dynamic = null;
        var pixels:Dynamic = null;
        try {
            root = G.create("h2d.Object", [scene]);
            var graphic = G.create("h2d.Graphics", [root]);
            draw(root, graphic);
            var output = haxe.io.Bytes.alloc(width * height * 4);
            // The constructor allocates immediately. Supply a native ArrayObj
            // containing Target before allocation, never an ArrayDyn or a late flag.
            var windows = G.field(G.current("ui.BaseUI", "current"), "windows");
            var flags = G.call("hl.types.ArrayObj", "slice", windows, [0, 0]);
            var target = G.enumeration("h3d.mat.TextureFlags", "Target");
            if (flags == null || target == null) throw "The renderer's target texture flags are unavailable.";
            G.call("hl.types.ArrayObj", "pushDyn", flags, [target]);
            // Render in strips so a tall rift ranking is not limited by the
            // GPU's maximum texture height. The final clipboard image is whole.
            var y = 0;
            while (y < height) {
                var stripHeight = Std.int(Math.min(2048, height - y));
                texture = SnapshotTexture.create(width, stripHeight, flags);
                position(root, 0, -y);
                G.call("h2d.Object", "drawTo", root, [texture]);
                pixels = SnapshotTexture.readBgra(texture);
                var bytes = G.field(pixels, "bytes");
                var offset = G.integer(G.field(pixels, "offset"));
                var stride = G.integer(G.field(pixels, "stride"));
                var length = G.integer(G.field(bytes, "length"));
                var rowBytes = width * 4;
                if (offset < 0 || stride < rowBytes || length < offset + (stripHeight - 1) * stride + rowBytes)
                    throw "The renderer returned an incomplete chart image.";
                var raw:hl.Bytes = cast HlxRuntime.unboxPointer(G.field(bytes, "b"));
                if (raw == null) throw "The chart pixel buffer is unavailable.";
                var source = raw.toBytes(length);
                for (row in 0...stripHeight) output.blit((y + row) * rowBytes, source, offset + row * stride, rowBytes);
                G.call("hxd.Pixels", "dispose", pixels); pixels = null;
                G.call("h3d.mat.Texture", "dispose", texture); texture = null;
                y += stripHeight;
            }
            DesktopActions.copyImage(output, width, height);
        } catch (error:Dynamic) {
            cleanup(scene, root, texture, pixels);
            throw error;
        }
        cleanup(scene, root, texture, pixels);
    }
    static function drawChart(root:Dynamic, graphic:Dynamic, plan:SnapshotPlan, bodyFont:Dynamic, titleFont:Dynamic):Void {
        if (plan.breakdown) { drawBreakdown(root, graphic, plan, bodyFont, titleFont); return; }
        text(root, titleFont, "Player", 24, 112, 440, 17);
        text(root, titleFont, "Damage", 468, 112, 140, 17, 0x5b4334, true);
        text(root, titleFont, "DPS", 620, 112, 120, 17, 0x5b4334, true);
        text(root, titleFont, "Damage (%)", 752, 112, 124, 17, 0x5b4334, true);
        for (i in 0...plan.rows.length) {
            var row = plan.rows[i]; var y = 140 + i * plan.rowHeight;
            text(root, bodyFont, row.name, 24, y, 440, 18);
            text(root, bodyFont, compact(row.damage), 468, y, 140, 18, 0x5b4334, true);
            text(root, bodyFont, compact(row.dps), 620, y, 120, 18, 0x5b4334, true);
            text(root, bodyFont, Std.string(dpsmeter.CombatModel.SkillStats.rounded(row.percent, 1)) + "%", 752, y, 124, 18, 0x5b4334, true);
            rect(graphic, 24, y + 28, 852, 8, 0xb29a8c);
            rect(graphic, 24, y + 28, 852 * row.percent / 100, 8, classColor(row.className));
        }
        if (plan.rows.length == 0) text(root, bodyFont, "No damage recorded", 24, 140, 852, 18);
    }
    static function drawBreakdown(root:Dynamic, graphic:Dynamic, plan:SnapshotPlan, bodyFont:Dynamic, titleFont:Dynamic):Void {
        var inner = plan.width - 48;
        text(root, titleFont, plan.playerName + " · Ability breakdown", 24, 110, inner, 22, classColor(plan.playerClass));
        var columns = SkillBreakdown.columns(inner);
        for (column in columns) {
            var x = 24 + column.x; var width = column.width - 10;
            if (column.key == "damage") {
                text(root, titleFont, "Damage (%)", x, 150, width - 80, 16);
                text(root, titleFont, "Damage", x + width - 74, 150, 74, 16, 0x5b4334, true);
            } else text(root, titleFont, column.title, x, 150, width, 16, 0x5b4334, column.key != "ability");
        }
        for (i in 0...plan.skills.length) {
            var row = plan.skills[i]; var v = row.values; var y = 180 + i * plan.rowHeight;
            if (i % 2 == 0) rect(graphic, 24, y, inner, plan.rowHeight, 0xc4afa3);
            var values = ["damage" => compact(v.damage), "casts" => Std.string(v.casts), "avgCast" => compact(v.avgCast),
                "hits" => Std.string(v.hits), "avgHit" => compact(v.avgHit),
                "crit" => Std.string(dpsmeter.CombatModel.SkillStats.rounded(v.crit, 1)) + "%", "dps" => compact(v.dps)];
            for (column in columns) {
                var x = 24 + column.x; var width = column.width - 10;
                if (column.key == "ability") {
                    var tile = NativeCombatMetadata.skillIcon(row.id);
                    if (tile != null) {
                        var icon = G.create("h2d.Bitmap", [tile, root]);
                        G.call("h2d.Object", "setScale", icon, [26 / Math.max(1, Math.max(G.number(G.field(tile, "width")), G.number(G.field(tile, "height"))))]);
                        position(icon, x + 3, y + 7);
                    }
                    text(root, titleFont, NativeCombatMetadata.skillName(row.id), x + 34, y + 11, width - 34, 17);
                } else if (column.key == "damage") {
                    text(root, bodyFont, Std.string(dpsmeter.CombatModel.SkillStats.rounded(v.percent, 1)) + "%", x, y + 11, 51, 17, 0x5b4334, true);
                    var barX = x + 58; var barWidth = width - 58 - 74 - 6;
                    rect(graphic, barX, y + 16, barWidth, 8, 0xb29a8c);
                    rect(graphic, barX, y + 16, barWidth * Math.max(0, Math.min(1, v.percent / 100)), 8, classColor(plan.playerClass));
                    text(root, bodyFont, values[column.key], x + width - 74, y + 11, 74, 17, 0x5b4334, true);
                } else text(root, column.key == "dps" ? titleFont : bodyFont, values[column.key], x, y + 11, width, 17, 0x5b4334, true);
            }
        }
        if (plan.skills.length == 0) text(root, bodyFont, "No ability damage recorded", 24, 180, inner, 18);
    }
    static function cleanup(scene:Dynamic, root:Dynamic, texture:Dynamic, pixels:Dynamic):Void {
        if (pixels != null) try G.call("hxd.Pixels", "dispose", pixels) catch (_:Dynamic) {}
        if (texture != null) try G.call("h3d.mat.Texture", "dispose", texture) catch (_:Dynamic) {}
        if (root != null) try G.call("h2d.Object", "removeChildren", root) catch (_:Dynamic) {}
        if (scene != null) try G.call("h2d.Scene", "dispose", scene) catch (_:Dynamic) {}
    }
    static function text(parent:Dynamic, font:Dynamic, value:String, x:Float, y:Float, width:Float, height:Float,
        color:Int = 0x5b4334, right:Bool = false):Void {
        var object = G.create("h2d.Text", [font, parent]);
        G.call("h2d.Text", "set_text", object, [value]);
        G.call("h2d.Text", "set_lineBreak", object, [false]);
        G.call("h2d.Text", "set_textColor", object, [color]);
        var w = G.number(G.call("h2d.Text", "get_textWidth", object));
        var h = G.number(G.call("h2d.Text", "get_textHeight", object));
        var scale = Math.min(height / Math.max(1, h), width / Math.max(1, w));
        G.call("h2d.Object", "setScale", object, [scale]);
        position(object, right ? x + width - w * scale : x, y);
    }
    static function rect(graphic:Dynamic, x:Float, y:Float, width:Float, height:Float, color:Int):Void {
        G.call("h2d.Graphics", "beginFill", graphic, [color, 1.0]);
        G.call("h2d.Graphics", "drawRect", graphic, [x, y, width, height]);
        G.call("h2d.Graphics", "endFill", graphic);
    }
}
