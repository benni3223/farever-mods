# More Settings

[Builds](https://github.com/xWink/farever-mods/actions/workflows/build-more-settings.yml) · [Releases](https://github.com/xWink/farever-mods/releases?q=more-settings%2Fv&expanded=true)

Client settings for **Farever**: autorun, chat filtering, temporary audio levels, and separate ally presentation controls for rifts, dungeons, and the overworld. Previously called **More Audio Settings**.

## Settings

Open **More Settings** in [Better Mod Settings](../better-mod-settings/).

| Category | Controls | Defaults |
| --- | --- | --- |
| General | Disable profanity filter; Hide UI hotkey; Autorun hotkey | Profanity option on (imports previous preference); Hide UI defaults to F2; autorun unassigned |
| Unfocused Volume | Adjust unfocused volume; Unfocused volume % | On; 0% |
| Fast Travel Music | Adjust fast travel music volume; Fast travel music volume % | Off; 0% |
| Rift Effects | Hide ally attacks; Hide ally buffs; Hide allies | All off |
| Dungeon Effects | Hide ally attacks; Hide ally buffs; Hide allies | All off |
| Overworld Effects | Hide ally attacks; Hide ally buffs; Hide allies | All off |

The profanity option applies to displayed player text and keeps HTML escaping. Character-name validation is unchanged.

**Hide UI hotkey** rebinds the game's existing UI visibility shortcut. Choose a key under **General**; the default is **F2**. The selected key replaces the original keyboard binding and retains the game's normal hide/show behavior and input restrictions. Typing in chat or another text field does not hide the UI. Update Better Mod Settings too: its key-capture guard prevents assigning a shortcut from hiding the settings window. Bindings use one key; Escape cancels capture.

**Autorun hotkey** toggles continuous forward movement. Movement input in any direction, attacks, skills, blocks, and dodges cancel it; jumping keeps it active. Movement and action detection follow your game's bindings, including gamepad movement. Typing or assigning a hotkey does not activate autorun. Losing focus, a blocking menu, death, travel, or a character/zone change clears it. The hotkey is unassigned by default.

The unfocused setting temporarily limits Farever's master volume and restores it on focus, including any master-volume change made in the game's options. It never raises a quieter master setting.

The fast-travel slider adjusts **only your obelisk travel music event** (`Hero_FlyToObelisk`). It leaves other music, ambience, sound effects, and all shared volume controls unchanged. 0% mutes that track; 100% keeps its normal level under your existing music/master settings. Slider changes apply during a trip, and disabling the option restores the track's original gain. Unfocused volume works independently, so it can still quiet the whole game when you alt-tab during travel. Existing fast-travel preferences are preserved.

**Hide ally attacks** hides the visuals and sounds of friendly players' damaging or harmful abilities with no beneficial component. **Hide ally buffs** covers healing, shields, beneficial statuses, and utility abilities. Mixed damage/support abilities belong to the buffs category so attack hiding preserves useful support effects. Classification follows native skill data and referenced subskills/statuses.

**Hide allies** hides friendly player models and equipment independently of their abilities. Names and other UI remain visible. Your own model, abilities, summons' effects, and buffs you cast on other players remain visible. Enemy and duel/PvP opponent effects remain visible. Other players' buffs applied to you follow the caster's filter.

Rifts take precedence over dungeons; dungeon instances (including boss instances) use Dungeon Effects; World maps use Overworld Effects. Unknown locations are left visible. Visibility options are client presentation changes: skills, damage, healing, targeting, animation callbacks, and network state continue normally.

## Installation and upgrade

1. Install [HLX Core](https://github.com/hlx-framework/hlx-core) and [Better Mod Settings](../better-mod-settings/).
2. Close Farever. Remove the old **binary and settings descriptor** from `hlx/mods/more-audio-settings/` (or `hlx/mods/mute-unfocused/`). Keep old configuration files for migration.
3. If the standalone Disable Profanity Filter mod is installed, remove its binary and settings descriptor as well so this setting has one owner. Keep its configuration file.
4. Install `farever-more-settings.zip` with Vortex, or extract it into the Farever game directory. Extract the **whole archive**: it contains `hlx/mods/more-settings/more-settings.hl`, its `configFormats.json`, and `hlx/plugins/more-settings/more_settings_audio.hdll` for individual music-event volume control.
5. Relaunch Farever.

Settings live at `hlx/config/more-settings/config.json`. On first launch, the mod imports the previous native or mod-local configuration from `more-audio-settings`, then `mute-unfocused` if needed. Existing More Settings configuration takes priority. Old files remain intact as backups. The former `enabled` setting migrates to `adjustUnfocusedVolume`.

The GitHub Actions artifact is **farever-more-settings**. Release ZIPs are **farever-more-settings.zip**; release tags use **more-settings/vX.Y.Z**.

## Build and verification

Requires Haxe 4.3.7 and HLX runtime:

```sh
haxelib git hlx-runtime https://github.com/hlx-framework/hlx-core.git main hlx-runtime/src
cd more-settings
haxe test.hxml
haxe compile.hxml
```

Output: `build/more-settings/more-settings.hl`. For a complete install, also build the Windows x64 audio plugin with MinGW (`gcc-mingw-w64-x86-64` on Ubuntu):

```sh
bash native/build.sh
cc -std=c11 -Wall -Wextra -Werror tests/event_volume_test.c -o build/event-volume-test
build/event-volume-test
```

The plugin output is `build/native/more_settings_audio.hdll`; install it in `hlx/plugins/more-settings/`. It resolves the public FMOD event-volume API from the game's loaded `fmodstudio.dll`; no game or FMOD binaries are bundled. If the plugin is missing or unavailable, an audio error is logged and the mod never falls back to changing a global volume for travel.

Regression tests exercise the production UI binding adapter, autorun controller, volume controller, region/ability policy, classifier, and presentation tracker with a simulated native adapter. CI requires those tests plus native bridge tests before compiling and packaging both binaries. Native API and bytecode inspection supplements these tests; movement, rendering and audio still require in-game testing after game updates.

The mod avoids repeating FMOD writes on unchanged frames. Model membership and adoption of existing effects refresh at most five times per second. Native member lookup and skill classification are cached; disabled filters avoid entity scans. Rendering hooks never skip skill execution or character animation updates.
