package bettermodsettings;

typedef TooltipBounds = {xMin:Float, yMin:Float, xMax:Float, yMax:Float};

/** Literal help text and placement in one shared (tooltip-parent) coordinate space. */
class SettingTooltip {
    public static function text(definition:Dynamic):String {
        if (definition == null) return null;
        var tip = Reflect.field(definition, "tooltip");
        if (tip == null || Reflect.field(tip, "enabled") != true) return null;
        var value = Reflect.field(tip, "tooltipText");
        if (!Std.isOfType(value, String) || StringTools.trim(value).length == 0) return null;
        return value;
    }

    public static function place(anchor:TooltipBounds, bounds:TooltipBounds,
            viewport:TooltipBounds, gap:Float):{x:Float, y:Float, scale:Float} {
        var width = bounds.xMax - bounds.xMin, height = bounds.yMax - bounds.yMin;
        var availableWidth = viewport.xMax - viewport.xMin, availableHeight = viewport.yMax - viewport.yMin;
        if (width <= 0 || height <= 0 || availableWidth <= 0 || availableHeight <= 0)
            return {x: viewport.xMin, y: viewport.yMin, scale: 1};
        var scale = Math.min(1, Math.min(availableWidth / width, availableHeight / height));
        var left = anchor.xMin;
        var top = anchor.yMax + gap;
        if (top + height * scale > viewport.yMax) top = anchor.yMin - gap - height * scale;
        left = Math.max(viewport.xMin, Math.min(left, viewport.xMax - width * scale));
        top = Math.max(viewport.yMin, Math.min(top, viewport.yMax - height * scale));
        return {x: left - bounds.xMin * scale, y: top - bounds.yMin * scale, scale: scale};
    }
}
