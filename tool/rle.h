#include <stdint.h>
#include <stdlib.h>

size_t rle(uint8_t *src, uint8_t *dst, size_t len);
size_t unrle(uint8_t *dst, uint8_t *src, size_t len);
