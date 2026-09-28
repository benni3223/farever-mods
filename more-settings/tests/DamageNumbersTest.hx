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
    static function display(critical:Bool):Dynamic return {
        isCrit: critical,
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
        eq(config.damageNumberOutline || config.damageNumberGradient || config.damageNumberRed, false, "Existing users keep flat pink");
        config.damageNumberOutline = config.damageNumberGradient = config.damageNumberRed = true;
        var disabled = display(true);
        FancyDamageNumbers.apply(disabled, config);
        eq(disabled.counter.textColor, 0xABCDEF, "Master toggle gates every style option");
        eq(G.textures.length, 0, "Disabled feature allocates no GPU texture");
        config.fancyDamageNumbers = true;
        var normal = display(false);
        FancyDamageNumbers.apply(normal, config);
        eq(normal.counter.textColor, 0xABCDEF, "Normal hits retain native colors");
        eq(normal.counter.filter, null, "Normal hits acquire no filters");
        for (outline in [false, true]) for (gradient in [false, true]) for (red in [false, true]) {
            config.damageNumberOutline = outline;
            config.damageNumberGradient = gradient;
            config.damageNumberRed = red;
            var d = display(true);
            var nativeFilter:Dynamic = {kind: "native"};
            d.counter.filter = nativeFilter;
            FancyDamageNumbers.apply(d, config);
            var stack = filters(d.counter.filter);
            eq(stack[0], nativeFilter, "Existing native filter survives every combination");
            eq(d.counter.text, "123,456", "Styling never rewrites damage text");
            eq(d.counter.textColor, gradient ? 0xFFFFFF : red ? 0xF04424 : 0xF060D0, "Fill prepares the selected palette");
            eq(stack.length, 1 + (gradient ? 1 : 0) + (outline ? 1 : 0), "Only enabled effects are attached");
            if (outline) {
                eq(stack[stack.length - 1].kind, "outline", "Outline follows gradient so it stays black");
                eq(stack[stack.length - 1].color, 0, "Black outline");
            }
            if (gradient) {
                var shader = stack[1].shader;
                eq(shader.useAlpha__, true, "Native filter preserves source alpha");
                eq(shader.hasSecondMatrix__ && shader.useMask__, true, "Uses both gradient endpoints");
                eq(shader.maskMatB__.y, 1.0, "Ramp follows screen-quad vertical coordinate");
                eq(shader.maskChannel__.w, 0.0, "Opaque mask alpha must not bias interpolation");
                var top = red ? 0xF04424 : 0xD92565, bottom = red ? 0xFFB52E : 0xEF8DEB;
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
        config.damageNumberGradient = true;
        FancyDamageNumbers.apply(display(true), config);
        eq(G.textures.length, 2, "Next scene creates a fresh valid ramp");
        FancyDamageNumbers.dispose();
        Sys.println('Fancy damage numbers: $checks checks passed.');
    }
}
