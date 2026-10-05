/* Test-only replacement for dx12.resource_release. Never shipped with the mod. */
#define HL_NAME(n) dx12_##n
#include <hl.h>
#include <pthread.h>
#include <errno.h>
#include <stdlib.h>
#include <time.h>

typedef struct { pthread_t creator; } test_resource;
static pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t condition = PTHREAD_COND_INITIALIZER;
static int waiting, allowed, released, errors;

HL_PRIM test_resource *HL_NAME(test_create)(void) {
    test_resource *res = malloc(sizeof(*res));
    if (!res) hl_error("test allocation failed");
    res->creator = pthread_self();
    return res;
}

HL_PRIM void HL_NAME(resource_release)(test_resource *res) {
    pthread_mutex_lock(&mutex);
    if (!hl_is_blocking() || pthread_equal(res->creator, pthread_self())) errors++;
    struct timespec deadline;
    clock_gettime(CLOCK_REALTIME, &deadline);
    deadline.tv_sec += 3;
    waiting = 1;
    while (!allowed) {
        if (pthread_cond_timedwait(&condition, &mutex, &deadline) == ETIMEDOUT) {
            errors++;
            break;
        }
    }
    waiting = 0;
    released++;
    pthread_mutex_unlock(&mutex);
    free(res);
}

HL_PRIM bool HL_NAME(test_waiting)(void) {
    pthread_mutex_lock(&mutex);
    bool value = waiting != 0;
    pthread_mutex_unlock(&mutex);
    return value;
}
HL_PRIM void HL_NAME(test_unblock)(void) {
    pthread_mutex_lock(&mutex);
    allowed = 1;
    pthread_cond_signal(&condition);
    pthread_mutex_unlock(&mutex);
}
HL_PRIM int HL_NAME(test_released)(void) {
    pthread_mutex_lock(&mutex);
    int value = released;
    pthread_mutex_unlock(&mutex);
    return value;
}
HL_PRIM int HL_NAME(test_errors)(void) {
    pthread_mutex_lock(&mutex);
    int value = errors;
    pthread_mutex_unlock(&mutex);
    return value;
}
HL_PRIM bool HL_NAME(test_blocking)(void) { return hl_is_blocking(); }

DEFINE_PRIM(_ABSTRACT(dx_resource), test_create, _NO_ARG);
DEFINE_PRIM(_VOID, resource_release, _ABSTRACT(dx_resource));
DEFINE_PRIM(_BOOL, test_waiting, _NO_ARG);
DEFINE_PRIM(_VOID, test_unblock, _NO_ARG);
DEFINE_PRIM(_I32, test_released, _NO_ARG);
DEFINE_PRIM(_I32, test_errors, _NO_ARG);
DEFINE_PRIM(_BOOL, test_blocking, _NO_ARG);
