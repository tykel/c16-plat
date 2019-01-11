#include <stdio.h>
#include <stdbool.h>
#include <string.h>
#include "swe.h"

#ifndef MIN
#define MIN(x,y) ((x) < (y) ? (x) : (y))
#endif

static int find_byte(uint8_t *in, uint8_t *in_end, uint8_t v)
{
   uint8_t *in_start = in;
   for (; in != in_end; ++in) {
      if (*in == v) {
         return in - in_start;
      }
   }
   return -1;
}

/*
 * Sliding window encoding.
 *
 * Simplistic variant of LZ-family encoding.
 * In this scheme, each length-value pair may encode one of two situations:
 * - "write the following byte 0<N<128 times"
 * - "copy 0<N<128 bytes from the following negative offset in the decode buffer"
 */
size_t swe(uint8_t *out, uint8_t *in, size_t in_size, uint8_t sw_size)
{
   int bc = 0;
   int i = 0;
   int window_size = 0;
   
   // in:  00 00 00 00 01 f8 00 00 fa fa f8 00 14 00 00 00
   // out: 84 00 81 01 81 f8 02 06 82 fa 02 05 81 14 83 0c
   //
   while (i < in_size) {
      uint8_t b = in[i];
      int b_pos_in_w = find_byte(in + i - window_size, in + i, b);
      if (b_pos_in_w == -1) {
         /* 
          * If the current input byte is not in the window, encode as a
          * literal.
          */
         size_t n = 1;
         while (in[i + n] == b) ++n;
         out[bc++] = 0x80 + n;
         out[bc++] = b;
         i += n;
         window_size = MIN(window_size + n, sw_size - 1);
      } else {
         /*
          * Otherwise, find the longest sequence of bytes in the window which
          * matches the current+following input bytes.
          */
         size_t longest_match = 1;
         size_t longest_match_start = b_pos_in_w;
         // Each occurrence of b in the window may mark the start of a run.
         while (b_pos_in_w != -1) {
            uint8_t temp[sw_size];
            int next_b_in_w_offs;
            size_t match_len = 1;
            bool match = true;
            while (match &&
                   i + b_pos_in_w + match_len < in_size &&
                   b_pos_in_w + match_len < MIN(window_size + match_len, sw_size - 1)) {
               match = memcmp(in + i - window_size + b_pos_in_w, in + i, match_len + 1) == 0;
               if (match) ++match_len;
            }
            if (match_len > longest_match) {
               longest_match = match_len;
               longest_match_start = b_pos_in_w;
            }
            next_b_in_w_offs = find_byte(in + i - window_size + b_pos_in_w + 1,
                                         in + i,
                                         b);
            if (next_b_in_w_offs < 0)
               b_pos_in_w = -1;
            else
               b_pos_in_w += next_b_in_w_offs + 1;
         }
         out[bc++] = longest_match;
         out[bc++] = window_size - longest_match_start;
         i += longest_match;
         window_size = MIN(window_size + longest_match, sw_size - 1);
      }
   }
   return bc;
}

size_t unswe(uint8_t *dst, uint8_t *src, size_t src_len)
{
   uint8_t *dst_orig = dst;
   uint8_t *src_orig = src;

   while (src - src_orig < src_len) {
      uint8_t b0 = *src++;
      uint8_t b1 = *src++;
      if (b0 & 0x80) {
         b0 = b0 & 0x7f;
         while (b0--) {
            *dst++ = b1;
         }
      } else {
         uint8_t *dst_copy = dst - b1;
         while (b0--) {
            *dst++ = *dst_copy++;
         }
      }
   }
   
   return dst - dst_orig;
}



/*
 * LZK ("Lempel-Ziv Kelsall") - Custom Chip16 variant of LZ compression.
 *
 * Stream format:
 * - Initial 16-bit word reporting the compressed buffer length.
 * - Control word: 8x 2 bits, mapping what the next 8 input block types are.
 * - LITB type: 8 bits value.
 * - LITW type: 16 bits value.
 * - REP type: 1 bit keep reading for length, 7 bits length (repeat).
 *   Then 8 bits value.
 * - COPY type: 1 bit keep reading for length, 7 bits length (repeat).
 *   Then 1 bit keep reading for distance, 8 bits distance (repeat).
 *
 * Window size limited to src buffer size, which is OK as we are dealing with
 * small data files.
 *
 * Another improvement over SWE, the previous LZ-based encoder, is an effort to
 * approach an optimal parsing more closely.
 *
 * in :               00 00 00 00 01 f8 00 00 fa fa f8 00 14 00 00 00
 * out (excl. size) : xx xx 04 00 01 f8 00 00 fa fa f8 00 14 0c 03
 *
 */
#define INPUT_BLOCKS 8

enum block_type {
   BLOCKTYPE_LITB = 0,
   BLOCKTYPE_LITW = 1,
   BLOCKTYPE_REP  = 2,
   BLOCKTYPE_COPY = 3,
};

struct match {
   enum block_type type;
   size_t len;
   size_t distance;
};

