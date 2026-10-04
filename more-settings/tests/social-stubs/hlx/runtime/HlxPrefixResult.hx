package hlx.runtime;

// Same hook return contract as hlx-runtime, used by standalone tests.
enum HlxPrefixResult<T> {
    Continue;
    Skip;
    SkipWith(result:T);
}
