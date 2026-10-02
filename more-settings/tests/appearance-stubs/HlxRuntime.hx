/** Window geometry is not exercised by the save/close lifecycle tests. */
class HlxRuntime {
    public static function resolveType(name:String):Dynamic throw "Unexpected type allocation: " + name;
    public static function allocInstance(type:Dynamic):Dynamic throw "Unexpected geometry allocation";
}
