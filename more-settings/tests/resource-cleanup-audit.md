# Background DX12 resource retirement

Audited against supplied `hlboot(20261001-232103).dat`, HL6, SHA-256
`617f602066c762869d5c15a01c83714664b0026868f0d24b129bbcc850da88d8`.

## Evidence and intended effect

The supplied PresentMon export records a 5.100-second gap between game presents
at 1321.287727–1326.388089 seconds. The corresponding WPA stack on thread 20332
contains `D3D12Core!CResource::FinalRelease`, NVIDIA `nvwgf2umx`,
`D3DKMTDestroyAllocation2`, and Windows graphics allocation destruction. Roughly
1.65 seconds of inclusive sampled CPU time lies under resource final release.
This corroborates the earlier inclusive `frame-recycle` wall-time logs, but does
not attribute the entire gap to one resource or establish a driver defect.
Tracing overhead can contribute to these timings.

The former 2 ms / 64-release main-thread scheduler could not preempt one slow
Release and bypassed small queues entirely. The new implementation moves every
eligible nonempty queue to one dedicated worker, including a single resource.

## Native safety boundary and ownership

`DX12Driver.present` calls `waitForFrame(currentBackBuffer)` before `beginFrame`.
`resize` instead calls `waitCopy` and `waitGpu` before `beginFrame`. Inside
`beginFrame`, the driver selects its current `DxFrame`, resets render commands,
then calls `BufferAllocator.reset`. Afterwards it resets copy commands and drains
`frame.toRelease` through `dx12.resource_release`. Texture and buffer descriptor
handles are retired afterwards, before `beginQueries`.

The existing beginFrame/BufferAllocator checkpoints run with diagnostics off.
The allocator must match the current native frame, the scope must be
non-recursive, and GameApp.update must have enabled gameplay on the main thread.
Only that already-fence-safe `toRelease` queue is eligible. Other frame queues,
fences, command resets, descriptors, live textures, immediate native disposal,
and device lifecycle operations remain owned by the game.

On the main thread, all native pointers are validated and reboxed through
`HlxRuntime.resolveAbstract` into a mod-owned typed array. No game array is cast
to a mod array. Conversion/allocation/worker startup precede the field swap.
An empty ArrayObj allocated with the game's `slice(0, 0)` replaces its old queue.
The validated references are staged without releasing them; no AddRef is added
because the existing owned references are transferred, not copied in ownership.
Subsequent unsafe retirements go to the replacement native queue.

Publication waits until the beginFrame postfix, after native copy-command
resets and descriptor processing complete. If a native exception omits the
postfix, the next update or lifecycle boundary publishes the already-safe stage.
The worker receives only native references in mod-owned arrays: no HlxRuntime,
reflection, game arrays, game objects, or rendering/UI operations run there.
Its linked queue is FIFO between batches and preserves native pop order within
batches. The queue mutex is never held across a resource release or lifecycle wait.

## HashLink and Direct3D threading

The supplied bytecode's `dx12.resource_release` primitive has signature
`Void(Abstract<dx_resource>)`. HashLink's DirectX implementation is precisely
`res->Release()` on an IUnknown, without HashLink allocations or callbacks.
The production wrapper brackets only that native call with `hl.Gc.blocking(true)`
and `hl.Gc.blocking(false)`. No allocations or managed callbacks are permitted
inside the section. A slow release therefore does not keep the worker active
from the GC's perspective and force the main thread to wait for a GC safepoint.
A native driver crash remains unrecoverable, as with the original call.

D3D12's CPU efficiency specification requires resource destruction to coexist
with command-list recording. Already-retired resources retain their existing COM
references until Release completes. No command list/allocator is reset from the
worker; rendering remains on its original thread. Resize, reset, and disposal
prefixes join outstanding accepted work before native device transitions.

Sources:
- https://github.com/microsoft/DirectX-Specs/blob/master/d3d/CPUEfficiency.md
  (Reference Counting; DDI threading requirements)
- https://github.com/HaxeFoundation/hashlink/blob/04a207d73816132b9f742867e8643f58b02a5afa/libs/directx/dx12.cpp
  (`resource_release`)
- Haxe 4.3.7 `std/hl/Gc.hx` blocking-section contract, and HashLink `src/gc.c`
  (`hl_blocking` / GC thread synchronization).

## Limits and lifecycle

The pending count includes in-flight batches until they complete. At most 4,096
references are accepted. If a new batch would exceed that limit, or DXGI reports
less than max(512 MiB, 10% of budget) free, accepted work finishes before the new
queue drains natively. Unknown memory information also uses the native path.
This bounds retained reference count and checks real DXGI memory headroom; it is
not an exact retained-byte cap. Pressure fallback can still wait on the driver.

The worker drains continuously; there is no intentional per-frame deferral or
age-based trigger that forces a second synchronous cleanup after two seconds.
Disabling, loading, world disposal, and driver replacement finish and stop the
worker. Device resize/reset/dispose do the same before their native work. A later
eligible frame can start a fresh worker. Shutdown never steals newly queued,
unfenced references from the game.

All fallible game interop occurs before ownership transfer. Failure there leaves
the original queue native; previously accepted work still finishes exactly once.
There is no per-resource diagnostic logging. Existing freeze diagnostics retain
the >=500 ms threshold. No new native library or user dependency is introduced.

## Verification and limitations

`ResourceCleanupTest` runs the production scheduler and worker with simulated
native resources on both the interpreter and HashLink. It covers an intentionally
blocked single release while the producer submits later frames, FIFO/native pop
order, exactly-once ownership, readiness and delayed publication, empty/small/large
queues, count and memory fallback, disable/loading/device transitions, worker
restart, partial conversion and allocation/field-swap failures, interrupted frame
postfixes, recursive scopes, and background-thread hook exclusion.

`GpuReleaseNativeTest` runs the production worker AND `GpuResources` blocking
wrapper against a test-only Linux `dx12.hdll`. The fake native verifies another
thread and the GC-blocking flag, then holds its release open while the main
thread successfully completes a major GC. A watchdog makes a regression fail
instead of hanging CI. This test-only library is outside the mod's package tree.

The production HLX implementation is compiled as well. These checks do not run
Windows/NVIDIA or prove that every driver operation is independent of rendering.
Shared driver/kernel locks, memory-pressure fallback, native paths outside this
retirement queue, and lifecycle joins can still cause stalls. Actual in-game
frame-time improvement requires gameplay verification.
