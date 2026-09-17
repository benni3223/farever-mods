#include <MinHook.h>

typedef void (*TrampolineFn)(void);

/* HashLink 2's JIT can start with short branches, relative calls and RIP-relative
 * loads. A byte-copy whitelist cannot relocate those instructions. MinHook
 * decodes and relocates them and uses a register-preserving near relay.
 * Keep the known-function boundary guard and disable MinHook's hotpatch-above
 * fallback in apply.py: padding before a JIT function belongs to the module. */
static bool PatchFunctionPrologue(void *targetFun, void *hookFn,
    TrampolineFn *outTrampoline, const char *label)
{
    const unsigned char *fun = (const unsigned char *)targetFun;
    const unsigned char *limit = FindNextFunctionBoundary(fun);
    if (limit && (uintptr_t)limit - (uintptr_t)fun < 5) {
        hlx_log(HLX_LOG_ERROR, "[hlx-boot] %s: function is shorter than the 5-byte hook - refusing", label);
        return false;
    }
    MH_STATUS status = MH_Initialize();
    if (status != MH_OK && status != MH_ERROR_ALREADY_INITIALIZED) {
        hlx_log(HLX_LOG_ERROR, "[hlx-boot] %s: hook initialization failed: %s", label, MH_StatusToString(status));
        return false;
    }
    void *original = NULL;
    status = MH_CreateHook(targetFun, hookFn, &original);
    if (status != MH_OK) {
        hlx_log(HLX_LOG_ERROR, "[hlx-boot] %s: hook relocation failed: %s", label, MH_StatusToString(status));
        return false;
    }
    status = MH_EnableHook(targetFun);
    if (status != MH_OK) {
        MH_RemoveHook(targetFun);
        hlx_log(HLX_LOG_ERROR, "[hlx-boot] %s: hook activation failed: %s", label, MH_StatusToString(status));
        return false;
    }
    *outTrampoline = (TrampolineFn)original;
    hlx_log(HLX_LOG_DEBUG, "[hlx-boot] %s: relocated hook installed at %p", label, targetFun);
    return true;
}
