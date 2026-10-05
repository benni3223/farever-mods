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

The user's report establishes that changing the original passes was insufficient.
We have not captured the failing effect's runtime shader list, so this does not
identify a particular shader as the sole cause. The independent outline avoids
depending on the original decal's projection, fading, or later child materials.

## Independent boundary

- Two native `h3d.scene.Graphics` children of the area's `obj` draw the same
  64-segment closed circle. The native constructor supplies the unlit vertex
  colour and screen-width line shaders, disables shadows, and disables culling.
- The dark 6-pixel backing and amber 3-pixel core have ordered overlay layers,
  `Compare.Always`, and no depth writes. They contain no decal/depth-fade shader.
  No filled disk obscures the arena. No collision or damage state is changed.
- Geometry is built once per warning; native rendering follows the parent and
  camera. No update hook rebuilds geometry or scans the scene. A construction
  failure cleans up and suppresses further attempts for that warning until the
  setting is toggled.
- `SkillArea.killTelegraph` detaches and fades the FX for 0.5 seconds before
  pooling. Our prefix removes the outline immediately and clears its area
  reference so toggling during that fade cannot restore an expired warning.
- Disabling, FX reset/removal, and game disposal remove outlines and restore the
  original native passes. Native `Graphics.onRemove` clears its BigPrimitive;
  native parent removal calls children's `onRemove`.

## Validation

`CrabgantuaWarningsTest` covers radius/closure, render-state setters, late scene
attachment, no repeated geometry allocation, active toggles, impact/fade,
pool reuse, partial failures, and shutdown. Run it with the interpreter and
HashLink. These use a simulated native boundary; an in-game water/rockfall overlap
is still required to validate visual weight and the actual DX12 output.
