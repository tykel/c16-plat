#include "rle.h"

/* 
 * Custom RLE where non-zero values are encoded literally. Only zero runs are
 * encoded as value + run.
 */
size_t rle(uint8_t *src, uint8_t *dst, size_t len)
{
   uint8_t byte_to_rep = *src;
   uint8_t byte_count = 1;
   uint8_t *s = src + 1;
   uint8_t *d = dst;

   // in:  81 82 83 84 00 00 00 00 81 82 83 84
   // out: 81 82 83 84 00 04 81 82 83 84
   //
   while (s < src + len) {
      if (*s == byte_to_rep && byte_count < 0xff && byte_to_rep == 0) {
         ++byte_count;
         ++s;
      } else {
         if (byte_to_rep > 0) {
            *d++ = byte_to_rep;
         } else {
            *d++ = 0x00;
            *d++ = byte_count;
         }
         byte_to_rep = *s++;
         byte_count = 1;
      }
   }
   if (byte_to_rep > 0) {
      *d++ = byte_to_rep;
   } else {
      *d++ = 0x00;
      *d++ = byte_count;
   }
   return d - dst;
}

size_t unrle(uint8_t *dst, uint8_t *src, size_t len)
{
   uint8_t *dst_orig = dst;
   uint8_t *src_orig = src;
   while (src - src_orig < len) {
      uint8_t b = *src++;
      if (b == 0) {
         uint8_t count = *src++;
         while (count--)
            *dst++ = 0;
      } else {
         *dst++ = b;
      }
   }
   return dst - dst_orig;
}

