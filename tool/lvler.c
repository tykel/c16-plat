#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <math.h>

#include "rle.h"
#include "swe.h"

#define expect_eq(x,y,s) do{if((x)!=(y)){fprintf(stderr,"test failed: %s. Expected %d, got %d\n",(s),(x),(y));}else{printf("test passed: %s\n",(s));}}while(0);
#define expect_eqmem(x,y,s) do{if(memcmp((x),(y),sizeof((x)))){fprintf(stderr,"test failed: %s\n",s);}else{printf("test passed: %s\n",(s));}}while(0);
#define MIN(x,y) ((x) < (y) ? (x) : (y))

char line[256];

struct metadata {
   int16_t width;
   int16_t height;
   char name[256];
} meta;

struct tile {
   int set;
   int solid;
   int frames;
} tiles[256], objects[256];

struct object_entry {
   int set;
   uint8_t object;
   int16_t x;
   int16_t y;
} obj_list[1024];
int obj_it = 0;

uint16_t *map;
int mapy = 0;

int (*readln_fptr)(FILE *, char *);

void print_buffer(uint8_t *buf, size_t len)
{
   uint8_t *p = buf;
   uint8_t *end = buf + len;
   while (p < end) {
      printf("%02x ", *p++);
   }
   printf("\n");
}

int readln_metadata(FILE *f, char *line)
{
   int len = 256;
   fgets(line, 256, f);
   if (line[0] == '.') {
      readln_fptr = NULL;
      return 0;
   }
   // Parse directives
   len = MIN(strnlen(line, 5), 256);
   if (!strncmp(line, "width", len)) {
      sscanf(line, "width %d\n", &meta.width);
   }
   len = MIN(strnlen(line, 6), 256);
   if (!strncmp(line, "height", len)) {
      sscanf(line, "height%d\n", &meta.height);
   }
   len = MIN(strnlen(line, 4), 256);
   if (!strncmp(line, "name", len)) {
      sscanf(line, "name %s\n", meta.name);
   }

   if (meta.width > 0 && meta.height > 0) {
      map = calloc(1, 2 * meta.width * meta.height);
   }
   return 0;
}

int readln_objects(FILE *f, char *line)
{
   int obj_index;
   int obj_solid;
   int obj_frames;
   int len = 256;
   fgets(line, 256, f);
   /* Handle new sections and empty lines. */
   len = MIN(strnlen(line, 5), 256);
   if (line[0] == '.') {
      readln_fptr = NULL;
      return 0;
   }
   if (line[0] == '\n') {
      return 0;
   }
   /* Parse tile entry. */
   sscanf(line, "%d %*s %d %d\n", &obj_index, &obj_solid, &obj_frames);
   objects[obj_index].set = 1;
   objects[obj_index].solid = !!obj_solid;
   objects[obj_index].frames = obj_frames;
   return 0;
}

int readln_tiles(FILE *f, char *line)
{
   int tile_index;
   int tile_solid;
   int tile_frames;
   int len = 256;
   fgets(line, 256, f);
   /* Handle new sections and empty lines. */
   len = MIN(strnlen(line, 5), 256);
   if (line[0] == '.') {
      readln_fptr = NULL;
      return 0;
   }
   if (line[0] == '\n') {
      return 0;
   }
   /* Parse tile entry. */
   sscanf(line, "%d %*s %d %d\n", &tile_index, &tile_solid, &tile_frames);
   tiles[tile_index].set = 1;
   tiles[tile_index].solid = tile_solid;
   tiles[tile_index].frames = tile_frames;
   return 0;
}

