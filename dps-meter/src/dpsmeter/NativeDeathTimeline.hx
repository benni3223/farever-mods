package dpsmeter;

import dpsmeter.DeathLog;
import dpsmeter.GameAccess as G;
import dpsmeter.NativeUi.*;

/** One consistent, responsive timeline in the popup and every recap. */
class NativeDeathTimeline {
    public static function render(parent:Dynamic, font:Dynamic, report:DeathReport, width:Int, y:Float = 0, flowParent:Bool = false):Int {
        // Flow.getProperties requires a real Flow. The popup's mask content is
        // a plain Object, so absolute-position only the outer recap container.
        var outer = parent;
        parent = G.create("h2d.Object", [outer]);
        if (flowParent) absolute(outer, parent);
        var narrow = width < 600;
        var icons:Map<String, Dynamic> = [];
        var rowHeight = DeathTimeline.rowHeight(width);
        var barX = 62.0, barW = narrow ? Math.max(24, width * .19) : 76.0;
        var hpX = barX + barW + 6;
        var amountX = narrow ? Math.max(hpX + 54, width - 90) : 202.0;
        var spellX = narrow ? 8.0 : 290.0;
        var sourceX = narrow ? width * .58 : spellX + (width - spellX) * .54;
        text(parent, font, "Time", 6, y, 52, 0x8a5f46);
        text(parent, font, "HP / hit", barX, y, Math.max(1, amountX - barX - 8), 0x8a5f46);
        text(parent, font, "Amount", amountX, y, width - amountX - 6, 0x8a5f46);
        if (!narrow) {
            text(parent, font, "Ability", spellX, y, sourceX - spellX - 8, 0x8a5f46);
            text(parent, font, "Source", sourceX, y, width - sourceX - 6, 0x8a5f46);
        }
        y += 28;
        if (report.rows.length <= 1) {
            text(parent, font, "No incoming events received before this death", 6, y, width - 12, 0x8a5f46);
            y += 30;
        }
        for (i in 0...report.rows.length) {
            var row = report.rows[i];
            var graphic = G.create("h2d.Graphics", [parent]);
            rect(graphic, 0, y, width, rowHeight, row.lethal == true ? 0x852629 : 0x5b4334, row.lethal == true ? .11 : i % 2 == 0 ? .045 : .0);
            rect(graphic, 0, y + rowHeight - 1, width, 1, 0x5b4334, .12);
            text(parent, font, row.timeText, 6, y + 5, 52, 0x8a5f46);
            var bar = DeathTimeline.bar(row, report.healthScale);
            rect(graphic, barX, y + 11, barW, 8, 0xe4d2bc, 1);
            rect(graphic, barX, y + 11, barW * bar.remaining, 8, 0xd9655a, 1);
            rect(graphic, barX + barW * bar.remaining, y + 11, barW * bar.removed, 8, 0x852629, 1);
            if (bar.estimated) text(parent, font, "~", barX + barW - 9, y + 2, 12, 0x852629);
            text(parent, font, DeathTimeline.health(row), hpX, y + 5, amountX - hpX - 6, 0x8a5f46);
            text(parent, font, row.amountText + (row.critical == true ? " *" : ""), amountX, y + 5,
                narrow ? width - amountX - 6 : spellX - amountX - 8,
                row.death ? 0x5b4334 : row.heal ? 0x2f7a45 : 0x852629);
            var detailY = y + (narrow ? 27 : 5);
            var abilityX = spellX;
            if (row.skillId != "" && row.skillId != null) {
                if (!icons.exists(row.skillId)) {
                    var tile = null;
                    try tile = NativeCombatMetadata.skillIcon(row.skillId) catch (_:Dynamic) {}
                    icons[row.skillId] = tile;
                }
                var tile = icons[row.skillId];
                if (tile != null) {
                    var icon = G.create("h2d.Bitmap", [tile, parent]);
                    G.call("h2d.Object", "setScale", icon, [16 / Math.max(1, Math.max(G.number(G.field(tile, "width")), G.number(G.field(tile, "height"))))]);
                    position(icon, abilityX, detailY);
                    abilityX += 20;
                }
            }
            text(parent, font, (row.lethal == true ? "Fatal · " : "") + row.spell,
                abilityX, detailY, sourceX - abilityX - 8, 0x5b4334);
            text(parent, font, row.source, sourceX, detailY, width - sourceX - 6,
                row.className != "" ? classColor(row.className) : 0x8d3b32);
            y += rowHeight;
        }
        text(parent, font, "Light red: HP · dark red: hit · ~: HP sample / estimated hit", 6, y + 8, width - 12, 0x8a5f46);
        return Std.int(y + 34);
    }
    public static function text(parent:Dynamic, font:Dynamic, value:String, x:Float, y:Float, width:Float, color:Int, flowParent:Bool = false):Dynamic {
        if (width < 12) return null;
        var t = G.create("h2d.Text", [font, parent]);
        if (flowParent) absolute(parent, t);
        G.call("h2d.Text", "set_lineBreak", t, [false]);
        G.call("h2d.Text", "set_textColor", t, [color]);
        G.call("h2d.Text", "set_text", t, [value]);
        var full = G.number(G.call("h2d.Text", "get_textWidth", t));
        if (full > width && width > 0) {
            var end = Std.int(value.length * width / Math.max(1, full));
            do {
                G.call("h2d.Text", "set_text", t, [value.substr(0, Std.int(Math.max(0, end))) + "…"]);
                end--;
            } while (end >= 0 && G.number(G.call("h2d.Text", "get_textWidth", t)) > width);
        }
        position(t, x, y);
        return t;
    }
    static function rect(g:Dynamic, x:Float, y:Float, w:Float, h:Float, color:Int, alpha:Float):Void {
        if (!(w > 0) || !(alpha > 0)) return;
        G.call("h2d.Graphics", "beginFill", g, [color, alpha]);
        G.call("h2d.Graphics", "drawRect", g, [x, y, w, h]);
        G.call("h2d.Graphics", "endFill", g);
    }
}
