package itemutilities;

typedef AppearanceSlotRule = {
    var slot:String;
    var index:Int;
}

typedef AppearanceChange = {
    var slot:String;
    var item:String;
    var after:Map<String, String>;
}

/** A null item means the equipped item's appearance; Hide_Gear means hidden. */
class AppearancePresetPlan {
    public static function decode(value:Dynamic):Map<String, String> {
        if (!Std.isOfType(value, Array)) throw "This preset has no saved appearances.";
        var result:Map<String, String> = [];
        for (record in (cast value:Array<Dynamic>)) {
            if (record == null || !Reflect.hasField(record, "item")) throw "Invalid saved appearance.";
            var slot:Dynamic = Reflect.field(record, "slot");
            var item:Dynamic = Reflect.field(record, "item");
            if (!Std.isOfType(slot, String) || slot == "" || result.exists(cast slot))
                throw "Invalid or duplicate appearance slot.";
            if (item != null && (!Std.isOfType(item, String) || item == ""))
                throw "Invalid saved appearance item.";
            result.set(cast slot, cast item);
        }
        return result;
    }

    public static function encode(choices:Map<String, String>):Array<Dynamic> {
        var slots = [for (slot in choices.keys()) slot];
        slots.sort(Reflect.compare);
        return [for (slot in slots) {slot: slot, item: choices.get(slot)}];
    }

    public static function validate(choices:Map<String, String>, rules:Array<AppearanceSlotRule>):Void {
        var slots:Map<String, Bool> = [];
        if (rules.length == 0) throw "The appearance slots are not available yet.";
        for (rule in rules) {
            if (rule.index < 0 || slots.exists(rule.slot)) throw "Invalid game appearance slots.";
            slots.set(rule.slot, true);
            if (!choices.exists(rule.slot)) throw "This preset is missing an armour appearance slot.";
        }
        for (slot in choices.keys())
            if (!slots.exists(slot)) throw "This preset contains an unavailable appearance slot.";
    }

    public static function same(a:Map<String, String>, b:Map<String, String>):Bool {
        if (a == null || b == null) return false;
        for (slot in a.keys())
            if (!b.exists(slot) || a.get(slot) != b.get(slot)) return false;
        for (slot in b.keys()) if (!a.exists(slot)) return false;
        return true;
    }

    public static function build(current:Map<String, String>, target:Map<String, String>,
        rules:Array<AppearanceSlotRule>):Array<AppearanceChange> {
        validate(current, rules);
        validate(target, rules);
        var state = current.copy();
        var changes:Array<AppearanceChange> = [];
        for (rule in rules) {
            var item = target.get(rule.slot);
            if (state.get(rule.slot) == item) continue;
            state.set(rule.slot, item);
            changes.push({slot: rule.slot, item: item, after: state.copy()});
        }
        return changes;
    }
}
