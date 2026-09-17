package gamecompat;

/** BaseSkillAccess was renamed in the new client; projectile/area fields were not. */
class HitSkill {
    public static inline function read(hit:Dynamic, field:Dynamic->String->Dynamic):Dynamic {
        var skill = field(hit, "skill");
        return skill != null ? skill : field(hit, "baseSkill");
    }
}
