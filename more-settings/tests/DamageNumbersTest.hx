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
            var top = critical ? (redCriticals ? 0x9C120D : 0xA80C2C) : coloredMagic ? (blueMagic ? 0x5963C4 : 0xF04424) : physical.top;
            var bottom = critical ? (redCriticals ? 0xFA4B34 : 0xEF8DEB) : coloredMagic ? (blueMagic ? 0xBCC2FF : 0xFFCB6D) : physical.bottom;
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
        var mappingFilter = gradientMapping();
        eq(G.textures.length, 1, "All hits and palettes reuse one ramp texture");
        var texture = G.textures[0];
        eq(texture.pixels.colors[0], 0xFF000000, "Gradient top selects first color");
        eq(texture.pixels.colors[63], 0xFFFFFFFF, "Gradient bottom selects second color");
        var reload:Void->Void = texture.realloc;
        reload(); eq(texture.uploads, 2, "Device reset can restore the mask from retained pixels");
        FancyDamageNumbers.dispose();
        mappingFilter.shader.maskMatB__.y = 123.0;
        FancyDamageNumbers.syncGradient(mappingFilter, null, null);
        eq(mappingFilter.shader.maskMatB__.y, 123.0, "Scene disposal clears gradient owners");
        eq(texture.disposed && texture.pixels.disposed, true, "Scene disposal releases GPU and CPU ramp resources");
        eq(texture.realloc, null, "Disposed texture cannot retain the restore callback");
        FancyDamageNumbers.dispose();
        FancyDamageNumbers.apply(display(true), config);
        eq(G.textures.length, 2, "Next scene creates a fresh valid ramp");
        FancyDamageNumbers.dispose();
        Sys.println('Fancy damage numbers: $checks checks passed.');
    }

    static function gradientMapping():Dynamic {
        var config = SettingsData.defaults();
        config.fancyDamageNumbers = true;
        config.redCriticals = true;
        var lastFilter:Dynamic = null;
        for (fancyBorder in [false, true]) for (thickness in [0.5, 2.0, 6.0]) {
            if (lastFilter != null) FancyDamageNumbers.unbindGradient(lastFilter);
            config.fancyBorder = fancyBorder;
            config.borderThickness = thickness;
            var d = display(true);
            FancyDamageNumbers.apply(d, config);
            var filter = filters(d.counter.filter)[0];
            var shader = filter.shader;
            // Native Group.bind forwards the owning text to every child filter.
            FancyDamageNumbers.bindGradient(filter, d.counter);
            for (glyphHeight in [16.0, 37.5]) for (resolution in [1.0, 2.0])
            for (screenScale in [1.0, 1.5]) for (clipped in [false, true]) {
                d.counter.calcYMin = 4.25;
                d.counter.calcHeight = glyphHeight;
                d.counter.filter.resolutionScale = resolution;
                d.counter.filter.useScreenResolution = screenScale != 1;
                var context:Dynamic = {scene: {viewportScaleY: screenScale}};
                var scale = resolution * screenScale;
                var padding = thickness * 2 * (fancyBorder ? 2 : 1);
                // Same bounds expansion/rounding as native Object.drawFilters.
                var pixelTop = Math.floor(4.25 * scale - padding);
                var pixelBottom = Math.ceil((4.25 + glyphHeight) * scale + padding);
                if (clipped) pixelTop += Math.floor(glyphHeight * scale / 3);
                var tile:Dynamic = {dy: pixelTop / scale, height: pixelBottom - pixelTop};
                FancyDamageNumbers.syncGradient(filter, context, tile);
                var slope:Float = shader.maskMatB__.y, offset:Float = shader.maskMatB__.z;
                for (fraction in [0.0, 0.25, 0.5, 0.75, 1.0]) {
                    var pixelY = (4.25 + glyphHeight * fraction) * scale;
                    var uv = (pixelY - pixelTop) / (pixelBottom - pixelTop);
                    if (uv < 0 || uv > 1) continue;
                    var maskUV = slope * uv + offset;
                    // Bilinear sampling of a 64-row ramp at its texel centers.
                    var blend = (maskUV * 64 - 0.5) / 63;
                    near(blend, fraction, "Gradient spans glyphs despite border padding, font size, scale, or clipping");
                    var r0:Float = shader.matrix__._11, r1:Float = shader.matrix2__._11;
                    near(r0 * (1-blend) + r1 * blend, (156 * (1-fraction) + 250 * fraction) / 255,
                        "Rendered red blend reaches both sampled endpoints with an even transition");
                }
            }
            FancyDamageNumbers.unbindGradient(filter);
            shader.maskMatB__.y = 123.0;
            FancyDamageNumbers.syncGradient(filter, null, null);
            eq(shader.maskMatB__.y, 123.0, "Unbinding releases the counter and disables further updates");
            FancyDamageNumbers.bindGradient(filter, d.counter);
            FancyDamageNumbers.syncGradient(filter, {scene: {viewportScaleY: 1.5}}, {dy: 0.0, height: 100.0});
            eq(shader.maskMatB__.y == 123.0, false, "Rebinding restores gradient tracking");
            lastFilter = filter;
        }
        var other:Dynamic = {pass: {shader: {mask__: {}, maskMatB__: {y: 321.0}}}};
        FancyDamageNumbers.bindGradient(other, {});
        FancyDamageNumbers.syncGradient(other, null, null);
        eq(other.pass.shader.maskMatB__.y, 321.0, "Unrelated native shaders are not tracked or modified");
        return lastFilter;
    }
}