int readln_map(FILE *f, char *line)
{
   char *tile;
   int mapx = 0;
   int len = 256;

   fgets(line, 256, f);
   /* Handle new sections and empty lines. */
   len = MIN(strnlen(line, 5), 256);
   if (line[0] == '.') {
      readln_fptr = NULL;
      return 0;
   }
   if (line[0] == '\n') {
      return 0;
   }
   if (feof(f)) {
      return 0;
   }
   if (mapy >= meta.height) {
      fprintf(stderr, "warning: map contains more rows than declared! (y: %d, height: %d)\n", mapy, meta.height);
   }

   /* Parse map entries. */
   tile = strtok(line, " ");
   while (tile != NULL) {
      /* If prefixed by '$', it's an object. */
      if (!strncmp(tile, "$", 1)) {
         uint8_t obj_index = (atoi(tile + 1) & 0x7f) + 1;
         obj_list[obj_it].set = 1;
         obj_list[obj_it].object = obj_index;
         obj_list[obj_it].x = mapx;
         obj_list[obj_it].y = mapy;
         printf("map: found obj %d @ (%d,%d)\n", obj_index, mapx, mapy);
         ++obj_it;
      } else {
         uint8_t tile_index = atoi(tile) & 0x7f;
         uint8_t tile_frames = (tiles[tile_index].frames - 1) & 1;
         uint8_t tile_solid = tiles[tile_index].solid;
         uint tile_in_map = (tile_index + 1) | (tile_frames << 6) | (tile_solid << 7);

         if (!strncmp(tile, "_", 1)) {
            map[mapy * meta.width + mapx] = 0;
         } else {
            map[mapy * meta.width + mapx] = tile_in_map;
         }
      }
      mapx += 1;
      tile = strtok(NULL , " ");
   }

   mapy += 1;
   return 0;
}

int readln(FILE *f, char *line)
{
   if (readln_fptr != NULL) {
      return readln_fptr(f, line);
   }
   if (!strncmp(line, ".meta\n", 256)) {
      readln_fptr = readln_metadata;
      //printf("found metadata entry\n");
   } else if (!strncmp(line, ".tiles\n", 256)) {
      readln_fptr = readln_tiles;
      //printf("found tiles entry\n");
   } else if (!strncmp(line, ".map\n", 256)) {
      readln_fptr = readln_map;
      //printf("found map entry\n");
      mapy = 0;
      if (meta.width < 1 || meta.height < 1) {
         fprintf(stderr, "error: no width and/or height set in .meta section\n");
         return 1;
      }
   } else if (!strncmp(line, ".objects\n", 256)) {
      readln_fptr = readln_objects;
      //printf("found objects entry\n");
   }
   return 0;
}


size_t compress(uint16_t *map, int cols, int rows, bool use_swe, uint8_t **dst)
{
   const char *enc_str = use_swe ? "SWE" : "RLE";
   const size_t bufsz = rows * cols;
   uint8_t *tmp_tiles = calloc(1, bufsz);
   uint8_t *cpx_tiles = calloc(1, 2 * bufsz);
   uint8_t *cpx_map;
   uint8_t *tmp;
   int x, y;
   int tiles_cpx_size = 0;
   int total_cpx_size = 0;

   for (y = 0; y < rows; y++) {
      for (x = 0; x < cols; x++) {
         uint16_t val = map[(y * cols + x)];
         tmp_tiles[y * cols + x] = val & 0xff;
         printf("%02x ", val & 0xff);
      }
      printf("\n");
   }
  
   if (use_swe) {
      tiles_cpx_size = swe(cpx_tiles, tmp_tiles, bufsz, 128);
   } else {
      tiles_cpx_size = rle(tmp_tiles, cpx_tiles, bufsz);
   }
#ifdef DEBUG
   printf("Raw tiles data:\n");
   print_buffer(tmp_tiles, bufsz);
   printf("%s tiles data:\n", enc_str);
   print_buffer(cpx_tiles, tiles_cpx_size);
   printf("%s size ratio for tiles data: % 3.2f %%\n",
          enc_str, 100.f*(float)tiles_cpx_size/(float)bufsz);
#endif

   total_cpx_size = 2 + tiles_cpx_size + 2 + 6*obj_it;
   printf("Raw map size: %d bytes\n", meta.width * meta.height * 2);
   printf("%s map size: %d bytes\n", enc_str, total_cpx_size);
   printf("%s size is % .2f %% of raw\n",
          enc_str, 100.f*(float)total_cpx_size/(float)(meta.width * meta.height * 2));

   /* Allow for the section sizes too! */
   cpx_map = malloc(total_cpx_size);
   tmp = cpx_map;
   // 2 b
   *(int16_t *)tmp = tiles_cpx_size;
   tmp += 2;
   // tiles_cpx_size b
   memcpy(tmp, cpx_tiles, tiles_cpx_size);
   tmp += tiles_cpx_size;
   printf("writing %04x\n", obj_it);
   // 2 b
   *(int16_t *)tmp = (int16_t) obj_it;
   tmp += 2;
   for (x = 0; x < obj_it; ++x) {
      printf("writing %04x %04x %04x\n", obj_list[x].object, obj_list[x].x, obj_list[x].y);
      // 2 b
      *(int16_t *)tmp = obj_list[x].object;
      tmp += 2;
      // 2 b
      *(int16_t *)tmp = obj_list[x].x;
      tmp += 2;
      // 2 b
      *(int16_t *)tmp = obj_list[x].y;
      tmp += 2;
   }

   *dst = cpx_map;
   
   free(tmp_tiles);
   free(cpx_tiles);

   return total_cpx_size;
}