static inline size_t min4(size_t a, size_t b, size_t c, size_t d)
{
   size_t min_ab = a < b ? a : b;
   size_t min_cd = c < d ? c : d;
   return min_ab < min_cd ? min_ab : min_cd;
}

static size_t lzk_memcmp(uint8_t *a, uint8_t *b, size_t max_len)
{
   uint8_t *a_orig = a;
   while (a - a_orig < max_len &&
          *a == *b) {
      ++a;
      ++b;
   }
   return a - a_orig;
}

void lzk_pass1(uint8_t *src, size_t src_len, struct match *best_match)
{
   size_t b;

   for (b = 0; b < src_len; ++b) {
      uint8_t *src_cur = src + b;
      uint8_t *window = src;
      size_t len_rep = 0;
      size_t len_copy = 0;
      size_t distance_copy = 0;

      /* First calculate number of repetitions. */
      while (src_cur + len_rep < src + src_len &&
             *(src_cur + len_rep) == *src_cur)
         ++len_rep;
      /* Then calculate longest from window. */
      if (src_cur - window > 0x7fff) window = src_cur - 0x7fff;
      /*
       * TODO: Implement some form of optimization so we can skip as much as
       * possible.
       */
#ifdef LZK_SLOW
      for (; window < src_cur; ++window) {
         size_t max_match_len = src_cur - window;
         if (src_cur + max_match_len > src + src_len)
            max_match_len = src_len - (src_cur - src);
         /* If we can no longer get better match, no point looking further. */
         if (max_match_len <= len_copy ||
             max_match_len <= len_rep ||
             max_match_len <= 2)
            break;
         size_t len_common = lzk_memcmp(window, src_cur, max_match_len);
         if (len_common > len_copy) {
            len_copy = len_common;
            distance_copy = src_cur - window;
         }
      }
#else
      size_t i;
      size_t max_match_len = src_cur - window;
      if (src_cur + max_match_len > src + src_len)
         max_match_len = src_len - (src_cur - src);
      for (i = max_match_len; i > 2; --i) {
         size_t len_match = lzk_memcmp(src_cur - i, src_cur, i);
         if (len_match > len_copy) {
            len_copy = len_match;
            distance_copy = i;
         }
      }
#endif
      /* Record the longest of the two. */
      if (len_copy > len_rep) {
         best_match[b].type = BLOCKTYPE_COPY;
         best_match[b].len = len_copy;
         best_match[b].distance = distance_copy;
      } else {
         best_match[b].type = BLOCKTYPE_REP;
         best_match[b].len = len_rep;
         best_match[b].distance = 0; 
      }
   }
}

