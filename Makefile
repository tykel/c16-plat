SRC:=gfx.s level.s plat.s
GFX_SRC:=gfx/tilemap.bmp gfx/c2b.bmp gfx/font.bmp
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

#gfx/tilemap.bmp: gfx/o-tiles.bmp
#	convert gfx/o-tiles.bmp -crop 7x8-1@\!-1@\! +repage +adjoin gfx/tile-%02d.bmp
#	mogrify -crop 16x16+0+0 gfx/tile-*.bmp
#	convert gfx/tile-*.bmp -append gfx/tilemap.bmp
#	rm gfx/tile-*.bmp

lvler: tool/lvler.c
	gcc $< -o $@ -O2
	#gcc $< -o $@ -O0 -g

level/%.bin: level/%.src lvler
	./lvler $< -o $@ --rle | grep importbin > level.s
