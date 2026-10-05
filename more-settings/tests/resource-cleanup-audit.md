# Bounded DX12 resource retirement

Audited against supplied `hlboot(20261001-232103).dat`, HL6, SHA-256
`617f602066c762869d5c15a01c83714664b0026868f0d24b129bbcc850da88d8`.

## Native boundary and ownership

`DX12Driver.present` calls `waitForFrame(currentBackBuffer)` before `beginFrame`.
`resize` instead calls `waitCopy` and `waitGpu` before `beginFrame`. Inside
`beginFrame`, the driver selects its current `DxFrame`, resets render commands,
then calls `BufferAllocator.reset`. Immediately afterwards it resets copy
commands and drains `frame.toRelease` through `dx12.resource_release`. Texture
and buffer descriptor handles are retired afterwards, before `beginQueries`.

We use the existing beginFrame/BufferAllocator checkpoints even when diagnostics
are off. The allocator must match the current native frame, the scope must be
non-recursive, and GameApp.update must have enabled gameplay on the main thread.
Only that already-fence-safe `toRelease` queue is eligible. No other frame's
queue is inspected or released early. No fence, command reset, descriptor work,
texture allocation, immediate native disposal or device lifecycle call is skipped.

The game receives an empty ArrayObj created by its own `slice(0, 0)` method;
ownership of the original ArrayObj moves to a mod batch. Every allocation happens
before the field swap, with rollback if the swap fails. New disposals accumulate
in the replacement queue and cannot enter our backlog until their own native
release checkpoint. Arrays/resources are never cast to mod Array types.

The actual release uses the game's existing `dx12.resource_release` native,
`Void(Abstract<dx_resource>)`, which invokes `IUnknown::Release`. The supplied
bytecode contains this primitive; HashLink's DirectX source declares the same
signature (`DEFINE_PRIM(_VOID, resource_release, _RES)`). `HlxRuntime.resolveAbstract`
checks and reboxes the native abstract into the mod module's type identity. This
uses the existing game library and adds no HDLL/dependency. Abstract conversion
runs before removing ownership. Then the native ArrayObj pop decrements length
and clears the pointer, and we call Release, matching the game's removal order.
No fallible reflection follows Release that could put an already-freed pointer
back in a queue. Conversion failure leaves the reference owned by the batch for
the native fallback. A native driver crash itself is not a recoverable Haxe error.

## Limits and fallback

Queues of up to 64 resources remain fully native when no backlog exists. Larger
bursts share a 2 ms / 64-release budget per eligible frame, checked between
releases. FIFO batches prevent newer frames starving older work; each batch
retains the native stack's pop order. A single driver call cannot be preempted.

At most 4,096 resources are accepted. After two seconds of pending age, or if
DXGI reports less than max(512 MiB, 10% of budget) free, pending work drains and
the current queue stays native. Unknown memory information also bypasses
deferral. `getMemoryUsage` is queried only when there is a large queue/backlog;
native `allocated/free/total` values are bytes from DXGI current usage/budget,
not MemoryManager's logical texture counter. This bounds count/age and responds
to memory pressure; it is not an exact cap on retained bytes. A long frame can
delay the next age check. Full fallback cleanup can itself stall.

Disabling, loading, world disposal, driver replacement, driver disposal and reset
drain only accepted, already-safe references. Newly queued unsafe resources stay
with the game. Interrupted frame postfixes do not lose ownership. On an interop
error, batching stops for the session and remaining references return to the
current native queue for normal retirement. No resource is intentionally dropped.
If no frame exists, owned references remain available to the next cleanup attempt.

The existing diagnostics continue to report only >=500 ms stalls; no recurring
logs/counters were added. Release work at the shared checkpoint is inside the
existing frame-recycle timing; cleanup on loading/disable is included in the
surrounding lifecycle/update call.

## Verification

`ResourceCleanupTest` runs the production scheduler against a native-boundary
simulation on both the interpreter and HashLink. It checks one-and-only-one
release, readiness, independent frame queues, FIFO progress, time/count limits,
small/disabled/loading paths, memory/age/backlog fallback, world/driver lifecycle,
failed allocation/field swap/conversion, partial progress, missing/recursive
checkpoints and background-thread exclusion. The main implementation also builds
against HLX. These checks do not simulate a Windows GPU driver or establish an
in-game frame-time improvement; the cleanup-burst hypothesis remains experimental.
