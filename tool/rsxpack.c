#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define MAX(a,b) ((a) > (b) ? (a) : (b))
#define MIN(a,b) ((a) < (b) ? (a) : (b))


/*
 * Run length encoding.
 *
 * This variant encodes non-zeroes directly, and zero bytes as a (00, NN)
 * pair.
 */
size_t rle(uint8_t *out, uint8_t *in, size_t in_size, size_t max_out_size, bool only0)
{
   int bc = 0;
   int i = 0;
   for (; i < in_size;) {
      uint8_t b = in[i];
      if (b != 0 && only0) {
         out[bc++] = b;
         i++;
      } else {
         int j = 0;
         for (j = 0; j < 256; j++) {
            if (i + j >= in_size)
               break;
            if (in[i + j] != b)
               break;
         }
         out[bc++] = b;
         out[bc++] = j;
         i += j;
      }
   }
   return bc;
}

int find_byte(uint8_t *in, uint8_t *in_end, uint8_t v)
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
size_t swe(uint8_t *out, uint8_t *in, size_t in_size, size_t max_out_size, uint8_t sw_size)
{
   /*
    * 00 00 00 00 01 f8 00 00 fa fa f8 00 14 00 00 00
    * ->
    * 84 00 81 01 81 f8 02 06 82 fa 02 05 81 14 83 0c
    */
   int bc = 0;
   int i = 0;
   int window_size = 0;
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
            int next_b_in_w_offs;
            size_t match_len = 1;
            bool match = true;
            while (match &&
                   i + b_pos_in_w - window_size + match_len < in_size &&
                   b_pos_in_w + match_len < window_size) {
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

int run_tests(void)
{
   uint8_t i[]  = {
      0x00, 0x00, 0x00, 0x00, 0x01, 0xf8, 0x00, 0x00,
      0xfa, 0xfa, 0xf8, 0x00, 0x14, 0x00, 0x00, 0x00,
   };
   // SWE 1
   {
      uint8_t e[]  = {
         0x84, 0x00, 0x81, 0x01, 0x81, 0xf8, 0x02, 0x06,
         0x82, 0xfa, 0x02, 0x05, 0x81, 0x14, 0x03, 0x0d,
      };
      uint8_t o[2 * sizeof(e)] = { 0 };
      size_t o_size;
      if ((o_size = swe(o, i, sizeof(i), 2 * sizeof(e), 128)) != sizeof(e)) {
         fprintf(stderr, "test.fail: swe: output size (%d) != expected size (%d)\n",
                 o_size, sizeof(e));
         return -1;
      }
      if (memcmp(e, o, sizeof(e)) != 0) {
         int n;
         fprintf(stderr, "test.fail: swe: output differs from expected.\n");
         for (n = 0; n < sizeof(e); ++n) {
            fprintf(stderr, "%02x ", o[n]);
         }
         fprintf(stderr, "\n");
         for (n = 0; n < sizeof(e); ++n) {
            fprintf(stderr, "%02x ", e[n]);
         }
         fprintf(stderr, "\n");
      } else {
         printf("test.success: swe\n");
      }
   }
   // RLE 1
   {
      uint8_t e[]  = {
         0x00, 0x04, 0x01, 0xf8, 0x00, 0x02, 0xfa, 0xfa,
         0xf8, 0x00, 0x01, 0x14, 0x00, 0x03,
      }; 
      uint8_t o[2 * sizeof(e)] = { 0 };
      size_t o_size;
      if ((o_size = rle(o, i, sizeof(i), 2 * sizeof(e), true)) != sizeof(e)) {
         fprintf(stderr, "test.fail: rle: output size (%d) != expected size (%d)\n",
                 o_size, sizeof(e));
         return -1;
      }
      if (memcmp(e, o, sizeof(e)) != 0) {
         int n;
         fprintf(stderr, "test.fail: rle: output differs from expected.\n");
         for (n = 0; n < sizeof(e); ++n) {
            fprintf(stderr, "%02x ", o[n]);
         }
         fprintf(stderr, "\n");
         for (n = 0; n < sizeof(e); ++n) {
            fprintf(stderr, "%02x ", e[n]);
         }
         fprintf(stderr, "\n");
      } else {
         printf("test.success: rle\n");
      }
   }
   
}

int main(int argc, char **argv)
{
   FILE *fin = NULL, *fout = NULL;
   char *fname_in = NULL, *fname_out = NULL, *fname_out_imp = NULL;
   char *fname_pos = NULL, *suffix_pos = NULL;
   uint8_t *buf_in = NULL, *buf_out = NULL;
   size_t len_in, out_len;
   bool onlyZeroEnc = true, test = false;
   char opt;
   enum { ENC_NONE, ENC_RLE, ENC_SWE } enc_type = ENC_RLE;

   while ((opt = getopt(argc, argv, "te:ao:")) != -1) {
      switch (opt) {
         case 't':
            test = true;
            break;
         case 'o':
            fname_out = optarg;
            break;
         case 'a':
            onlyZeroEnc = false;
            break;
         case 'e':
            if (strcmp(optarg, "none") == 0) {
               enc_type = ENC_NONE;
               break;
            } else if (strcmp(optarg, "rle") == 0) {
               enc_type = ENC_RLE;
               break;
            } else if (strcmp(optarg, "swe") == 0) {
               enc_type = ENC_SWE;
               break;
            }
         default:
            printf("Usage: rsxpack [-e {none|rle|swe}] [-ta] <input> [-o <output>]\n");
            exit(0);
      }
   }
   if (optind < argc) {
      fname_in = argv[optind];
   }

   if (test) {
      printf("Running tests...\n");
      return run_tests();
   }

   if (fname_in) {
      fin = fopen(fname_in, "rb");
      if (!fin) {
         fprintf(stderr, "error: could not open input '%s'\n", fname_in);
         exit(1);
      }
   } else {
      fin = stdin;
   }
   fseek(fin, 0, SEEK_END);
   len_in = ftell(fin);
   fseek(fin, 0, SEEK_SET);

   buf_in = malloc(len_in);
   if (fread(buf_in, 1, len_in, fin) != len_in) {
      fprintf(stderr, "error: could not read '%s'\n", fname_in);
      fclose(fin);
      exit(1);
   }
   fclose(fin);

   /* 
    * The worst case for RLE is a sequence with no consecutive bytes.
    * For N input bytes, this works out to 2N output bytes.
    */
   buf_out = malloc(2 * len_in);

   if (enc_type == ENC_NONE) {
      out_len = len_in;
      memcpy(buf_out, buf_in, len_in);
   } else if (enc_type == ENC_RLE) {
      out_len = rle(buf_out, buf_in, len_in, 2 * len_in, onlyZeroEnc);
      if (out_len == 0) {
         fprintf(stderr, "error: RLE compression failed\n");
         exit(1);
      }
   } else if (enc_type == ENC_SWE) {
      out_len = swe(buf_out, buf_in, len_in, 2 * len_in, 128);
      if (out_len == 0) {
         fprintf(stderr, "error: SWE conmpression failed\n");
         exit(1);
      }
   }

   if (fname_out) {
      fout = fopen(fname_out, "wb");
      if (!fout) {
         fprintf(stderr, "error: could not open output '%s' for write\n", fname_out);
         exit(1);
      }
   } else {
      fout = stdout;
   }
   fwrite(buf_out, 1, out_len, fout);

   fname_out_imp = malloc(strlen(fname_out));
   strcpy(fname_out_imp, fname_out);
   if ((suffix_pos = strrchr(fname_out_imp, '.')) != NULL) {
      *suffix_pos = '\0';
   }
   while ((fname_pos = strrchr(fname_out_imp, '/')) != NULL) {
      *fname_pos = '_';
   }
   printf("importbin %s 0 %d data.%s\n", fname_out, out_len, fname_out_imp);

   free(buf_out);
   free(buf_in);

   return 0;
}
