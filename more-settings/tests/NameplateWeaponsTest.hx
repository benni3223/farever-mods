import moresettings.NameplateWeapons;
import moresettings.SettingsData;

class NameplateWeaponsTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, message:String):Void {
        checks++;
        if (actual != expected) throw message + ': expected $expected, got $actual';
    }
    static function main():Void {
        eq(SettingsData.defaults().showNameplateWeapons, true, "equipped weapon icons start enabled");
        var main = {inf: "sword"};
        var arsenal = {inf: "bow"};
        var pair = NameplateWeapons.pair(main, arsenal);
        eq(pair.length, 2, "both weapon columns exist");
        eq(pair[0], main, "weapon1 is the left icon");
        eq(pair[1], arsenal, "weapon2 is the right icon");
        eq(NameplateWeapons.shown(main), true, "an item with a definition is drawn");
        eq(NameplateWeapons.shown(null), false, "a null weapon is hidden");
        eq(NameplateWeapons.shown({}), false, "an item without a definition is hidden");
        eq(NameplateWeapons.colorForRarity("Rare"), 0x4aa3ff, "rare weapons get a blue plate");
        eq(NameplateWeapons.colorForRarity("Epic"), 0xb44cff, "epic weapons get a purple plate");
        eq(NameplateWeapons.colorForRarity("Legendary"), 0xffb020, "legendary weapons get a gold plate");
        eq(NameplateWeapons.colorForRarity("Common"), -1, "common weapons stay unmarked");
        eq(NameplateWeapons.colorForRarity("Uncommon"), -1, "uncommon weapons stay unmarked");
        var onlyArsenal = NameplateWeapons.pair(null, arsenal);
        eq(onlyArsenal[0], null, "a missing main weapon stays the left column");
        eq(onlyArsenal[1], arsenal, "the arsenal weapon stays the right column");
        Sys.println('Nameplate weapon tests passed ($checks checks)');
    }
}
