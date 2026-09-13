package itemutilities;

class TalentPresetLayout {
    public static function place(points:OverlayRect, root:OverlayRect,
        tree:OverlayRect, controls:OverlayRect):OverlayRect {
        if (points == null || root == null || tree == null || controls == null
            || !points.valid() || !root.valid() || !tree.valid() || !controls.valid()) return null;
        var gap = tree.right - root.right;
        if (gap <= 0) return null;
        // Match the equipment controls, fitting only if a narrower tree needs it.
        var scale = Math.min(1, gap / (controls.width + 16 * controls.height / 36));
        var width = controls.width * scale;
        var height = controls.height * scale;
        var x = (root.right + tree.right - width) * 0.5;
        var y = (points.top + points.bottom - height) * 0.5;
        return new OverlayRect(x, y, x + width, y + height);
    }
}
