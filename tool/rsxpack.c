#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "rle.h"
#include "swe.h"

#define MAX(a,b) ((a) > (b) ? (a) : (b))
#define MIN(a,b) ((a) < (b) ? (a) : (b))

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
      if ((o_size = swe(o, i, sizeof(i), 128)) != sizeof(e)) {
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
      if ((o_size = rle(o, i, sizeof(i))) != sizeof(e)) {
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
   bool test = false;
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
      out_len = rle(buf_out, buf_in, len_in);
      if (out_len == 0) {
         fprintf(stderr, "error: RLE compression failed\n");
         exit(1);
      }
   } else if (enc_type == ENC_SWE) {
      out_len = swe(buf_out, buf_in, len_in, 128);
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
