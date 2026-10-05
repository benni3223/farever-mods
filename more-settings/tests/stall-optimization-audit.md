# Incremental pipeline replay and character loading

Native inspection: supplied live `hlboot(20261001-232103).dat`, HL6,
SHA-256 `617f602066c762869d5c15a01c83714664b0026868f0d24b129bbcc850da88d8`.

## Pipeline replay

`DX12Driver.compileShader` releases `compileMutex`, then calls
`PSOConfigCache.resolveConfig`. That method copies the shader's saved configs
under the cache mutex and replays every variant without a time budget. Each
variant locks `CompiledShader.pipelineMutex`; `makePipeline` mutates the shared
pipeline descriptor before calling DX12. `flushPipeline` also takes that mutex
and creates a missing pipeline synchronously. `CacheFile2Loader.threadLoop`
already calls `warmupShader` on a background loader thread.

The mod defers only foreground gameplay replay. GameApp.update establishes the
main thread; background calls return before game reflection or queue mutation.
Loading-screen replay remains native. During quiet frames one saved variant is
passed to native `resolveConfig` using a private cache object with a singleton
config array. Shared cache arrays and disk files are never modified. Native
signature parsing, input-count validation, lookup/dedup and invalid-config
handling are reused. Variants already created by a real draw are native no-ops.

Nonblocking mutex acquisition protects the compiled-shader lookup, cache snapshot
and pipeline replay. The supplied game's Mutex constructor uses
`std.mutex_alloc(true)` (recursive), so holding `pipelineMutex` through native
replay is intentional. Foreign mutexes use `HlxRuntime.resolveAbstract`, not a
cross-module cast. Queue length is bounded to 128 shaders; overflow drops only
optional preparation. Required draws still create any missing pipeline. Driver
reset/disposal, driver replacement, GameApp disposal and disabling clear work.

This does not make shader compilation asynchronous, make a single pipeline
creation preemptible, or guarantee a maximum frame time. Slow frames (>25 ms),
combat, missing hero and loading reset the two-second quiet interval.

## Character visuals

`UnitView.setUnit` submits `displaySkin` with `Workers.addJob(..., false)` when
async is enabled. The native worker checks its gameplay/loading deadline only
after each whole callback. Native `displaySkin` builds the base model, finds its
skin, updates all dynamic visuals, reloads animation, calls checkReady and updates
culling. `updateDynamicVisuals(false)` calls weapons, equipment, body parts,
blend shapes and model weapons in that order.

Only an initial asynchronous remote-hero model is staged. Each weapon, equipment
slot and body part is a separate main-thread continuation. Native component
methods own all prefab loading, scene changes and skin links. Arguments such as
displayed gear are read when executing, not captured as old equipment. A model
or owner identity change, removal, reentrant replacement, or disposal cancels
the remaining work. A single continuation per view prevents queue amplification.

Base creation and AnimPlayer.reload stay in displaySkin. The reload routine
restores the current animation/frame/callback; postponing it could break skill
animations, so it is not delayed. checkReady retains a barrier until the components
complete. Outside construction, isReady does as well. During each component (and
native fallback), isReady returns its original native result for that view only.
This distinction is essential: displayGearSlot begins with `if (!isReady()) return`.
Blocking that internal check silently skipped every armor slot, leaving heads and
weapons visible. The construction scope restores its previous value on success or
exception and supports nested builds without exposing another pending view.
Native model-weapon jobs and their own readiness
checks are preserved. Completion removes the barrier before native callbacks,
then refreshes culling if the view remains current. Turning the setting off lets
accepted builds finish. A component failure restores through native visuals and
disables new staging for that session.

`updateDynamicVisuals` takes a nullable **Ref<Bool>** in this client; its hook
uses `hl.Ref<Bool>`, not `Null<Bool>`. Native onRemove traverses scene children,
so pending UnitViews are cancelled when an ancestor leaves the scene as well.

## Verification and limits

StallOptimizationTest exercises production scheduling with a simulated native
boundary on interpreter and HashLink: component ordering and current gear,
actual armor attachment through the native readiness guard, scoped/reentrant
readiness and armor attachment during native fallback,
readiness, exclusions, cancellation/reentrancy, failure fallback, disabling,
single-variant replay, combat/slow-frame delay, untouched shared arrays,
background-thread bypass, actual contended mutexes, stale shaders and resets.
The normal mod build checks the hook code. Existing More Settings tests remain
required. Tests do not run DX12 or Farever and do not establish the user's actual
freeze cause or measure frame-time improvement. Test crowded areas, combat,
zone changes, gear changes, appearance previews and toggling before release.
