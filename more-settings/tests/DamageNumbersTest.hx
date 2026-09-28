import moresettings.FancyDamageNumbers;
import moresettings.SettingsData;
import moresettings.GameAccess as G;

class DamageNumbersTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, message:String):Void {
        checks++;
        if (actual != expected) throw message + ': expected $expected, got $actual';
    }
    static function near(actual:Float, expected:Float, message:String):Void
        eq(Math.abs(actual - expected) < 0.000001, true, message + ': expected $expected, got $actual');
    static function display(critical:Bool, magic:Bool = false, raw:Bool = false):Dynamic return {
        isCrit: critical,
        dmg: {magic: magic, affinity: raw ? "Raw" : magic ? "Fire" : "Physical"},
        affinity: {damageColor: magic && !raw ? 0xFFFF00 : 0xFFFFFF},
        counter: {dom: {styles: {}}, textColor: 0xABCDEF, filter: null, text: "123,456"}
    };
    static function filters(filter:Dynamic):Array<Dynamic> {
        if (filter == null) return [];
        if (filter.kind != "group") return [filter];
        var result:Array<Dynamic> = [];
        for (f in (cast filter.filters:Array<Dynamic>)) result = result.concat(filters(f));
        return result;
    }
    static function main():Void {
        var config = SettingsData.defaults();
        eq(config.fancyDamageNumbers, false, "Fancy damage numbers remains opt-in");
        eq(config.redCriticals, false, "Criticals keep their existing pink palette by default");
        eq(config.blueMagic, false, "Magic damage keeps its existing orange palette by default");
        eq(config.orangePhysical, false, "Orange physical is opt-in");
        eq(config.lightOrangePhysical, false, "Light orange physical is opt-in");
        eq(config.flipGradient, false, "Gradients retain their original direction by default");
        eq(config.fancyBorder, false, "Fancy border is opt-in to preserve the existing black outline");
        eq(config.borderThickness, 2.0, "Border thickness preserves the existing two-pixel layers");
        for (sample in [
            {value: -10.0, expected: 0.5}, {value: 10.0, expected: 6.0},
            {value: Math.NaN, expected: 2.0}, {value: Math.POSITIVE_INFINITY, expected: 2.0},
            {value: 0.5, expected: 0.5}, {value: 3.5, expected: 3.5}, {value: 6.0, expected: 6.0}
        ]) {
            config.borderThickness = sample.value;
            SettingsData.normalize(config);
            eq(config.borderThickness, sample.expected, "Thickness stays within the supported range");
        }
        config.borderThickness = 2;
        config.redCriticals = true;
        config.blueMagic = true;
        config.flipGradient = true;
        config.orangePhysical = true;
        config.lightOrangePhysical = true;
        for (fancyBorder in [false, true]) for (critical in [false, true]) for (raw in [false, true]) {
            config.fancyBorder = fancyBorder;
            var disabled = display(critical, false, raw);
            FancyDamageNumbers.apply(disabled, config);
            eq(disabled.counter.textColor, 0xABCDEF, "Master toggle gates every style option");
            eq(disabled.counter.filter, null, "Fancy border cannot style numbers with the master disabled");
            eq(G.textures.length, 0, "Disabled feature allocates no GPU texture");
        }
        config.fancyDamageNumbers = true;
        for (critical in [false, true]) for (magic in [false, true])
        for (fancyBorder in [false, true]) for (flip in [false, true]) for (thickness in [0.5, 2.0, 6.0]) {
            config.fancyBorder = fancyBorder;
            config.flipGradient = flip;
            config.borderThickness = thickness;
            var raw = display(critical, magic, true);
            raw.counter.filter = {kind: "native"};
            raw.counter.dropShadow = {color: 0, alpha: 1.0, dx: 1.0, dy: 1.0};
            FancyDamageNumbers.apply(raw, config);
            eq(raw.counter.textColor, 0xFFFFFF, "Raw hits stay pure white, including criticals");
            eq(raw.counter.dom.styles.color, 0xFFFFFF, "CSS cannot restore a crit color on Raw hits");
            var stack = filters(raw.counter.filter);
            eq(stack.length, fancyBorder ? 2 : 1, "Raw uses only the chosen border layers");
            for (filter in stack) {
                eq(filter.kind, "outline", "Raw acquires no gradient or native color filter");
                eq(filter.size, thickness, "Raw respects the border thickness slider");
            }
            if (fancyBorder) eq(stack[0].color, 0xFFFFFF, "Fancy Raw border has a white inner layer");
            eq(stack[stack.length - 1].color, 0, "Raw always has a black outer border");
            eq(raw.counter.dom.styles.filter, raw.counter.filter, "Raw border survives CSS refreshes");
            eq(raw.counter.dropShadow, null, "Raw hits have no native text shadow");
            eq(Reflect.hasField(raw.counter.dom.styles, "text-shadow"), true, "Raw shadow stays disabled after CSS refresh");
            eq(raw.counter.text, "123,456", "Raw styling preserves the damage value");
            eq(G.textures.length, 0, "Raw-only hits allocate no gradient texture");
        }
        config.flipGradient = false;
        config.borderThickness = 2;
        for (redCriticals in [false, true]) for (physical in [
            {orange: false, light: false, top: 0x8C8C8C, bottom: 0xFFFFFF},
            {orange: false, light: true, top: 0x8C8C8C, bottom: 0xFFFFFF},
            {orange: true, light: false, top: 0xF04424, bottom: 0xFFCB6D},
            {orange: true, light: true, top: 0xF18745, bottom: 0xFEC59E}
        ])
        for (blueMagic in [false, true]) for (fancyBorder in [false, true]) for (critical in [false, true]) for (kind in [
            {magic: false, raw: false}, {magic: true, raw: false}
        ]) {
            config.redCriticals = redCriticals;
            config.orangePhysical = physical.orange;
            config.lightOrangePhysical = physical.light;
            config.fancyBorder = fancyBorder;
            config.blueMagic = blueMagic;
            var d = display(critical, kind.magic, kind.raw);
            var nativeFilter:Dynamic = {kind: "native"};
            d.counter.filter = nativeFilter;
            FancyDamageNumbers.apply(d, config);
            var stack = filters(d.counter.filter);
            eq(stack[0], nativeFilter, "Existing native filter survives every combination");
            eq(d.counter.text, "123,456", "Styling never rewrites damage text");
            var coloredMagic = !critical && kind.magic && !kind.raw;
            eq(d.counter.textColor, 0xFFFFFF, "Every damage type gets the gradient fill");
            eq(stack.length, fancyBorder ? 4 : 3, "Fancy border adds exactly one outline layer");
            if (fancyBorder) {
                eq(stack[2].kind, "outline", "White inner border follows the gradient");
                eq(stack[2].color, 0xFFFFFF, "Inner border stays white");
                eq(stack[2].size, 2.0, "White inner border thickness");
            }
            var outer = stack[stack.length - 1];
            eq(outer.kind, "outline", "Black outline wraps the fully styled number");
            eq(outer.color, 0, "Outer border stays black in both modes");
            eq(outer.size, 2.0, "Black outer border keeps its existing thickness");
            eq(d.counter.dom.styles.filter, d.counter.filter, "Both outline modes survive CSS refreshes");
            var shader = stack[1].shader;
            eq(shader.useAlpha__, true, "Native filter preserves source alpha");
            eq(shader.hasSecondMatrix__ && shader.useMask__, true, "Uses both gradient endpoints");
            eq(shader.maskMatB__.y, 1.0, "Ramp follows screen-quad vertical coordinate");
            eq(shader.maskChannel__.w, 0.0, "Opaque mask alpha must not bias interpolation");
            var top = critical ? (redCriticals ? 0x98233C : 0xA80C2C) : coloredMagic ? (blueMagic ? 0x5963C4 : 0xF04424) : physical.top;
            var bottom = critical ? (redCriticals ? 0xC2274B : 0xEF8DEB) : coloredMagic ? (blueMagic ? 0xBCC2FF : 0xFFCB6D) : physical.bottom;
            near(shader.matrix__._22, ((top >> 8) & 255) / 255.0,
                "Critical palette overrides physical and magic palettes only on critical hits");
            near(shader.matrix2__._33, (bottom & 255) / 255.0, "Gradient ends in the selected palette");
            var topRed:Float = shader.matrix__._11, bottomRed:Float = shader.matrix2__._11;
            var opacity:Float = shader.matrix__._44;
            for (y in [0.0, 0.5, 1.0]) for (alpha in [0.0, 0.25, 1.0]) {
                // Native ColorMatrixShader: mix(input * matrix, input * matrix2, mask.r).
                var r = (topRed * (1-y) + bottomRed * y) * alpha;
                near(r, (((top >> 16) & 255) * (1-y) + ((bottom >> 16) & 255) * y) / 255 * alpha,
                    "Gradient preserves premultiplied antialiasing and fades");
                near(opacity * alpha, alpha, "Opacity survives both palettes");
                near(shader.matrix__._41 + shader.matrix2__._41, 0, "Black shadow pixels receive no additive tint");
            }
            config.flipGradient = true;
            var flipped = display(critical, kind.magic, kind.raw);
            FancyDamageNumbers.apply(flipped, config);
            var flippedShader = filters(flipped.counter.filter)[0].shader;
            for (channel in ["_11", "_22", "_33"]) {
                near(Reflect.field(flippedShader.matrix__, channel), Reflect.field(shader.matrix2__, channel),
                    "Flip gradient moves the original bottom color to the top for every palette");
                near(Reflect.field(flippedShader.matrix2__, channel), Reflect.field(shader.matrix__, channel),
                    "Flip gradient moves the original top color to the bottom for every palette");
            }
            config.flipGradient = false;
        }
        for (fancyBorder in [false, true]) for (thickness in [0.5, 2.0, 3.5, 6.0]) {
            config.fancyBorder = fancyBorder;
            config.borderThickness = thickness;
            var d = display(false, true);
            FancyDamageNumbers.apply(d, config);
            var stack = filters(d.counter.filter);
            eq(stack.length, fancyBorder ? 3 : 2, "Thickness adds no extra filter passes");
            for (filter in stack) if (filter.kind == "outline")
                eq(filter.size, thickness, "Slider controls every border layer, including fractional sizes");
        }
        eq(G.textures.length, 1, "All hits and palettes reuse one ramp texture");
        var texture = G.textures[0];
        eq(texture.pixels.colors[0], 0xFF000000, "Gradient top selects first color");
        eq(texture.pixels.colors[63], 0xFFFFFFFF, "Gradient bottom selects second color");
        var reload:Void->Void = texture.realloc;
        reload(); eq(texture.uploads, 2, "Device reset can restore the mask from retained pixels");
        FancyDamageNumbers.dispose();
        eq(texture.disposed && texture.pixels.disposed, true, "Scene disposal releases GPU and CPU ramp resources");
        eq(texture.realloc, null, "Disposed texture cannot retain the restore callback");
        FancyDamageNumbers.dispose();
        FancyDamageNumbers.apply(display(true), config);
        eq(G.textures.length, 2, "Next scene creates a fresh valid ramp");
        FancyDamageNumbers.dispose();
        Sys.println('Fancy damage numbers: $checks checks passed.');
    }
}
