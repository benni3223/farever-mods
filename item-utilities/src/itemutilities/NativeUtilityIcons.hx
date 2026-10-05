package itemutilities;

import itemutilities.InspectAccess as G;

/** The existing utility artwork, retained in the owning native UI subtree. */
class NativeUtilityIcons {
    static inline var MARK = 0xF0E3D4;

    public static function draw(g:Dynamic, kind:String):Void {
        switch kind {
            case "badge":
                line(g, 0xB8C2D1, 2, [5,8, 5,5, 7,2, 10,2, 12,5, 12,8]);
                rect(g, 0xB8C2D1, 3,7,11,9,2);
                circle(g, 0x333842, 8.5,11,1.25);
                line(g, 0x333842, 1.5, [8.5,11, 8.5,14]);
            case "lock":
                line(g, MARK, 2, [11,13, 11,10, 14,6, 19,6, 21,10, 21,13]);
                G.call("h2d.Graphics", "lineStyle", g, [2., MARK, 1.]);
                G.call("h2d.Graphics", "drawRoundedRect", g, [9.,13.,14.,11.,2.,8]);
                G.call("h2d.Graphics", "lineStyle", g, [0.,0,0.]);
            case "materials":
                rect(g, 0xA16B3D, 9,9,4,10,1);
                rect(g, 0xC7D1DB, 3,5,9,6,1);
                fill(g, 0x8594A3, [12,6, 18,7, 18,9, 12,10]);
            case "food":
                circle(g, 0xDB6B4D, 11,12,5.5);
                line(g, 0x8CC261, 1.5, [11,7, 13,4]);
                line(g, 0x8CC261, 2, [13,5, 17,6]);
            case "consumable":
                line(g, 0x8CBAEB, 2, [9,5, 14,5]);
                line(g, 0x8CBAEB, 2, [10,6, 10,10]);
                line(g, 0x8CBAEB, 2, [13,6, 13,10]);
                fill(g, 0x8CBAEB, [10,9, 5,18, 16,18]);
            case "demon":
                fill(g, 0xC26EDB, [11,7, 16,12, 11,18, 6,12]);
                line(g, 0xC26EDB, 2, [7,10, 4,5]);
                line(g, 0xC26EDB, 2, [15,10, 18,5]);
            case "misc":
                circle(g, 0xC4AD87, 7,8,2.5);
                rect(g, 0xC4AD87, 11,6,5,5,1);
                fill(g, 0xC4AD87, [4,18, 8,12, 12,18]);
            case "all":
                line(g, 0xE8B363, 2.5, [11,4, 11,18]);
                line(g, 0xE8B363, 2.5, [4,11, 17,11]);
                line(g, 0xE8B363, 1.5, [7,7, 15,15]);
                line(g, 0xE8B363, 1.5, [15,7, 7,15]);
        }
        if (kind != "badge" && kind != "lock") {
            line(g, MARK, 2, [23,6, 23,16]);
            fill(g, MARK, [19,14, 27,14, 23,19]);
            line(g, MARK, 2, [18,19, 18,23, 28,23, 28,19]);
        }
        G.call("h2d.Graphics", "flush", g);
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
        G.call("h2d.Graphics", "drawRoundedRect", g, [x,y,w,h,radius,8]);
        G.call("h2d.Graphics", "endFill", g);
    }
    static function circle(g:Dynamic, color:Int, x:Float, y:Float, r:Float):Void {
        G.call("h2d.Graphics", "beginFill", g, [color,1.]);
        G.call("h2d.Graphics", "drawCircle", g, [x,y,r,24]);
        G.call("h2d.Graphics", "endFill", g);
    }
}
