package itemutilities;

import itemutilities.InspectAccess as G;

/** Match the fields compared by Item/Gear/Weapon/Mastery.equals in the live game. */
class NativeJunk {
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
            if (G.field(item, "slots") == null || G.field(G.field(item, "slots"), "array") == null) return null;
            parts.push(G.field(item, "level"));
            parts.push(G.field(item, "upgradeLevel"));
            parts.push([for (slot in G.array(G.field(item, "slots"), true)) slot == null ? null : Std.string(slot)]);
            parts.push(G.text(G.field(item, "infusion")));
            parts.push(G.text(G.field(item, "infusionBonusStat")));
        }
        if (G.isA(item, "st.item.Weapon")) {
            parts.push(G.text(G.field(item, "rarity")));
            if (G.field(G.field(item, "effects"), "array") == null) return null;
            parts.push([for (effect in G.array(G.field(item, "effects"), true))
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
