#include <stdint.h>
#include <stdlib.h>

size_t swe(uint8_t *out, uint8_t *in, size_t in_size, uint8_t sw_size);
size_t unswe(uint8_t *dst, uint8_t *src, size_t src_len);

size_t lzk(uint8_t *dst, uint8_t *src, size_t src_len);
size_t unlzk(uint8_t *dst, uint8_t *src, size_t src_len);

