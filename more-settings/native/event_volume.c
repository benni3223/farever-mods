/* Per-event volume bridge for Farever's Windows x64 HashLink client.
 * Resolves the public FMOD C API from the game's already-loaded DLL. No FMOD
 * binaries/headers are redistributed and no private object layouts are read.
 * API: https://www.fmod.com/docs/2.03/api/studio-api-eventinstance.html
 */
#include <stdbool.h>
#include <stddef.h>
#include <float.h>
#include <math.h>

#ifdef _WIN32
#include <windows.h>
#ifndef _WIN64
#error More Settings requires Windows x64
#endif
#define FMOD_CALL WINAPI
#define EXPORT __declspec(dllexport)
#else
/* Linux is used only for the simulated API tests, not the shipped plugin. */
#define FMOD_CALL
#define EXPORT
#endif

typedef int (FMOD_CALL *event_valid_fn)(void *);
typedef int (FMOD_CALL *event_get_fn)(void *, float *, float *);
typedef int (FMOD_CALL *event_set_fn)(void *, float);
static event_valid_fn event_valid;
static event_get_fn event_get;
static event_set_fn event_set;

static bool resolve_api(void) {
    if (event_valid && event_get && event_set) return true;
#ifdef _WIN32
    HMODULE module = GetModuleHandleW(L"fmodstudio.dll");
    if (!module) module = GetModuleHandleW(L"fmodstudioL.dll");
    if (!module) return false;
    event_valid = (event_valid_fn)(void *)GetProcAddress(module, "FMOD_Studio_EventInstance_IsValid");
    event_get = (event_get_fn)(void *)GetProcAddress(module, "FMOD_Studio_EventInstance_GetVolume");
    event_set = (event_set_fn)(void *)GetProcAddress(module, "FMOD_Studio_EventInstance_SetVolume");
#endif
    return event_valid && event_get && event_set;
}

static double event_get_volume(void *instance) {
    float volume = 0;
    if (!instance || !resolve_api() || !event_valid(instance)) return -1;
    /* Read the user gain, not final gain (which includes FMOD automation). */
    if (event_get(instance, &volume, NULL) != 0 || !isfinite(volume) || volume < 0) return -1;
    return (double)volume;
}

static bool event_set_volume(void *instance, double volume) {
    if (!instance || !isfinite(volume) || volume < 0 || volume > FLT_MAX ||
        !resolve_api() || !event_valid(instance)) return false;
    return event_set(instance, (float)volume) == 0;
}

/* HashLink DEFINE_PRIM ABI, from hashlink/src/hl.h: P<args>_<return>;
 * B = raw bytes/pointer, d = f64, b = bool. These exports need no libhl import.
 * https://github.com/HaxeFoundation/hashlink/blob/master/src/hl.h
 */
EXPORT void *hlp_event_get_volume(const char **signature) {
    *signature = "PB_d";
    return (void *)&event_get_volume;
}
EXPORT void *hlp_event_set_volume(const char **signature) {
    *signature = "PBd_b";
    return (void *)&event_set_volume;
}
