package dpsmeter;

import dpsmeter.CombatModel.Fight;
import dpsmeter.FightHistory.HistoryEntry;
import dpsmeter.GameAccess as G;
import dpsmeter.NativeUi.*;

/** Offscreen player chart: native fonts and class colours, with no viewport crop. */
class NativeFightSnapshot {
    public static function copy(fight:Fight, entry:HistoryEntry, encounter:String, bodyFont:Dynamic, titleFont:Dynamic):Void {
        if (bodyFont == null || titleFont == null) throw "The chart fonts are not ready. Try again.";
        var plan = FightSnapshot.plan(fight);
        var scene = G.create("h2d.Scene", []);
        var root = G.create("h2d.Object", [scene]);
        var graphic = G.create("h2d.Graphics", [root]);
        var texture:Dynamic = null;
        var pixels:Dynamic = null;
        try {
            rect(graphic, 0, 0, plan.width, plan.height, 0xcfbbb0);
            rect(graphic, 0, 0, plan.width, 64, 0xecd5ca);
            text(root, titleFont, encounter, 24, 14, 852, 28, 0x815c43);
            text(root, bodyFont, FightHistory.chartDetail(entry), 24, 78, 852, 18, 0x5b4334);
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
            var output = haxe.io.Bytes.alloc(plan.width * plan.height * 4);
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
            while (y < plan.height) {
                var stripHeight = Std.int(Math.min(2048, plan.height - y));
                texture = SnapshotTexture.create(plan.width, stripHeight, flags);
                position(root, 0, -y);
                G.call("h2d.Object", "drawTo", root, [texture]);
                pixels = SnapshotTexture.readBgra(texture);
                var bytes = G.field(pixels, "bytes");
                var offset = G.integer(G.field(pixels, "offset"));
                var stride = G.integer(G.field(pixels, "stride"));
                var length = G.integer(G.field(bytes, "length"));
                var rowBytes = plan.width * 4;
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
            DesktopActions.copyImage(output, plan.width, plan.height);
        } catch (error:Dynamic) {
            cleanup(scene, root, texture, pixels);
            throw error;
        }
        cleanup(scene, root, texture, pixels);
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
