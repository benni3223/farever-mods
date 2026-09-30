package moresettings;

import moresettings.GameAccess as G;
import moresettings.AppearanceUi.*;

/** Draw gradient samples without reading textures back or flushing GPU work. */
class AppearanceSwatches {
    public static function paint(button:Dynamic, gradient:Dynamic, selected:Bool):Void {
        var tile = G.staticCall("lib.ExtensionsUI", "toTile", [G.field(gradient, "ref")]);
        if (tile == null || G.number(G.field(tile, "width")) < 1 || G.number(G.field(tile, "height")) < 1)
            throw "This appearance color's texture is unavailable.";
        // Native ColorSelector/ColorPickButton captures the entire texture to
        // read this one pixel. A sub-tile only creates UV
        // coordinates; Bitmap samples the same pixel in the normal UI draw.
        var sample = G.call("h2d.Tile", "sub", tile, [0.0, 0.0, 1.0, 1.0, null, null]);
        var bitmap = G.create("h2d.Bitmap", [sample, button]);
        absolute(button, bitmap); position(bitmap, 4, 4);
        G.set(bitmap, "smooth", false);
        G.call("h2d.Bitmap", "set_width", bitmap, [26.0]);
        G.call("h2d.Bitmap", "set_height", bitmap, [26.0]);
        if (selected) {
            var border = G.create("h2d.Graphics", [button]);
            absolute(button, border);
            G.call("h2d.Graphics", "lineStyle", border, [2.0, 0xE8C15F, 1.0]);
            G.call("h2d.Graphics", "drawRect", border, [2.0, 2.0, 30.0, 30.0]);
        }
        // The atlas belongs to the game. Neither its pixels, filtering nor its
        // lifetime are changed; the window owns only these drawable children.
    }
}
