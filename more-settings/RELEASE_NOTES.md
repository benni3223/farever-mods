# More Settings

## Boss health

- Added **Show boss health** under **General**, off by default.
- Displays current boss HP as `123,456 (100%)`, updating during the fight.
- Preserves native percentage formatting and shield information; disabling restores the original label.
- Supports both current and new/PTR clients. Existing numeric HP labels from the PTR resource-display option remain unchanged.

## Hide UI keybinding

- Added **Hide UI hotkey** under **General**, defaulting to F2, with live rebinding.
- Reuses the native ToggleUI action and keeps input-mode checks and hide/show behavior.
- Prevents activation while typing; update Better Mod Settings for protection during key capture.
- Existing audio and ally-presentation preferences remain intact.

## Earlier changes

More Audio Settings is now **More Settings**, including the project, module, settings tab, GitHub workflow, artifact, and ZIP names.

- Added Disable profanity filter from the standalone mod, retaining text escaping.
- Added fast-travel volume controls that cooperate with unfocused volume and restore the current master preference correctly.
- Added independent Hide ally attacks, Hide ally buffs, and Hide allies controls for Rift Effects, Dungeon Effects, and Overworld Effects.
- Preserved local-player presentation, enemy presentation, ability timing, and gameplay/network state.
- Migrated previous audio preferences automatically. New visibility and fast-travel controls default off.

Install `farever-more-settings.zip` with HLX Core and Better Mod Settings. Before launching, remove the old More Audio Settings binary/settings descriptor and any installed standalone Disable Profanity Filter binary/settings descriptor. Keep their configuration files until migration completes. See [README.md](README.md) for details.

Build and automated regression checks are supplemented by native bytecode inspection. Multiplayer visual/audio behavior needs in-game testing.
