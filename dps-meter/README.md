# DPS Meter

[Builds](https://github.com/xWink/farever-mods/actions/workflows/build-dps-meter.yml) · [Releases](https://github.com/xWink/farever-mods/releases?q=dps-meter&expanded=true)

An HLX combat meter with a movable, resizable native Farever window and boss-kill
uploads to [Farever Logs](https://fareverlogs.fr/).

## Installation

### Easy Installation

1. Install [HLX Core](https://github.com/hlx-framework/hlx-core) and [Better Mod Settings](https://github.com/xWink/farever-mods/tree/main/better-mod-settings) with Vortex.
2. Download DPS Meter with Vortex on [NexusMods](https://www.nexusmods.com/farever/mods/11).

### Manual Installation

1. Install [HLX Core](https://github.com/hlx-framework/hlx-core).
2. Install [Better Mod Settings](https://github.com/xWink/farever-mods/tree/main/better-mod-settings) to configure the meter in-game.
3. Download the latest DPS Meter [release](https://github.com/xWink/farever-mods/releases?q=dps-meter&expanded=true) or the `farever-dps-meter` artifact from a successful [build](https://github.com/xWink/farever-mods/actions/workflows/build-dps-meter.yml).
4. Extract the ZIP directly into the Farever game directory. The archive already contains `hlx/mods/dps-meter/`.
5. Launch Farever.

All mod files are contained in `hlx/mods/dps-meter/`. Upload settings
(`uploader.ini`), upload history (`uploader.log`), and queued reports (`logs/`)
also live in this folder. Local fight charts live in `history/`. An external
uploader is not required.

Use DPS Meter in place of the original Group DPS `dinput8.dll` collector to avoid
running two collectors that export the same encounters. Keep DLLs belonging to
unrelated mods. Installation does not replace `uploader.ini`, `group-dps.ini`, or
saved meter settings.

### Upgrading from the external uploader

Close Farever and let the old uploader finish before upgrading. Existing
`uploader.ini` settings and queued logs in the mod folder are reused automatically.
You can remove the old `uploader.exe`, `start-uploader.ps1`, and
`UPLOADER-NOTICE.md` from `hlx/mods/dps-meter/`. Uploads now run while Farever is
open; unsent reports resume on the next launch.

If your uploader files are still in the game directory, move their
`uploader.ini`, `uploader.log`, and uploader-owned `logs/` contents into
`hlx/mods/dps-meter/`, preserving the `logs/` subdirectories. Do not overwrite
existing files or copy reports into both queues. Existing files in the game
directory are not migrated automatically. The old game-folder `uploader.exe`
can be removed if no other mod uses it.

## Highlights

- **Live party DPS:** Damage, DPS, and team contribution with class-colored bars and clickable skill breakdowns using game skill names and each skill's share of that player's damage.
- **Summon tracking:** Minion damage credited to its owner and the skill that summoned it.
- **Native, customizable window:** Move, resize, lock, and scroll the meter, with optional automatic hiding and a smooth fade.
- **Rift tracking and recaps:** Separate gate and boss phases covering all players present, with both charts in one post-rift recap.
- **Fight history:** Browse Boss Dungeons, Classic Dungeons, World Bosses, and Other encounters; choose an attempt by duration, your DPS, and local date/time, then reopen its player and skill charts.
- **Kill notifications:** Optional boss kill totals and Codex progress popups, including counts for completed entries.
- **Automatic log uploads:** Send completed boss encounters to [Farever Logs](https://fareverlogs.fr/) in the background, with no external application.
- **Better Mod Settings integration:** Customize display options and hotkeys, with settings and window placement saved between sessions.

## Reviewing past fights

Click the **book icon** on the left of the meter's header. Choose a category and an encounter name,
then an attempt from the newest-first list. Each attempt shows its duration,
your character's total DPS, local date and time, and character name. The DPS
uses the same duration and one-second minimum as the live chart. If an older
report did not identify your character, the list shows that your DPS is unavailable.

Selecting an attempt replaces the list with that fight's damage chart. Click a
player to see their skills; click a skill row to return to the player chart.
**Back** returns to the same page of attempts, then to the encounter names.
The encounter and attempt lists have page controls and scroll when space is limited. The history
window stays open independently of the live meter's out-of-combat fade.
The footer shows the full absolute path to the local chart archive. Section
headings use the same larger bold style as Better Mod Settings titles.

Categories follow the running game's activity inheritance: **Boss Dungeons**
uses Boss activities, **Classic Dungeons** uses other Dungeon activities, and
**World Bosses** contains rift phases. Only actual boss encounters enter the
dungeon categories; ordinary combats, elites, and other activities appear in
**Other**. New bosses inheriting these activity types are handled automatically;
there is no list of hardcoded boss names.

New charts retain their activity ID and category. For older imported reports,
the browser uses those original reports' activity metadata where it is still
available. Charts made by the first history release omitted activity metadata;
when their context cannot be recovered exactly, they remain in **Other**.
Rift phase names can still identify old rift charts. Game-provided names replace
unit IDs where available. Skill labels use the game's name resolver, including
references from projectiles and other child effects to their named abilities;
the recorded skill IDs and damage totals remain unchanged.

History records ordinary combats, boss attempts, and both rift phases. Combats
without a boss name appear under **Other combat**. A fight still in progress
when you leave an area or exit normally is also preserved. Completed rift phases
keep their separate **Rift: Gates** and **Rift: [boss name]** charts.

All fight history and sent reports are kept indefinitely, across game restarts
and character changes. The former uploader `keep_days` option is ignored; no
age-based cleanup runs. Local history works even with log uploads disabled,
and ordinary or abandoned fights are never submitted as completed boss reports.
The first launch imports surviving reports from `logs/`, `logs/sent/`, and
`logs/rejected/` without submitting them again. Previously deleted reports
cannot be recovered. Older reports use their original encounter names and an
estimated start time derived from the recorded export time and duration.

Disk writes, history indexing, and chart reads run on the uploader worker.
Only compact summaries are kept in its index; the browser requests one page
or one chart at a time. Back up `hlx/mods/dps-meter/history/` to preserve your
local charts when reinstalling the mod or moving to another computer.
