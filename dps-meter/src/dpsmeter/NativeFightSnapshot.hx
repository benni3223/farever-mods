package dpsmeter;

import dpsmeter.GameAccess as G;
import dpsmeter.NativeUi.*;

/** Render the native body with its skin, fonts and gauges, hiding UI controls. */
class NativeFightSnapshot {
    public static function copyBody(window:Dynamic, width:Int, height:Int, controls:Array<Dynamic>):Void {
        var size = SnapshotLayout.imageSize(width, height);
        var parent = G.field(window, "parent");
        if (parent == null) throw "The window is not ready. Try again.";
        var x = G.number(G.field(window, "x")), y = G.number(G.field(window, "y"));
        var scaleX = G.number(G.field(window, "scaleX"), 1), scaleY = G.number(G.field(window, "scaleY"), 1);
        var origin = localPoint(parent, 0, 0);
        var unit = localPoint(parent, SnapshotLayout.SCALE, SnapshotLayout.SCALE);
        var visibility = [for (object in controls) {object: object, visible: G.field(object, "visible") == true}];
        var texture:Dynamic = null, pixels:Dynamic = null;
        try {
            for (state in visibility) show(state.object, false);
            // Cancel the game's UI scaling so the output has a consistent
            // resolution. Keep the window attached: removing it triggers native
            // UI disposal and loses its DOM styling and input registration.
            G.call("h2d.Object", "set_scaleX", window, [unit.x - origin.x]);
            G.call("h2d.Object", "set_scaleY", window, [unit.y - origin.y]);
            var output = haxe.io.Bytes.alloc(size.width * size.height * 4);
            var windows = G.field(G.current("ui.BaseUI", "current"), "windows");
            var flags = G.call("hl.types.ArrayObj", "slice", windows, [0, 0]);
            var target = G.enumeration("h3d.mat.TextureFlags", "Target");
            if (flags == null || target == null) throw "The renderer's target texture flags are unavailable.";
            G.call("hl.types.ArrayObj", "pushDyn", flags, [target]);
            var rowBytes = size.width * 4;
            var top = 0;
            while (top < size.height) {
                var stripHeight = Std.int(Math.min(2048, size.height - top));
                texture = SnapshotTexture.create(size.width, stripHeight, flags);
                // CF_DIB has no alpha channel. Use an opaque neutral backdrop
                // so rounded corners and translucent native details composite
                // correctly instead of becoming black premultiplied pixels.
                G.call("h3d.mat.Texture", "clear", texture, [0x261f1a, null, null]);
                var point = localPoint(parent, SnapshotLayout.MARGIN * SnapshotLayout.SCALE,
                    SnapshotLayout.MARGIN * SnapshotLayout.SCALE - top);
                position(window, point.x, point.y);
                G.call("h2d.Object", "drawTo", window, [texture]);
                pixels = SnapshotTexture.readBgra(texture);
                var bytes = G.field(pixels, "bytes");
                var offset = G.integer(G.field(pixels, "offset"));
                var stride = G.integer(G.field(pixels, "stride"));
                var length = G.integer(G.field(bytes, "length"));
                if (offset < 0 || stride < rowBytes || length < offset + (stripHeight - 1) * stride + rowBytes)
                    throw "The renderer returned an incomplete window image.";
                var raw:hl.Bytes = cast HlxRuntime.unboxPointer(G.field(bytes, "b"));
                if (raw == null) throw "The window pixel buffer is unavailable.";
                var source = raw.toBytes(length);
                for (row in 0...stripHeight) output.blit((top + row) * rowBytes, source, offset + row * stride, rowBytes);
                G.call("hxd.Pixels", "dispose", pixels); pixels = null;
                G.call("h3d.mat.Texture", "dispose", texture); texture = null;
                top += stripHeight;
            }
            DesktopActions.copyImage(output, size.width, size.height);
        } catch (error:Dynamic) {
            cleanup(texture, pixels);
            restore(window, x, y, scaleX, scaleY, visibility);
            throw error;
        }
        restore(window, x, y, scaleX, scaleY, visibility);
    }
    static function restore(window:Dynamic, x:Float, y:Float, scaleX:Float, scaleY:Float,
        visibility:Array<{object:Dynamic, visible:Bool}>):Void {
        for (state in visibility) show(state.object, state.visible);
        G.call("h2d.Object", "set_scaleX", window, [scaleX]);
        G.call("h2d.Object", "set_scaleY", window, [scaleY]);
        position(window, x, y);
    }
    static function cleanup(texture:Dynamic, pixels:Dynamic):Void {
        if (pixels != null) try G.call("hxd.Pixels", "dispose", pixels) catch (_:Dynamic) {}
        if (texture != null) try G.call("h3d.mat.Texture", "dispose", texture) catch (_:Dynamic) {}
    }
    static function localPoint(parent:Dynamic, x:Float, y:Float):{x:Float, y:Float} {
        var point = HlxRuntime.allocInstance(HlxRuntime.resolveType("h2d.col.PointImpl"));
        G.set(point, "x", x); G.set(point, "y", y);
        G.call("h2d.Object", "globalToLocal", parent, [point]);
        return {x: G.number(G.field(point, "x")), y: G.number(G.field(point, "y"))};
    }
    public static function reflow(object:Dynamic):Void {
        // Existing DOM styles are already applied. Reflow descendants after
        // expanding the chart, then rebuild the native frame at its new size.
        for (child in children(object)) reflow(child);
        if (G.field(object, "needReflow") != null) G.call("h2d.Flow", "reflow", object);
    }
}
