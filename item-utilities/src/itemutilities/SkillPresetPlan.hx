package itemutilities;

typedef SavedSkillSlot = {
    var skill:String;
    var runes:Array<String>;
}

typedef SkillPresetState = {
    var slots:Array<String>;
    var runes:Array<String>;
}

typedef SkillPresetRules = {
    var skills:Map<String, Array<String>>;
    var unlockedSlots:Array<Bool>;
    var maxRunes:Int;
}

typedef SkillPresetChange = {
    var slot:Int; // -1 denotes a rune request.
    var skill:String;
    var rune:String;
    var enable:Bool;
    var after:SkillPresetState;
}

/** Plan only class skill slots and runes belonging to the saved skills. */
class SkillPresetPlan {
    public static inline var SLOT_COUNT = 4;

    public static function saved(state:SkillPresetState, owners:Map<String, String>):Array<SavedSkillSlot> {
        return [for (skill in state.slots) {skill: skill,
            runes: skill == null ? [] : [for (rune in state.runes) if (owners.get(rune) == skill) rune]}];
    }

    public static function decode(value:Dynamic):Array<SavedSkillSlot> {
        if (!Std.isOfType(value, Array)) throw "This preset has no saved skills.";
        var records:Array<Dynamic> = cast value;
        if (records.length != SLOT_COUNT) throw "This preset has an invalid number of skill slots.";
        var result:Array<SavedSkillSlot> = [];
        for (record in records) {
            if (record == null || !Reflect.hasField(record, "skill")) throw "Invalid saved skill slot.";
            var skill:Dynamic = Reflect.field(record, "skill");
            if (skill != null && (!Std.isOfType(skill, String) || skill == ""))
                throw "Invalid saved skill.";
            var runes:Dynamic = Reflect.field(record, "runes");
            if (!Std.isOfType(runes, Array)) throw "This preset has no saved rune selection.";
            var copied:Array<String> = [];
            for (rune in (cast runes:Array<Dynamic>)) {
                if (!Std.isOfType(rune, String) || rune == "" || copied.indexOf(rune) >= 0)
                    throw "Invalid or duplicate saved rune.";
                copied.push(cast rune);
            }
            if (skill == null && copied.length > 0) throw "An empty skill slot cannot have runes.";
            result.push({skill: cast skill, runes: copied});
        }
        return result;
    }

    public static function validate(target:Array<SavedSkillSlot>, rules:SkillPresetRules):Void {
        if (target.length != SLOT_COUNT || rules.unlockedSlots.length != SLOT_COUNT)
            throw "The skill slots are not available yet.";
        var seen:Map<String, Bool> = [];
        for (i in 0...SLOT_COUNT) {
            var saved = target[i];
            if (saved.skill == null) continue;
            if (seen.exists(saved.skill)) throw "The same skill cannot occupy multiple slots.";
            seen.set(saved.skill, true);
            var available = rules.skills.get(saved.skill);
            if (available == null || !rules.unlockedSlots[i]) throw "A saved skill or slot is not unlocked.";
            if (saved.runes.length > rules.maxRunes) throw "This character cannot equip that many runes yet.";
            for (rune in saved.runes)
                if (available.indexOf(rune) < 0) throw "A saved rune is unavailable or belongs to another skill.";
        }
    }

    public static function copy(state:SkillPresetState):SkillPresetState {
        return {slots: state.slots.copy(), runes: state.runes.copy()};
    }

    public static function same(a:SkillPresetState, b:SkillPresetState):Bool {
        if (a == null || b == null || a.slots.length != b.slots.length || a.runes.length != b.runes.length)
            return false;
        for (i in 0...a.slots.length) if (a.slots[i] != b.slots[i]) return false;
        // Rune order does not change the build. Requests explicitly remove
        // unwanted runes before adding, so native automatic eviction is avoided.
        for (rune in a.runes) if (b.runes.indexOf(rune) < 0) return false;
        return true;
    }

    public static function build(current:SkillPresetState, target:Array<SavedSkillSlot>,
        rules:SkillPresetRules, runeSkills:Map<String, String>):Array<SkillPresetChange> {
        validate(target, rules);
        if (current.slots.length != SLOT_COUNT) throw "The skill slots are not ready yet.";
        var state = copy(current);
        var changes:Array<SkillPresetChange> = [];
        function setSlot(slot:Int, skill:String):Void {
            state.slots[slot] = skill;
            changes.push({slot: slot, skill: skill, rune: null, enable: false, after: copy(state)});
        }
        for (i in 0...SLOT_COUNT) {
            var skill = target[i].skill;
            if (state.slots[i] == skill) continue;
            // Clear the previous position before moving a skill. Every
            // intermediate server state keeps skill IDs unique, including cycles.
            if (skill != null) {
                var previous = state.slots.indexOf(skill);
                if (previous >= 0) setSlot(previous, null);
            }
            setSlot(i, skill);
        }
        for (saved in target) {
            if (saved.skill == null) continue;
            for (rune in state.runes.copy()) {
                if (runeSkills.get(rune) != saved.skill || saved.runes.indexOf(rune) >= 0) continue;
                state.runes.remove(rune);
                changes.push({slot: -1, skill: saved.skill, rune: rune, enable: false, after: copy(state)});
            }
            for (rune in saved.runes) {
                if (state.runes.indexOf(rune) >= 0) continue;
                state.runes.push(rune);
                changes.push({slot: -1, skill: saved.skill, rune: rune, enable: true, after: copy(state)});
            }
        }
        return changes;
    }
}
