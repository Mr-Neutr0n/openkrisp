#include <assert.h>
#include <stdlib.h>
#include <stdio.h>
#include "rnnoise.h"
static int index_to_fail;
static int calls;
void *lab_malloc(size_t size) { return calls++ == index_to_fail ? NULL : malloc(size); }
void *lab_calloc(size_t n, size_t size) { return calls++ == index_to_fail ? NULL : calloc(n, size); }
void lab_free(void *pointer) { free(pointer); }
int main(int argc, char **argv) {
    assert(argc == 2);
    index_to_fail = atoi(argv[1]);
    DenoiseState *state = rnnoise_create(NULL);
    assert(state == NULL);
    // A failed attempt must leave shared FFT state usable for a later create.
    index_to_fail = -1;
    state = rnnoise_create(NULL);
    assert(state != NULL);
    float in[480] = {0}, out[480];
    const int before_processing = calls;
    rnnoise_process_frame(state, out, in);
    assert(calls == before_processing);
    rnnoise_destroy(state);
    printf("allocation failure %s: clean failure and recovery\n", argv[1]);
}
