package moresettings;

import moresettings.GameAccess as G;
import moresettings.SettingsData.MoreSettingsConfig;

/** Styles native damage counters; all rendering objects stay in the game module. */
class FancyDamageNumbers {
    static var ramp:Dynamic;
    static var rampPixels:Dynamic;

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
        // Raw is always plain white, even for critical hits or magic-tagged skills.
        if (G.field(damage, "affinity") == "Raw") {
            G.call("domkit.Properties", "initStyle", dom, ["filter", null]);
            G.call("h2d.Object", "set_filter", counter, [null]);
            G.call("domkit.Properties", "initStyle", dom, ["text-shadow", null]);
            G.set(counter, "dropShadow", null);
            return;
        }

        var critical = G.field(display, "isCrit") == true;
        // Physical and magic criticals keep their pink identity.
        var magic = false;
        if (!critical && damage != null)
            magic = G.call("st.skill.DamageResult", "get_isMagic", damage) == true;

        var magicTop = config.blueMagic ? 0x5963C4 : 0xF04424;
        var magicBottom = config.blueMagic ? 0x9FA8FF : 0xFFB52E;
        var orangePhysical = config.orangePhysical && damage != null;
        var physicalTop = orangePhysical ? (config.lightOrangePhysical ? 0xF18745 : 0xF04424) : shade(baseColor);
        var physicalBottom = orangePhysical ? (config.lightOrangePhysical ? 0xFEAC74 : 0xFFB52E) : baseColor;
        var top = critical ? 0xA80C2C : magic ? magicTop : physicalTop;
        var bottom = critical ? 0xEF8DEB : magic ? magicBottom : physicalBottom;
        if (config.flipGradient) {
            var originalTop = top;
            top = bottom;
            bottom = originalTop;
        }
        var filter:Dynamic = G.field(counter, "filter");
        filter = append(filter, gradient(top, bottom));
        // Outline after tinting to keep both borders free of the gradient.
        // The black pass surrounds the white pass, forming the outer layer.
        if (config.fancyBorder) filter = append(filter, outline(0xFFFFFF, config.borderThickness));
        filter = append(filter, outline(0x000000, config.borderThickness));
        G.call("domkit.Properties", "initStyle", dom, ["filter", filter]);
        G.call("h2d.Object", "set_filter", counter, [filter]);
    }

    static function outline(color:Int, thickness:Float):Dynamic {
        var filter = G.create("h2d.filter.Outline", [null, null, null, null]);
        G.call("h2d.filter.Outline", "set_size", filter, [thickness]);
        G.call("h2d.filter.Outline", "set_quality", filter, [0.5]);
        G.call("h2d.filter.Outline", "set_color", filter, [color]);
        // Keep native opaque, premultiplied-alpha rendering for both layers.
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
        // Reuse the game's masked two-matrix screen shader. UVs cover the whole
        // rendered counter, not the unrelated positions of digits in the font atlas.
        var shader = G.create("h3d.pass.ColorMatrixShader", []);
        for (name in ["useAlpha", "useMask", "hasSecondMatrix"])
            G.call("h3d.pass.ColorMatrixShader", "set_" + name, shader, [true]);
        G.call("h3d.pass.ColorMatrixShader", "set_maskInvert", shader, [false]);
        G.call("h3d.pass.ColorMatrixShader", "set_matrix", shader, [tint(top)]);
        G.call("h3d.pass.ColorMatrixShader", "set_matrix2", shader, [tint(bottom)]);
        G.call("h3d.pass.ColorMatrixShader", "set_mask", shader, [getRamp()]);
        G.call("h3d.pass.ColorMatrixShader", "set_maskPower", shader, [1.0]);
        vector(G.field(shader, "maskMatA__"), 1, 0, 0);
        vector(G.field(shader, "maskMatB__"), 0, 1, 0);
        var channel = G.field(shader, "maskChannel__");
        vector(channel, 1, 0, 0);
        G.set(channel, "w", 0.0);
        return G.create("h2d.filter.Shader", [shader, "texture"]);
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

    public static function dispose():Void {
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
