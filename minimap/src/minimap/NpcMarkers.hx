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
        var npc = G.field(props, "npc");
        var unit = G.text(G.field(npc, "unit"));
        // The PTR adds this distinct UnitKind alongside TODO_WanderingMerchant.
        // Match the resolved instance's unit, as Npc.get_uinf does: its shop
        // prices and localized service title need not be present here.
        if (unit == "TODO_MOG_Merchant") return "glory";
        var texts = G.field(inf, "texts");
        // Some world NPCs expose their service in npcTitle / the popup's
        // texts.type without exposing Glory-priced offers in props.shop.
        // Only match the complete service label; personal names, templates,
        // dialogue and incidental mentions of glory are not a role.
        if (gloryTitle(G.field(npc, "npcTitle")) || gloryTitle(G.field(texts, "type"))) return "glory";
        // Element.getShopItems copies props.shop[].cost[].kind as the price
        // currency. Match the currency, not an NPC's translated name, model,
        // or the items it sells. shopList entries use the ordinary gold price.
        for (offer in G.array(G.field(props, "shop")))
            for (cost in G.array(G.field(offer, "cost")))
                if (G.text(G.field(cost, "kind")) == "BadgeOfGlory") return "glory";

        // Match Npc.get_uinf: the resolved instance's unit is authoritative.
        // Ancestor templates and inherited dialogue do not identify its role.
        return switch unit {
            case "TODO_WanderingMerchant": "bank";
            case "DemonHunterMira", "DemonHunterZoey", "DemonHunterRumi": "demon";
            default: "npc";
        };
    }

    static function gloryTitle(value:Dynamic):Bool
        return StringTools.trim(G.text(value)).toLowerCase() == "glory merchant";
}
