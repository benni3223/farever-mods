package moresettings;

import moresettings.GameAccess as G;
import moresettings.SettingsData.MoreSettingsConfig;

/** Styles native damage counters; all rendering objects stay in the game module. */
class FancyDamageNumbers {
    static var ramp:Dynamic;
    static var rampPixels:Dynamic;
    static var halfMask:Dynamic;
    static var halfPixels:Dynamic;
    static var gradientOwners = new haxe.ds.ObjectMap<Dynamic, {counter:Dynamic, shader:Dynamic}>();

    public static function apply(display:Dynamic, config:MoreSettingsConfig):Void {
        if (!config.fancyDamageNumbers) return;
        var counter = G.field(display, "counter");
        var dom = G.field(counter, "dom");
        if (dom == null) return;

        var nativeColor:Dynamic = G.field(G.field(display, "affinity"), "damageColor");
        if (nativeColor == null) nativeColor = G.field(counter, "textColor");
        var baseColor:Int = nativeColor == null ? 0xFFFFFF : cast nativeColor;

        // Inline styles survive subsequent native affinity/crit CSS refreshes.
        // DamageDisplay.init creates a fresh counter, so toggling affects new hits.
        G.call("domkit.Properties", "initStyle", dom, ["color", 0xFFFFFF]);
        G.call("h2d.Text", "set_textColor", counter, [0xFFFFFF]);

        var damage = G.field(display, "dmg");
        // Raw keeps a white fill and black border, without a gradient.
        if (G.field(damage, "affinity") == "Raw") {
            applyBorder(counter, dom, null);
            G.call("domkit.Properties", "initStyle", dom, ["text-shadow", null]);
            G.set(counter, "dropShadow", null);
            return;
        }

        var critical = G.field(display, "isCrit") == true;
        // Criticals must use their damage affinity too, so each set of colour
        // overrides follows the actual hit rather than the skill or crit flag.
        var magic = false;
        if (damage != null)
            magic = G.call("st.skill.DamageResult", "get_isMagic", damage) == true;

        var criticalPrefix = magic ? "magicalCritical" : "critical";
        var top = critical ? SettingsData.hexColour(Reflect.field(config, criticalPrefix + "LightColour"), config.pinkCrits ? 0xEF8DEB : 0xFF7F66)
            : magic ? 0xBCC2FF : damage != null ? 0xFFCB6D : baseColor;
        var bottom = critical ? SettingsData.hexColour(Reflect.field(config, criticalPrefix + "DarkColour"), config.pinkCrits ? 0xA80C2C : 0xFF0000)
            : magic ? 0x5963C4 : damage != null ? 0xF04424 : shade(baseColor);
        var filter:Dynamic = G.field(counter, "filter");
        if (critical && config.threeColourCriticals) {
            var middle = SettingsData.hexColour(Reflect.field(config, criticalPrefix + "MiddleColour"), midpoint(top, bottom));
            // Encode the original white/black intensity in R and height in G.
            // A second native matrix pass selects a linear segment at half height.
            // This supports arbitrary stops (including black) without dividing by
            // a colour channel, tinting shadows, or allocating textures per hit.
            filter = append(filter, gradient(0xFF00FF, 0xFFFFFF));
            filter = append(filter, matrixGradient(segment(top, middle, false), segment(middle, bottom, true), getHalfMask()));
        } else filter = append(filter, gradient(top, bottom));
        applyBorder(counter, dom, filter);
    }

    static function applyBorder(counter:Dynamic, dom:Dynamic, filter:Dynamic):Void {
        // A single 1 px black outline after tinting keeps the border uncoloured.
        filter = append(filter, outline());
        G.call("domkit.Properties", "initStyle", dom, ["filter", filter]);
        G.call("h2d.Object", "set_filter", counter, [filter]);
    }

    static function outline():Dynamic {
        var filter = G.create("h2d.filter.Outline", [null, null, null, null]);
        G.call("h2d.filter.Outline", "set_size", filter, [1.0]);
        G.call("h2d.filter.Outline", "set_quality", filter, [0.5]);
        G.call("h2d.filter.Outline", "set_color", filter, [0x000000]);
        // Keep native opaque, premultiplied-alpha rendering.
        return filter;
    }

    static function append(existing:Dynamic, next:Dynamic):Dynamic {
        if (existing == null) return next;
        var group = G.create("h2d.filter.Group", [null]);
        G.call("h2d.filter.Group", "add", group, [existing]);
        G.call("h2d.filter.Group", "add", group, [next]);
        return group;
    }