int main(int argc, char **argv)
{
   FILE *file_input;
   FILE *file_output;
   size_t file_output_len = 0;

   if (argc > 1 && !strncmp(argv[1], "test", 4)) {
      {
         uint8_t src[] = { 0, 0, 0, 0, 0, 1, 1, 0 };
         uint8_t expected_dst[] = { 0, 5, 1, 1, 0, 1 };
         uint8_t actual_dst[256] = { 0 };
         size_t len = rle(src, actual_dst, sizeof(src));
         expect_eq(sizeof(expected_dst), len, "RLE test (size)");
         expect_eqmem(expected_dst, actual_dst, "RLE test (contents)"); 
      }
      {
         uint8_t src[] = { 0, 0, 0, 0, 0, 1, 1, 0 };
         uint8_t expected_dst[] = { 0x85, 0, 0x82, 1, 0x01, 7 };
         uint8_t actual_dst[256] = { 0 };
         size_t len = swe(actual_dst, src, sizeof(src), 128);
         expect_eq(sizeof(expected_dst), len, "SWE test (size)");
         expect_eqmem(expected_dst, actual_dst, "SWE test (contents)");
      }
      return 0;
   }

   if (argc < 4 || !strncmp(argv[1], "-h", 2) || !strncmp(argv[1], "--help", 6) ||
       strncmp(argv[2], "-o", 2)) {
      printf("usage: lvler <infile> -o <outfile> [--rle|--swe]\n");
      printf("       lvler test\n");
      return 0;
   }

   readln_fptr = readln_metadata;

   file_input = fopen(argv[1], "r");
   while (!feof(file_input)) {
      readln(file_input, line);
   }
   fclose(file_input);

   if (meta.name == NULL) {
      fprintf(stderr, "error: no level name set in .meta section\n");
      return 1;
   }

   file_output = fopen(argv[3], "wb");
   
   file_output_len += fwrite(&meta, 1, 2*sizeof(int16_t), file_output);
   if (argc > 4 && !strncmp(argv[4], "--rle", 5) ||
       argc > 4 && !strncmp(argv[4], "--swe", 5)) {
      size_t compress_len;
      size_t file_actual_len;
      uint8_t *cpx_map;
      bool use_swe = !strncmp(argv[4], "--swe", 5);
      compress_len = compress(map, meta.width, meta.height, use_swe, &cpx_map);
      printf("compress returned len %d bytes\n", compress_len);
      file_output_len += compress_len;
      file_actual_len = fwrite(cpx_map, 1, file_output_len, file_output);
      if (file_actual_len != file_output_len) {
         printf("warning: wrote %u bytes, expected %u bytes\n",
                file_actual_len, file_output_len);
      }
      free(cpx_map);
   } else {
      file_output_len += meta.width * meta.height * sizeof(int16_t);
      fwrite(map, file_output_len, 1, file_output);
   }
   fclose(file_output);
   printf("importbin %s 0 %d data.%s\n", argv[3], file_output_len, meta.name);

   free(map);

   return 0;
}
