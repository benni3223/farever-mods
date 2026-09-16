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
- A server-synchronized Rift countdown above the map, with upcoming and open portal markers.
- Red Rift alerts during the final 15 minutes, including an arrow when the destination is off-screen.
- Adjustable zoom, size, and transparency.
- Marker scale slider resizes icons and all arrows together.
- Left or right corner placement (right by default) with X/Y offsets from 0–100% in 1% steps.
- Directional player arrows and markers for enemies, resources, NPCs, obelisks, and respawn points.
- Distinct icons for Guild Merchants, Demon Huntresses, and crafting, upgrade, and recycling stations.
- Soulstone summoning circles with rune-ring and crystal markers.
- Unopened treasure chest, undiscovered secret orb, and activity markers.
- Hide completed activities while keeping ascensions and dungeons visible, with separate options to hide either.
- Independent enemy filters for Codex XP completion, full mastery, and target dummies.
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
| Target dummies | Tan practice dummy on a wooden cross, with a red bullseye |
| Companions | Green pawprint; thick yellow ring for sparkling variants |
| Activities | Purple square with a white four-point star |
| Ascensions | Gold device with a bright cyan core |
| Dungeons | Stone doorway with a purple and cyan portal |
| Upcoming Rift | Three red horned demons |
| Open Rift Portal | Jagged pink tear with a dark interior |
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

**Show Rift timer** and **Rift alerts** follow the north setting in **General**, both on by default. The `mm:ss` countdown sits above the minimap with a slightly larger gap than the hover caption. It uses the native Rift event timer when available, otherwise the game's Rift frequency and synchronized server clock. A local top-of-the-hour fallback is used only if native timing is unavailable; fallback time never supplies a guessed portal location. The countdown advances to the next Rift when the current one opens.

Rift locations follow the replicated event's selected portal. Before the event is announced, the upcoming marker uses the same candidate order, event-time seed, and isolated native random generator as the game's own Rift selection. Open portals use the live event state and disappear when the portal closes. If consecutive Rifts choose the same location, the open icon takes precedence over the upcoming icon. Rift markers follow **Show activities**, but completion filters never hide them.

With **Rift alerts** enabled, the countdown turns red at **15:00** or less. A red arrow without a ring or height indicator points to the next Rift until its upcoming/portal marker enters view, including partial visibility. This follows zoom, rotation, and both minimap shapes. Alerts work independently of timer visibility and can still guide you when activity markers are disabled. Definitions, selected locations, and icon geometry are cached; native event state is sampled five times per second and text changes only when its displayed second or colour changes. These features only read game state and do not send server commands.

**Show soulstone summoning circles** is on by default in **Markers**. These landmarks use the world's element definitions and identify interactions that consume an item of type **Soulstone**. They remain visible without a soulstone in your inventory and are independent of activity-completion filters. Locations and elevation come from the native world prefab; definitions and icon geometry are cached.

**Show in left corner** defaults to off, placing new installations on the right. Existing saved corner preferences are preserved.

**X offset %** and **Y offset %** are in **General**, both defaulting to **0%**. X moves right from the left corner, or left from the right corner; Y always moves down. **50%** centers the minimap on that axis. **100%** reaches the opposite screen edge with the same 24 UI-pixel margin as the starting edge, including the map's border. Position updates with minimap size, window size, and UI scale. Both map shapes and their hover/zoom controls move together.

The **Activities** section includes **Show activities**, **Hide completed activities** (on by default), **Hide ascensions**, and **Hide dungeons** (both off by default). Completed ascensions and dungeons remain visible unless hidden with their own option. **Show activities** controls all three categories. Other activities, including rifts, still follow **Hide completed activities**. Markers use the game's world-map locations, including overworld entrances for instanced activities.

**Hide mastered Codex enemies** filters at each enemy's final Codex mastery threshold. **Hide partially completed Codex enemies** filters at the Codex XP-reward milestone. Both options are in **Enemies** and default to off; existing saved preferences are preserved. To keep enemies visible until full mastery, turn **Hide mastered Codex enemies** on and **Hide partially completed Codex enemies** off. If both are enabled, the earlier completion milestone hides the marker. Both filters read the game's thresholds for normal, large, elite, and boss enemies and compare them with the current character's kill count.

**Hide target dummies** is off by default in **Enemies**. Dummies have their own marker and use the game's native Dummy group, independent of their names or Codex progress. **Show enemies** controls them too. The former **Hide enemies without Codex entries** option has been removed; its old saved value no longer hides anything. Other enemies without Codex entries stay visible.

Settings use HLX's native persistence at `hlx/config/minimap/config.json`. Better Mod Settings is optional; the mod works with its defaults without it.

## Building

Use Haxe 4.3.7 and the HLX runtime:

```sh
haxelib git hlx-runtime https://github.com/hlx-framework/hlx-core.git main hlx-runtime/src
cd minimap
haxe compile.hxml
```

Run the marker classification, activity visibility, Rift schedule/state, Codex milestone, percentage-position, clipping, and compass regression tests with `haxe test.hxml` (no game or HLX runtime required).

Output: `build/minimap/minimap.hl`. The independent workflow packages this project and publishes releases for `minimap/v*` tags.
