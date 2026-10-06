package itemutilities;

class SkillPresetLayout {
    public static function place(footer:OverlayRect, text:OverlayRect, controls:OverlayRect,
            ?window:OverlayRect, ?equippedSkills:OverlayRect):OverlayRect {
        if (footer == null || text == null || controls == null
            || !footer.valid() || !text.valid() || !controls.valid()) return null;
        var padding = 16 * controls.width / PresetSlots.CONTROLS_WIDTH;
        var right = footer.right - 2 * padding;
        // Mirror the actual equipped-skills inset from the window edge. The
        // footer can extend past that edge, so its own padding isn't enough.
        if (window != null && equippedSkills != null && window.valid() && equippedSkills.valid()) {
            var margin = equippedSkills.left - window.left;
            if (margin > 0 && margin < window.width * 0.5)
                right = Math.min(footer.right, window.right - margin);
        }
        right -= 10 * controls.width / PresetSlots.CONTROLS_WIDTH;
        var gap = right - text.right - padding;
        if (gap <= 0) return null;
        var scale = Math.min(1, Math.min(gap / controls.width, footer.height / controls.height));
        var width = controls.width * scale;
        var height = controls.height * scale;
        var x = right - width;
        var y = (footer.top + footer.bottom - height) * 0.5;
        return new OverlayRect(x, y, x + width, y + height);
    }
}
