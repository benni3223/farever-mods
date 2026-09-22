# Loot Database

A native Farever window for weapons, items, bosses, and instances. Data comes from a JSON snapshot of the [Metaforge Farever database](https://metaforge.app/farever/database). The game does not contact the website.

## Installation

Requires [HLX Core 0.0.8 or newer](https://github.com/hlx-framework/hlx-core/releases/tag/0.0.8). Install [Better Mod Settings](../better-mod-settings/) to change the hotkey.

Copy `loot-db.hl`, `configFormats.json`, `README.md`, and `database.json` into `hlx/mods/loot-db/`. Do not copy this folder into the game yourself if you are only building it; the files in `build/` and `data/` stay in the repository until you install them.

Open the window with the **Loot** button on the left of the HUD, or with the hotkey under **Loot Database**. The hotkey is unset until you bind one.

## Browser

- **Instances** lists dungeons, world bosses, and rifts. A dungeon page shows its bosses, their skills, and drop groups with the site's recorded chances.
- **Bosses** and **Items** / **Weapons** search by name. A weapon shows its skills. An item shows who drops it and in which instance.
- **Map** pans and zooms Farever's own overworld tiles. Pins are dungeon and world-boss entrances. Click a pin to open that instance. **Show on map** centers the entrance. The map can be dragged; the scroll wheel zooms. Tiles load after you have entered Siagarta at least once this session.

## Refreshing the data

From `loot-db/`:

```sh
python tools/export.py
```

The script reads Metaforge's SvelteKit page data and overwrites `data/database.json`. Copy that file over `hlx/mods/loot-db/database.json`. A data refresh does not require a new `.hl`.

Re-run it when the site changes. The command prints item, creature, boss, instance, and pin counts. An empty catalog is a failed run.
