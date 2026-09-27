# Farever Fix Target Lock

[Builds](https://github.com/xWink/farever-mods/actions/workflows/build-fix-target-lock.yml) · [Releases](https://github.com/xWink/farever-mods/releases?q=fix-target-lock&expanded=true)

An unofficial HLX mod that restores **Lock Target** on older Farever clients.

**Deprecation has begun.** The current PTR handles target locking natively, so this mod is no longer needed there. **Quick cast** and **Disable target-lock camera movement** now live in [More Settings → Combat](../more-settings/). Install the updated More Settings build and remove or disable Fix Target Lock on PTR; keep its configuration file for preference migration.

This updated build also stands down automatically when the game's own input handler checks Lock Target, so it can remain installed for the older live client without undoing PTR's native lock. Older Fix Target Lock builds toggle the same press a second time on PTR and must be removed, disabled, or updated.

Look at an enemy and press Farever's existing Lock Target binding to lock it. Press the same binding again to unlock. While locked, Farever routes single-target attacks to that enemy even if another enemy moves under the crosshair. Area-of-effect and point-targeted skills keep their normal targeting.

The mod uses Farever's existing `lockedTarget`, `SkillTarget`, and `hard-lock` HUD systems rather than implementing a separate combat targeting system.

For every attack that Farever immediately submits as `Target(autoTarget)`, including normal staff attacks, the mod replaces the last-second `autoTarget` choice with a native `SkillTarget.Target` containing the locked enemy. This prevents another enemy under the crosshair from stealing the attack. Skills that enter Farever's manual point/ground-targeting mode continue through the original targeting path

## Installation

**Required:** HLX Core, [Better Mod Settings](https://www.nexusmods.com/farever/mods/10), and [Mod Update Alerts](https://www.nexusmods.com/farever/mods/17). A missing dependency shows a desktop error naming what to install and closes Farever before this mod starts.

Install the **complete archive**, including the `implementation/` subfolder. Missing or mismatched implementation files also stop startup with a reinstall message.

### Easy Installation

1. Download the mod with Vortex on [NexusMods](https://www.nexusmods.com/farever/mods/8)

### Manual Installation

1. Install [HLX Core](https://www.nexusmods.com/site/mods/2118?tab=files) in the Farever game directory.
2. Install [Better Mod Settings](https://github.com/xWink/farever-mods/tree/main/better-mod-settings) (required) to configure the mod in-game.
3. Download the latest build artifact ZIP. Install it with Vortex, or extract it directly into the Farever game directory; the archive already contains `hlx\mods\fix-target-lock\fix-target-lock.hl`.
4. Fully close and relaunch Farever.

## Usage

Open **Mod Settings** from Farever's Game Menu to configure the mod.

- **Enable** restores the target-lock feature. Disabling the mod clears the current lock and restores Farever's original feature flag.
- **Auto-unlock when target dies** clears the lock as soon as the locked enemy is defeated or despawns. It is enabled by default.
- **Press Lock Target to switch targets** changes the lock directly to Farever's current `autoTarget` when another enemy is aimed at. Pressing it without another valid target still unlocks normally. It is disabled by default.
- Quick cast and camera controls are configured in **More Settings → Combat**. Their old saved values remain available for one-time migration; this mod no longer hooks those features.
- Use Farever's normal **Lock Target** key or controller binding to toggle a target lock.
- Farever's native animated hard-lock indicator appears above the locked enemy.

Settings are saved to `Farever\hlx\config\fix-target-lock\config.json`.

## How it works

Older live clients contain a nearly complete target-lock implementation, but `PlayerController.updateInputs()` does not check the `LockTarget` input action. On those clients, the mod adds that missing toggle behavior:

- unlocked + Lock Target: calls Farever's `lockAutoTarget()` using the enemy currently selected by its normal auto-targeting code;
- locked + Lock Target: calls Farever's `leaveLock()`;
- enabled: keeps Farever's `Const.Camera.TargetLock` feature flag active.

Farever already stores the target on `Hero.lockedTarget`, feeds target-based skills through `SkillTarget.Target`, leaves `SkillTarget.Point` behavior intact, and marks the corresponding enemy widget with the native `hard-lock` style.

On clients that check `LockTarget` inside the native input update, all legacy input, forced attack-target, feature-flag, and auto-unlock repairs are bypassed. Detection observes the native input query even when unpressed and excludes this mod's own later query; it does not guess a version from unrelated game classes.


## Building (for developers)

Requires Haxe 4.3.x and `hlx-runtime`.

```text
haxelib git hlx-runtime https://github.com/hlx-framework/hlx-core.git main hlx-runtime/src
cd fix-target-lock
haxe compile.hxml
```

Output: `build/fix-target-lock/fix-target-lock.hl`

## Compatibility

This mod relies on Farever's internal HashLink layout. Game updates can require a rebuild or adjustment.

## Disclaimer

Unofficial community mod. Not affiliated with or endorsed by Farever's developers, HLX, Steam, or Valve.
