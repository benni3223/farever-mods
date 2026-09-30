package gamecompat;

/** Damage/FX hit data exposes skill; projectile and area entities still use baseSkill. */
class HitSkill {
    public static inline function read(hit:Dynamic, field:Dynamic->String->Dynamic):Dynamic {
        return field(hit, "skill");
    }
}
