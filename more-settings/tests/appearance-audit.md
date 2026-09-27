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
| `Unit.updateSkin` | 4699 / 4761 | Model-dependent refresh. Same-model customization requires an explicit `UnitView.applyModelInfo` refresh. |
| `HeroData.save` | 14839 / 9139 | Stores the hero's current skin data for normal character persistence. The mod does not call server save functions or admin RPCs. |
| `ColorSelector.createButton` | 25865 / 27072 | Stateless swatch factory; no receiver fields are read. Live passes a gradient to ColorPickButton; PTR passes its sampled color. Use this factory to retain both constructors. |
| `UnitScene.postInitUnitView` | 25758 / 21178 | Native dynamic callback computes bounds and starts an independent idle animation. Preserve rotation around the callback because live adds `viewAngle`. PTR-only `setAnim` is not required. |

The preview receives no live unit, so it cannot share the hero's animation
player or equipment. It gets a separate native skin copy via
`overrideSkinData`. Changes only touch that copy. Save creates a second copy
before using the replicated setters; subsequent preview cleanup cannot change
the saved state. World/player changes, a removed hero, a closed/rebuilt window,
and concurrent appearance replacement invalidate the session. Cancel and
Escape use normal native window removal and do not call an appearance setter.

`AppearanceTest` runs in the Haxe interpreter and actual HashLink in CI. It
checks nested draft isolation, cancel/reopen, save/retry, rejected setters,
immediate and same-model refresh, concurrent changes, stale ownership/world
state, creation-option filters, and category/button metadata. Rendering is not
simulated by these tests.

In-game verification still required on live and PTR: open from BMS; rotate the
preview; try all body types, palettes, hair/facial hair, eyebrows and four shape
categories; Save and check another client's view and relog persistence; cancel
using Cancel/X/Escape; reopen; resize the game; close during loading; change
world or log out while the editor is open. The game cannot be launched in the
build environment.
