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
        for (critical in [false, true]) for (magic in [false, true]) for (raw in [false, true]) {
            var disabled = display(critical, magic, raw);
            FancyDamageNumbers.apply(disabled, config);
            eq(disabled.counter.textColor, 0xABCDEF, "Master toggle gates every style option");
            eq(disabled.counter.filter, null, "Disabled feature preserves native styling");
            eq(G.textures.length, 0, "Disabled feature allocates no GPU texture");
        }
        config.fancyDamageNumbers = true;
        // Retired experiments cannot override the decided palettes or add text.
        for (key in ["criticalLightColour", "criticalMiddleColour", "criticalDarkColour",
            "magicalCriticalLightColour", "magicalCriticalMiddleColour", "magicalCriticalDarkColour"])
            Reflect.setField(config, key, "00ff00");
        Reflect.setField(config, "borderThickness", 6.0);
        for (oldToggle in [false, true]) {
            for (key in ["pinkCrits", "exclamationMarkCrits", "threeColourCriticals",
                "blueMagic", "orangePhysical", "flipGradient", "lightOrangePhysical", "fancyBorder"])
                Reflect.setField(config, key, oldToggle);
            for (critical in [false, true]) for (magic in [false, true]) for (raw in [false, true]) {
                var hit = display(critical, magic, raw);
                var nativeFilter:Dynamic = {kind: "native"};
                hit.counter.filter = nativeFilter;
                hit.counter.dropShadow = {color: 0, alpha: 1.0, dx: 1.0, dy: 1.0};
                hit.dmg.amount = 123456.0;
                FancyDamageNumbers.apply(hit, config);
                var stack = filters(hit.counter.filter);
                eq(stack.length, (critical ? 3 : 2) + (raw ? 0 : 1), "All crits use three stops; normal hits use two");
                if (!raw) eq(stack[0], nativeFilter, "Physical/magical hits retain the native filter");
                else {
                    eq(hit.counter.dropShadow, null, "Raw remains unshadowed");
                    eq(Reflect.hasField(hit.counter.dom.styles, "text-shadow"), true, "Raw shadow stays disabled after CSS refresh");
                }
                eq(hit.counter.text, "123,456", "Styling preserves native formatting without punctuation");
                eq(hit.dmg.amount, 123456.0, "Styling never modifies the actual damage");
                eq(hit.counter.textColor, 0xFFFFFF, "White input preserves gradient colours");
                eq(hit.counter.dom.styles.color, 0xFFFFFF, "Affinity/crit CSS cannot restore a native tint");
                eq(hit.counter.dom.styles.filter, hit.counter.filter, "Styling survives CSS refreshes");
                var outer = stack[stack.length - 1];
                eq(outer.kind, "outline", "Black outline wraps the fully styled number");
                eq(outer.color, 0, "Border stays black");
                eq(outer.size, 1.0, "Border stays 1 px despite legacy settings");
                var palette = raw ? (critical ? [0xFFFFFF, 0xFFFFFF, 0xFFFFFF] : [0xFFFFFF, 0xFFFFFF])
                    : critical ? (magic ? [0xEF8DE8, 0xC08DEF, 0x5963C4] : [0xFFCB6D, 0xF04424, 0xFF0000])
                    : magic ? [0xBCC2FF, 0x5963C4] : [0xFFCB6D, 0xF04424];
                checkPalette(hit, palette);
            }
        }
        var heal = display(true);
        heal.nativeType = "ui.comp.HealDisplay";
        FancyDamageNumbers.apply(heal, config);
        eq(heal.counter.filter, null, "Healing retains its native appearance");
        FancyDamageNumbers.dispose();
        rawColourInputs();
        FancyDamageNumbers.dispose();
        var before = G.textures.length;
        var mappingFilter = gradientMapping();
        eq(G.textures.length, before + 1, "Normal hits share one ramp texture");
        var texture = G.textures[before];
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
        FancyDamageNumbers.apply(display(false), config);
        eq(G.textures.length, before + 2, "Next scene creates a fresh valid ramp");
        FancyDamageNumbers.dispose();
        threeColourGradients();
        formattedGradientMapping();
        Sys.println('Fancy damage numbers: $checks checks passed.');
    }

    static function checkPalette(hit:Dynamic, palette:Array<Int>):Void {
        var stack = filters(hit.counter.filter);
        for (filter in stack) if (filter.kind == "gradient") {
            eq(filter.shader.useAlpha__, true, "Gradient preserves source alpha");
            eq(filter.shader.maskChannel__.w, 0.0, "Opaque mask alpha does not bias interpolation");
            FancyDamageNumbers.bindGradient(filter, hit.counter);
            hit.counter.calcYMin = 0.0; hit.counter.calcHeight = 40.0;
            FancyDamageNumbers.syncGradient(filter, null, {dy: 0.0, height: 40.0});
        }
        for (fraction in [0.0, 0.25, 0.499, 0.5, 0.501, 0.75, 1.0])
        for (alpha in [0.0, 0.25, 1.0]) for (intensity in [0.0, 0.6, 1.0]) {
            var out = render(stack, fraction, intensity, alpha);
            var lower = palette.length == 3 && fraction >= 0.5;
            var low = lower ? palette[1] : palette[0];
            var high = lower ? palette[2] : palette[1];
            var weight = palette.length == 2 ? fraction : lower ? fraction * 2 - 1 : fraction * 2;
            for (channel in 0...3) {
                var shift = (2-channel)*8;
                var expected = (((low >> shift) & 255) * (1-weight) + ((high >> shift) & 255) * weight) / 255.0 * alpha * intensity;
                eq(Math.abs(out[channel] - expected) <= 1.01 / 255.0, true,
                    'Rendered gradient: palette=$palette y=$fraction channel=$channel expected=$expected got=${out[channel]}');
            }
            near(out[3], alpha, "Gradient preserves fades and premultiplied antialiasing");
        }
    }

    static function rawColourInputs():Void {
        var keys = ["rawTopColour", "rawBottomColour", "rawCriticalTopColour", "rawCriticalMiddleColour", "rawCriticalBottomColour"];
        for (text in ["ff0003", "#FF0003", "0Xff0003", "  #ff0003 "])
            eq(SettingsData.hexColour(text, 0), 0xFF0003, "Supported hex notation parses the entire RGB value");
        for (bad in (["", "#FFF", "ff0003junk", "gg0000", "12345678", 123456, {bytes: "???", length: 6}, null]:Array<Dynamic>))
            eq(SettingsData.hexColour(bad, 0xABCDEF), 0xABCDEF, "Incomplete or malformed input safely uses the preset");
        for (value in (["#123456", "", {bytes: "???", length: 6}, 123456, null]:Array<Dynamic>)) {
            var config = SettingsData.defaults();
            for (key in keys) Reflect.setField(config, key, value);
            config = cast haxe.Json.parse(haxe.Json.stringify(config));
            SettingsData.normalize(config);
            for (key in keys) eq(Reflect.field(config, key), Std.isOfType(value, String) ? value : "",
                "Saved strings survive; corrupted native String objects reset before typed access");
            config.fancyDamageNumbers = true;
            for (critical in [false, true]) {
                var hit = display(critical, false, true);
                FancyDamageNumbers.apply(hit, config);
                var colour = value == "#123456" ? 0x123456 : 0xFFFFFF;
                checkPalette(hit, critical ? [colour, colour, colour] : [colour, colour]);
            }
        }
        var config = SettingsData.defaults();
        for (key in keys) Reflect.deleteField(config, key);
        Reflect.setField(config, "criticalLightColour", "123456");
        Reflect.setField(config, "magicalCriticalDarkColour", "654321");
        SettingsData.normalize(config);
        for (key in keys) eq(Reflect.field(config, key), "", "Missing Raw settings stay white without inheriting retired inputs");
        config.fancyDamageNumbers = true;
        config.rawTopColour = " #012345 ";
        config.rawBottomColour = "0xABCDEF";
        config.rawCriticalTopColour = "FE1020";
        config.rawCriticalMiddleColour = "20fe10";
        config.rawCriticalBottomColour = "1020FE";
        config = cast haxe.Json.parse(haxe.Json.stringify(config));
        SettingsData.normalize(config);
        eq(config.rawTopColour, " #012345 ", "Saving preserves input text exactly");
        for (magic in [false, true]) for (critical in [false, true]) {
            var hit = display(critical, magic, true);
            FancyDamageNumbers.apply(hit, config);
            checkPalette(hit, critical ? [0xFE1020, 0x20FE10, 0x1020FE] : [0x012345, 0xABCDEF]);
        }
        config.rawCriticalTopColour = "000000";
        config.rawCriticalMiddleColour = "invalid";
        config.rawCriticalBottomColour = "";
        config = cast haxe.Json.parse(haxe.Json.stringify(config));
        SettingsData.normalize(config);
        var fallback = display(true, false, true);
        FancyDamageNumbers.apply(fallback, config);
        checkPalette(fallback, [0x000000, 0x808080, 0xFFFFFF]);
        var normal = display(false, false, true);
        FancyDamageNumbers.apply(normal, config);
        checkPalette(normal, [0x012345, 0xABCDEF]);
        for (magic in [false, true]) for (critical in [false, true]) {
            var hit = display(critical, magic);
            FancyDamageNumbers.apply(hit, config);
            checkPalette(hit, critical ? (magic ? [0xEF8DE8, 0xC08DEF, 0x5963C4] : [0xFFCB6D, 0xF04424, 0xFF0000])
                : magic ? [0xBCC2FF, 0x5963C4] : [0xFFCB6D, 0xF04424]);
        }
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
        var tracked:Array<Dynamic> = [];
        for (magic in [false, true])
        for (palette in [[0xFF0000, 0x00FF00, 0x0000FF], [0x000000, 0xFFFFFF, 0x000000], [0xFFFFFF, 0x000000, 0xFFFFFF], [0xEF8DEB, 0xFF0003, 0xA80C2C]]) {
            config.rawCriticalTopColour = StringTools.hex(palette[0], 6);
            config.rawCriticalMiddleColour = StringTools.hex(palette[1], 6);
            config.rawCriticalBottomColour = StringTools.hex(palette[2], 6);
            var hit = display(true, magic, true);
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
        }
        // Clearing the middle input keeps the current top-to-bottom appearance.
        config.rawCriticalTopColour = "ff7f66";
        config.rawCriticalBottomColour = "ff0000";
        config.rawCriticalMiddleColour = "";
        var fallback = display(true, false, true);
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
        var two = display(false, false, true);
        FancyDamageNumbers.apply(two, config);
        eq(filters(two.counter.filter).length, 2, "Normal Raw hits always use one gradient pass");
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
        config.rawCriticalTopColour = config.rawCriticalBottomColour = "F04424";
        config.rawCriticalMiddleColour = "EF8DEB";
        SettingsData.normalize(config);
        for (raw in [false, true]) for (magic in [false, true]) for (runs in [false, true]) for (resolution in [1.0, 2.0]) {
            var hit = display(true, magic, raw);
            var palette = raw ? [0xF04424, 0xEF8DEB, 0xF04424]
                : magic ? [0xEF8DE8, 0xC08DEF, 0x5963C4] : [0xFFCB6D, 0xF04424, 0xFF0000];
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
                var low = fraction < 0.5 ? palette[0] : palette[1];
                var high = fraction < 0.5 ? palette[1] : palette[2];
                var weight = fraction < 0.5 ? fraction * 2 : fraction * 2 - 1;
                for (channel in 0...3) {
                    var shift = (2-channel)*8;
                    var expected = (((low >> shift) & 255) * (1-weight) + ((high >> shift) & 255) * weight) / 255;
                    eq(Math.abs(rgba[channel] - expected) <= 1.01 / 255, true,
                        'All crit palettes reach the visible glyph stops despite blank font space: y=$fraction channel=$channel');
                }
            }
            // New glyph geometry must be used immediately after text/font rebuild.
            hit.counter.elements = [];
            hit.counter.glyphs.content = {yMin: 12.0, yMax: 60.0};
            for (filter in stack) if (filter.kind == "gradient")
                FancyDamageNumbers.syncGradient(filter, null, tile);
            var movedTop = render(stack, (12.0 - tileY) * resolution / tileHeight, 1, 1);
            near(movedTop[2], (palette[0] & 255) / 255.0, "Rebuilt glyphs move the top endpoint without reopening or recolouring the counter");
        }
        FancyDamageNumbers.dispose();
    }

    static function gradientMapping():Dynamic {
        var config = SettingsData.defaults();
        config.fancyDamageNumbers = true;
        var d = display(false);
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
                near(g0 * (1-blend) + g1 * blend, (203 * (1-fraction) + 68 * fraction) / 255,
                    "Rendered physical blend reaches both fixed endpoints with an even transition");
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
