# Character appearance editor: native boundary audit

Inspected the supplied live `hlboot(8).dat` (bytecode 4, SHA-256
`7d0c189415ad6832b11da0fafda29eaaa2a41f93330c4489942820b495e1df89`) and
PTR `hlboot(9).dat` (bytecode 6, SHA-256
`42a7ee2e85ed9166510bdc7df2bfddb8ecebcd10917a3fdea94a8bc4f381e5ed`).
Function indices below are evidence only; runtime code resolves names.

| Native boundary | Live / PTR | Verified behavior |
| --- | --- | --- |
| `CharacterCreationScreen.getTemplateValues` | 25855 / 27062 | The three body choices are 0, 1, 2. |
| `CharacterCreationScreen.getBodyPart` | 25863 / 27070 | Filter by body-part type and player flag bit 1. Hair = 0, eyebrows = 2, facial hair = 3. |
| Creation screen initialization | Both clients | Gradient `playerCustomization` must be true; masks are skin 4, eyes 2, hair 1. Shape categories are Eyes, Face, Nose, Lips. Hair color updates both primary and secondary colors. |
| `UnitSkinData.copySkinData` | 22963 / 24064 | Copies basic fields and allocates a fresh native array and shape records for active blend shapes. |
| `Unit.set_skinData` | 4682 / 4744 | Client-owned replicated property; a replacement object marks the property dirty. Local owner needs an explicit visual refresh. |
| `Unit.set_skin` | 4685 / 4747 | Also a client-owned property. Selects the active body model and invokes `updateSkin`. The native character editor uses it for body changes. |
| `Unit.updateSkin` | 4699 / 4761 | Model-dependent refresh. Same-model customization requires an explicit visual refresh (now `UnitView.displaySkin`; see the October 2 save audit below). |
| `HeroData.save` | 14839 / 9139 | Stores the hero's current skin data for normal character persistence. The mod does not call server save functions or admin RPCs. |
| `ColorSelector.createButton` | 25865 / 27072 | Both clients ultimately call `Texture.capturePixels` to sample each swatch (live in ColorPickButton.init; PTR in this factory). The mod now avoids both native picker classes. |
| `UnitScene.postInitUnitView` | 25758 / 21178 | Native dynamic callback computes bounds and starts an independent idle animation. Preserve rotation around the callback because live adds `viewAngle`. PTR-only `setAnim` is not required. |

The preview receives no live unit, so it cannot share the hero's animation
player or equipment. It gets a separate native skin copy via
`overrideSkinData`. Changes only touch that copy. Save creates a second copy
before using the replicated setters; subsequent preview cleanup cannot change
the saved state. World/player changes, a removed hero, a closed/rebuilt window,
and concurrent appearance replacement invalidate the session. Cancel and
Escape use normal native window removal and do not call an appearance setter.

After a reported DX12 `flushFrame`/`present` crash, inspected PTR
`DX12Driver.captureTexPixels` (24819): it records a texture copy, flushes the
frame, waits for copy/GPU work, and calls `beginFrame`. The old palette executed
this once per color while opening/rebuilding the window. This is a likely
trigger, not a GPU-reproduced diagnosis. `AppearanceSwatches` now draws the first
gradient texel via `Tile.sub` and a normal `Bitmap`, with nearest filtering on
that drawable only. It uses the existing atlas without readback, texture
allocation, disposal, shared filtering changes, or direct driver calls. The
model preview remains the native independent UnitScene.

`AppearanceTest` runs in the Haxe interpreter and actual HashLink in CI. It
checks nested draft isolation, cancel/reopen, save/retry, rejected setters,
immediate and same-model refresh, concurrent changes, stale ownership/world
state, creation-option filters, and category/button metadata. Regression tests
also run literal button labels and error-dialog messages through an XML parser:
both paths must escape text before constructing native controls. The original
raw `<` arrow and raw error message each reproduce a parse failure when their
escaping is removed. Rendering is not simulated by these tests.

Swatch regression tests exercise atlas offsets, one-texel sampling, display
size, selected framing, missing textures, and shared resource preservation.
Their strict adapter rejects native color-picker constructors, pixel readback,
texture allocation, and driver calls. Actual DX12 rendering still needs an
in-game check on the user's machine.

