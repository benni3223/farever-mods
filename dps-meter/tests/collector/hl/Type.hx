package hl;

/** Collector's summon path is native-only and must not run in these tests. */
class Type {
    public static function getDynamic(value:Dynamic):Type throw "Unexpected native summon type lookup";
    public function getTypeName():String throw "Unexpected native summon type lookup";
}
