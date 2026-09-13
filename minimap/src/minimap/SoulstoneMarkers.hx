package minimap;

import minimap.GameAccess as G;

/** Identify the interaction that consumes a soulstone, not its summoned foe. */
class SoulstoneMarkers {
    public static function isCircle(inf:Dynamic):Bool {
        var interaction = G.field(G.field(inf, "props"), "interactible");
        var costs = G.field(interaction, "cost");
        if (costs == null) return false;
        var items = G.field(G.current("Data", "item"), "byId");
        if (items == null) return false;
        for (cost in G.array(costs)) {
            var id = G.text(G.field(cost, "item"));
            if (id == "") continue;
            var item = G.call("haxe.ds.StringMap", "get", items, [id]);
            if (G.text(G.field(item, "type")) == "Soulstone") return true;
        }
        return false;
    }
}