size_t lzk(uint8_t *dst, uint8_t *src, size_t src_len)
{
   size_t max_lookback = 0;
   uint8_t *dst_orig = dst;
   uint8_t enc_buffer[INPUT_BLOCKS * 2];
   size_t cur_input_block = 0;
   enum block_type enc_block_types[INPUT_BLOCKS];
   struct match *best_match;
   int b;
   size_t dst_blocks = 0;
   /* Worst case for output buffer is 8 COPYs with extended len/distance. */
   uint8_t outbuf[4 * 8];
   uint16_t outbuf_ctlw = 0;
   uint8_t outbuf_size = 0;

   /* Pass 1: Create a table of the best match length at each byte position. */
   best_match = malloc(sizeof(*best_match) * src_len);
   memset(best_match, 0, sizeof(*best_match) * src_len);
   lzk_pass1(src, src_len, best_match);

   /* Pass 2: Walk the matches (in reverse) to find an optimal parse. */
   /* Initial cost is 16 bits control, + 8 bits for LITB; = 3 bytes. */
   size_t *cost = malloc(src_len * sizeof(size_t));
   size_t blocks = 0;
   cost[src_len - 1] = 2 + 1;
   best_match[src_len - 1].type = BLOCKTYPE_LITB;
   for (b = src_len - 2; b >= 0; --b) {
      size_t cost_min, cost_litb, cost_litw, cost_rep, cost_copy;
      size_t best_len_rep, best_len_copy;
      int i;
      
      cost_litb = 1 + cost[b + 1];
      if (src_len - b > 2)
         cost_litw = 2 + cost[b + 2];
      else
         cost_litw = SIZE_MAX;
      cost_rep = SIZE_MAX;
      cost_copy = SIZE_MAX;
      if (best_match[b].len > 0) {
         size_t max_len = best_match[b].len < src_len - b ? best_match[b].len
                                                          : src_len - b;
         for (i = 1; i < max_len; ++i) {
            if (best_match[b].type == BLOCKTYPE_COPY) {
               size_t cost_this_copy = cost[b + i] + 2 + !!(best_match[b].len > 127) + !!(best_match[b].distance > 255);
               if (cost_this_copy < cost_copy) {
                  cost_copy = cost_this_copy;
                  best_len_copy = i;
               }
            } else {
               size_t cost_this_rep = cost[b + i] + 2 + !!(best_match[b].len > 127);
               if (cost_this_rep < cost_rep) {
                  cost_rep = cost_this_rep;
                  best_len_rep = i;
               }
            }
         }
      }
      cost_min = min4(cost_litb, cost_litw, cost_rep, cost_copy);
      if (cost_min == cost_litb) {
         best_match[b].type = BLOCKTYPE_LITB;
      }
      if (cost_min == cost_litw) {
         best_match[b].type = BLOCKTYPE_LITW;
      }
      if (cost_min == cost_rep) {
         best_match[b].type = BLOCKTYPE_REP;
         best_match[b].len = best_len_rep;
      }
      if (cost_min == cost_copy) {
         best_match[b].type = BLOCKTYPE_COPY;
         best_match[b].len = best_len_copy;
      }
      
      /* Emit another 16 control bits if the previous word filled up. */
      if (++blocks % 8 == 0) {
         cost_min += 2;
      }
      cost[b] = cost_min;
   }

   /* Pass 3: emit the optimal groups we ended up finding. */
   for (b = 0; b < src_len; ) {
      if (dst_blocks == 8) {
         *dst++ = outbuf_ctlw & 0xff;
         *dst++ = outbuf_ctlw >> 8;
         memcpy(dst, outbuf, outbuf_size);
         dst += outbuf_size;
         outbuf_size = 0;
         dst_blocks = 0;
         //printf("Control word %04x\n", outbuf_ctlw);
         outbuf_ctlw = 0;
      }
      outbuf_ctlw = outbuf_ctlw + (best_match[b].type << (dst_blocks++ * 2));
      switch (best_match[b].type) {
         case BLOCKTYPE_LITB:
            //printf("Lit. byte %02x\n", src[b]);
            outbuf[outbuf_size++] = src[b];
            b += 1;
            break;
         case BLOCKTYPE_LITW:
            //printf("Lit. word %02x%02x\n", src[b], src[b+1]);
            outbuf[outbuf_size++] = src[b];
            outbuf[outbuf_size++] = src[b+1];
            b += 2;
            break;
         case BLOCKTYPE_REP:
            //printf("Repeat (%d times) %02x\n", best_match[b].len, src[b]);
            outbuf[outbuf_size++] = best_match[b].len & 0x7f;
            if (best_match[b].len & ~0x7f) {
               outbuf[outbuf_size - 1] += 0x80;
               outbuf[outbuf_size++] = best_match[b].len >> 7;
            }
            outbuf[outbuf_size++] = src[b];
            b += best_match[b].len;
            break;
         case BLOCKTYPE_COPY:
            //printf("Copy (%d bytes) (from %d bytes back)\n", best_match[b].len, best_match[b].distance);
            outbuf[outbuf_size++] = best_match[b].len & 0x7f;
            if (best_match[b].len & ~0x7f) {
               outbuf[outbuf_size - 1] += 0x80;
               outbuf[outbuf_size++] = best_match[b].len >> 7;
            }
            outbuf[outbuf_size++] = best_match[b].distance & 0x7f;
            if (best_match[b].distance & ~0x7f) {
               outbuf[outbuf_size - 1] += 0x80;
               outbuf[outbuf_size++] = best_match[b].distance >> 7;
            }
            b += best_match[b].len;
            break;
      }
   }
   if (outbuf_size > 0) {   
      *dst++ = outbuf_ctlw & 0xff;
      *dst++ = outbuf_ctlw >> 8;
      memcpy(dst, outbuf, outbuf_size);
      dst += outbuf_size;
   }

   free(cost);
   free(best_match);
   return dst - dst_orig;
}

size_t unlzk(uint8_t *dst, uint8_t *src, size_t src_len)
{
   uint8_t *dst_orig = dst;
   uint8_t *src_orig = src;
   size_t blocks_read = 8;
   union {
      uint8_t b[2];
      uint16_t w;
   } ctl;
   while (src - src_orig < src_len) {
      if (blocks_read++ == 8) {
         ctl.b[0] = *src++;
         ctl.b[1] = *src++;
         blocks_read = 1;
         //printf("New control word: %04x\n", ctl.w);
      }
      switch (ctl.w & 3) {
         case BLOCKTYPE_LITW:
            //printf("Literal word: %02x%02x\n", *src, *(src+1));
            *dst++ = *src++;
            *dst++ = *src++;
            break;
         case BLOCKTYPE_LITB:
            //printf("Literal byte: %02x\n", *src);
            *dst++ = *src++;
            break;
         case BLOCKTYPE_REP:
         {
            size_t n = *src++;
            if (n > 127) n = (n & 0x7f) | (*src++ << 7);
            uint8_t v = *src++;
            //printf("Repeat (%d times) %02x\n", n, v);
            while (n--) *dst++ = v;
            break;
         }
         case BLOCKTYPE_COPY:
         {
            size_t n = *src++;
            if (n > 127) n = (n & 0x7f) + (*src++ << 7);
            size_t d = *src++;
            if (d > 127) d = (d & 0x7f) + (*src++ << 7);
            //printf("Copy (%d bytes) (from %d bytes back)\n", n, d);
            size_t di = 0;
            {
               uint8_t *dst_start = dst;
               while (n--) *dst++ = (*(dst_start - d + di++));
            }
            break;
         }
      }
      ctl.w = ctl.w >> 2;
   }
   return dst - dst_orig;
}
