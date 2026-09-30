package fixtargetlock;

import hlx.runtime.HlxPrefixResult;
import fixtargetlock.FixTargetLockMod.TargetLockConfig;

/** Optional combat controls; native lock input and skill targets are never replaced. */
class CombatHooks {
    static var quickCast = new QuickCast();
    static var camera = new TargetLockCamera();
    static var reportedError:Bool = false;

    public static function configure(config:TargetLockConfig):Void {
        quickCast.enabled = config.enabled && config.quickCast;
        camera.enabled = config.enabled && config.disableCameraMovement;
    }

    public static function beginFrame():Void {
        quickCast.beginFrame();
        try camera.reset() catch (error:Dynamic) report(error);
    }

    public static function dispose():Void {
        quickCast.reset();
        try camera.reset() catch (error:Dynamic) report(error);
    }

    @:hlx.postfix(client.PlayerController.updateInputs)
    static function afterPlayerInputs(instance:Dynamic, dt:Float, result:Void):Void
        quickCast.observeController(instance);

    @:hlx.postfix(client.UnitController.startTargetMode)
    static function afterStartTargetMode(instance:Dynamic, skill:Dynamic, callback:Dynamic,
        input:Dynamic, result:Void):Void
        quickCast.start(instance, input);

    @:hlx.prefix(client.UnitController.update)
    static function beforeControllerUpdate(instance:Dynamic, dt:Float):HlxPrefixResult<Void> {
        quickCast.beginUpdate(instance);
        return Continue;
    }

    @:hlx.postfix(client.UnitController.update)
    static function afterControllerUpdate(instance:Dynamic, dt:Float, result:Void):Void {
        try quickCast.endUpdate(instance) catch (error:Dynamic) report(error);
    }

    @:hlx.postfix(client.UnitController.setJob)
    static function afterJobChanged(instance:Dynamic, job:Dynamic, update:Dynamic,
        onStop:Dynamic, result:Dynamic):Dynamic {
        quickCast.stop(instance);
        return result;
    }

    @:hlx.postfix(client.UnitController.onEnd)
    static function afterControllerEnd(instance:Dynamic, result:Void):Void
        quickCast.stop(instance);

    @:hlx.prefix(lib.Input.isPressedWithoutMode)
    static function confirmOnRelease(input:String):HlxPrefixResult<Bool> {
        try {
            var confirm = quickCast.confirm(input);
            if (confirm != null) return SkipWith(confirm);
        } catch (error:Dynamic) report(error);
        return Continue;
    }

    @:hlx.prefix(client.GameCamera.postUpdate)
    static function beforeCameraUpdate(instance:Dynamic, dt:Float):HlxPrefixResult<Void> {
        try camera.begin() catch (error:Dynamic) report(error);
        return Continue;
    }

    @:hlx.postfix(client.GameCamera.postUpdate)
    static function afterCameraUpdate(instance:Dynamic, dt:Float, result:Void):Void {
        try camera.end() catch (error:Dynamic) report(error);
    }

    static function report(error:Dynamic):Void {
        if (!reportedError) {
            reportedError = true;
            trace("[Fix Target Lock] Combat: " + Std.string(error));
        }
    }
}
