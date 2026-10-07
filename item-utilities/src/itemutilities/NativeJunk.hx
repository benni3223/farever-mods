package itemutilities;

import itemutilities.InspectAccess as G;

/** Match the fields compared by Item/Gear/Weapon/Mastery.equals in the live game. */
class NativeJunk {
    public static function isInBag(loadout:Dynamic, item:Dynamic):Bool {
        var inventory = G.field(loadout, "inventory");
        // getItemStack compares actual item objects, not matching gear stats.
        // A worn item is not junk just because a matching bag item is marked.
        return item != null && inventory != null && G.field(inventory, "content") != null
            && G.call("st.Inventory", "getItemStack", inventory, [item]) != null;
    }

    public static function fingerprint(item:Dynamic):String {
        var kind = G.text(G.field(item, "kind"));
        var inf = G.field(item, "inf");
        var flags = G.field(G.field(item, "flags"), "value");
        if (kind == "" || inf == null || flags == null) return null;
        var type = G.typeName(item);
        // Fail closed for future item subclasses with unexamined instance data.
        if (["st.Item", "st.item.Gear", "st.item.Armor", "st.item.Weapon", "st.item.Mastery",
            "st.item.Recipe", "st.item.InfusionPattern"].indexOf(type) < 0) return null;
        var parts:Array<Dynamic> = [type, kind, flags, G.text(G.field(inf, "rarity"))];
        if (G.isA(item, "st.item.Gear")) {
            var slots = G.field(item, "slots");
            // Gear.doUnserialize/_load preserve null when there are no extra
            // stats. Null is a valid empty list, not unfinished replication.
            // A present proxy must still have its backing array.
            if (slots != null && G.field(slots, "array") == null) return null;
            parts.push(G.field(item, "level"));
            parts.push(G.field(item, "upgradeLevel"));
            parts.push([for (slot in G.array(slots, true)) slot == null ? null : Std.string(slot)]);
            parts.push(G.text(G.field(item, "infusion")));
            parts.push(G.text(G.field(item, "infusionBonusStat")));
        }
        if (G.isA(item, "st.item.Weapon")) {
            parts.push(G.text(G.field(item, "rarity")));
            // Unmodified weapons normally have no effects proxy at all.
            var effects = G.field(item, "effects");
            if (effects != null && G.field(effects, "array") == null) return null;
            parts.push([for (effect in G.array(effects, true))
                [G.text(G.field(effect, "source")), G.text(G.field(effect, "skill"))]]);
        }
        if (G.isA(item, "st.item.Mastery")) parts.push(G.text(G.field(item, "mastery")));
        return "junk-v1:" + haxe.Json.stringify(parts);
    }

    public static function isGuildMerchant(window:Dynamic):Bool {
        var inf = G.field(G.field(window, "element"), "inf");
        return G.text(G.field(G.field(G.field(inf, "props"), "npc"), "unit")) == "WanderingMerchant";
    }
}
