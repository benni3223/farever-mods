/* Exercise the actual patched installer and executable Windows x64 trampolines. */
#include <stdio.h>
#include <stdarg.h>
#include <patching.c>

void *module_get_code(void) { return NULL; }
void **module_get_functions_ptrs(void) { return NULL; }
void *call_resolved(const void *fn, const void *type, void *args) { return NULL; }
void hlx_narrow_utf16(const unsigned short *in, char *out, int size) { if (size) out[0] = 0; }
void hlx_log(HlxLogLevel level, const char *fmt, ...) {
    va_list args; va_start(args, fmt); vprintf(fmt, args); va_end(args); puts("");
}

typedef int (*TestFn)(int);
static TestFn original;
static int calls;
static int hook(int input) { calls++; return original(input) + 100; }
typedef double (*FloatFn)(void *, double);
static FloatFn floatOriginal;
static double floatHook(void *owner, double dt) { return floatOriginal(owner, dt) + 100.0; }
static void require(int ok, const char *message) {
    if (!ok) { fprintf(stderr, "FAIL: %s\n", message); ExitProcess(1); }
}
static void run_case(const unsigned char *code, size_t count, int zero, int nonzero, const char *name) {
    unsigned char *target = VirtualAlloc(NULL, 4096, MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE);
    require(target != NULL, "allocate executable fixture");
    memcpy(target, code, count);
    FlushInstructionCache(GetCurrentProcess(), target, count);
    void *bounds[2] = {target, target + count};
    g_sortedFunctionStarts = bounds; g_sortedFunctionCount = 2; g_boundaryBuildAttempted = true;
    TestFn test = (TestFn)target;
    require(test(0) == zero && test(4) == nonzero, "fixture's unhooked result");
    TrampolineFn trampoline = NULL;
    require(PatchFunctionPrologue(target, hook, &trampoline, name), "install relocated hook");
    original = (TestFn)trampoline; calls = 0;
    require(test(0) == zero + 100 && test(4) == nonzero + 100 && calls == 2, "hook preserves arguments, branches and original return");
    require(original(0) == zero && original(4) == nonzero, "original trampoline is independently callable");
    require(MH_DisableHook(target) == MH_OK && MH_RemoveHook(target) == MH_OK, "remove hook");
    require(test(4) == nonzero && memcmp(target, code, count) == 0, "restore original machine code");
    VirtualFree(target, 0, MEM_RELEASE);
}
int main(void) {
    const unsigned char registers[] = {0x8b,0xc1,0x83,0xc0,7,0xc3};
    run_case(registers, sizeof(registers), 7, 11, "32-bit register prologue");
    const unsigned char branch[] = {0x85,0xc9,0x74,6,0xb8,7,0,0,0,0xc3,0xb8,9,0,0,0,0xc3};
    run_case(branch, sizeof(branch), 9, 7, "short conditional branch");
    const unsigned char stack[] = {0x55,0x48,0x89,0xe5,0x48,0x83,0xec,0x20,
        0x48,0x89,0x4c,0x24,8,0x8b,0x44,0x24,8,0x83,0xc0,7,0xc9,0xc3};
    run_case(stack, sizeof(stack), 7, 11, "stack SIB addressing");
    const unsigned char relative[] = {0x8b,5,1,0,0,0,0xc3,42,0,0,0};
    run_case(relative, sizeof(relative), 42, 42, "RIP-relative data load");
    unsigned char call[68] = {0x48,0x83,0xec,0x28,0xe8,55,0,0,0,
        0x48,0x83,0xc4,0x28,0x83,0xc0,2,0xc3};
    call[64] = 0x8d; call[65] = 0x41; call[66] = 3; call[67] = 0xc3;
    run_case(call, sizeof(call), 5, 9, "relative function call");
    unsigned char *tiny = VirtualAlloc(NULL, 4096, MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE);
    const unsigned char bytes[] = {0x8b,0xc1,0xc3,0xcc,0xb8,99,0,0,0,0xc3};
    memcpy(tiny, bytes, sizeof(bytes));
    void *bounds[2] = {tiny, tiny + 4};
    g_sortedFunctionStarts = bounds; g_sortedFunctionCount = 2;
    TrampolineFn trampoline = NULL;
    require(!PatchFunctionPrologue(tiny, hook, &trampoline, "short function boundary"), "refuse crossing a neighbor");
    require(memcmp(tiny, bytes, sizeof(bytes)) == 0, "failed hook leaves both functions intact");
    VirtualFree(tiny, 0, MEM_RELEASE);
    unsigned char *floating = VirtualAlloc(NULL, 4096, MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE);
    const unsigned char xmm[] = {0xf2,0x0f,0x10,0xc1,0xc3}; // movsd xmm0,xmm1; ret
    memcpy(floating, xmm, sizeof(xmm));
    bounds[0] = floating; bounds[1] = floating + sizeof(xmm);
    g_sortedFunctionStarts = bounds;
    FlushInstructionCache(GetCurrentProcess(), floating, sizeof(xmm));
    require(PatchFunctionPrologue(floating, floatHook, &trampoline, "object and floating-point arguments"), "install floating-point hook");
    floatOriginal = (FloatFn)trampoline;
    require(((FloatFn)floating)(floating, 4.5) == 104.5 && floatOriginal(floating, 4.5) == 4.5,
        "preserve mixed pointer and floating-point arguments and return");
    require(MH_DisableHook(floating) == MH_OK && MH_RemoveHook(floating) == MH_OK, "remove floating-point hook");
    require(memcmp(floating, xmm, sizeof(xmm)) == 0, "restore SSE prologue");
    VirtualFree(floating, 0, MEM_RELEASE);
    unsigned char *hotpatch = VirtualAlloc(NULL, 4096, MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE);
    memset(hotpatch, 0x90, 64);
    hotpatch[32] = 0xc3; hotpatch[34] = hotpatch[35] = hotpatch[36] = 0x50;
    unsigned char before[64]; memcpy(before, hotpatch, sizeof(before));
    bounds[0] = hotpatch + 32; bounds[1] = hotpatch + 48;
    g_sortedFunctionStarts = bounds;
    require(!PatchFunctionPrologue(hotpatch + 32, hook, &trampoline, "hotpatch above JIT entry"), "disable MinHook hotpatch-above fallback");
    require(memcmp(hotpatch, before, sizeof(before)) == 0, "refusal leaves bytes before and inside the function untouched");
    VirtualFree(hotpatch, 0, MEM_RELEASE);
    MH_Uninitialize();
    puts("HLX executable hook regression tests passed.");
    return 0;
}
