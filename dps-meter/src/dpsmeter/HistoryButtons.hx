package dpsmeter;

import dpsmeter.GameAccess as G;
import dpsmeter.NativeUi.*;

class HistoryButtons {
    static var styledData:Dynamic;
    public static function folder(parent:Dynamic, click:Void->Void):Dynamic {
        var button = NativeUi.button(parent, "", "dpsHistoryFolder", click);
        padding(button, 0); size(button, 34, 30);
        var g = G.create("h2d.Graphics", [button]); absolute(button, g); position(g, 5, 5);
        G.call("h2d.Graphics", "lineStyle", g, [1.5, 0x71523c, 1.0]);
        G.call("h2d.Graphics", "beginFill", g, [0xf3d68e, 1.0]);
        // A single flat silhouette with a tab stays legible at icon size.
        path(g, [[1., 3.], [9., 3.], [12., 6.], [23., 6.], [23., 19.], [1., 19.], [1., 3.]]);
        G.call("h2d.Graphics", "endFill", g);
        return button;
    }
    public static function snapshot(parent:Dynamic, click:Void->Void):Dynamic {
        var button = NativeUi.button(parent, "", "dpsHistorySnapshot", click);
        padding(button, 0); size(button, 50, 34);
        var g = G.create("h2d.Graphics", [button]); absolute(button, g); position(g, 6, 5);
        G.call("h2d.Graphics", "lineStyle", g, [1.5, 0x5b4334, 1.0]);
        G.call("h2d.Graphics", "beginFill", g, [0xf4e4cf, 1.0]);
        G.call("h2d.Graphics", "drawRect", g, [23., 3., 15., 20.]);
        G.call("h2d.Graphics", "endFill", g);
        G.call("h2d.Graphics", "beginFill", g, [0xb99a70, 1.0]);
        G.call("h2d.Graphics", "drawRect", g, [27., 1., 7., 4.]);
        G.call("h2d.Graphics", "endFill", g);
        G.call("h2d.Graphics", "beginFill", g, [0xf3dfbc, 1.0]);
        path(g, [[1., 8.], [6., 8.], [9., 4.], [18., 4.], [21., 8.], [27., 8.], [27., 23.], [1., 23.], [1., 8.]]);
        G.call("h2d.Graphics", "endFill", g);
        G.call("h2d.Graphics", "drawCircle", g, [14., 15., 6., 24]);
        G.call("h2d.Graphics", "drawCircle", g, [14., 15., 3., 18]);
        return button;
    }
    public static function red(button:Dynamic):Void {
        var ui = G.current("ui.BaseUI", "current");
        var sheet = G.field(ui, "style"); var data = G.field(sheet, "data");
        if (data != styledData) {
            var selector = "button.dps-history-delete";
            var css = selector + " > #background { background: #D75C4E; }"
                + selector + ":hover > #background { background: darken(#D75C4E, 8%); }"
                + selector + ":active > #background { background: darken(#D75C4E, 15%); }";
            var rules = G.call("domkit.CssParser", "parseSheet", G.field(sheet, "cssParser"), [css, "dps-meter-actions"]);
            G.call("domkit.CssStyle", "add", sheet, [rules]); styledData = data;
        }
        G.call("domkit.Properties", "addClass", G.field(button, "dom"), ["dps-history-delete"]);
    }
    static function path(graphic:Dynamic, points:Array<Array<Float>>):Void {
        G.call("h2d.Graphics", "moveTo", graphic, [points[0][0], points[0][1]]);
        for (i in 1...points.length) G.call("h2d.Graphics", "lineTo", graphic, [points[i][0], points[i][1]]);
    }
}
