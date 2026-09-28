import moresettings.QuickCast;
import moresettings.TargetLockCamera;
import moresettings.CombatSettings;
import moresettings.SettingsData;
import moresettings.GameAccess as G;

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

        var c = SettingsData.defaults();
        eq(c.quickCast, false, "Quick cast default");
        eq(c.disableTargetLockCameraMovement, false, "Camera setting default");
        CombatSettings.migrate(c, {}, {enabled: true, quickCast: true, disableCameraMovement: true});
        eq(c.quickCast, true, "Import quick cast preference");
        eq(c.disableTargetLockCameraMovement, true, "Import renamed camera preference");
        c = SettingsData.defaults();
        CombatSettings.migrate(c, {quickCast: false, disableTargetLockCameraMovement: false},
            {quickCast: true, disableCameraMovement: true});
        eq(c.quickCast, false, "Existing More Settings choice wins");
        eq(c.disableTargetLockCameraMovement, false, "False is a saved camera choice, not a missing value");
        CombatSettings.migrate(c, {}, {enabled: false, quickCast: true, disableCameraMovement: true});
        eq(c.quickCast, false, "Disabled legacy mod does not unexpectedly enable quick cast");
        eq(c.disableTargetLockCameraMovement, false, "Disabled legacy mod does not unexpectedly change camera");
        CombatSettings.migrate(c, {}, {quickCast: "true", disableCameraMovement: 1});
        eq(c.quickCast, false, "Ignore malformed legacy values");
        CombatSettings.migrate(c, {}, null);
        eq(c.quickCast, false, "Clean installations retain defaults");
        CombatSettings.migrate(c, {}, {quickCast: true});
        eq(c.quickCast, true, "Older config without a master toggle imports its explicit choice");
        Sys.println('Combat tests passed ($checks checks)');
    }
}
