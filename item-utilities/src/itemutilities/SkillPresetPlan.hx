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
    @:optional var signatures:Map<String, Array<String>>;
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

/** Restore class slots plus saved class/signature runes through normal requests. */
class SkillPresetPlan {
    public static inline var SLOT_COUNT = 4;

    public static function saved(state:SkillPresetState, owners:Map<String, String>):Array<SavedSkillSlot> {
        // Game-owned strings have a different class identity in HashLink.
        // Copy both skill and rune IDs so decode accepts them immediately and
        // JSON saves their text instead of their internal bytes/length fields.
        return [for (skill in state.slots) {skill: skill == null ? null : Std.string(skill),
            runes: skill == null ? [] : [for (rune in state.runes)
                if (owners.get(rune) == skill) Std.string(rune)]}];
    }

    public static function decode(value:Dynamic):Array<SavedSkillSlot> {
        return decodeRecords(value, true);
    }

    public static function savedSignatures(state:SkillPresetState, owners:Map<String, String>,
        rules:SkillPresetRules):Array<SavedSkillSlot> {
        var skills = rules.signatures == null ? [] : [for (skill in rules.signatures.keys()) skill];
        skills.sort(Reflect.compare);
        // Include an explicit empty rune selection as well as equipped runes.
        return saved({slots: skills, runes: state.runes}, owners);
    }

    public static function decodeSignatures(value:Dynamic):Array<SavedSkillSlot>
        return decodeRecords(value, false);

    static function decodeRecords(value:Dynamic, slots:Bool):Array<SavedSkillSlot> {
        if (!Std.isOfType(value, Array)) throw "This preset has no saved skills.";
        var records:Array<Dynamic> = cast value;
        if (slots && records.length != SLOT_COUNT) throw "This preset has an invalid number of skill slots.";
        var result:Array<SavedSkillSlot> = [];
        for (record in records) {
            if (record == null || !Reflect.hasField(record, "skill")) throw "Invalid saved skill slot.";
            var skill:Dynamic = Reflect.field(record, "skill");
            if (!slots && skill == null) throw "Invalid saved signature skill.";
            if (skill != null && (!Std.isOfType(skill, String) || skill == ""))
                throw "Invalid saved skill. Press Set to re-save this preset.";
            var runes:Dynamic = Reflect.field(record, "runes");
            if (!Std.isOfType(runes, Array)) throw "This preset has no saved rune selection.";
            var copied:Array<String> = [];
            for (rune in (cast runes:Array<Dynamic>)) {
                if (!Std.isOfType(rune, String) || rune == "" || copied.indexOf(rune) >= 0)
                    throw "Invalid or duplicate saved rune. Press Set to re-save this preset.";
                copied.push(cast rune);
            }
            if (skill == null && copied.length > 0) throw "An empty skill slot cannot have runes.";
            result.push({skill: cast skill, runes: copied});
        }
        return result;
    }

    public static function validate(target:Array<SavedSkillSlot>, rules:SkillPresetRules,
        ?signatures:Array<SavedSkillSlot>):Void {
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
            validateRunes(saved, available, rules.maxRunes);
        }
        if (signatures != null) for (saved in signatures) {
            if (saved.skill == null || seen.exists(saved.skill)) throw "Invalid or duplicate saved signature skill.";
            seen.set(saved.skill, true);
            var available = rules.signatures == null ? null : rules.signatures.get(saved.skill);
            if (available == null) throw "A saved signature skill is not unlocked for this class.";
            validateRunes(saved, available, rules.maxRunes);
        }
    }

    static function validateRunes(saved:SavedSkillSlot, available:Array<String>, maxRunes:Int):Void {
        if (saved.runes.length > maxRunes) throw "This character cannot equip that many runes yet.";
        var seen:Array<String> = [];
        for (rune in saved.runes) {
            if (available.indexOf(rune) < 0 || seen.indexOf(rune) >= 0)
                throw "A saved rune is unavailable, duplicated, or belongs to another skill.";
            seen.push(rune);
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
        rules:SkillPresetRules, runeSkills:Map<String, String>,
        ?signatures:Array<SavedSkillSlot>):Array<SkillPresetChange> {
        validate(target, rules, signatures);
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
        for (saved in (signatures == null ? target : target.concat(signatures))) {
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
