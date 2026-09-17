# HLX Core PTR hook compatibility

Companion build for HLX Core 0.0.8. It replaces the native hook installer's
instruction whitelist with MinHook 1.3.4's instruction relocation. This supports
the new HashLink JIT's relative loads, calls, branches, and register/stack moves.
The loader and mod APIs are unchanged, so the same mods work on live and PTR.

Close Farever. With HLX Core 0.0.8 already installed, back up its `libhl64.dll`
in the game directory and replace only that file with this build. Keep the
existing `hlx` folder, loader, mods, and configuration. Restore the backed-up
DLL to roll back. This is a compatibility build, not an upstream HLX release.

The reported `install_patch failed` messages mean those mod hooks were not
installed. Updating mod binaries alone cannot repair the native installer.
Check the next launch log for remaining failures after installing this DLL.

Upstream sources are pinned by commit in `apply.py` and the workflow. The patch
retains function-boundary checks and disables hotpatching before JIT function
entries. Windows CI executes hooked machine-code fixtures to verify relative
instruction relocation, original calls, arguments, return values, hook removal,
and refusal to overwrite a neighboring short function. Actual game integration
still requires a live/PTR launch test.

Sources: https://github.com/hlx-framework/hlx-core and
https://github.com/TsudaKageyu/minhook. Their licenses accompany the binary.
