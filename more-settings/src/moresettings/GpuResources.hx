package moresettings;

/** The same IUnknown::Release entry point used by the game's DX12 driver. */
class GpuResources {
    public static function resolve(value:Dynamic):hl.Abstract<"dx_resource"> {
        // Native abstract identities differ between the game and mod modules.
        return HlxRuntime.resolveAbstract(value, (null:hl.Abstract<"dx_resource">));
    }

    @:hlNative("dx12", "resource_release")
    public static function release(resource:hl.Abstract<"dx_resource">):Void {}
}
