import fixtargetlock.QuickCast;
import fixtargetlock.TargetLockCamera;
import fixtargetlock.LockedTargeting;
import fixtargetlock.GameAccess as G;

class CombatTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, message:String):Void {
        checks++;
        if (actual != expected) throw message + ': expected $expected, got $actual';
    }

    static function main():Void {
        var q = new QuickCast();
        var player:Dynamic = {ended: false, lockedTarget: "Enemy"};
        var other:Dynamic = {ended: false};
        G.data = {_noCheckMode: false, checkActive: (_:Dynamic) -> G.inputActive};
        q.observeController(player);
        q.beginUpdate(player);
        q.start(player, "Skill1");
        eq(q.confirm("Skill1"), null, "Off by default keeps native confirmation");
        q.enabled = true;
        q.start(player, "Skill1");
        eq(q.confirm("Skill1"), false, "Holding the skill keeps native aiming open");
        eq(q.confirm("Skill2"), null, "Another skill input is unchanged");
        eq(q.confirm("AimSkillCancel"), null, "Cancellation remains native");
        eq(G.data._noCheckMode, false, "Input mode restored after checking release");
        q.beginUpdate(other);
        G.releasedInput = "Skill1";
        eq(q.confirm("Skill1"), null, "Nested non-player controller cannot confirm player's skill");
        q.endUpdate(other);
        eq(q.confirm("Skill1"), true, "Releasing the bound skill confirms native ground aim");
        eq(player.lockedTarget, "Enemy", "Quick cast never replaces the lock");
        q.stop(player); // Native setJob on cast/cancel.
        eq(q.confirm("Skill1"), null, "Native job change clears confirmation");
        q.endUpdate(player);

        // Native aiming skips its confirmation block on the first frame.
        q.beginUpdate(player);
        q.start(player, "Skill1");
        q.endUpdate(player);
        G.releasedInput = null;
        q.beginUpdate(player);
        eq(q.confirm("Skill1"), true, "First-frame quick tap is retained for the next native update");
        q.stop(player);
        q.start(player, "Skill2");
        eq(q.confirm("Skill2"), false, "A later skill cannot reuse an old release");
        q.enabled = false;
        eq(q.confirm("Skill2"), null, "Disabling while aiming restores native click confirmation");
        q.enabled = true;
        q.start(other, "Skill1");
        eq(q.confirm("Skill1"), null, "Non-player aiming is not intercepted");
        q.start(player, "Skill1");
        G.inputActive = false;
        G.releasedInput = "Skill1";
        var reads = G.releaseReads;
        eq(q.confirm("Skill1"), false, "Inactive input cannot cast");
        eq(G.releaseReads, reads, "Respect the native focus/UI gate before reading bindings");
        G.inputActive = true;
        G.releasedInput = null;
        eq(q.confirm("Skill1"), false, "Refocusing does not cast a stale release");
        G.data._noCheckMode = true;
        eq(q.confirm("Skill1"), false, "Still holding in an existing mode override");
        eq(G.data._noCheckMode, true, "An existing input mode override is preserved");
        G.data._noCheckMode = false;
        G.failRelease = true;
        var failed = false;
        try q.confirm("Skill1") catch (_:Dynamic) failed = true;
        eq(failed, true, "Input errors reach the guarded hook");
        eq(G.data._noCheckMode, false, "Input mode restored even on native error");
        G.failRelease = false;
        eq(q.confirm("Skill1"), null, "A failed release check returns future input to native handling");
        q.start(player, "Skill1");
        q.observeController(other);
        eq(q.confirm("Skill1"), null, "Controller replacement clears the old skill");
        q.observeController(player);
        q.start(player, "Skill1");
        player.ended = true;
        eq(q.confirm("Skill1"), null, "Ended controllers cannot cast");
        player.ended = false;
        q.start(player, "Skill1");
        q.beginFrame(); // Recover a native update that exited before its postfix.
        eq(q.confirm("Skill1"), null, "An abandoned update scope cannot leak into other input");
        q.reset();

        var camera = new TargetLockCamera();
        var settings:Dynamic = {LockRotateSpeed: 8.0, TargetLock: true};
        G.data = {Camera: settings};
        camera.begin();
        eq(settings.LockRotateSpeed, 8.0, "Camera default leaves native steering on");
        camera.end();
        camera.enabled = true;
        camera.begin();
        eq(settings.LockRotateSpeed, 0.0, "Disable only automatic lock steering");
        eq(1 - Math.exp(-settings.LockRotateSpeed * 0.016), 0.0, "Native steering interpolation makes no correction");
        eq(settings.TargetLock, true, "Target-lock feature and locked sensitivity stay enabled");
        camera.begin();
        camera.end();
        eq(settings.LockRotateSpeed, 0.0, "Nested camera updates preserve the outer override");
        camera.enabled = false;
        camera.end();
        eq(settings.LockRotateSpeed, 8.0, "Restore even if setting changes before postfix");
        settings.LockRotateSpeed = 12.0;
        camera.enabled = true;
        camera.begin();
        camera.reset();
        eq(settings.LockRotateSpeed, 12.0, "Recover the exact current tuning after an interrupted update");
        G.data = {Camera: {TargetLock: true}};
        camera.begin(); camera.end();
        eq(G.data.Camera.TargetLock, true, "Missing optional steering field leaves native behavior intact");

        var targeting = new LockedTargeting();
        var locked = {name: "locked"};
        var aimed = {name: "crosshair"};
        player.autoTarget = aimed;
        targeting.begin(player, locked);
        eq(player.autoTarget, locked, "Instant skills without a fresh target query use the lock");
        eq(targeting.target(player), locked, "Native skill target query stays on the lock");
        eq(targeting.target(other), null, "Another controller keeps native targeting");
        targeting.begin(other, null);
        eq(targeting.target(player), null, "Nested skill aiming cannot borrow the outer lock");
        targeting.end();
        eq(targeting.target(player), locked, "Nested call restores the outer aim scope");
        targeting.begin(player, locked);
        targeting.end();
        eq(player.autoTarget, locked, "Nested same-controller scope keeps the outer target");
        targeting.end();
        eq(player.autoTarget, aimed, "Native crosshair target restored after skill callback");
        eq(targeting.target(player), null, "Ordinary target picking is never pinned");
        targeting.begin(player, null);
        player.autoTarget = other;
        targeting.end();
        eq(player.autoTarget, other, "Unlocked skill keeps native auto-target changes");
        targeting.begin(player, locked);
        targeting.reset();
        eq(player.autoTarget, other, "Interrupted skill scope restores the prior target next frame");
        eq(targeting.target(player), null, "Interrupted scope cannot affect later skills");
        Sys.println('Combat tests passed ($checks checks)');
    }
}