In-game verification still required on live and PTR: open from BMS; rotate the
preview; try all body types, palettes, hair/facial hair, eyebrows and four shape
categories; Save and check another client's view and relog persistence; cancel
using Cancel/X/Escape; reopen; resize the game; close during loading; change
world or log out while the editor is open. The game cannot be launched in the
build environment.

## Grouped appearance choices and camera zoom

The window now uses the creation screen's `Separator`, `TemplatePickButton`,
`BodyPartPickButton` and `BlendShapePickButton` components. Body has three
thumbnails; hair and face features have four choices per page with arrows and
page dots. Nine-column color grids retain `AppearanceSwatches`. A native Flow
with `Scroll` overflow contains the groups; tabs, preview, Save and Cancel stay
outside that viewport.

Audited `PortraitGen.makeFromUnitView` (live 25330 / PTR 26537): it pushes a
render target, clears, renders the scene and pops the target. Unlike the native
color swatches, it does not call `capturePixels` or read texture data back to
the CPU. Thumbnail cameras and lighting come from the same
`Items/MenuPortraitScene.prefab` used by character creation. One thumbnail is
generated per update, using a second private UnitView and skin. Hair is hidden
for eyebrow/beard thumbnails; hair and beard are hidden for face shapes.

Native shape buttons do not fully restore the default shape after rendering,
so the skin is copied afresh before every thumbnail. An absent shape array is
replaced with an empty native ArrayObj before calling native shape code.
`PortraitGen.scene` and `prefab` are restored after each capture, including
failure; the private view is detached before disposing the temporary scene.
Page changes and closing explicitly dispose thumbnail textures and clear their
reallocation closures.

The preview camera waits for UnitScene's native `needFit` countdown to finish,
then records the full-body camera position, target and projection zoom. Face
and Hair shift the camera and target together by 38% of fitted body height,
centering the upper 88% point, and multiply the native projection zoom by
1/0.38. The already-visible camera distance and near/far clipping planes stay
unchanged. Body restores the complete baseline. Before a native refit, the
original projection zoom is restored so repeated body/part changes cannot
compound the magnification. Rotation still belongs to UnitScene.

This replaces the initial close-up implementation after an in-game report that
Face/Hair hid the model. That implementation shortened camera distance to 38%
without accounting for the native clipping range, and used a skeleton transform
as a focus point without checking it against the fitted bounds. The replacement
uses the same body coordinates as the working native fit. PTR
`Camera.makeFrustumMatrix` (2080) confirms that `zoom` adjusts projection scale
independently of near/far clipping; live and PTR both expose that camera field.

After the reported thumbnail shrink on hover (and on the first body's initial
layout), thumbnail width/height are now also set through `Properties.initStyle`.
`CompBitmap` registers style handlers for both dimensions, so one-off Bitmap
setters alone are overwritten on native restyling. The pinned styles preserve
the existing absolute icon/root positions and apply before the first capture.

Appearance tests now include camera waiting/refitting/restoration, repeated
optical zoom, clipping-range preservation, mismatched skeleton coordinates,
initial thumbnail layout and hover restyling, draft isolation, default shapes,
render throttling, global context restoration on failure and texture cleanup.
They pass in the interpreter and HashLink (156 checks). Native method names and
constructor signatures were checked against both supplied clients. These
checks do not replace an in-game visual/DX12 test of the new thumbnails,
scrolling and face framing.

Regression checks also run these tests against the previous camera and portrait
implementations independently: both fail at their respective new assertions.
The fixes still need an in-game rendering check; no game/GPU run is available
in this environment.

After the reported brief zoom-out when picking hair/face options, the window
now separates completing a visual refresh from requesting a camera refit.
`postInitUnitView` starts a four-update full-body fit countdown on both clients;
it is now called only for initial loading and body-type changes. Hair, facial
hair, face features and palettes still refresh the model and thumbnails after
readiness, but retain camera bounds, projection and rotation. Audited PTR
`UnitView.updateDynamicVisuals` (15415): it updates equipment, body parts and
blend shapes without scheduling a UnitScene camera refit.


