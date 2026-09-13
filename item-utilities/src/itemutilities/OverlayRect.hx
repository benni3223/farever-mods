package itemutilities;

/** Pixel bounds shared by overlay drawing, hit testing, and native UI clipping. */
class OverlayRect {
    public var left:Float;
    public var top:Float;
    public var right:Float;
    public var bottom:Float;
    public var width(get, never):Float;
    public var height(get, never):Float;

    public function new(left:Float, top:Float, right:Float, bottom:Float) {
        this.left = left;
        this.top = top;
        this.right = right;
        this.bottom = bottom;
    }

    inline function get_width():Float return right - left;
    inline function get_height():Float return bottom - top;

    public function valid():Bool {
        return Math.isFinite(left) && Math.isFinite(top)
            && Math.isFinite(right) && Math.isFinite(bottom)
            && width > 0 && height > 0;
    }

    public function intersects(other:OverlayRect):Bool {
        return other != null && valid() && other.valid()
            && left < other.right && right > other.left
            && top < other.bottom && bottom > other.top;
    }

    public function clippedTo(other:OverlayRect):OverlayRect {
        if (!intersects(other)) return null;
        return new OverlayRect(Math.max(left, other.left), Math.max(top, other.top),
            Math.min(right, other.right), Math.min(bottom, other.bottom));
    }
}
