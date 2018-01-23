SRC:=plat.s
GFX_SRC:=$(wildcard gfx/*.bmp)
GFX=$(patsubst gfx/%.bmp,gfx/%.bin,$(GFX_SRC))
LEVELS_SRC:=$(wildcard level/*.src)
LEVELS=$(patsubst level/%.src,level/%.bin,$(LEVELS_SRC))

all: plat.c16 lvler

plat.c16: $(SRC) $(GFX) $(LEVELS)
	as16 gfx.s $< -o $@ -m

gfx/c2b.bin: gfx/c2b.bmp
	img16 $< -o $@ -k 13 

gfx/%.bin: gfx/%.bmp
	img16 $< -o $@ -k 4

lvler: tool/lvler.c
	gcc $< -o $@ -O2

level/%.bin: level/%.src lvler
	./lvler $<
