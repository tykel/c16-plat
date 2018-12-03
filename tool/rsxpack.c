#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

size_t rle(uint8_t *out, uint8_t *in, size_t in_size, size_t max_out_size, bool only0)
{
   int bc = 0;
   int i = 0;
   for (; i < in_size;) {
      uint8_t b = in[i];
      if (b != 0 && only0) {
         out[bc++] = 0;
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

int main(int argc, char **argv)
{
   FILE *fin = NULL, *fout = NULL;
   char *fname_in = NULL, *fname_out = NULL, *fname_out_imp = NULL;
   char *fname_pos = NULL, *suffix_pos = NULL;
   uint8_t *buf_in = NULL, *buf_out = NULL;
   size_t len_in, out_len;
   bool onlyZeroEnc = true, dummy = false;
   char opt;

   while ((opt = getopt(argc, argv, "dao:")) != -1) {
      switch (opt) {
         case 'o':
            fname_out = optarg;
            break;
         case 'a':
            onlyZeroEnc = false;
            break;
         case 'd':
            dummy = true;
            break;
         default:
            printf("Usage: rsxpack [-da] <input> [-o <output>]\n");
            exit(0);
      }
   }
   if (optind < argc) {
      fname_in = argv[optind];
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

   if (dummy) {
      out_len = len_in;
      memcpy(buf_out, buf_in, len_in);
   } else {
      out_len = rle(buf_out, buf_in, len_in, 2 * len_in, onlyZeroEnc);
      if (out_len == 0) {
         fprintf(stderr, "error: RLE failed\n");
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