Pagination now owns a separate flow for each style's thumbnails and pager.
Arrow/page-dot clicks dirty only that row; selecting the current dot is a no-op.
A row refresh cancels its old pending captures and disposes only its textures,
then queues its replacement options. Other groups retain their native controls,
textures and outstanding capture work. Tabs and actual appearance changes still
rebuild all affected previews so they reflect the current skin. Pagination does
not reset the private UnitView, scroll position or main camera.

The scroll viewport and its content flow now explicitly use Top vertically and
Middle horizontally, with matching inline DOMKit styles. This keeps the first
heading above a tall list inside the clip region, and centers the complete
narrower content column (separators, thumbnails, page controls and palettes) in
the viewport. The shared live/PTR `content-valign`/`content-halign` handlers and
Flow alignment methods are present in both supplied clients. Visual placement
still requires the in-game check.

Pagination regressions cover already-rendered siblings, pending captures in
other rows, quick consecutive page changes, stale-capture cancellation,
per-row texture disposal, unchanged renderer/draft state and complete cleanup
when a tab or appearance change requires a full rebuild.

The appearance window is now 800 px tall, with a 560 px options viewport.
Its native scrollbar is explicitly 10 px wide and pinned to the top/right
inside the clip region using both Flow properties and inline DOMKit styles.
Resetting inherited offsets and drawing the bar after the content keeps it in
the 13 px right gutter without relying on the Options theme's positioning.
Only its width and placement are fixed: native Flow still controls visibility,
thumb height, wheel input and dragging. The relevant fields and methods are
present in both supplied live/PTR clients. In-game visibility and interaction
still need visual confirmation; the local checks do not render the native UI.

The subsequent in-game report confirmed that positioning alone did not restore
the scrollbar. The actual failure is the Block's default Stack layout. In both
clients, `Flow.reflow` (live 3181 / PTR 3214), Stack branch, clamps the measured
height to `realMaxHeight` before assigning `contentHeight`. Thus a 560 px
viewport reports 560 px of content even when its child list is much taller.
The end of reflow hides the scrollbar when `contentHeight <= calculatedHeight`;
`onMouseWheel` (live 3168 / PTR 3201) checks the same condition and ignores input.

The viewport now explicitly uses Vertical layout, with multiline disabled so
the long list cannot wrap into another column. This branch retains the child's
full height in `contentHeight` while clipping `calculatedHeight` to 560 px,
enabling both the native scrollbar and wheel path. Inline DOMKit styles pin
these settings across restyling. The background is fixed outside normal flow
at the viewport size; the content column explicitly participates in normal
flow, so it contributes to scroll bounds and moves with the scroll position.
Top alignment, horizontal centering, per-row
pagination, preview framing and the 800 px window height remain unchanged.

### October 2: save/close rendering lifecycle

Audited against the supplied October 1 live bytecode (SHA-256
`617f602066c762869d5c15a01c83714664b0026868f0d24b129bbcc850da88d8`).
The reported screenshot shows persistent trails of world nameplates/health
bars after saving. The GPU symptom has not been reproduced locally; the
following concrete lifecycle faults were corrected and still require an
in-game save/reopen check:

- Save and our Close/Cancel callbacks now queue their action. Commit, preview
  teardown and live-model refresh run at the next `GameApp.update` prefix,
  outside the native UI callback/traversal. Character/world ownership is
  revalidated before committing; Cancel wins over a queued Save.
- Hide and detach the native window before releasing its thumbnail textures.
  Page/tab retirement also hides each icon, clears its tile and marks the
  native button stale before releasing its texture/reallocation callback.
  This prevents remaining drawable references from sampling disposed targets.
- `Unit.set_skin` calls `updateSkin`, which already applies the new model when
  `resolveModel` changes it. The old save code unconditionally applied the
  model again. That second rebuild is gone. Same-model customization calls
  `UnitView.displaySkin`, matching the game's `set_skinData` refresh for remote
  heroes and retaining skin, hair, gear, gradient and shape updates.

The appearance regression harness exercises the actual window Save/Close
callbacks and queued update path, including double clicks, cancellation,
world changes, retry after a failed commit and idempotent cleanup. Its texture
disposal mock rejects any target still referenced by a thumbnail tile, and it
verifies detach → release → live refresh ordering. The native setter mock
includes its built-in model refresh so duplicate rebuilding fails the test.
