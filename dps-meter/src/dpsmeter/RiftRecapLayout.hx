package dpsmeter;

/** Shared chart geometry for the popup and the narrower history body. */
class RiftRecapLayout {
    public static inline var GAP:Int = 24;
    public static inline var HEADER:Int = 40;
    public static function columns(width:Int):Bool return width >= 792;

    public static function snapshotHeight(width:Int, charts:Array<Int>):Int {
        return columns(width) ? Std.int(Math.max(charts[0], charts[1])) + HEADER
            : charts[0] + charts[1] + HEADER * 2 + GAP;
    }

    public static function panels(width:Int, height:Int, ?charts:Array<Int>):Array<{x:Int, y:Int, width:Int, height:Int}> {
        var sideBySide = columns(width);
        var panelWidth = sideBySide ? Std.int((width - GAP) / 2) : width;
        var panelHeight = sideBySide ? height : Std.int((height - GAP) / 2);
        var y = 0;
        return [for (i in 0...2) {
            var h = charts != null && !sideBySide ? charts[i] + HEADER : panelHeight;
            var rect = {x: sideBySide ? i * (panelWidth + GAP) : 0, y: sideBySide ? 0 : y,
                width: panelWidth, height: h};
            y += h + GAP;
            rect;
        }];
    }
}
