SRC:=gfx.s level.s sfx.s plat.s sf.s
GFX_SRC:=gfx/tilemap.bmp gfx/c2b.bmp gfx/objects.bmp gfx/font.bmp
GFX=$(patsubst gfx/%.bmp,gfx/%.bin,$(GFX_SRC))
SFX_SRC:=sfx/mus_menu.mid
SFX=$(patsubst sfx/%.mid,sfx/%.bin,$(SFX_SRC))
LEVELS_SRC:=$(wildcard level/*.src)
LEVELS=$(patsubst level/%.src,level/%.bin,$(LEVELS_SRC))

all: plat.c16 lvler rsxpack

run: plat.c16
	mash16 plat.c16 --symbols plat.sym --audio-volume 128

plat.c16: $(SRC) $(GFX) $(SFX) $(LEVELS)
	sort gfx.s -o gfx.s
	sort level.s -o level.s
	sort sfx.s -o sfx.s
	as16 $(SRC) -o $@ -m
	ctags -R .

gfx/c2b.bin: gfx/c2b.bmp rsxpack
	sed -i '\#$@#d' gfx.s
	img16 $< -o /tmp/$(@F) -k 13
	./rsxpack -e none /tmp/$(@F) -o $@  >> gfx.s
	#rm /tmp/$(@F)

gfx/%.bin: gfx/%.bmp rsxpack
	sed -i '\#$@#d' gfx.s
	img16 $< -o /tmp/$(@F) -k 1
	./rsxpack -e none /tmp/$(@F) -o $@  >> gfx.s
	#rm /tmp/$(@F)

gfx/tilemap.bmp: gfx/n-tiles.bmp
	convert $< -crop 16x16 +repage +adjoin /tmp/tile-%02d.bmp
	convert /tmp/tile-*.bmp -append $@
	rm /tmp/tile-*.bmp

gfx/objects.bmp: gfx/n-objects.bmp
	convert $< -crop 16x16 +repage +adjoin /tmp/obj-%02d.bmp
	convert /tmp/obj-*.bmp -append $@
	rm /tmp/obj-*.bmp

sfx/%.bin: sfx/%.mid rsxpack
	sed -i '\#$@#d' sfx.s
	midi16 $< --channel 4 && echo -ne \\x00\\x00 | dd conv=notrunc bs=2 count=2 of=$@
	mv sfx/mus_menu.bin /tmp/sfx-$(@F)
	./rsxpack -e swe /tmp/sfx-$(@F) -o $@ >> sfx.s
	#rm /tmp/sfx-$(@F)

level.s: lvler

lvler: tool/rle.c tool/swe.c tool/lvler.c
	gcc $^ -o $@ -O2 -Itool

compress_test: tool/rle.c tool/swe.c tool/test.c
	gcc $^ -o $@ -O3 -Itool

rsxpack: tool/rle.c tool/swe.c tool/rsxpack.c
	gcc $^ -o $@ -O2

lvler-gui: tool/lvler-gui.c
	gcc $< -o $@ -O2 $(shell sdl-config --cflags) $(shell sdl-config --libs)

level/%.bin: level/%.src lvler
	sed -i '\#$@#d' level.s
	./lvler $< -o $@ --swe | grep importbin >> level.s
