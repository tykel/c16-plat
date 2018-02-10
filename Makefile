SRC:=gfx.s level.s plat.s
GFX_SRC:=gfx/tilemap.bmp gfx/c2b.bmp gfx/objects.bmp gfx/font.bmp
GFX=$(patsubst gfx/%.bmp,gfx/%.bin,$(GFX_SRC))
LEVELS_SRC:=$(wildcard level/*.src)
LEVELS=$(patsubst level/%.src,level/%.bin,$(LEVELS_SRC))

all: plat.c16 lvler

plat.c16: $(SRC) $(GFX) $(LEVELS)
	as16 $(SRC) -o $@ -m
	ctags -R .

gfx/c2b.bin: gfx/c2b.bmp
	img16 $< -o $@ -k 13 

gfx/%.bin: gfx/%.bmp
	img16 $< -o $@ -k 1

gfx/tilemap.bmp: gfx/n-tiles.bmp
	convert $< -crop 16x16 +repage +adjoin /tmp/tile-%02d.bmp
	convert /tmp/tile-*.bmp -append $@
	rm /tmp/tile-*.bmp

gfx/objects.bmp: gfx/n-objects.bmp
	convert $< -crop 16x16 +repage +adjoin /tmp/obj-%02d.bmp
	convert /tmp/obj-*.bmp -append $@
	rm /tmp/obj-*.bmp

level.s: lvler

lvler: tool/lvler.c
	gcc $< -o $@ -O2

lvler-gui: tool/lvler-gui.c
	gcc $< -o $@ -O2 $(shell sdl-config --cflags) $(shell sdl-config --libs)

level/%.bin: level/%.src lvler
	./lvler $< -o $@ --rle | grep importbin > level.s
