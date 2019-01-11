#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include "swe.h"
#include "rle.h"

int main(int argc, char *argv[])
{
   size_t len_in, len_compressed, len_uncompressed;
   uint8_t *buf_in, *buf_compressed, *buf_uncompressed;
   FILE *fin = fopen(argv[1], "rb");
   size_t len_rle, len_swe, len_lzk;

   fseek(fin, 0, SEEK_END);
   len_in = ftell(fin);
   fseek(fin, 0, SEEK_SET);

   buf_in = malloc(len_in);
   buf_compressed = malloc(len_in * 2);
   buf_uncompressed = malloc(len_in * 2);
   if (fread(buf_in, 1, len_in, fin) != len_in) {
      fprintf(stderr, "error: could not read '%s'\n", argv[1]);
      fclose(fin);
      exit(1);
   }
   fclose(fin);

   printf("compressing lzk... "); fflush(stdout);
   len_compressed = lzk(buf_compressed, buf_in, len_in);
   printf("done.\n");
   /*{ 
      int i;
      for (i = 0; i < len_compressed; ++i) {
         bool lstart = i%16==0;
         bool lend = i%16==15;
         if (lstart) printf("%06x: ", i);
         printf("%02x%c", buf_compressed[i], lend?'\n':' ');
      }
      printf("\n");
   }*/
   len_lzk = len_compressed;
   len_uncompressed = unlzk(buf_uncompressed, buf_compressed, len_compressed);
   
   if (len_uncompressed != len_in) {
      fprintf(stderr, "error: lzk: length uncompressed (%d) != length input (%d)\n",
              len_uncompressed, len_in);
      exit(1);
   }
   if (memcmp(buf_uncompressed, buf_in, len_in) != 0) {
      int i;
      fprintf(stderr, "error: lzk: uncompressed != input. Dump:\n",
              len_uncompressed, len_in);
      for (i = 0; i < len_in; ++i) {
         bool lstart = i%16==0;
         bool lend = i%16==15;
         if (lstart) printf("%06x: ", i);
         printf("%02x%c", buf_uncompressed[i], lend?'\n':' ');
      }
      printf("\n");
      for (i = 0; i < len_in; ++i) {
         bool lstart = i%16==0;
         bool lend = i%16==15;
         if (lstart) printf("%06x: ", i);
         printf("%02x%c", buf_in[i], lend?'\n':' ');
      }
      printf("\n");
      exit(1);
   }

   printf("compressing swe... "); fflush(stdout);
   len_compressed = swe(buf_compressed, buf_in, len_in, 128);
   printf("done.\n");
   len_swe = len_compressed;
   len_uncompressed = unswe(buf_uncompressed, buf_compressed, len_compressed);
   
   if (len_uncompressed != len_in) {
      fprintf(stderr, "error: swe: length uncompressed (%d) != length input (%d)\n",
              len_uncompressed, len_in);
      exit(1);
   }
   if (memcmp(buf_uncompressed, buf_in, len_in) != 0) {
      int i;
      fprintf(stderr, "error: swe: uncompressed != input. Dump:\n",
              len_uncompressed, len_in);
      for (i = 0; i < len_in; ++i) {
         bool lstart = i%16==0;
         bool lend = i%16==15;
         if (lstart) printf("%06x: ", i);
         printf("%02x%c", buf_uncompressed[i], lend?'\n':' ');
      }
      printf("\n");
      for (i = 0; i < len_in; ++i) {
         bool lstart = i%16==0;
         bool lend = i%16==15;
         if (lstart) printf("%06x: ", i);
         printf("%02x%c", buf_in[i], lend?'\n':' ');
      }
      printf("\n");
      exit(1);
   }
   
   printf("compressing rle... "); fflush(stdout);
   len_compressed = rle(buf_in, buf_compressed, len_in);
   printf("done.\n");
   len_rle = len_compressed;
   len_uncompressed = unrle(buf_uncompressed, buf_compressed, len_compressed);
   
   if (len_uncompressed != len_in) {
      fprintf(stderr, "error: rle: length uncompressed (%d) != length input (%d)\n",
              len_uncompressed, len_in);
      exit(1);
   }
   if (memcmp(buf_uncompressed, buf_in, len_in) != 0) {
      int i;
      fprintf(stderr, "error: rle: uncompressed != input. Dump:\n",
              len_uncompressed, len_in);
      for (i = 0; i < len_in; ++i) {
         bool lstart = i%16==0;
         bool lend = i%16==15;
         if (lstart) printf("%06x: ", i);
         printf("%02x%c", buf_uncompressed[i], lend?'\n':' ');
      }
      printf("\n");
      for (i = 0; i < len_in; ++i) {
         bool lstart = i%16==0;
         bool lend = i%16==15;
         if (lstart) printf("%06x: ", i);
         printf("%02x%c", buf_in[i], lend?'\n':' ');
      }
      printf("\n");
      exit(1);
   }
  
   printf("| Compression | Size (bytes) | Comp. Ratio |\n");
   printf("+-------------+--------------+-------------+\n");
   printf("| -           | % 12u | %10.1f%% |\n",
          len_in, 100.0);
   printf("| RLE         | % 12u | %10.1f%% |\n",
          len_rle, 100.0*(double)len_rle/(double)len_in);
   printf("| SWE (LZ v1) | % 12u | %10.1f%% |\n",
          len_swe, 100.0*(double)len_swe/(double)len_in);
   printf("| LZK (LZ v2) | % 12u | %10.1f%% |\n",
          len_lzk, 100.0*(double)len_lzk/(double)len_in);

   free(buf_uncompressed);
   free(buf_compressed);
   free(buf_in);

   return 0;
}
