#include "../native/image_buffer.h"
#include <cassert>
#include <climits>
#include <iostream>

int main() {
    assert(dps_image_bytes(2, 2, 16) == 16);
    assert(dps_image_bytes(2, 2, 15) == 0);
    assert(dps_image_bytes(2, 2, 20) == 0);
    assert(dps_image_bytes(-1, 2, 8) == 0);
    assert(dps_image_bytes(2, 0, 8) == 0);
    assert(dps_image_bytes(INT_MAX, INT_MAX, INT_MAX) == 0);
    assert(dps_image_bytes(900, 100000, 360000000) == 0);
    // Top row red/green, bottom row blue/white: preserve channels, invert row
    // order for a positive-height DIB, and clear its reserved fourth bytes.
    const uint8_t input[] = {0,0,255,255, 0,255,0,128, 255,0,0,255, 255,255,255,255};
    const uint8_t expected[] = {255,0,0,0, 255,255,255,0, 0,0,255,0, 0,255,0,0};
    uint8_t output[18]; memset(output, 0xa5, sizeof output);
    dps_copy_bottom_up(output + 1, input, 2, 2);
    assert(memcmp(output + 1, expected, 16) == 0);
    assert(output[0] == 0xa5 && output[17] == 0xa5);
    assert(input[3] == 255 && input[7] == 128);
    std::cout << "Snapshot pixel buffers: 10 checks passed\n";
}
