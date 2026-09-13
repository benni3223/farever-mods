#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "../native/event_volume.c"

static int valid = 1, result = 0, reads = 0, writes = 0;
static float gain = 0.8f;
static int fake_valid(void *instance) { assert(instance == &gain); return valid; }
static int fake_get(void *instance, float *volume, float *final) {
    assert(instance == &gain && volume && !final);
    reads++; *volume = gain; return result;
}
static int fake_set(void *instance, float volume) {
    assert(instance == &gain); writes++; gain = volume; return result;
}

int main(void) {
    const char *signature = NULL;
    assert(hlp_event_get_volume(&signature) == (void *)&event_get_volume);
    assert(strcmp(signature, "PB_d") == 0);
    assert(hlp_event_set_volume(&signature) == (void *)&event_set_volume);
    assert(strcmp(signature, "PBd_b") == 0);
    assert(event_get_volume(&gain) == -1); /* FMOD absent */
    assert(!event_set_volume(&gain, 0.4));
    event_valid = fake_valid; event_get = fake_get; event_set = fake_set;
    assert(fabs(event_get_volume(&gain) - 0.8) < 0.000001);
    assert(event_set_volume(&gain, 0.4));
    assert(fabs(gain - 0.4) < 0.000001 && reads == 1 && writes == 1);
    valid = 0;
    assert(event_get_volume(&gain) == -1);
    assert(!event_set_volume(&gain, 0.3));
    valid = 1;
    assert(event_get_volume(NULL) == -1);
    assert(!event_set_volume(NULL, 0.3));
    assert(!event_set_volume(&gain, NAN));
    assert(!event_set_volume(&gain, INFINITY));
    assert(!event_set_volume(&gain, -0.1));
    assert(!event_set_volume(&gain, DBL_MAX));
    assert(reads == 1 && writes == 1); /* invalid requests never reach FMOD */
    result = 1;
    assert(event_get_volume(&gain) == -1);
    assert(!event_set_volume(&gain, 0.2));
    result = 0; gain = NAN;
    assert(event_get_volume(&gain) == -1);
    assert(event_set_volume(&gain, 0));
    assert(gain == 0);
    assert(event_set_volume(&gain, 1.5)); /* restore gain above unity faithfully */
    assert(gain == 1.5);
    puts("Event volume bridge: all checks passed.");
    return 0;
}
