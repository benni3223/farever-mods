# Farever Minimap

[Builds](https://github.com/xWink/farever-mods/actions/workflows/build-minimap.yml) · [Releases](https://github.com/xWink/farever-mods/releases?q=minimap%2F&expanded=true)

A compact overworld minimap with a centered player arrow.

## Installation

### Easy Installation

1. Download the mod with Vortex on [NexusMods](https://www.nexusmods.com/farever/mods/15).

### Manual Installation

1. Install [HLX Core](https://www.nexusmods.com/site/mods/2118?tab=files) in your Farever game folder.
2. Download the latest successful [build artifact](https://github.com/xWink/farever-mods/actions/workflows/build-minimap.yml).
3. Extract the ZIP into the game folder. It contains `hlx/mods/minimap/minimap.hl` and `configFormats.json`.
4. Install [Better Mod Settings](../better-mod-settings/) for in-game controls, then fully restart Farever.

## Highlights

- A square or circular minimap using Farever's own map artwork.
- Follows your position an arrow showing your character's facing direction.
- Fixed orientation, character-following rotation, or camera-following rotation.
- An outlined N and compass needle track north along the minimap edge.
- Adjustable zoom, size, and transparency.
- Marker scale slider resizes icons and all arrows together.
- Left or right corner placement with X/Y offsets from 0–100% in 1% steps.
- Directional player arrows and markers for enemies, resources, NPCs, obelisks, and respawn points.
- Distinct icons for Guild Merchants, Demon Huntresses, and crafting, upgrade, and recycling stations.
- Soulstone summoning circles with rune-ring and crystal markers.
- Unopened treasure chest, undiscovered secret orb, and activity markers.
- Hide completed activities while keeping ascensions and dungeons visible, with separate options to hide either.
- Independent enemy filters for Codex XP completion, full mastery, and enemies without Codex entries.
- Companion markers with an option to hide variants already in your collection.
- Yellow-ringed edge arrows guide you toward uncollected sparkling companions when their markers are out of view.
- Yellow rings highlight sparkling enemies and bosses.
- Individual plant and ore type filters.
- Hover over markers to see their names below the map
- Hover the mouse over the map and scroll to zoom.
- Up/down arrows show markers more than 15 metres above or below you.

The minimap covers the overworld and hides in other instances. Live player, enemy, gatherable, and chest markers are limited to entities currently sent to your client. Harvested plants and ore disappear until they respawn. Opened or inactive chests are hidden; secret orbs disappear once recorded as discovered by the game.

| Marker | Appearance |
| --- | --- |
| Your character | Flat ivory arrow |
| Other players | Larger light-blue arrow showing facing direction |
| Plants | Green leaf |
| Ore | Gray stone |
| Enemies | Red circle; larger for bosses; thick yellow ring for sparkling variants |
| Companions | Green pawprint; thick yellow ring for sparkling variants |
| Activities | Purple square with a white four-point star |
| Ascensions | Gold device with a bright cyan core |
| Dungeons | Stone doorway with a purple and cyan portal |
| Respawn points | White cross |
| Obelisks | Broad grey stone idol with a split crown and gold inlays |
| Soulstone summoning circles | Purple rune ring surrounding a pink faceted soulstone |
| NPCs | Yellow circle |
| Guild Merchants | Yellow $ |
| Demon Huntresses | Purple horned face |
| Spark Recycler | Mint recycling arrows |
| Weapon Upgrade | Light-blue sword and upward arrow |
| Crafting Station | Orange hammer and workbench |
| Chests | Orange rectangular treasure chest |
| Undiscovered secret orbs | Gold orb with an ivory centre and broken purple rings |

**Show NPCs** also controls the Guild Merchant, Demon Huntress, and station icons. NPC markers draw in front of all other map elements. All player markers, including your character arrow, draw behind other marker types so crowds cannot obscure them. **Show chests** and **Show secret orbs** are separate options in the **Markers** section.

Secret orb tooltips always read **Secret Orb**. Sparkling companion alerts disappear whenever any part of the companion marker is visible, and reappear when it leaves the map. This follows zoom and rotation for both map shapes. Alerts still work when normal companion markers are disabled. Their yellow rings have no height arrows; ordinary markers retain their height indicators.

**Show north indicator** is on by default in **General**. The north indicator stays at the top of a fixed map and follows north around the edge of a rotating map. It scales with the other markers. Compass and alert geometry is cached; movement updates only their transforms and visibility. Turning it off also frees its edge space for sparkling companion alerts.

**Show soulstone summoning circles** is on by default in **Markers**. These landmarks use the world's element definitions and identify interactions that consume an item of type **Soulstone**. They remain visible without a soulstone in your inventory and are independent of activity-completion filters. Locations and elevation come from the native world prefab; definitions and icon geometry are cached.

**X offset %** and **Y offset %** are in **General**, both defaulting to **0%**. X moves right from the left corner, or left from the right corner; Y always moves down. **50%** centers the minimap on that axis. **100%** reaches the opposite screen edge with the same 24 UI-pixel margin as the starting edge, including the map's border. Position updates with minimap size, window size, and UI scale. Both map shapes and their hover/zoom controls move together.

The **Activities** section includes **Show activities**, **Hide completed activities** (on by default), **Hide ascensions**, and **Hide dungeons** (both off by default). Completed ascensions and dungeons remain visible unless hidden with their own option. **Show activities** controls all three categories. Other activities, including rifts, still follow **Hide completed activities**. Markers use the game's world-map locations, including overworld entrances for instanced activities.

**Hide completed Codex enemies** filters at the Codex XP-reward milestone. **Hide mastered Codex enemies** filters at each enemy's final Codex mastery threshold. Both options are in **Enemies** and default to off; existing saved preferences are preserved. To keep enemies visible until full mastery, turn **Hide completed Codex enemies** off and **Hide mastered Codex enemies** on. If both are enabled, the earlier completion milestone hides the marker. Both filters read the game's thresholds for normal, large, elite, and boss enemies and compare them with the current character's kill count.

Settings use HLX's native persistence at `hlx/config/minimap/config.json`. Better Mod Settings is optional; the mod works with its defaults without it.

## Building

Use Haxe 4.3.7 and the HLX runtime:

```sh
haxelib git hlx-runtime https://github.com/hlx-framework/hlx-core.git main hlx-runtime/src
cd minimap
haxe compile.hxml
```

Run the marker classification, activity visibility, Codex milestone, percentage-position, clipping, and compass regression tests with `haxe test.hxml` (no game or HLX runtime required).

Output: `build/minimap/minimap.hl`. The independent workflow packages this project and publishes releases for `minimap/v*` tags.
