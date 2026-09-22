package;

import haxe.Json;
import lootdb.Catalog;

class CatalogTest {
    static var checks = 0;
    static function check(condition:Bool, message:String):Void {
        checks++;
        if (!condition) throw message;
    }
    static function main():Void {
        var catalog = Catalog.parse(fixture());
        var lair = catalog.search("instances", "ratsar");
        check(lair.length == 1 && lair[0].id == "ratsars-lair", "Dungeon search finds the grouped lair");
        check(catalog.search("instances", "egglektra").length == 1, "A world boss is its own instance");
        check(catalog.search("instances", "crab").length == 0, "Ordinary creature spawns stay out of the instance list");
        var bosses = [for (hit in catalog.search("bosses", "")) hit.title];
        check(bosses.length == 2 && bosses.indexOf("Egglektra") >= 0 && bosses.indexOf("King Ratsar") >= 0,
            "Bosses are listed without the rest of the bestiary");
        var fangs = catalog.search("weapons", "fang");
        check(fangs.length == 1 && fangs[0].title == "Twin Fangs of Ratsar", "Weapon search matches the item name");
        check(catalog.search("items", "fang").length == 0, "Weapons stay on the weapon tab");
        check(catalog.search("items", "linen").length == 1, "Other items stay searchable");
        var sources = catalog.droppedBy("Twin Fangs of Ratsar");
        check(sources.length == 1 && sources[0].creatureName == "King Ratsar" && sources[0].chance == "1%"
            && sources[0].instanceId == "ratsars-lair", "Drop lookup points at the boss and instance");
        check(catalog.droppedBy("twin-fangs-of-ratsar")[0].group == "boss", "The same drop is indexed by slug");
        check(catalog.instanceOfBoss("king-ratsar").name == "Ratsar's Lair", "A boss resolves to the grouped instance");
        check(catalog.instanceOfBoss("king-ratsar").bosses.length == 1, "The lair keeps its boss list");
        var dungeonPins = catalog.pinsFor("", true, false, false);
        check(dungeonPins.length == 1 && dungeonPins[0].instanceId == "ratsars-lair", "Dungeon filter keeps the lair pin");
        check(catalog.pinsFor("", false, true, false)[0].label == "Egglektra", "World-boss filter keeps that pin");
        check(catalog.pinsFor("egg", false, false, true).length == 1, "Search hits can show a pin while the other filters are off");
        check(catalog.item("twin-fangs-of-ratsar").skills[0].name == "Cheesebane", "Weapon skills are kept on the item");
        check(catalog.item("twin-fangs-of-ratsar").scales.length == 2
            && catalog.item("twin-fangs-of-ratsar").scales[1].mode == "max"
            && catalog.item("twin-fangs-of-ratsar").scales[1].rarity == "Legendary",
            "Scaled rarity steps stay on the item");
        check(catalog.item("linen-cloth").scales.length == 0, "Items without scaled stats stay empty");
        check(catalog.searchFiltered("weapons", "", ["Rogue", "Mage"], [], []).length == 1, "Choosing several classes keeps a weapon that matches one of them");
        check(catalog.search("weapons", "", "Rogue").length == 1, "Class filter keeps the matching weapon");
        check(catalog.search("weapons", "", "Mage").length == 0, "Class filter hides other weapons");
        check(catalog.search("weapons", "", "", "Daggers").length == 1, "Weapon type filter uses the gear slot");
        check(catalog.search("items", "", "", "Cloth").length == 1, "Item slot filter uses the subcategory");
        check(Catalog.prettySlot("GreatMace") == "Great Mace" && Catalog.prettySlot("GearNeck") == "Neck", "Gear slots are shown as words");
        trace("ok " + checks);
    }

    static function fixture():String {
        var droppedBy:Dynamic = {};
        var source = [{creatureId: "king-ratsar", creatureName: "King Ratsar", group: "boss", chance: "1%", instanceId: "ratsars-lair"}];
        Reflect.setField(droppedBy, "twin fangs of ratsar", source);
        Reflect.setField(droppedBy, "twin-fangs-of-ratsar", source);
        return Json.stringify({
            exportedAt: "2026-09-22T00:00:00Z",
            items: [
                {id: "twin-fangs-of-ratsar", name: "Twin Fangs of Ratsar", slug: "twin-fangs-of-ratsar", category: "weapons", subcategory: "Daggers", classes: ["Rogue"], rarity: "Rare", level: 8, description: "Stolen fangs.", obtain: ["Dropped"], stats: [{label: "Dexterity", value: "+20"}], scales: [{mode: "normal", rarity: "Rare", level: 8, stats: [{label: "Dexterity", value: "+20"}]}, {mode: "max", rarity: "Legendary", level: 25, stats: [{label: "Dexterity", value: "+40"}]}], skills: [{id: "combo", name: "Cheesebane", cooldown: null}], recipe: ""},
                {id: "linen-cloth", name: "Linen Cloth", slug: "linen-cloth", category: "materials", subcategory: "Cloth", classes: [], rarity: "Common", level: null, description: "", obtain: ["Dropped"], stats: [], skills: [], recipe: ""}
            ],
            creatures: [
                {id: "king-ratsar", name: "King Ratsar", slug: "king-ratsar", faction: "Kobold", subcategory: "Bosses", level: 10, description: "A spiteful king.", skills: [{id: "slam", name: "Great Slam", cooldown: 36, duration: 8, power: "40% FoePower Physical"}], drops: {boss: [{name: "Twin Fangs of Ratsar", slug: "twin-fangs-of-ratsar", chance: "1%", rarity: "Rare", group: "boss"}], unit: [], faction: [], world: []}},
                {id: "egglektra", name: "Egglektra", slug: "egglektra", faction: "Bee", subcategory: "Bosses", level: 12, description: "", skills: [], drops: {boss: [], unit: [], faction: [], world: []}},
                {id: "abyssal-crab", name: "Abyssal Crab", slug: "abyssal-crab", faction: "Crab", subcategory: "Crab", level: 14, description: "", skills: [], drops: {boss: [], unit: [], faction: [], world: []}}
            ],
            instances: [
                {id: "ratsars-lair", name: "Ratsar's Lair", kind: "dungeon", bosses: ["king-ratsar"], names: ["Ratsar's Lair", "King Ratsar"], pin: {x: 2936.7, y: 6671.1}, drops: ["Twin Fangs of Ratsar"]},
                {id: "egglektra", name: "Egglektra", kind: "world-boss", bosses: ["egglektra"], names: ["Egglektra"], pin: {x: 10, y: 20}, drops: []},
                {id: "abyssal-crab", name: "Abyssal Crab", kind: "location", bosses: [], names: ["Abyssal Crab"], pin: {x: 1, y: 2}, drops: []}
            ],
            pins: [
                {id: "ratsar", x: 2936.7, y: 6671.1, kind: "dungeon", label: "King Ratsar", instanceId: "ratsars-lair", creatureId: "king-ratsar"},
                {id: "egg", x: 10, y: 20, kind: "world-boss", label: "Egglektra", instanceId: "egglektra", creatureId: "egglektra"},
                {id: "crab", x: 1, y: 2, kind: "location", label: "Abyssal Crab", instanceId: "abyssal-crab", creatureId: "abyssal-crab"}
            ],
            droppedBy: droppedBy,
            bossInstance: {"king-ratsar": "ratsars-lair", egglektra: "egglektra"}
        });
    }
}
