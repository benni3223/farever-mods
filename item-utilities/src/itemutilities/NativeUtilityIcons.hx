package itemutilities;

import itemutilities.InspectAccess as G;

/** Small, flat utility symbols drawn inside their owning native window. */
class NativeUtilityIcons {
    static inline var MARK = 0xF0E3D4;

    public static function smooth(object:Dynamic):Void {
        // Use the same bounded supersampling as BMS help icons. One filter
        // covers the button and symbol together; no full-window render target.
        var filter = G.create("h2d.filter.Nothing", []);
        G.set(filter, "smooth", true);
        G.set(filter, "boundsExtend", 1.0);
        G.call("h2d.filter.Filter", "set_useScreenResolution", filter, [true]);
        G.call("h2d.filter.Filter", "set_resolutionScale", filter, [4.0]);
        G.call("h2d.Object", "set_filter", object, [filter]);
    }

    public static function background(g:Dynamic, w:Float, h:Float):Void {
        G.call("h2d.Graphics", "clear", g);
        // A one-pixel coverage ramp avoids hard stair-steps on the corners
        // even at fractional UI scales; the drawable's tint supplies its color.
        var previous = 0.0;
        for (step in 1...9) {
            var coverage = step / 8.0;
            var inset = -0.5 + (step - 0.5) / 8.0;
            G.call("h2d.Graphics", "beginFill", g, [0xFFFFFF, (coverage - previous) / (1 - previous)]);
            G.call("h2d.Graphics", "drawRoundedRect", g, [inset,inset,w-2*inset,h-2*inset,6-inset,16]);
            G.call("h2d.Graphics", "endFill", g);
            previous = coverage;
        }
    }

    public static function draw(g:Dynamic, kind:String):Void {
        switch kind {
            case "badge":
                line(g, 0xB8C2D1, 2, [5,8, 5,5, 7,2, 10,2, 12,5, 12,8]);
                rect(g, 0xB8C2D1, 3,7,11,9,2);
                circle(g, 0x333842, 8.5,11,1.25);
                line(g, 0x333842, 1.5, [8.5,11, 8.5,14]);
            case "lock":
                var shackle:Array<Float> = [11.5,14, 11.5,10];
                arc(shackle,16,10,4.5,Math.PI,Math.PI*2);
                shackle.push(20.5); shackle.push(14);
                line(g, MARK, 1.8, shackle);
                outline(g, MARK, 1.8, 8.5,13,15,11,2.5);
                circle(g, MARK, 16,17.7,1.25);
                rect(g, MARK, 15.5,18,1,3,0.45);
            case "materials":
                // Steel hammer with a wood grip and a narrower peen.
                rect(g, 0x513B29, 9,9,4.5,12,1.2);
                rect(g, 0xBD8A51, 9.8,9,2.8,11,0.8);
                line(g, 0xE2B778, 0.8, [10.4,12, 10.4,18.5]);
                fill(g, 0x8EABBE, [12,6, 17,7, 17,9, 12,11]);
                rect(g, 0xD3E0E5, 3.5,5.5,9.5,6.5,1.3);
                rect(g, 0x8DA5B3, 3.5,9.5,9.5,2.5,0.8);
                line(g, 0xF0F1E9, 1, [5,6.5, 11.5,6.5]);
            case "food":
                // Lobed apple, leaf and a small highlight.
                fill(g, 0xCC4939, [10.5,9, 7,8, 4.5,9.5, 3.5,12.5,
                    4.8,17, 7.5,20, 10.5,19, 13,19.7, 16,16.5, 17,12,
                    15.5,9, 13,8.3]);
                circle(g, 0xE86C4C, 7.5,12.5,3);
                fill(g, 0x92C86C, [10.5,7.7, 12,4.5, 16,4, 15,6.5, 12,8]);
                line(g, 0x664830, 1.3, [10.5,9.2, 10,6]);
                line(g, 0xFFC18D, 1, [5.5,11.5, 5,13, 5.5,14.5]);
            case "consumable":
                // Corked glass flask with visible blue liquid.
                fill(g, 0xCEE8EF, [8,6, 13,6, 13,10, 17,16,
                    17,18, 15,20, 6,20, 4,18, 4,16, 8,10]);
                fill(g, 0x4E9BCC, [8,13, 13,13, 15.5,16.5, 15.5,18,
                    14.5,18.5, 6.5,18.5, 5.5,17.5, 5.5,16.5]);
                line(g, 0x86D6EF, 1, [7.5,14, 13.3,14]);
                line(g, 0xF0FAF4, 1, [8,10.5, 6,14]);
                rect(g, 0xBE915F, 8,4,5,3,0.7);
                line(g, 0xE4BD87, 0.8, [9,4.8, 12,4.8]);
            case "demon":
                // Faceted purple enchantment crystal with curved ivory horns.
                fill(g, 0xB46AE2, [10.5,7, 16,12, 10.5,21, 5,12]);
                fill(g, 0xE7B5FA, [10.5,7, 10.5,13, 5,12]);
                fill(g, 0x8B4DB5, [10.5,13, 16,12, 10.5,21]);
                fill(g, 0xD4C2D8, [6,11, 3.5,9, 3,5, 5,7.5, 8,8.8]);
                fill(g, 0xD4C2D8, [15,11, 17.5,9, 18,5, 16,7.5, 13,8.8]);
                line(g, 0xF3D4FE, 0.8, [10.5,8.5, 13,11]);
            case "misc":
                // Drawstring pouch for miscellaneous belongings.
                fill(g, 0xB78B59, [7,8, 5,5, 9,5.8, 13,5, 15,5.8,
                    12.5,9, 16,13.5, 17,17, 15,20, 6,20, 3.5,17,
                    4.5,13.5]);
                fill(g, 0xD5AD72, [7,10, 10,11, 8,17.5, 6,18, 5.5,16]);
                line(g, 0x62462F, 1.5, [6.8,9, 13.2,9]);
                line(g, 0xE9D3A2, 1, [12,9, 14.8,11.5, 14,13]);
            case "all":
                // A stack of parcels reads as everything, rather than a spark.
                rect(g, 0x8F673F, 3,12,8,8,0.8);
                rect(g, 0xCAA36B, 3,12,8,2.5,0.5);
                rect(g, 0xE2C796, 6.1,12,1.6,8,0);
                rect(g, 0xB8884F, 10.5,10,7,10,0.8);
                rect(g, 0xDFB97C, 10.5,10,7,2.5,0.5);
                rect(g, 0xF1D7A3, 13.3,10,1.4,10,0);
                rect(g, 0xD0A76C, 5.5,4.5,9,6,0.8);
                rect(g, 0xF1D7A3, 9.2,4.5,1.6,6,0);
        }
        if (kind != "badge" && kind != "lock") {
            rect(g, MARK, 23,7,2,9.5,0.8);
            fill(g, MARK, [19.7,14, 28.3,14, 24,19]);
            line(g, MARK, 1.8, [19,19.5, 19,22, 19.5,22.5,
                28.5,22.5, 29,22, 29,19.5]);
        }
        G.call("h2d.Graphics", "flush", g);
    }

