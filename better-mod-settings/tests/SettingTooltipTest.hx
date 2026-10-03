import bettermodsettings.SettingTooltip;
import bettermodsettings.SettingTooltip.TooltipBounds;

class SettingTooltipTest {
    static var checks = 0;
    static function check(value:Bool, message:String):Void {
        checks++;
        if (!value) throw message;
    }
    static function rect(x:Float, y:Float, width:Float, height:Float):TooltipBounds
        return {xMin: x, yMin: y, xMax: x + width, yMax: y + height};
    static function main():Void {
        for (definition in [null, {}, {tooltip: null}, {tooltip: false}, {tooltip: {}},
                {tooltip: {enabled: false, tooltipText: "hidden"}},
                {tooltip: {enabled: "true", tooltipText: "hidden"}},
                {tooltip: {enabled: true}}, {tooltip: {enabled: true, tooltipText: 100}},
                {tooltip: {enabled: true, tooltipText: " \n\t"}}])
            check(SettingTooltip.text(definition) == null, "Disabled or invalid help stays absent");
        var literal = 'Use <500 & "100%".\nNext line.';
        check(SettingTooltip.text({tooltip: {enabled: true, tooltipText: literal}}) == literal,
            "Help remains literal, preserving symbols and line breaks");
        var body = rect(-4, -6, 380, 96);
        var viewport = rect(8, 8, 1000, 700);
        var below = SettingTooltip.place(rect(100, 100, 18, 18), body, viewport, 8);
        check(below.y + body.yMin == 126 && below.scale == 1, "Ordinary help appears below its icon");
        var above = SettingTooltip.place(rect(100, 650, 18, 18), body, viewport, 8);
        check(above.y + body.yMax == 642, "Near the bottom help flips above its icon");
        // Shifted/scaled parent coordinates, both screen edges, negative shadows,
        // tiny screens, tall multi-line content, and long unbroken content.
        for (scale in [0.5, 1.0, 1.5, 2.0]) for (offset in [-120.0, 0.0, 250.0]) {
            var screen = rect(offset + 8 / scale, offset + 8 / scale, 1264 / scale, 704 / scale);
            for (x in [screen.xMin - 30, screen.xMin + 40, screen.xMax - 10])
            for (y in [screen.yMin - 20, screen.yMin + 40, screen.yMax - 10])
            for (box in [body, rect(-12, -8, 2000, 60), rect(-4, -6, 380, 1800)]) {
                var fitted = SettingTooltip.place(rect(x, y, 18, 18), box, screen, 8 / scale);
                var epsilon = .00001;
                check(fitted.x + box.xMin * fitted.scale >= screen.xMin - epsilon
                    && fitted.x + box.xMax * fitted.scale <= screen.xMax + epsilon,
                    "Whole tooltip fits horizontally, including shadow");
                check(fitted.y + box.yMin * fitted.scale >= screen.yMin - epsilon
                    && fitted.y + box.yMax * fitted.scale <= screen.yMax + epsilon,
                    "Whole tooltip fits vertically");
                check(fitted.scale > 0 && fitted.scale <= 1, "Only oversized help is reduced");
            }
        }
        Sys.println('Setting tooltip tests passed ($checks checks)');
    }
}
