"""Apply the reviewed PTR hook patch to exact, pinned upstream sources."""
from pathlib import Path
import subprocess
import sys

CORE = "4fc70d92ce82bf2589ef25aeae2898a96c9a3b4e"
MINHOOK = "c3fcafdc10146beb5919319d0683e44e3c30d537"
core = Path(sys.argv[1]).resolve()
minhook = core / "hlx-boot/vendor/minhook"
for path, expected in [(core, CORE), (minhook, MINHOOK)]:
    actual = subprocess.check_output(["git", "-C", str(path), "rev-parse", "HEAD"], text=True).strip()
    if actual != expected:
        raise SystemExit(f"Unexpected source revision in {path}: {actual}")

source = core / "hlx-boot/src/patching.c"
text = source.read_text()
start = text.index("static int ModRMExtraBytes(")
end = text.index("static void **g_sortedFunctionStarts", start)
text = text[:start] + text[end:]
start = text.index("static int FindSafeCutPoint(")
end = text.index("#define MAX_PATCHES", start)
replacement = (Path(__file__).parent / "hook_installer.c").read_text()
text = text[:start] + replacement + "\n" + text[end:]
source.write_text(text)

# JIT functions do not have the Windows hotpatch padding contract. Never
# redirect through bytes preceding the known function's entry address.
source = minhook / "src/trampoline.c"
text = source.read_text()
assert text.count("ct->patchAbove = TRUE;") == 1
source.write_text(text.replace("ct->patchAbove = TRUE;", "return FALSE; /* No hotpatch-above for JIT functions. */"))

cmake = core / "hlx-boot/CMakeLists.txt"
with cmake.open("a") as out:
    out.write('''
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
add_subdirectory(vendor/minhook)
target_link_libraries(hlx-boot PRIVATE minhook)
add_executable(hlx-hook-tests "${HLX_COMPAT_TEST}")
target_include_directories(hlx-hook-tests PRIVATE src)
target_link_libraries(hlx-hook-tests PRIVATE minhook user32)
enable_testing()
add_test(NAME hlx-hook-tests COMMAND hlx-hook-tests)
''')
print("Applied bounded MinHook installer to pinned HLX Core sources.")
