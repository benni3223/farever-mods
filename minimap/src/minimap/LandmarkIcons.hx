package minimap;

import minimap.GameAccess as G;

/** Local pixel geometry, retained by the marker pool across refreshes. */
class LandmarkIcons {
    public static function draw(graphics:Dynamic, kind:String, radius:Float):Void {
        if (kind == "obelisk") obelisk(graphics, radius);
        else if (kind == "dungeon") dungeon(graphics, radius);
        else if (kind == "soulstone") soulstone(graphics, radius);
        else if (kind == "secretOrb") secretOrb(graphics, radius);
        else if (kind == "targetDummy") targetDummy(graphics, radius);
        else if (kind == "riftPortal") riftPortal(graphics, radius);
        else if (kind == "upcomingRift") upcomingRift(graphics, radius);
    }

    static function riftPortal(g:Dynamic, r:Float):Void {
        // A jagged pink tear with a dark interior, like the open world portal.
        var tear = [-0.92, 0.71, -0.35, 0.14, -0.32, -0.36, -0.04, -0.67,
            0.2, -1., 0.27, -0.45, 0.78, -0.87, 0.54, -0.24,
            0.84, -0.12, 0.43, 0.12, 0.54, 0.8, 0.12, 0.64, -0.3, 0.82];
        fill(g, 0x32132e);
        polygon(g, r + 1, tear);
        end(g);
        fill(g, 0xf52e9c);
        polygon(g, r, tear);
        end(g);
        fill(g, 0xffa5df);
        polygon(g, r * 0.82, tear);
        end(g);
        fill(g, 0x25132b);
        polygon(g, r * 0.66, tear);
        end(g);
        fill(g, 0xffb5e5);
        polygon(g, r, [-0.74, -0.4, -0.58, -0.54, -0.52, -0.27]);
        polygon(g, r, [0.7, 0.36, 0.94, 0.48, 0.73, 0.61]);
        end(g);
    }

    static function upcomingRift(g:Dynamic, r:Float):Void {
        // Three red horned faces: a compact group of demons at minimap scale.
        demonHead(g, r, -0.53, -0.12, 0.43);
        demonHead(g, r, 0.53, -0.12, 0.43);
        demonHead(g, r, 0, 0.36, 0.53);
    }

    static function demonHead(g:Dynamic, r:Float, x:Float, y:Float, size:Float):Void {
        var face = [-0.72, -0.14, -0.94, -0.96, -0.28, -0.52, 0.28, -0.52,
            0.94, -0.96, 0.72, -0.14, 0.63, 0.5, 0, 0.86, -0.63, 0.5];
        for (pass in 0...2) {
            var s = size + (pass == 0 ? 0.1 : 0);
            var vertices:Array<Float> = [];
            for (i in 0...Std.int(face.length / 2)) {
                vertices.push(x + face[i * 2] * s);
                vertices.push(y + face[i * 2 + 1] * s);
            }
            fill(g, pass == 0 ? 0x321b20 : 0xef5350);
            polygon(g, r, vertices);
            end(g);
        }
        fill(g, 0xffefb3);
        for (side in [-1, 1])
            polygon(g, r, [x + side * size * 0.16, y + size * 0.11,
                x + side * size * 0.55, y - size * 0.12, x + side * size * 0.49, y + size * 0.24]);
        end(g);
    }

    static function targetDummy(g:Dynamic, r:Float):Void {
        // Flat sack head and padded torso on a wooden cross, with a red target.
        fill(g, 0x38291f);
        dummyShape(g, r + 1);
        end(g);
        fill(g, 0x96704b);
        dummyShape(g, r);
        end(g);
        fill(g, 0xd5ac76);
        circle(g, 0, -0.7 * r, 0.26 * r);
        polygon(g, r, [-0.52, -0.36, 0.52, -0.36, 0.57, 0.18, 0.38, 0.52,
            -0.38, 0.52, -0.57, 0.18]);
        for (side in [-1, 1])
            polygon(g, r, [0.61, -0.3, 0.83, -0.3, 0.83, 0.11, 0.61, 0.11], side);
        end(g);
        fill(g, 0xb82e34);
        circle(g, 0, 0.07 * r, 0.34 * r);
        end(g);
        fill(g, 0xe4bc87);
        circle(g, 0, 0.07 * r, 0.23 * r);
        end(g);
        fill(g, 0xb82e34);
        circle(g, 0, 0.07 * r, 0.12 * r);
        end(g);
    }

