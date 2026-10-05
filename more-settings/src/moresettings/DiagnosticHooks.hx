package moresettings;

import hlx.runtime.HlxPrefixResult;
import moresettings.GameAccess as G;
import moresettings.FrameMetrics as M;

/** A few frame-level/rare-operation hooks; never per hit, entity update or draw. */
class DiagnosticHooks {
    public static function update(app:Dynamic, optimization:Bool):Void {
        if (!StallMetrics.enabled) return;
        try {
            var hero = G.field(app, "hero");
            var window = G.field(G.field(app, "engine"), "window");
            var gameplay = hero != null && window != null && G.call("GameApp", "get_isLoading", app) == false
                && G.call("hxd.Window", "get_isFocused", window) == true;
            StallMetrics.context(gameplay, G.field(hero, "isInCombat") == true, optimization);
        } catch (_:Dynamic) StallMetrics.context(false, false, optimization);
        StallMetrics.begin(M.UPDATE);
    }

    @:hlx.prefix(hxd.System.mainLoop)
    static function beforeFrame():HlxPrefixResult<Void> { StallMetrics.beginFrame(); return Continue; }
    @:hlx.postfix(hxd.System.mainLoop)
    static function afterFrame(result:Void):Void StallMetrics.endFrame();

    @:hlx.postfix(GameApp.update)
    static function afterUpdate(instance:Dynamic, dt:Float, result:Void):Void StallMetrics.end(M.UPDATE);

    @:hlx.prefix(h3d.Engine.render)
    static function beforeRender(instance:Dynamic, object:Dynamic):HlxPrefixResult<Bool> {
        StallMetrics.begin(M.RENDER); return Continue;
    }
    @:hlx.postfix(h3d.Engine.render)
    static function afterRender(instance:Dynamic, object:Dynamic, result:Bool):Bool {
        StallMetrics.end(M.RENDER); return result;
    }

    @:hlx.prefix(h3d.impl.DX12Driver.present)
    static function beforePresent(instance:Dynamic):HlxPrefixResult<Void> { StallMetrics.begin(M.PRESENT); return Continue; }
    @:hlx.postfix(h3d.impl.DX12Driver.present)
    static function afterPresent(instance:Dynamic, result:Void):Void StallMetrics.end(M.PRESENT);

    // compileShader is also called for cache hits; compileSource only runs when
    // native code needs source loading/compilation for a newly compiled shader.
    @:hlx.prefix(h3d.impl.DX12Driver.compileSource)
    static function beforeSource(instance:Dynamic, shader:Dynamic, model:String, root:String):HlxPrefixResult<Dynamic> {
        StallMetrics.begin(M.SHADER_SOURCE); return Continue;
    }
    @:hlx.postfix(h3d.impl.DX12Driver.compileSource)
    static function afterSource(instance:Dynamic, shader:Dynamic, model:String, root:String, result:Dynamic):Dynamic {
        StallMetrics.end(M.SHADER_SOURCE); return result;
    }

    @:hlx.prefix(h3d.impl.DX12Driver.waitForFrame)
    static function beforeWait(instance:Dynamic, index:Int):HlxPrefixResult<Void> { StallMetrics.begin(M.FRAME_WAIT); return Continue; }
    @:hlx.postfix(h3d.impl.DX12Driver.waitForFrame)
    static function afterWait(instance:Dynamic, index:Int, result:Void):Void StallMetrics.end(M.FRAME_WAIT);

    // Graphics resource cleanup, not HashLink's implicit garbage collector.
    @:hlx.prefix(h3d.impl.MemoryManager.garbage)
    static function beforeCleanup(instance:Dynamic):HlxPrefixResult<Void> { StallMetrics.begin(M.GRAPHICS_CLEANUP); return Continue; }
    @:hlx.postfix(h3d.impl.MemoryManager.garbage)
    static function afterCleanup(instance:Dynamic, result:Void):Void StallMetrics.end(M.GRAPHICS_CLEANUP);
}
