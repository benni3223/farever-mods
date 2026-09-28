# Combat compatibility audit

Source inspection used the supplied client bytecode; function indices are audit
references, not constants used by the mod.

- Live (hlboot(8).dat): bytecode 4, SHA-256 `7d0c189415ad6832b11da0fafda29eaaa2a41f93330c4489942820b495e1df89`.
- PTR (hlboot(9).dat): bytecode 6, SHA-256 `42a7ee2e85ed9166510bdc7df2bfddb8ecebcd10917a3fdea94a8bc4f381e5ed`.

## Native input ownership

`PlayerController.updateInputs` in the old live client does not query LockTarget.
The new PTR queries it and calls leaveLock or lockAutoTarget itself. The old mod's
postfix repeats that same press and reverses the native result. The initial Combat
migration added automatic native-input detection to Fix Target Lock. That change
has since been reverted at the maintainer's request: Fix Target Lock retains its
original input handling, attack targeting, feature flag, quick cast and camera
controls. More Settings does not change native lock input handling.

## Camera

Both clients' GameCamera.postUpdate have the same lock-steering block. Its only
writes to yaw/direction and pitch multiply the angular correction by
MathX.smoothLerp(Const.Camera.LockRotateSpeed, dt). The function computes
`1 - exp(-speed * dt)`, giving exactly zero at speed zero. More Settings temporarily
sets only this speed to zero for that call and restores its exact prior value.
Nested updates restore in stack order. The next GameApp update/disposal recovers
an unfinished scope if a native camera update threw.

Const.Camera.TargetLock, Hero.lockedTarget and input state are never changed by
the camera option. Water avoidance and BaseCamera.postUpdate still run. The new
PTR's gamepad recenter on a failed lock attempt (no target) remains native.

## Quick cast

Both clients enter the Aiming job through UnitController.startTargetMode. The
job ignores confirmation on its first frame, then confirms through AimSkillConfirm
or isPressedWithoutMode(originalSkillInput), and exits through setJob on cast or
cancel. More Settings substitutes a latched release only for the latter query
inside the owning local controller update. It does not replace callbacks or targets.
The release check follows the current mutable Input.checkActive closure and the
same native keyboard/gamepad/modifier bindings, temporarily bypassing the aiming
input mode and restoring that flag even when the release read throws.

## Validation

CombatTest exercises release timing, controller ownership, cancellation/job
changes, disabled/focused input, failures, nested camera scopes, interrupted-update
recovery and settings migration. The reverted Fix Target Lock native-input
detection and its NativeLockInputTest are no longer part of the build.
Combat tests also run as real HashLink bytecode, including malformed JSON
values that the Haxe interpreter alone can handle differently. Both full mods
compile against HLX. In-game aiming and camera feel still require
live/PTR play-testing; automated checks do not simulate the renderer or server.
