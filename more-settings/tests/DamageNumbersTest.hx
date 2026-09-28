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
        // Leftover preferences from older builds cannot override the fixed style.
        var legacy:Dynamic = config;
        for (key in ["blueMagic", "orangePhysical", "flipGradient"])
            Reflect.setField(legacy, key, false);
        Reflect.setField(legacy, "lightOrangePhysical", true);
        Reflect.setField(legacy, "fancyBorder", true);
        Reflect.setField(legacy, "borderThickness", 6.0);
        for (critical in [false, true]) for (raw in [false, true]) {
            var disabled = display(critical, false, raw);
            FancyDamageNumbers.apply(disabled, config);
            eq(disabled.counter.textColor, 0xABCDEF, "Master toggle gates every style option");
            eq(disabled.counter.filter, null, "Colours and borders cannot style numbers with the master disabled");
            eq(G.textures.length, 0, "Disabled feature allocates no GPU texture");
        }
        config.fancyDamageNumbers = true;
        for (critical in [false, true]) for (magic in [false, true]) {
            var raw = display(critical, magic, true);
            raw.counter.filter = {kind: "native"};
            raw.counter.dropShadow = {color: 0, alpha: 1.0, dx: 1.0, dy: 1.0};
            FancyDamageNumbers.apply(raw, config);
            eq(raw.counter.textColor, 0xFFFFFF, "Raw hits stay pure white, including criticals");
            eq(raw.counter.dom.styles.color, 0xFFFFFF, "CSS cannot restore a crit color on Raw hits");
            var stack = filters(raw.counter.filter);
            eq(stack.length, 1, "Raw uses one black border layer");
            for (filter in stack) {
                eq(filter.kind, "outline", "Raw acquires no gradient or native color filter");
                eq(filter.size, 1.0, "Raw uses a fixed 1 px border");
            }
            eq(stack[stack.length - 1].color, 0, "Raw always has a black outer border");
            eq(raw.counter.dom.styles.filter, raw.counter.filter, "Raw border survives CSS refreshes");
            eq(raw.counter.dropShadow, null, "Raw hits have no native text shadow");
            eq(Reflect.hasField(raw.counter.dom.styles, "text-shadow"), true, "Raw shadow stays disabled after CSS refresh");
            eq(raw.counter.text, "123,456", "Raw styling preserves the damage value");
            eq(G.textures.length, 0, "Raw-only hits allocate no gradient texture");
        }
        for (critical in [false, true]) for (magic in [false, true]) {
            var d = display(critical, magic);
            var nativeFilter:Dynamic = {kind: "native"};
            d.counter.filter = nativeFilter;
            FancyDamageNumbers.apply(d, config);
            var stack = filters(d.counter.filter);
            eq(stack[0], nativeFilter, "Existing native filter survives every combination");
            eq(d.counter.text, "123,456", "Styling never rewrites damage text");
            var coloredMagic = !critical && magic;
            eq(d.counter.textColor, 0xFFFFFF, "Every damage type gets the gradient fill");
            eq(stack.length, 3, "Only the gradient and one outline follow the native filter");
            var outer = stack[stack.length - 1];
            eq(outer.kind, "outline", "Black outline wraps the fully styled number");
            eq(outer.color, 0, "Border stays black");
            eq(outer.size, 1.0, "Black border is fixed at 1 px despite legacy preferences");
            eq(d.counter.dom.styles.filter, d.counter.filter, "Outline survives CSS refreshes");
            var shader = stack[1].shader;
            eq(shader.useAlpha__, true, "Native filter preserves source alpha");
            eq(shader.hasSecondMatrix__ && shader.useMask__, true, "Uses both gradient endpoints");
            eq(shader.maskMatB__.y, 1.0, "Ramp follows screen-quad vertical coordinate");
            eq(shader.maskChannel__.w, 0.0, "Opaque mask alpha must not bias interpolation");
            var top = critical ? 0xFF7F66 : coloredMagic ? 0xBCC2FF : 0xFFCB6D;
            var bottom = critical ? 0xFF0000 : coloredMagic ? 0x5963C4 : 0xF04424;
            assertRGB(shader.matrix__, top, "All palettes start with their light endpoint at the top");
            assertRGB(shader.matrix2__, bottom, "All palettes end with their dark endpoint at the bottom");
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
        }
        legacyCriticalPreferences();
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

    static function legacyCriticalPreferences():Void {
        for (red in [false, true])
        for (oldColour in (["#123456", "", {bytes: "???", length: 6}, null]:Array<Dynamic>)) {
            var config = SettingsData.defaults();
            config.fancyDamageNumbers = true;
            Reflect.setField(config, "redCriticals", red);
            Reflect.setField(config, "criticalDarkColour", oldColour);
            Reflect.setField(config, "criticalLightColour", oldColour);
            config = cast haxe.Json.parse(haxe.Json.stringify(config));
            SettingsData.normalize(config);
            for (magic in [false, true]) {
                var hit = display(true, magic);
                FancyDamageNumbers.apply(hit, config);
                var shader = filters(hit.counter.filter)[0].shader;
                assertRGB(shader.matrix__, 0xFF7F66, "Legacy colour settings cannot override the fixed light end");
                assertRGB(shader.matrix2__, 0xFF0000, "Legacy or damaged text cannot override the fixed dark end");
            }
        }
    }

    static function assertRGB(matrix:Dynamic, colour:Int, message:String):Void {
        near(matrix._11, ((colour >> 16) & 255) / 255.0, message + " (red)");
        near(matrix._22, ((colour >> 8) & 255) / 255.0, message + " (green)");
        near(matrix._33, (colour & 255) / 255.0, message + " (blue)");
    }

    static function gradientMapping():Dynamic {
        var config = SettingsData.defaults();
        config.fancyDamageNumbers = true;
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
            var padding = 2.0; // Native bounds padding for the fixed 1 px outline.
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
                var g0:Float = shader.matrix__._22, g1:Float = shader.matrix2__._22;
                near(g0 * (1-blend) + g1 * blend, 127 * (1-fraction) / 255,
                    "Rendered critical blend reaches both fixed endpoints with an even transition");
            }
        }
        FancyDamageNumbers.unbindGradient(filter);
        shader.maskMatB__.y = 123.0;
        FancyDamageNumbers.syncGradient(filter, null, null);
        eq(shader.maskMatB__.y, 123.0, "Unbinding releases the counter and disables further updates");
        FancyDamageNumbers.bindGradient(filter, d.counter);
        FancyDamageNumbers.syncGradient(filter, {scene: {viewportScaleY: 1.5}}, {dy: 0.0, height: 100.0});
        eq(shader.maskMatB__.y == 123.0, false, "Rebinding restores gradient tracking");
        var other:Dynamic = {pass: {shader: {mask__: {}, maskMatB__: {y: 321.0}}}};
        FancyDamageNumbers.bindGradient(other, {});
        FancyDamageNumbers.syncGradient(other, null, null);
        eq(other.pass.shader.maskMatB__.y, 321.0, "Unrelated native shaders are not tracked or modified");
        return filter;
    }
}
