package minimap;

import minimap.GameAccess as G;

/** Service roles from resolved world definitions, shared by static and live markers. */
class NpcMarkers {
    public static function stationKind(type:Int):String return switch type {
        // Data.Element_type; InfusionStation is appended in the new client.
        // Older clients never produce type 33; no optional native type is resolved.
        case 23: "craft";
        case 24: "upgrade";
        case 31: "recycler";
        case 33: "infusion";
        default: "";
    };

    public static function isNpc(kind:String):Bool return switch kind {
        case "npc", "bank", "demon", "craft", "upgrade", "recycler", "glory", "infusion": true;
        default: false;
    };

    public static function kind(inf:Dynamic):String {
        var station = stationKind(G.integer(G.field(inf, "type")));
        if (station != "") return station;
        var props = G.field(inf, "props");
        // Element.getShopItems copies props.shop[].cost[].kind as the price
        // currency. Match the currency, not an NPC's translated name, model,
        // or the items it sells. shopList entries use the ordinary gold price.
        for (offer in G.array(G.field(props, "shop")))
            for (cost in G.array(G.field(offer, "cost")))
                if (G.text(G.field(cost, "kind")) == "BadgeOfGlory") return "glory";

        // Match Npc.get_uinf: the resolved instance's unit is authoritative.
        // Ancestor templates and inherited dialogue do not identify its role.
        return switch G.text(G.field(G.field(props, "npc"), "unit")) {
            case "TODO_WanderingMerchant": "bank";
            case "DemonHunterMira", "DemonHunterZoey", "DemonHunterRumi": "demon";
            default: "npc";
        };
    }
}
