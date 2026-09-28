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
        eq(config.pinkCrits, false, "Criticals keep their red palette until Pink crits is enabled");
        // Leftover preferences from older builds cannot override the fixed style.
        var legacy:Dynamic = config;
        for (key in ["blueMagic", "orangePhysical", "flipGradient"])
            Reflect.setField(legacy, key, false);
        Reflect.setField(legacy, "lightOrangePhysical", true);
        Reflect.setField(legacy, "fancyBorder", true);
        Reflect.setField(legacy, "borderThickness", 6.0);
        for (pink in [false, true]) for (critical in [false, true]) for (raw in [false, true]) {
            config.pinkCrits = pink;
            var disabled = display(critical, false, raw);
            FancyDamageNumbers.apply(disabled, config);
            eq(disabled.counter.textColor, 0xABCDEF, "Master toggle gates every style option");
            eq(disabled.counter.filter, null, "Colours and borders cannot style numbers with the master disabled");
            eq(G.textures.length, 0, "Disabled feature allocates no GPU texture");
        }
        config.fancyDamageNumbers = true;
        for (pink in [false, true]) for (critical in [false, true]) for (magic in [false, true]) {
            config.pinkCrits = pink;
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
        for (pink in [false, true]) for (critical in [false, true]) for (magic in [false, true]) {
            config.pinkCrits = pink;
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
            var top = critical ? (pink ? 0xEF8DEB : 0xFF7F66) : coloredMagic ? 0xBCC2FF : 0xFFCB6D;
            var bottom = critical ? (pink ? 0xA80C2C : 0xFF0000) : coloredMagic ? 0x5963C4 : 0xF04424;
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
        criticalColourInputs();
        criticalColourMigration();
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
        threeColourGradients();
        formattedGradientMapping();
        Sys.println('Fancy damage numbers: $checks checks passed.');
    }

    static function criticalColourInputs():Void {
        eq(SettingsData.defaults().threeColourCriticals, false, "Three-colour gradients remain opt-in");
        for (text in ["ff0003", "#FF0003", "0Xff0003", "  #ff0003 "])
            eq(SettingsData.hexColour(text, 0), 0xFF0003, "Supported hex notation parses the entire RGB value");
        for (bad in (["", "#FFF", "ff0003junk", "gg0000", "12345678", 123456, {bytes: "???", length: 6}, null]:Array<Dynamic>))
            eq(SettingsData.hexColour(bad, 0xABCDEF), 0xABCDEF, "Incomplete or malformed input safely uses the preset");
        for (pink in [false, true]) for (oldColour in (["#123456", "", {bytes: "???", length: 6}, null]:Array<Dynamic>)) {
            var config = SettingsData.defaults();
            config.fancyDamageNumbers = true;
            config.pinkCrits = pink;
            Reflect.setField(config, "criticalDarkColour", oldColour);
            Reflect.setField(config, "criticalLightColour", oldColour);
            Reflect.setField(config, "criticalMiddleColour", oldColour);
            config = cast haxe.Json.parse(haxe.Json.stringify(config));
            SettingsData.normalize(config);
            var valid = oldColour == "#123456";
            eq(config.criticalMiddleColour, valid ? "#123456" : "", "JSON strings survive; corrupted native String objects recover safely");
            for (magic in [false, true]) {
                var hit = display(true, magic);
                FancyDamageNumbers.apply(hit, config);
                var shader = filters(hit.counter.filter)[0].shader;
                assertRGB(shader.matrix__, valid ? 0x123456 : pink ? 0xEF8DEB : 0xFF7F66, "Custom top colour overrides either preset");
                assertRGB(shader.matrix2__, valid ? 0x123456 : pink ? 0xA80C2C : 0xFF0000, "Custom bottom colour overrides either preset");
            }
        }
        var separate = SettingsData.defaults();
        separate.fancyDamageNumbers = true;
        separate.criticalLightColour = "ffbbaa";
        separate.criticalDarkColour = "aa1122";
        separate.magicalCriticalLightColour = "aabbff";
        separate.magicalCriticalDarkColour = "1122aa";
        for (pink in [false, true]) for (magic in [false, true]) {
            separate.pinkCrits = pink;
            var hit = display(true, magic);
            FancyDamageNumbers.apply(hit, separate);
            var shader = filters(hit.counter.filter)[0].shader;
            assertRGB(shader.matrix__, magic ? 0xAABBFF : 0xFFBBAA, "Each critical hit selects its own top colour regardless of Pink crits");
            assertRGB(shader.matrix2__, magic ? 0x1122AA : 0xAA1122, "Each critical hit selects its own bottom colour");
        }
        separate.magicalCriticalLightColour = "";
        separate.magicalCriticalDarkColour = "invalid";
        SettingsData.normalize(separate);
        var magicHit = display(true, true);
        FancyDamageNumbers.apply(magicHit, separate);
        var magicShader = filters(magicHit.counter.filter)[0].shader;
        assertRGB(magicShader.matrix__, 0xEF8DEB, "A cleared magical stop uses Pink crits without inheriting physical colours");
        assertRGB(magicShader.matrix2__, 0xA80C2C, "Invalid magical input uses its preset independently");
        var physicalHit = display(true);
        FancyDamageNumbers.apply(physicalHit, separate);
        assertRGB(filters(physicalHit.counter.filter)[0].shader.matrix__, 0xFFBBAA, "Changing magical overrides leaves physical crits unchanged");
    }

    static function criticalColourMigration():Void {
        var config = SettingsData.defaults();
        config.criticalLightColour = " #FFBBAA ";
        config.criticalMiddleColour = "12AB34";
        config.criticalDarkColour = "0x991122";
        config = cast haxe.Json.parse(haxe.Json.stringify(config));
        // Old files do not have the newly introduced fields at all.
        for (stop in ["Light", "Middle", "Dark"])
            Reflect.deleteField(config, "magicalCritical" + stop + "Colour");
        SettingsData.normalize(config);
        for (stop in ["Light", "Middle", "Dark"])
            eq(Reflect.field(config, "magicalCritical" + stop + "Colour"), Reflect.field(config, "critical" + stop + "Colour"),
                "An upgrade copies each saved stop to magical crits without changing the text");
        config.magicalCriticalLightColour = "";
        config.magicalCriticalMiddleColour = "abcdef";
        config.criticalDarkColour = "000000";
        config = cast haxe.Json.parse(haxe.Json.stringify(config));
        SettingsData.normalize(config);
        eq(config.magicalCriticalLightColour, "", "Cleared magical input survives save/reload without being remigrated");
        eq(config.magicalCriticalMiddleColour, "abcdef", "Explicit magical input survives save/reload");
        eq(config.magicalCriticalDarkColour, "0x991122", "Later physical edits do not affect magical colours");
        Reflect.setField(config, "magicalCriticalMiddleColour", {bytes: "???", length: 6});
        SettingsData.normalize(config);
        eq(config.magicalCriticalMiddleColour, "", "Malformed magical strings recover without a HashLink cast failure");
        config = SettingsData.defaults();
        SettingsData.normalize(config);
        for (stop in ["Light", "Middle", "Dark"])
            eq(Reflect.field(config, "magicalCritical" + stop + "Colour"), "", "Fresh installations keep the existing preset for both crit types");
    }

    // Evaluate the native ColorMatrixShader's row-vector multiplication and
    // texture sampling, including mask quantization. Test the rendered colour,
    // not merely the presence of the new settings or matrix objects.
    static function sampleMask(shader:Dynamic, fraction:Float):Float {
        var texture:Dynamic = shader.mask__;
        var colors:Array<Int> = texture.pixels.colors;
        var slope:Float = shader.maskMatB__.y, offset:Float = shader.maskMatB__.z;
        var uv:Float = slope * fraction + offset;
        if (texture.filter == "h3d.mat.Filter.Nearest") {
            var index = Std.int(Math.max(0, Math.min(63, Math.floor(uv * 64))));
            return ((colors[index] >> 16) & 255) / 255.0;
        }
        var texel = Math.max(0, Math.min(63, uv * 64 - 0.5));
        var lo = Std.int(Math.floor(texel)), hi = Std.int(Math.min(63, lo + 1));
        return ((((colors[lo] >> 16) & 255) * (1 - (texel-lo))) + (((colors[hi] >> 16) & 255) * (texel-lo))) / 255.0;
    }

    static function render(stack:Array<Dynamic>, fraction:Float, intensity:Float, alpha:Float):Array<Float> {
        var rgba = [intensity * alpha, intensity * alpha, intensity * alpha, alpha];
        for (filter in stack) if (filter.kind == "gradient") {
            var shader = filter.shader;
            var weight = sampleMask(shader, fraction);
            var out:Array<Float> = [];
            for (column in 1...5) {
                var value = 0.0;
                for (row in 1...5) {
                    var key = '_$row$column';
                    var a:Float = Reflect.field(shader.matrix__, key), b:Float = Reflect.field(shader.matrix2__, key);
                    value += rgba[row-1] * (a * (1-weight) + b * weight);
                }
                out.push(Math.max(0, Math.min(1, value)));
            }
            rgba = out;
        }
        return rgba;
    }

    static function threeColourGradients():Void {
        FancyDamageNumbers.dispose();
        var before = G.textures.length;
        var config = SettingsData.defaults();
        config.fancyDamageNumbers = true;
        config.threeColourCriticals = true;
        var tracked:Array<Dynamic> = [];
        for (pink in [false, true]) for (magic in [false, true])
        for (palette in [[0xFF0000, 0x00FF00, 0x0000FF], [0x000000, 0xFFFFFF, 0x000000], [0xFFFFFF, 0x000000, 0xFFFFFF], [0xEF8DEB, 0xFF0003, 0xA80C2C]]) {
            config.pinkCrits = pink;
            var prefix = magic ? "magicalCritical" : "critical";
            var otherPrefix = magic ? "critical" : "magicalCritical";
            var stops = ["Light", "Middle", "Dark"];
            for (i in 0...3) {
                Reflect.setField(config, prefix + stops[i] + "Colour", StringTools.hex(palette[i], 6));
                Reflect.setField(config, otherPrefix + stops[i] + "Colour", "987654");
            }
            var hit = display(true, magic);
            FancyDamageNumbers.apply(hit, config);
            var stack = filters(hit.counter.filter);
            eq(stack.length, 3, "Three stops use two native matrix passes and one outline");
            eq(stack[2].color, 0, "Three-stop border remains black");
            eq(stack[2].size, 1.0, "Three-stop border remains 1 px");
            for (filter in stack) if (filter.kind == "gradient") {
                FancyDamageNumbers.bindGradient(filter, hit.counter);
                hit.counter.calcYMin = 0.0; hit.counter.calcHeight = 40.0;
                FancyDamageNumbers.syncGradient(filter, null, {dy: 0.0, height: 40.0});
                tracked.push(filter);
            }
            for (fraction in [0.0, 0.25, 0.499, 0.5, 0.501, 0.75, 1.0]) for (alpha in [0.0, 0.25, 1.0]) for (intensity in [0.0, 0.6, 1.0]) {
                var out = render(stack, fraction, intensity, alpha);
                var low = fraction < 0.5 ? palette[0] : palette[1];
                var high = fraction < 0.5 ? palette[1] : palette[2];
                var weight = fraction < 0.5 ? fraction * 2 : fraction * 2 - 1;
                for (channel in 0...3) {
                    var shift = (2-channel)*8;
                    var expected = (((low >> shift) & 255) * (1-weight) + ((high >> shift) & 255) * weight) / 255.0 * alpha * intensity;
                    eq(Math.abs(out[channel] - expected) <= 1.01 / 255.0, true, 'Rendered gradient stop: palette=$palette y=$fraction channel=$channel intensity=$intensity alpha=$alpha expected=$expected got=${out[channel]}');
                }
                near(out[3], alpha, "Three-colour interpolation preserves alpha");
            }
            for (other in [display(false, magic), display(true, magic, true)]) {
                FancyDamageNumbers.apply(other, config);
                var otherStack = filters(other.counter.filter);
                eq(otherStack.length, other.dmg.affinity == "Raw" ? 1 : 2, "Critical overrides do not change normal hits or Raw");
            }
        }
        // Clearing the middle input keeps the current top-to-bottom appearance.
        config.criticalLightColour = "ff7f66";
        config.criticalDarkColour = "ff0000";
        config.criticalMiddleColour = "";
        var fallback = display(true);
        FancyDamageNumbers.apply(fallback, config);
        for (f in filters(fallback.counter.filter)) if (f.kind == "gradient") {
            FancyDamageNumbers.bindGradient(f, fallback.counter);
            fallback.counter.calcYMin = 0.0; fallback.counter.calcHeight = 40.0;
            FancyDamageNumbers.syncGradient(f, null, {dy: 0.0, height: 40.0});
        }
        var middle = render(filters(fallback.counter.filter), 0.5, 1, 1);
        near(middle[0], 1.0, "Default middle keeps red fully saturated");
        eq(Math.abs(middle[1] - 64 / 255.0) < 1.01 / 255, true, "Empty middle uses the average endpoint colour");
        eq(G.textures.length, before + 2, "All three-colour palettes share two masks without per-hit allocations");
        for (texture in G.textures.slice(before)) {
            var reload:Void->Void = texture.realloc;
            reload();
            eq(texture.uploads, 2, "Both masks can recover after GPU reset");
        }
        config.threeColourCriticals = false;
        var two = display(true);
        FancyDamageNumbers.apply(two, config);
        eq(filters(two.counter.filter).length, 2, "Disabling three colours restores the original one-pass gradient");
        FancyDamageNumbers.dispose();
        for (texture in G.textures.slice(before)) {
            eq(texture.disposed && texture.pixels.disposed, true, "Both gradient resources are released on disposal");
            eq(texture.realloc, null, "Neither disposed mask retains its recovery callback");
        }
        for (filter in tracked) {
            filter.shader.maskMatB__.y = 123.0;
            FancyDamageNumbers.syncGradient(filter, null, null);
            eq(filter.shader.maskMatB__.y, 123.0, "Disposal releases both kinds of gradient owners");
        }
    }

    static function assertRGB(matrix:Dynamic, colour:Int, message:String):Void {
        near(matrix._11, ((colour >> 16) & 255) / 255.0, message + " (red)");
        near(matrix._22, ((colour >> 8) & 255) / 255.0, message + " (green)");
        near(matrix._33, (colour & 255) / 255.0, message + " (blue)");
    }

    static function formattedGradientMapping():Void {
        var config = SettingsData.defaults();
        config.fancyDamageNumbers = true;
        config.threeColourCriticals = true;
        config.criticalLightColour = config.criticalDarkColour = "F04424";
        config.criticalMiddleColour = "EF8DEB";
        SettingsData.normalize(config);
        for (magic in [false, true]) for (runs in [false, true]) for (resolution in [1.0, 2.0]) {
            var hit = display(true, magic);
            hit.counter.text = "66";
            // HtmlText reserves its font's entire line height, but these glyphs
            // occupy only the middle part. A missing glyph group uses infinities.
            hit.counter.calcYMin = 0.0;
            hit.counter.calcHeight = 88.0;
            hit.counter.glyphs = {visible: false, content: {
                yMin: runs ? Math.POSITIVE_INFINITY : 24.0,
                yMax: runs ? Math.NEGATIVE_INFINITY : 72.0
            }};
            var elements:Array<Dynamic> = runs ? [
                {content: {yMin: 24.0, yMax: 48.0}},
                {content: {yMin: 40.0, yMax: 72.0}},
                {y: -100.0, height: 300.0}, // Inline image/interactive box.
                {visible: false, content: {yMin: -100.0, yMax: 200.0}},
                {content: {yMin: Math.NaN, yMax: Math.NaN}}
            ] : [];
            hit.counter.elements = elements;
            FancyDamageNumbers.apply(hit, config);
            hit.counter.filter.resolutionScale = resolution;
            var stack = filters(hit.counter.filter);
            var tile:Dynamic = {dy: -2.0 / resolution, height: 88.0 * resolution + 4.0};
            for (filter in stack) if (filter.kind == "gradient") {
                FancyDamageNumbers.bindGradient(filter, hit.counter);
                FancyDamageNumbers.syncGradient(filter, null, tile);
            }
            var tileHeight:Float = tile.height, tileY:Float = tile.dy;
            for (fraction in [0.0, 0.25, 0.5, 0.75, 1.0]) {
                var glyphY = 24.0 + 48.0 * fraction;
                var uv = (glyphY - tileY) * resolution / tileHeight;
                var rgba = render(stack, uv, 1.0, 1.0);
                var middleWeight = 1 - Math.abs(fraction * 2 - 1);
                for (channel in 0...3) {
                    var shift = (2-channel)*8;
                    var edge = (0xF04424 >> shift) & 255;
                    var middle = (0xEF8DEB >> shift) & 255;
                    var expected = (edge * (1-middleWeight) + middle * middleWeight) / 255;
                    eq(Math.abs(rgba[channel] - expected) <= 1.01 / 255, true,
                        'Orange/pink/orange reaches the visible glyph stops despite blank font space: y=$fraction channel=$channel');
                }
            }
            // New glyph geometry must be used immediately after text/font rebuild.
            hit.counter.elements = [];
            hit.counter.glyphs.content = {yMin: 12.0, yMax: 60.0};
            for (filter in stack) if (filter.kind == "gradient")
                FancyDamageNumbers.syncGradient(filter, null, tile);
            var movedTop = render(stack, (12.0 - tileY) * resolution / tileHeight, 1, 1);
            near(movedTop[2], 36 / 255.0, "Rebuilt glyphs move the orange endpoint without reopening or recolouring the counter");
        }
        FancyDamageNumbers.dispose();
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
            d.counter.calcYMin = 0.0;
            d.counter.calcHeight = glyphHeight + 24.0;
            d.counter.glyphs = {content: {yMin: 4.25, yMax: 4.25 + glyphHeight}};
            d.counter.filter.resolutionScale = resolution;
            d.counter.filter.useScreenResolution = screenScale != 1;
            var context:Dynamic = {scene: {viewportScaleY: screenScale}};
            var scale = resolution * screenScale;
            var padding = 2.0; // Native bounds padding for the fixed 1 px outline.
            // Same bounds expansion/rounding as native Object.drawFilters.
            var pixelTop = Math.floor(-padding);
            var pixelBottom = Math.ceil((glyphHeight + 24.0) * scale + padding);
            if (clipped) pixelTop = Math.floor((4.25 + glyphHeight / 3) * scale);
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
                near(blend, fraction, "Gradient spans glyphs despite blank font space, border padding, font size, scale, or clipping");
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
