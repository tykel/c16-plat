SRC:=gfx.s level.s sfx.s plat.s sf.s
GFX_SRC:=gfx/tilemap.bmp gfx/c2b.bmp gfx/objects.bmp gfx/font.bmp
GFX=$(patsubst gfx/%.bmp,gfx/%.bin,$(GFX_SRC))
SFX_SRC:=sfx/mus_menu.mid
SFX=$(patsubst sfx/%.mid,sfx/%.bin,$(SFX_SRC))
LEVELS_SRC:=$(wildcard level/*.src)
LEVELS=$(patsubst level/%.src,level/%.bin,$(LEVELS_SRC))

all: plat.c16 lvler rsxpack

plat.c16: $(SRC) $(GFX) $(SFX) $(LEVELS)
	sort level.s -o level.s
	sort sfx.s -o sfx.s
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

sfx/%.bin: sfx/%.mid
	sed -i '\#$@#d' sfx.s
	midi16 $< --channel 3 && echo -ne \\x00\\x00 | dd conv=notrunc bs=2 count=2 of=$@
	echo importbin $@ 0 $(shell stat --printf="%s" $@) data.$(basename $(@F)) > sfx.s

level.s: lvler

lvler: tool/lvler.c
	gcc $< -o $@ -O2

rsxpack: tool/rsxpack.c
	gcc $< -o $@ -O2

lvler-gui: tool/lvler-gui.c
	gcc $< -o $@ -O2 $(shell sdl-config --cflags) $(shell sdl-config --libs)

level/%.bin: level/%.src lvler
	sed -i '\#$@#d' level.s
	./lvler $< -o $@ --rle | grep importbin >> level.s