    static function dummyShape(g:Dynamic, r:Float):Void {
        circle(g, 0, -0.7 * r, 0.3 * r);
        polygon(g, r, [-1, -0.23, 1, -0.23, 1, 0.06, -1, 0.06]);
        polygon(g, r, [-0.16, -0.5, 0.16, -0.5, 0.16, 1, -0.16, 1]);
        polygon(g, r, [-0.57, -0.4, 0.57, -0.4, 0.62, 0.18, 0.42, 0.56,
            -0.42, 0.56, -0.62, 0.18]);
        for (side in [-1, 1])
            polygon(g, r, [0.58, -0.34, 0.87, -0.34, 0.87, 0.15, 0.58, 0.15], side);
    }

    static function secretOrb(g:Dynamic, r:Float):Void {
        // The in-world orb has a warm gold centre and broken lavender orbits.
        // Flat bands and solid colours keep that silhouette readable at 16 px.
        for (i in 0...3) {
            var angle = -2.9 + i * Math.PI * 2 / 3;
            fill(g, 0x35283e);
            arc(g, r + 0.7, 2.5, angle - 0.05, 1.52);
            end(g);
            fill(g, 0xc594ec);
            arc(g, r, 1.25, angle, 1.42);
            end(g);
            fill(g, 0x9b6fc6);
            arc(g, r * 0.77, 0.8, angle + 0.55, 0.92);
            end(g);
        }
        fill(g, 0x655132);
        circle(g, 0, 0, r * 0.57);
        end(g);
        fill(g, 0xf2be4f);
        circle(g, 0, 0, r * 0.49);
        polygon(g, r, [-0.13, -0.65, 0.13, -0.65, 0.1, -0.39, -0.1, -0.39]);
        for (side in [-1, 1])
            polygon(g, r, [0.39, -0.1, 0.66, -0.14, 0.66, 0.14, 0.39, 0.1], side);
        polygon(g, r, [-0.1, 0.39, 0.1, 0.39, 0.13, 0.65, -0.13, 0.65]);
        end(g);
        fill(g, 0xffe778);
        circle(g, 0, 0, r * 0.35);
        end(g);
        fill(g, 0xfff8c8);
        circle(g, -r * 0.06, -r * 0.06, r * 0.22);
        end(g);
    }

    static function arc(g:Dynamic, radius:Float, width:Float, angle:Float, sweep:Float):Void {
        // Separate convex quads avoid a concave ring polygon's triangulation.
        var inner = radius - width;
        for (i in 0...10) {
            var a = angle + sweep * i / 10, b = angle + sweep * (i + 1) / 10;
            polygon(g, 1, [Math.cos(a) * radius, Math.sin(a) * radius, Math.cos(b) * radius, Math.sin(b) * radius,
                Math.cos(b) * inner, Math.sin(b) * inner, Math.cos(a) * inner, Math.sin(a) * inner]);
        }
    }

    static function soulstone(g:Dynamic, r:Float):Void {
        // A runic summoning ring around a faceted soulstone, distinct from portals.
        fill(g, 0x251c32);
        circle(g, 0, 0, r + 1);
        end(g);
        fill(g, 0xc5a0e6);
        circle(g, 0, 0, r);
        end(g);
        fill(g, 0x473458);
        circle(g, 0, 0, r * 0.73);
        end(g);
        fill(g, 0xeee0ff);
        polygon(g, r, [-0.12, -1, 0.12, -1, 0.12, -0.64, -0.12, -0.64]);
        for (side in [-1, 1])
            polygon(g, r, [0.64, -0.12, 1, -0.12, 1, 0.12, 0.64, 0.12], side);
        polygon(g, r, [-0.12, 0.64, 0.12, 0.64, 0.12, 1, -0.12, 1]);
        end(g);
        fill(g, 0x211829);
        polygon(g, r, [0, -0.67, 0.43, -0.12, 0.32, 0.43, 0, 0.65, -0.32, 0.43, -0.43, -0.12]);
        end(g);
        fill(g, 0xf28fc8);
        polygon(g, r, [0, -0.52, 0.3, -0.1, 0.22, 0.33, 0, 0.49, -0.22, 0.33, -0.3, -0.1]);
        end(g);
        fill(g, 0xa74596);
        polygon(g, r, [0, -0.52, 0.3, -0.1, 0.22, 0.33, 0, 0.49]);
        end(g);
        fill(g, 0xffdbf0);
        polygon(g, r, [0, -0.52, 0, 0.12, -0.3, -0.1]);
        end(g);
    }

