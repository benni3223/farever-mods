package moresettings;

import hlx.runtime.HlxPrefixResult;

/** Opt-in fixes for audited client queues and terrain rendering. */
class PerformanceHooks {
    public static var enabled(default, set):Bool = false;
    static var queue = new WorkerQueue();
    static var terrain = new TerrainGlobalsCache();
    static var pipelines = new PipelineWarmup();
    static var characters = new CharacterVisualJobs();
    static var pipelineFailed:Bool = false;
    static var queueFailed:Bool = false;
    static var feedFailed:Bool = false;
    static var terrainFailed:Bool = false;

    static function set_enabled(value:Bool):Bool {
        if (!value) { terrain.clear(); pipelines.clear(); }
        // Accepted character builds must finish even after the option is disabled.
        return enabled = value;
    }

    public static function update(app:Dynamic, dt:Float):Void {
        if (enabled && !pipelineFailed) try pipelines.update(app, true, dt) catch (e:Dynamic) pipelineError(e);
    }

    public static function dispose():Void {
        pipelines.clear();
        characters.clear();
        terrain.clear();
    }

    static function pipelineError(error:Dynamic):Void {
        pipelines.clear();
        if (!pipelineFailed) trace("[More Settings] Incremental pipeline warm-up disabled: " + Std.string(error));
        pipelineFailed = true;
    }

    @:hlx.prefix(h3d.impl.PSOConfigCache.resolveConfig)
    static function beforePipelineReplay(instance:Dynamic, shader:Dynamic):HlxPrefixResult<Void> {
        StallMetrics.begin(FrameMetrics.PIPELINE_REPLAY);
        if (enabled && !pipelineFailed) try {
            if (pipelines.defer(instance, shader)) return Skip;
        } catch (e:Dynamic) pipelineError(e);
        return Continue;
    }

    @:hlx.postfix(h3d.impl.PSOConfigCache.resolveConfig)
    static function afterPipelineReplay(instance:Dynamic, shader:Dynamic, result:Void):Void
        StallMetrics.end(FrameMetrics.PIPELINE_REPLAY);

    @:hlx.prefix(h3d.impl.DX12Driver.reset)
    static function beforeDriverReset(instance:Dynamic):HlxPrefixResult<Void> {
        StallMetrics.begin(FrameMetrics.DRIVER_RESET);
        pipelines.invalidate(instance);
        return Continue;
    }

    @:hlx.postfix(h3d.impl.DX12Driver.reset)
    static function afterDriverReset(instance:Dynamic, result:Void):Void StallMetrics.end(FrameMetrics.DRIVER_RESET);

    @:hlx.prefix(h3d.impl.DX12Driver.dispose)
    static function beforeDriverDispose(instance:Dynamic):HlxPrefixResult<Void> {
        pipelines.invalidate(instance);
        return Continue;
    }

    @:hlx.prefix(client.UnitView.displaySkin)
    static function beforeSkin(instance:Dynamic):HlxPrefixResult<Void> {
        StallMetrics.begin(FrameMetrics.SKIN);
        try characters.begin(instance, enabled) catch (e:Dynamic) {
            characters.cancel(instance);
            characters.report(e);
        }
        return Continue;
    }

    @:hlx.postfix(client.UnitView.displaySkin)
    static function afterSkin(instance:Dynamic, result:Void):Void {
        characters.end(instance);
        StallMetrics.end(FrameMetrics.SKIN);
    }

    @:hlx.prefix(client.UnitView.updateDynamicVisuals)
    static function beforeCharacterParts(instance:Dynamic, excludeGear:hl.Ref<Bool>):HlxPrefixResult<Void> {
        try {
            if (enabled && characters.defer(instance, excludeGear != null && excludeGear.get())) return Skip;
        } catch (e:Dynamic) { characters.cancel(instance); characters.report(e); }
        return Continue;
    }

    @:hlx.prefix(client.UnitView.checkReady)
    static function beforeCharacterReady(instance:Dynamic):HlxPrefixResult<Void>
        return characters.pending(instance) ? Skip : Continue;

    @:hlx.postfix(client.UnitView.isReady)
    static function afterCharacterReady(instance:Dynamic, result:Bool):Bool
        return characters.ready(instance, result);

    @:hlx.prefix(h3d.scene.Object.onRemove)
    static function beforeSceneObjectRemoved(instance:Dynamic):HlxPrefixResult<Void> {
        characters.cancel(instance);
        return Continue;
    }

    static function terrainError(e:Dynamic):Void {
        terrain.clear();
        if (!terrainFailed) trace("[More Settings] Performance terrain reuse disabled: " + Std.string(e));
        terrainFailed = true;
    }

    @:hlx.prefix(world.terrain.Terrain.updateGlobals)
    static function beforeTerrainGlobals(instance:Dynamic, context:Dynamic):HlxPrefixResult<Void> {
        if (enabled && !terrainFailed) try {
            if (terrain.reuse(instance, context)) return Skip;
        } catch (e:Dynamic) terrainError(e);
        return Continue;
    }

    @:hlx.postfix(world.terrain.Terrain.updateGlobals)
    static function afterTerrainGlobals(instance:Dynamic, context:Dynamic, result:Void):Void {
        if (enabled && !terrainFailed)
            try terrain.remember(instance, context) catch (e:Dynamic) terrainError(e);
    }

    @:hlx.prefix(world.terrain.ChunkGround.refresh)
    static function beforeGroundRefresh(instance:Dynamic):HlxPrefixResult<Void> {
        if (enabled && !terrainFailed) terrain.invalidate(moresettings.GameAccess.field(instance, "terrain"));
        return Continue;
    }

    @:hlx.prefix(world.terrain.Terrain.dispose)
    static function beforeTerrainDispose(instance:Dynamic):HlxPrefixResult<Void> {
        terrain.forget(instance);
        return Continue;
    }

    @:hlx.prefix(lib.Workers.work)
    static function work(instance:Dynamic):HlxPrefixResult<Void> {
        StallMetrics.begin(FrameMetrics.WORKERS);
        // A nested work() must use the current cursor even if a job toggles us off.
        if ((!enabled || queueFailed) && !queue.active(instance)) return Continue;
        try return queue.run(instance) ? Skip : Continue catch (e:Dynamic) {
            // run() compacts the consumed prefix on failure. Do not dispatch the
            // original in the same pass and accidentally rerun a failing job.
            if (!queueFailed) trace("[More Settings] Performance worker queue disabled: " + Std.string(e));
            queueFailed = true;
            return Skip;
        }
    }

    @:hlx.postfix(lib.Workers.work)
    static function afterWork(instance:Dynamic, result:Void):Void StallMetrics.end(FrameMetrics.WORKERS);

    @:hlx.postfix(lib.Workers.isEmpty)
    static function isEmpty(instance:Dynamic, result:Bool):Bool
        return queue.isEmpty(instance, result);

    @:hlx.prefix(ui.hud.EffectsFeed.addLine)
    static function beforeFeedLine(instance:Dynamic, text:String):HlxPrefixResult<Dynamic> {
        if (enabled && !feedFailed) try FeedBacklog.trim(instance) catch (e:Dynamic) {
            feedFailed = true;
            trace("[More Settings] Performance feed limit disabled: " + Std.string(e));
        }
        return Continue;
    }
}
