# Crabgantua warning visibility

Audited against the supplied Live HL6 bytecode, SHA-256
`617f602066c762869d5c15a01c83714664b0026868f0d24b129bbcc850da88d8`.

## Scope and native rendering

- Only `R1CrabBoss_Heroic_Avalanche` warning areas are tracked. Its Rock step
  uses `Telegraph_Circle_Physical`, a circular area, and a two-second travel time.
- `SkillArea.playTelegraph` creates the FX, calls `matchFXShape`, then assigns
  `telegraphFx`. `matchFXShape` passes `SkillArea.getRange()` to the FX; the area
  collision builder uses this range as the circular collision radius.
- `client.Renderer.render` draws water and water distortion before tone mapping
  and the final `overlay` stage. `Pass.setPassName`, `set_depthTest`, and
  `set_depthWrite` update the queue ID / render-state bits, not just field names.
- Native colour decals can use `beforeTonemappingDecal`. The previous filter
  missed that stage; it is now included. Deferred G-buffer/depth/shadow passes
  remain excluded.

## Original swirl only

The user confirmed the brown swirl is visible during the water phase after the
colour decal stages were included. The supplemental amber/dark circle has been
removed at their request. The swirl retains its overlay stage and depth state;
its native shaders, shape, animation, and warning timing are unchanged.

- No additional geometry or skill-area lifecycle hook is needed.
- Passes are patched once per warning; FX whose meshes are created later are
  picked up on sync. No whole-scene scan is performed.
- Disabling, FX reset/removal, and game disposal restore the original native
  passes. Native detachment and fading run normally.

## Validation

`CrabgantuaWarningsTest` covers render-state setters, colour decal stages,
late-created materials, no repeated material traversal, active toggles without
added geometry, pool reuse, partial failures, and shutdown. Run it with the
interpreter and HashLink. These use a simulated native boundary; actual DX12
visual output is validated in-game.