    static function obelisk(g:Dynamic, r:Float):Void {
        fill(g, 0x282828);
        obeliskShape(g, r + 1);
        end(g);
        fill(g, 0x999999);
        obeliskShape(g, r);
        end(g);

        // The idol's gold spine and four round inlays below its split crown.
        fill(g, 0xd8aa50);
        polygon(g, r, [-0.16, -0.35, 0.16, -0.35, 0.16, 0.9, -0.16, 0.9]);
        for (side in [-1, 1]) {
            circle(g, side * 0.74 * r, -0.65 * r, 0.145 * r);
            circle(g, side * 0.42 * r, -0.54 * r, 0.145 * r);
        }
        end(g);
        // Keep the split crown's center entirely gold, like the spine below.
        fill(g, 0xe2b85f);
        polygon(g, r, [-0.065, -0.94, 0.065, -0.94, 0.1, -0.24, -0.1, -0.24]);
        end(g);
        // A broad stone foot gives the thicker column a substantial base.
        fill(g, 0x636363);
        polygon(g, r, [-0.62, 0.78, 0.62, 0.78, 0.62, 1, -0.62, 1]);
        end(g);

        // Broader hands and shoulders remain legible at the default icon size.
        fill(g, 0x555555);
        polygon(g, r, [-0.72, -0.14, 0.72, -0.14, 0.61, 0.21, -0.61, 0.21]);
        end(g);
        fill(g, 0xbfbfbf);
        polygon(g, r, [-0.68, -0.14, 0.68, -0.14, 0.61, 0.02, -0.61, 0.02]);
        end(g);
    }

    static function obeliskShape(g:Dynamic, r:Float):Void {
        polygon(g, r, [-0.58, -0.35, 0.58, -0.35, 0.62, 1, -0.62, 1]);
        // Separate convex pieces preserve the open split when triangulated.
        for (side in [-1, 1])
            polygon(g, r, [-1, -0.83, -0.24, -1, -0.19, -0.8,
                -0.25, -0.22, -0.84, -0.22, -1, -0.43], side);
    }

    static function dungeon(g:Dynamic, r:Float):Void {
        fill(g, 0x201b2e);
        doorway(g, r + 1);
        end(g);
        fill(g, 0xc2bdad);
        doorway(g, r);
        end(g);
        // An inset opening leaves a thick stone arch and two door posts.
        fill(g, 0x38315f);
        polygon(g, r, [-0.51, 0.78, -0.51, -0.31, -0.32, -0.6,
            0, -0.73, 0.32, -0.6, 0.51, -0.31, 0.51, 0.78]);
        end(g);
        fill(g, 0x8559df);
        polygon(g, r, [-0.37, 0.73, -0.42, -0.2, -0.24, -0.48,
            0.04, -0.59, 0.35, -0.25, 0.38, 0.73]);
        end(g);
        // A curved cyan ribbon reads as a portal at the default 16 px size.
        fill(g, 0x55dfff);
        polygon(g, r, [0.08, -0.5, 0.28, -0.25, 0.29, 0.16, 0.08, 0.08]);
        polygon(g, r, [0.29, 0.16, 0.12, 0.44, -0.05, 0.27, 0.08, 0.08]);
        polygon(g, r, [-0.05, 0.27, 0.12, 0.44, -0.14, 0.65, -0.31, 0.49]);
        end(g);
        fill(g, 0xe0fcff);
        circle(g, 0.12 * r, -0.13 * r, 0.09 * r);
        end(g);
        fill(g, 0x777b86);
        polygon(g, r, [-0.8, 0.79, 0.8, 0.79, 0.8, 0.97, -0.8, 0.97]);
        end(g);
    }

    static function doorway(g:Dynamic, r:Float):Void {
        polygon(g, r, [-0.8, 1, -0.8, -0.38, -0.5, -0.82, 0, -1,
            0.5, -0.82, 0.8, -0.38, 0.8, 1]);
    }

    static function fill(g:Dynamic, color:Int):Void
        G.call("h2d.Graphics", "beginFill", g, [color, 1.0]);

    static function end(g:Dynamic):Void
        G.call("h2d.Graphics", "endFill", g);

    static function circle(g:Dynamic, x:Float, y:Float, r:Float):Void
        G.call("h2d.Graphics", "drawCircle", g, [x, y, r, 16]);

    static function polygon(g:Dynamic, r:Float, vertices:Array<Float>, side:Int = 1):Void {
        var count = Std.int(vertices.length / 2);
        for (i in 0...count + 1) {
            // Reverse mirrored vertices to retain the same winding.
            var j = (side < 0 ? (count - i) % count : i % count) * 2;
            G.call("h2d.Graphics", i == 0 ? "moveTo" : "lineTo", g, [side * vertices[j] * r, vertices[j + 1] * r]);
        }
    }
}
