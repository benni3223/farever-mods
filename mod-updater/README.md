# Mod Updater

[Builds](https://github.com/xWink/farever-mods/actions/workflows/build-mod-updater.yml) · [Releases](https://github.com/xWink/farever-mods/releases?q=mod-updater&expanded=true)

Checks Nexus Mods for updates in the background once per game launch. When updates
are found, a native window lists mod names, installed versions, and available
versions. Close it with its X or Escape to keep playing. To update, close Farever,
open Vortex, check for updates, install them, and deploy.

The checkbox **Don't remind me again about these versions** remembers the listed
available versions immediately. Unchecking it restores the prior preference.
If any mod later has a newer update, or another mod gains an update, the next
launch shows the **entire outstanding update list**, including previously dismissed
updates. Installing some updates or a temporary failure to check one mod does not
erase remembered versions. Large lists have Previous/Next pages.

## Installation

Requires HLX Core 0.0.8 or newer for the new/PTR client. Also supports the current
live client. No ImGui or Better Mod Settings dependency, Nexus login, API key,
Premium subscription, or external executable.

Install the build ZIP with Vortex or extract it into the Farever game directory.
The installed file is `hlx/mods/mod-updater/mod-updater.hl`.
This mod only notifies; it never downloads, installs, or changes other mods.

## How installed versions are identified

HLX binaries in this repository do not contain a standard release-version field.
The checker reads local data without opening Vortex's live database or accessing
its credentials:

1. Vortex's `vortex.deployment.*json` records select mods actually deployed into
   this game directory. Only present, unmodified deployed code/package files
   (`.hl`, `.dll`, `.hdll`, `.pak`) qualify.
2. The newest valid Vortex full state backup under
   `%APPDATA%/Vortex/temp/state_backups_full/` supplies Nexus IDs, names, and
   installed versions when available. Disabled/staged-only mods are excluded.
3. Otherwise a standard Nexus archive identifier in the deployment record is
   checked against Nexus's actual mod ID, version, and upload timestamp. The
   numeric version is **not guessed from the folder name**.
   Farever mods and tools published under Nexus's Site category are supported.
4. Manual installs can include the opt-in metadata below.

This cannot identify every arbitrary manual install, renamed archive, portable
Vortex installation, or mod lacking version metadata. Missing/stale deployment
records, changed binaries, unknown version schemes, and unavailable Nexus
metadata are logged as `[Mod Updater]` and skipped; they are never reported as
up to date. Vortex need not be running, but mods must have been deployed.

The public [Nexus GraphQL API](https://api.nexusmods.com/v2/graphql) supplies current
page versions and file metadata. An alert requires a newer numeric/SemVer version
with a matching public main/update file. Optional, archived, or removed files alone
do not trigger alerts. Only requested Nexus game domains and mod IDs leave the
computer; no file paths, binaries, Vortex database, or credentials are uploaded.
Each identity is checked once per launch, using a worker thread, verified TLS,
bounded responses, request timeouts, and an overall time budget. Network failures
do not block startup; the next launch retries. Public API changes may require a
checker update.

Discovery format references: Vortex's
[deployment manifest](https://github.com/Nexus-Mods/Vortex/blob/master/src/renderer/src/extensions/mod_management/types/IDeploymentManifest.ts),
[deployed files](https://github.com/Nexus-Mods/Vortex/blob/master/src/renderer/src/extensions/mod_management/types/IDeploymentMethod.ts),
and [full state backups](https://github.com/Nexus-Mods/Vortex/blob/master/src/renderer/src/store/store.ts).

## Manual-install metadata

A mod author can package `update-info.json` beside their binary:

```json
{
  "name": "Example Mod",
  "domain": "farever",
  "modId": 123,
  "version": "1.2.3",
  "binary": "example.hl",
  "sha256": "<64-character SHA-256 of the packaged binary>"
}
```

Use the real Nexus mod ID and the installed release version. Regenerate the hash
for each build. Mismatched hashes are ignored so stale metadata cannot label a
replacement binary as an older release. Mod Updater itself can use this metadata
once it has a Nexus page; until then, it has no Nexus identity to check.

Reminder preferences are stored in `hlx/config/mod-updater/reminders.json`.
Remove that file and its `.bak` backup while Farever is closed to reset all
suppressed reminders.

## Build and test

```sh
haxelib git hlx-runtime https://github.com/hlx-framework/hlx-core.git main hlx-runtime/src
haxe test.hxml
haxe compile.hxml
```

Tests cover numeric/prerelease ordering, new-version reminders, partial update
lists, persisted suppression, archive matching, stale deployments, and manual
metadata hashes. Native popup layout and deployment discovery should also be
verified in-game with real Vortex installations.
