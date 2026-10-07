/** The native release test does not exercise cross-module pointer resolution. */
class HlxRuntime {
    public static function resolveAbstract<T>(value:Dynamic, sample:T):T return cast value;
}