    static function shade(color:Int):Int {
        return (Math.round(((color >> 16) & 255) * 0.55) << 16)
            | (Math.round(((color >> 8) & 255) * 0.55) << 8)
            | Math.round((color & 255) * 0.55);
    }

    static function gradient(top:Int, bottom:Int):Dynamic {
        return matrixGradient(tint(top), tint(bottom), getRamp());
    }

    static function midpoint(top:Int, bottom:Int):Int {
        var result = 0;
        for (shift in [0, 8, 16])
            result |= Math.round((((top >> shift) & 255) + ((bottom >> shift) & 255)) / 2) << shift;
        return result;
    }

    /** Transform intensity * [1, height, 1] into either half of the RGB gradient. */
    static function segment(start:Int, end:Int, lower:Bool):Dynamic {
        var matrix = tint(0);
        for (column in 1...4) {
            var shift = (3 - column) * 8;
            var a = ((start >> shift) & 255) / 255.0;
            var b = ((end >> shift) & 255) / 255.0;
            G.set(matrix, "_1" + column, lower ? 2 * a - b : a);
            G.set(matrix, "_2" + column, 2 * (b - a));
        }
        return matrix;
    }

    static function matrixGradient(first:Dynamic, second:Dynamic, mask:Dynamic):Dynamic {
        // Reuse the game's masked two-matrix screen shader. UVs cover the whole
        // rendered counter, not the unrelated positions of digits in the font atlas.
        var shader = G.create("h3d.pass.ColorMatrixShader", []);
        for (name in ["useAlpha", "useMask", "hasSecondMatrix"])
            G.call("h3d.pass.ColorMatrixShader", "set_" + name, shader, [true]);
        G.call("h3d.pass.ColorMatrixShader", "set_maskInvert", shader, [false]);
        G.call("h3d.pass.ColorMatrixShader", "set_matrix", shader, [first]);
        G.call("h3d.pass.ColorMatrixShader", "set_matrix2", shader, [second]);
        G.call("h3d.pass.ColorMatrixShader", "set_mask", shader, [mask]);
        G.call("h3d.pass.ColorMatrixShader", "set_maskPower", shader, [1.0]);
        vector(G.field(shader, "maskMatA__"), 1, 0, 0);
        vector(G.field(shader, "maskMatB__"), 0, 1, 0);
        var channel = G.field(shader, "maskChannel__");
        vector(channel, 1, 0, 0);
        G.set(channel, "w", 0.0);
        return G.create("h2d.filter.Shader", [shader, "texture"]);
    }

    public static function bindGradient(filter:Dynamic, counter:Dynamic):Void {
        if (ramp == null) return;
        var shader = G.field(G.field(filter, "pass"), "shader");
        if (shader != null && (G.field(shader, "mask__") == ramp || (halfMask != null && G.field(shader, "mask__") == halfMask)))
            gradientOwners.set(filter, {counter: counter, shader: shader});
    }

    public static function unbindGradient(filter:Dynamic):Void {
        gradientOwners.remove(filter);
    }

    /** Map the actual render tile to glyph bounds, excluding border padding. */
    public static function syncGradient(filter:Dynamic, context:Dynamic, input:Dynamic):Void {
        var owner = gradientOwners.get(filter);
        if (owner == null) return;
        // Text and font styles are finalized after DamageDisplay.init. Read the
        // live bounds at draw time, also covering resized text and clipped tiles.
        G.call("h2d.Text", "updateSize", owner.counter);
        var yMin:Float = G.field(owner.counter, "calcYMin");
        var height:Float = G.field(owner.counter, "calcHeight");
        var root = G.field(owner.counter, "filter");
        var scale = number(root, "resolutionScale", 1);
        if (G.field(root, "useScreenResolution") == true)
            scale *= number(G.field(context, "scene"), "viewportScaleY", 1);
        var tileHeight = number(input, "height", 0);
        var tileY = number(input, "dy", 0);
        if (!Math.isFinite(height) || height <= 0 || !Math.isFinite(yMin)
            || !Math.isFinite(scale) || scale <= 0 || tileHeight <= 0) return;
        // Sample texel centers in the 64-row ramp for an even linear blend.
        var span = 63.0 / 64.0;
        vector(G.field(owner.shader, "maskMatB__"), 0,
            span * tileHeight / (scale * height),
            0.5 / 64.0 + span * (tileY - yMin) / height);
    }

