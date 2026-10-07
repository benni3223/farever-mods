package moresettings;

typedef GpuResource = hl.Abstract<"dx_resource">;

/** The same IUnknown::Release entry point used by the game's DX12 driver. */
class GpuResources {
    public static function resolve(value:Dynamic):GpuResource {
        // Native abstract identities differ between the game and mod modules.
        return HlxRuntime.resolveAbstract(value, (null:hl.Abstract<"dx_resource">));
    }

    @:hlNative("dx12", "resource_release")
    public static function release(resource:GpuResource):Void {}

    /** Only for exclusively owned references whose GPU fence already completed. */
    public static function releaseRetired(resource:GpuResource):Void {
        // This native is only IUnknown::Release: no HL allocations or callbacks.
        // Otherwise a slow driver call on a worker can still hold up GC.
        hl.Gc.blocking(true);
        release(resource);
        hl.Gc.blocking(false);
    }
}
