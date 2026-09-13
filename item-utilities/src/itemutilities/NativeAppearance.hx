package itemutilities;

import hlx.runtime.ResolvedMember;
import itemutilities.AppearancePresetPlan.AppearanceSlotRule;

/** Use the same visible slots, appearance inventory, and RPC as GearAppearance. */
class NativeAppearance {
    static var members:Map<String, ResolvedMember> = [];
    static var slotRules:Array<AppearanceSlotRule>;

    static function call(type:String, name:String, object:Dynamic, args:Array<Dynamic>):Dynamic {
        var key = type + "." + name;
        var member = members.get(key);
        if (member == null) {
            var nativeType = HlxRuntime.resolveType(type);
            if (nativeType == null) throw "Game type unavailable: " + type;
            member = HlxRuntime.resolveMember(nativeType, name);
            if (member == null) throw "Game member unavailable: " + key;
            members.set(key, member);
        }
        return HlxRuntime.callResolved(member, [object].concat(args));
    }

    static function field(object:Dynamic, name:String):Dynamic {
        return object == null ? null : HlxRuntime.resolveField(object, name);
    }

    static function staticField(type:String, name:String):Dynamic {
        var nativeType = HlxRuntime.resolveType(type);
        if (nativeType == null) throw "Game type unavailable: " + type;
        return HlxRuntime.resolveStaticField(nativeType, name);
    }

    public static function rules():Array<AppearanceSlotRule> {
        if (slotRules != null) return slotRules;
        var slots = staticField("DataCache", "EQUIPMENT_SLOTS");
        var types = field(staticField("Data", "itemType"), "byId");
        if (slots == null || types == null) throw "The appearance slots are not available yet.";
        var count:Int = cast field(slots, "length");
        var result:Array<AppearanceSlotRule> = [];
        for (i in 0...count) {
            var slot:String = cast call("hl.types.ArrayObj", "getDyn", slots, [i]);
            var definition = call("haxe.ds.StringMap", "get", types, [slot]);
            var props = field(definition, "slot");
            var category = field(props, "displayCategory");
            // These are the exact filters GearAppearance uses for its two
            // columns, without depending on hard-coded inventory indices.
            if (field(props, "isVisibleGear") == true && (category == 0 || category == 1))
                result.push({slot: slot, index: i});
        }
        if (result.length == 0) throw "The appearance slots are not available yet.";
        slotRules = result;
        return slotRules;
    }

    public static function current(loadout:Dynamic):Map<String, String> {
        var inventory = field(loadout, "appearance");
        if (inventory == null || field(inventory, "content") == null)
            throw "The character's appearance is not ready yet.";
        var choices:Map<String, String> = [];
        for (rule in rules()) {
            var item = call("st.Inventory", "getItem", inventory, [rule.index]);
            var id:String = item == null ? null : cast field(item, "kind");
            if (item != null && id == null) throw "Unable to read an armour appearance.";
            choices.set(rule.slot, id);
        }
        return choices;
    }

    public static function validate(loadout:Dynamic, choices:Map<String, String>):Void {
        AppearancePresetPlan.validate(choices, rules());
        for (rule in rules()) {
            // Native checks include slot compatibility, class aptitudes, and
            // collection ownership. The boolean wrapper avoids enum indices
            // that differ between live and PTR. It does not execute changes.
            if (call("st.Loadout", "canSetAppearance", loadout, [choices.get(rule.slot), rule.slot]) != true)
                throw "A saved appearance is unavailable or cannot be used by this character.";
        }
    }

    public static function apply(loadout:Dynamic, slot:String, item:String, callback:Bool->Void):Void {
        call("st.Loadout", "setAppearance", loadout, [item, slot, callback]);
    }

    public static function refreshView(view:Dynamic, loadout:Dynamic):Void {
        if (view != null && field(view, "loadout") == loadout && field(view, "currentSlot") != null)
            call("ui.win.GearAppearance", "updateSelected", view, []);
        // The native view already watches the appearance inventory signature
        // to refresh its model; each slot also refreshes its own icon.
    }
}
