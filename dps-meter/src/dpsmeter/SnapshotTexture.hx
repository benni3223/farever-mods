package dpsmeter;

import dpsmeter.GameAccess as G;

/** GPU and clipboard channel orders are separate: DX12 rejects BGRA textures. */
class SnapshotTexture {
    public static function create(width:Int, height:Int, flags:Dynamic):Dynamic {
        var rgba = G.enumeration("hxd.PixelFormat", "RGBA");
        if (rgba == null) throw "The game's RGBA texture format is unavailable.";
        return G.create("h3d.mat.Texture", [width, height, flags, rgba]);
    }
    public static function readBgra(texture:Dynamic):Dynamic {
        var bgra = G.enumeration("hxd.PixelFormat", "BGRA");
        if (bgra == null) throw "The game's BGRA image format is unavailable.";
        var pixels = G.call("h3d.mat.Texture", "capturePixels", texture, [null, null, null]);
        if (pixels == null) throw "Could not read the chart image from the renderer.";
        try G.call("hxd.Pixels", "convert", pixels, [bgra])
        catch (error:Dynamic) {
            try G.call("hxd.Pixels", "dispose", pixels) catch (_:Dynamic) {}
            throw error;
        }
        return pixels;
    }
}
