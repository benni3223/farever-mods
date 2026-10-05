# Bounded freeze diagnostics

Native signatures checked against supplied October 1 Live `hlboot.dat` (HL6),
SHA-256 `617f602066c762869d5c15a01c83714664b0026868f0d24b129bbcc850da88d8`.

| Timing | Native boundary | Return |
| --- | --- | --- |
| Frame body | `hxd.System.mainLoop()` | Void |
| Update | `GameApp.update(Float)` | Void |
| Render | `h3d.Engine.render({render:Engine->Void})` | Bool, passed through |
| Present | `h3d.impl.DX12Driver.present()` | Void |
| Shader source | `h3d.impl.DX12Driver.compileSource(RuntimeShaderData, String, String)` | Bytes object, passed through |
| Frame wait | `h3d.impl.DX12Driver.waitForFrame(Int)` | Void |
| Graphics cleanup | `h3d.impl.MemoryManager.garbage()` | Void |
| Worker jobs | Existing `lib.Workers.work()` hook | Void |
| Character model | Existing `client.UnitView.displaySkin()` hook | Void |
| Pipeline replay | Existing `h3d.impl.PSOConfigCache.resolveConfig(CompiledShader)` hook | Void |
| Character component | Existing staged-component construction scope | No new native hook |

`mainLoop` handles platform events, calls the app loop, then presents. Work in
the surrounding event loop is visible as a separate gap before the next measured
frame. `present` includes native frame submission and `waitForFrame`, so its
duration cannot be interpreted as GPU execution time. `compileSource` loads or
compiles source for new shaders; the hotter `compileShader` cache-hit path and
per-draw `flushPipeline` are deliberately not instrumented. Required pipeline
creation can therefore remain inside the broader render timing.

The existing worker/skin/cache hooks start a timer even when their optimization
is off, so A/B comparisons use the same diagnostics. HLX runs postfixes after a
prefix skips native execution too, covering the mod's replacement work. Timings
include nested scopes; root-phase union avoids subtracting them twice. Exceptions
that bypass postfixes are marked incomplete or discarded on the next frame.
Other mods' hook order may affect which enclosing scope includes their work.

All samples are restricted to the main-loop thread before reading the clock or
mutating shared timing data. Threaded compilation continues without touching the
buffer. Only a few frame-level and rare-operation hooks are added. Collection
reuses fixed numeric arrays and 32 records; no names, scene scans, stacks or heap
dumps are collected. HLX dispatch itself may allocate and is not claimed to be
free. No GC configuration, native scheduling, return value or rendering decision
is changed by diagnostics.

Gameplay/focus/combat state is read during the normal GameApp update. Two stable
seconds are required before capture. Records of >=100 ms frame body or inter-loop
gap retain their original timestamp, combat flag and optimization flag. Overflow
keeps the newest records and increments a visible counter. Formatting and normal
mod-log output happen only after two seconds of quiet, focused gameplay outside
combat, one record per second. Output failure disables diagnostics. Their own
deferred output time is excluded from the next measured gap. World disposal
suspends collection without writing during a loading transition; process exit or
turning off diagnostics discards any unreported records.

`FrameMetricsTest` passes on interpreter and HashLink. It exercises nested and
recursive scopes, retained snapshots, interval versus body timing, quiet/combat
and loading gates, capacity/rate limits, output-delay exclusion, incomplete
scopes, session boundaries, disabled timers and a real background-thread bypass.
An optional `--bench` measures only the in-memory timing core. The local HashLink
run took approximately 0.65 microseconds per simulated frame across 100,000
iterations with five timed scopes; it excludes HLX dispatch and native context
lookups, and is not an in-game overhead measurement.

The metric locates elapsed time, not necessarily its cause. Implicit HashLink GC,
OS preemption, native locks, disk and GPU waits may contribute inside any measured
scope. A remaining unmeasured gap must not be labeled as GC without more evidence.