    static function number(object:Dynamic, field:String, fallback:Float):Float {
        var value:Dynamic = G.field(object, field);
        return value == null ? fallback : cast value;
    }

    static function vector(value:Dynamic, x:Float, y:Float, z:Float):Void {
        G.set(value, "x", x); G.set(value, "y", y); G.set(value, "z", z);
    }

    static function tint(color:Int):Dynamic {
        var matrix = G.create("h3d.MatrixImpl", []);
        G.call("h3d.MatrixImpl", "zero", matrix);
        // Multiply existing RGB instead of replacing it: native black shadows
        // stay black, transparent pixels stay transparent, and fades retain alpha.
        G.set(matrix, "_11", ((color >> 16) & 255) / 255.0);
        G.set(matrix, "_22", ((color >> 8) & 255) / 255.0);
        G.set(matrix, "_33", (color & 255) / 255.0);
        G.set(matrix, "_44", 1.0);
        return matrix;
    }

    static function getRamp():Dynamic {
        if (ramp != null && G.call("h3d.mat.Texture", "isDisposed", ramp) != true) return ramp;
        dispose();
        var format = G.enumeration("hxd.PixelFormat", "RGBA");
        rampPixels = G.staticCall("hxd.Pixels", "alloc", [1, 64, format]);
        for (y in 0...64) {
            var gray = Math.round(y * 255 / 63);
            G.call("hxd.Pixels", "setPixel", rampPixels, [0, y, 0xFF000000 | (gray << 16) | (gray << 8) | gray]);
        }
        ramp = G.staticCall("h3d.mat.Texture", "fromPixels", [rampPixels, format]);
        G.call("h3d.mat.Texture", "set_filter", ramp, [G.enumeration("h3d.mat.Filter", "Linear")]);
        G.call("h3d.mat.Texture", "set_wrap", ramp, [G.enumeration("h3d.mat.Wrap", "Clamp")]);
        G.call("h3d.mat.Texture", "preventAutoDispose", ramp);
        var texture = ramp, pixels = rampPixels;
        G.set(texture, "realloc", function():Void {
            G.call("h3d.mat.Texture", "uploadPixels", texture, [pixels, null, null]);
        });
        return ramp;
    }

    static function getHalfMask():Dynamic {
        if (halfMask != null && G.call("h3d.mat.Texture", "isDisposed", halfMask) != true) return halfMask;
        if (halfMask != null) G.set(halfMask, "realloc", null);
        if (halfPixels != null) G.call("hxd.Pixels", "dispose", halfPixels);
        // Same texel-center mapping as the linear ramp, with an exact split at
        // 50%. Nearest avoids blending the two line equations near the middle.
        var format = G.enumeration("hxd.PixelFormat", "RGBA");
        halfPixels = G.staticCall("hxd.Pixels", "alloc", [1, 64, format]);
        for (y in 0...64)
            G.call("hxd.Pixels", "setPixel", halfPixels, [0, y, y < 32 ? 0xFF000000 : 0xFFFFFFFF]);
        halfMask = G.staticCall("h3d.mat.Texture", "fromPixels", [halfPixels, format]);
        G.call("h3d.mat.Texture", "set_filter", halfMask, [G.enumeration("h3d.mat.Filter", "Nearest")]);
        G.call("h3d.mat.Texture", "set_wrap", halfMask, [G.enumeration("h3d.mat.Wrap", "Clamp")]);
        G.call("h3d.mat.Texture", "preventAutoDispose", halfMask);
        var texture = halfMask, pixels = halfPixels;
        G.set(texture, "realloc", function():Void {
            G.call("h3d.mat.Texture", "uploadPixels", texture, [pixels, null, null]);
        });
        return halfMask;
    }

    public static function dispose():Void {
        gradientOwners.clear();
        if (halfMask != null) {
            G.set(halfMask, "realloc", null);
            G.call("h3d.mat.Texture", "dispose", halfMask);
            halfMask = null;
        }
        if (halfPixels != null) {
            G.call("hxd.Pixels", "dispose", halfPixels);
            halfPixels = null;
        }
        if (ramp != null) {
            G.set(ramp, "realloc", null);
            G.call("h3d.mat.Texture", "dispose", ramp);
            ramp = null;
        }
        if (rampPixels != null) {
            G.call("hxd.Pixels", "dispose", rampPixels);
            rampPixels = null;
        }
    }
}
