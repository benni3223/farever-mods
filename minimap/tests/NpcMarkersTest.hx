import minimap.NpcMarkers;

class NpcMarkersTest {
    static var checks = 0;

    static function expect(actual:Dynamic, expected:Dynamic, message:String):Void {
        checks++;
        if (actual != expected) throw message + ': expected $expected, got $actual';
    }

    static function main():Void {
        // Current-client definitions have no InfusionStation or Glory currency.
        expect(NpcMarkers.kind(null), "npc", "Missing definition");
        expect(NpcMarkers.kind({type: 22, props: {}}), "npc", "Ordinary NPC");
        expect(NpcMarkers.kind({type: 22, props: {npc: {unit: "TODO_WanderingMerchant"}}}), "bank", "Guild merchant");
        expect(NpcMarkers.kind({id: "World_NPC_17", type: 22, props: {npc: {unit: "TODO_MOG_Merchant"}}}),
            "glory", "PTR Glory merchant is identified without shop or title fields");
        expect(NpcMarkers.kind({type: 22, props: {npc: {unit: "TODO_MOG_Merchant", npcTitle: "localized service"}},
            texts: {name: "localized name", type: "localized type"}}), "glory", "Native identity is language-independent");
        expect(NpcMarkers.kind({type: 22, inherit: "TODO_MOG_Merchant", props: {npc: {unit: "Other"}}}),
            "npc", "Borrowing an ancestor does not turn an unrelated NPC into a Glory merchant");
        for (unit in ["DemonHunterMira", "DemonHunterZoey", "DemonHunterRumi"])
            expect(NpcMarkers.kind({type: 22, props: {npc: {unit: unit}}}), "demon", "Demon huntress " + unit);
        expect(NpcMarkers.kind({type: 22, inherit: "DemonHunterMira", props: {npc: {unit: "Other"}}}),
            "npc", "Unrelated NPC borrowing a template");
        expect(NpcMarkers.kind({type: 23}), "craft", "Craft station");
        expect(NpcMarkers.kind({type: 24}), "upgrade", "Upgrade station");
        expect(NpcMarkers.kind({type: 31}), "recycler", "Recycler");
        expect(NpcMarkers.stationKind(22), "", "NPC is not a station");
        expect(NpcMarkers.stationKind(32), "", "Wave spawner is not a station");
        expect(NpcMarkers.kind({id: "arbitrary-world-id", type: 33}), "infusion", "Crucible uses its native type");

        var gloryOffer = {item: "Reward", cost: [{kind: "BadgeOfGlory", amount: 5}]};
        expect(NpcMarkers.kind({type: 22, props: {shop: [gloryOffer]}}), "glory", "Glory-priced shop");
        expect(NpcMarkers.kind({type: 22, props: {npc: {unit: "TODO_WanderingMerchant"}, shop: [gloryOffer]}}),
            "glory", "Currency identifies role even with a reused merchant model");
        expect(NpcMarkers.kind({type: 33, props: {shop: [gloryOffer]}}), "infusion", "Station type takes precedence");
        expect(NpcMarkers.kind({type: 22, props: {shop: [
            {item: "Other", cost: []},
            {item: "Reward", cost: [{kind: "Gold", amount: 10}, {kind: "BadgeOfGlory", amount: 5}]}
        ]}}), "glory", "Search all offers and all currencies");
        expect(NpcMarkers.kind({type: 22, props: {shop: [{item: "BadgeOfGlory", cost: [{kind: "Gold", amount: 1}]}]}}),
            "npc", "Selling tokens does not identify a Glory merchant");
        expect(NpcMarkers.kind({type: 22, props: {npc: {npcTitle: "Glory Merchant"}, shop: [{item: "Reward"}]}}),
            "glory", "Service title works when the NPC does not expose Glory-priced offers");
        expect(NpcMarkers.kind({type: 22, texts: {type: "Glory Merchant"}}), "glory", "Native popup service label");
        expect(NpcMarkers.kind({type: 22, props: {npc: {npcTitle: " Glory Merchant ", unit: "TODO_WanderingMerchant"}}}),
            "glory", "Service title takes precedence over a reused merchant model");
        expect(NpcMarkers.kind({type: 22, texts: {name: "Glory Merchant", desc: "Glory Merchant"},
            props: {npc: {npcTitle: "Merchant of Glory Stories"}}}), "npc", "Incidental words and personal names are not a service title");
        expect(NpcMarkers.kind({type: 22, props: {shopList: [{lootTable: "BadgeOfGlory"}]}}),
            "npc", "Shop lists do not set a custom price");
        expect(NpcMarkers.isNpc("glory"), true, "Glory uses NPC visibility and priority");
        expect(NpcMarkers.isNpc("infusion"), true, "Crucible uses NPC visibility and priority");
        expect(NpcMarkers.isNpc("riftPortal"), false, "Rifts keep their own category");
        Sys.println('NPC marker checks passed ($checks)');
    }
}
