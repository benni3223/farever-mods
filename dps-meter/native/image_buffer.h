#pragma once
#include <stdint.h>
#include <stddef.h>
#include <string.h>

// Bound temporary memory and reject overflow/truncated buffers before copying.
static inline size_t dps_image_bytes(int width, int height, int length) {
    if (width <= 0 || height <= 0 || length <= 0) return 0;
    uint64_t bytes = (uint64_t)width * (uint64_t)height * 4;
    return bytes <= 128 * 1024 * 1024 && bytes == (uint64_t)length ? (size_t)bytes : 0;
}
static inline void dps_copy_bottom_up(uint8_t *dst, const uint8_t *src, int width, int height) {
    size_t stride = (size_t)width * 4;
    for (int y = 0; y < height; ++y) {
        uint8_t *row = dst + (size_t)y * stride;
        memcpy(row, src + (size_t)(height - 1 - y) * stride, stride);
        // CF_DIB BI_RGB uses the fourth byte as reserved, not alpha.
        for (int x = 0; x < width; ++x) row[(size_t)x * 4 + 3] = 0;
    }
}
