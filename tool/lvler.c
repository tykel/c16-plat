#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#define MIN(x,y) ((x) < (y) ? (x) : (y))

char line[256];

struct metadata {
   int width;
   int height;
   char name[256];
} meta;

struct tile {
   int set;
   int frames;
} tiles[256];

uint16_t *map;
int mapy = 0;

int (*readln_fptr)(FILE *, char *);

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

int readln_tiles(FILE *f, char *line)
{
   int tile_index;
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
   sscanf(line, "%d %*s %d\n", &tile_index, &tile_frames);
   tiles[tile_index].set = 1;
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

   /* Parse map entries. */
   tile = strtok(line, " ");
   while (tile != NULL) {
      uint8_t tile_index = atoi(tile) & 0x7f;
      uint8_t tile_frames = (tiles[tile_index].frames - 1) & 1;
      uint tile_in_map = (tile_index + 1) | (tile_frames << 6);
      if (!strncmp(tile, "_", 1)) {
         map[mapy * meta.width + mapx] = 0;
      } else {
         map[mapy * meta.width + mapx] = tile_in_map;
      }
      mapx += 1;
      tile = strtok(NULL , " ");
   }

   mapy += 1;
   return 0;
}

int readln_solid(FILE *f, char *line)
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

   /* Parse map entries. */
   tile = strtok(line, " ");
   while (tile != NULL) {
      uint8_t tile_solid = atoi(tile) & 1;
      uint tile_in_map = map[mapy * meta.width + mapx] | (tile_solid << 7);
      map[mapy * meta.width + mapx] = tile_in_map;
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
   } else if (!strncmp(line, ".solid\n", 256)) {
      readln_fptr = readln_solid;
      //printf("found solid-ness entry\n");
      mapy = 0;
      if (meta.width < 1 || meta.height < 1) {
         fprintf(stderr, "error: no width and/or height set in .meta section\n");
         return 1;
      }
   }
   return 0;
}


int main(int argc, char **argv)
{
   FILE *file_input;
   FILE *file_output;

   if (argc < 2 || !strncmp(argv[1], "-h", 2) || !strncmp(argv[1], "--help", 6)) {
      printf("usage: lvler <file.txt>\n");
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
   file_output = fopen(meta.name, "wb");
   fwrite(map, 2 * meta.width * meta.height, 1, file_output);
   fclose(file_output);

   free(map);

   return 0;
}