    static function arc(points:Array<Float>, cx:Float, cy:Float, r:Float, from:Float, to:Float):Void {
        for (i in 0...13) {
            var angle = from + (to - from) * i / 12;
            points.push(cx + Math.cos(angle) * r);
            points.push(cy + Math.sin(angle) * r);
        }
    }
    static function outline(g:Dynamic, color:Int, width:Float, x:Float, y:Float, w:Float, h:Float, r:Float):Void {
        var points:Array<Float> = [];
        arc(points,x+w-r,y+r,r,-Math.PI/2,0);
        arc(points,x+w-r,y+h-r,r,0,Math.PI/2);
        arc(points,x+r,y+h-r,r,Math.PI/2,Math.PI);
        arc(points,x+r,y+r,r,Math.PI,Math.PI*1.5);
        points.push(points[0]); points.push(points[1]);
        line(g,color,width,points);
    }
    static function line(g:Dynamic, color:Int, width:Float, points:Array<Float>):Void {
        G.call("h2d.Graphics", "lineStyle", g, [width,color,1.]);
        path(g, points);
        G.call("h2d.Graphics", "lineStyle", g, [0.,0,0.]);
    }
    static function fill(g:Dynamic, color:Int, points:Array<Float>):Void {
        G.call("h2d.Graphics", "beginFill", g, [color,1.]);
        path(g, points);
        G.call("h2d.Graphics", "endFill", g);
    }
    static function path(g:Dynamic, points:Array<Float>):Void {
        for (i in 0...Std.int(points.length / 2))
            G.call("h2d.Graphics", i == 0 ? "moveTo" : "lineTo", g, [points[i * 2],points[i * 2 + 1]]);
    }
    static function rect(g:Dynamic, color:Int, x:Float, y:Float, w:Float, h:Float, radius:Float):Void {
        G.call("h2d.Graphics", "beginFill", g, [color,1.]);
        G.call("h2d.Graphics", "drawRoundedRect", g, [x,y,w,h,radius,16]);
        G.call("h2d.Graphics", "endFill", g);
    }
    static function circle(g:Dynamic, color:Int, x:Float, y:Float, r:Float):Void {
        G.call("h2d.Graphics", "beginFill", g, [color,1.]);
        G.call("h2d.Graphics", "drawCircle", g, [x,y,r,48]);
        G.call("h2d.Graphics", "endFill", g);
    }
}
