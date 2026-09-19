package dpsmeter;

/** Native body dimensions in UI units, before high-resolution rasterization. */
class SnapshotLayout {
    public static inline var SCALE:Int = 2;
    // Both native windows place their body eight UI units inside the frame.
    public static inline var BODY_INSET:Int = 8;
    public static function historyHeight(chartHeight:Int, windowHeight:Int = 320):Int
        // Retain the encounter heading/summary, but remove the 52-unit header
        // space and 68-unit action footer from the live window's dimensions.
        return Std.int(Math.max(windowHeight - 120, 124 + chartHeight));
    public static function recapHeight(columns:Bool, chartHeights:Array<Int>, windowHeight:Int = 0):Int {
        var body = 0;
        for (h in chartHeights) body = columns ? Std.int(Math.max(body, h + 40)) : body + h + 64;
        // Native frame inset is eight units at each edge; no window header.
        return Std.int(Math.max(windowHeight - 52, 16 + (columns ? 24 + body : body)));
    }
    public static function imageSize(width:Int, height:Int, scale:Int = SCALE):{width:Int, height:Int} {
        if (width <= 2 * BODY_INSET || height <= 2 * BODY_INSET || scale <= 0) throw "Invalid snapshot dimensions.";
        // Capture exactly the native body: no outer frame or added canvas.
        var w = (width - 2.0 * BODY_INSET) * scale, h = (height - 2.0 * BODY_INSET) * scale;
        if (w * h * 4 > 128 * 1024 * 1024) throw "This fight is too large to copy as one image.";
        return {width: Std.int(w), height: Std.int(h)};
    }
}
