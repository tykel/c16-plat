SRC:=plat.s
GFX_SRC:=$(wildcard gfx/*.bmp)
GFX=$(patsubst gfx/%.bmp,gfx/%.bin,$(GFX_SRC))

plat.c16: $(SRC) $(GFX)
	as16 $< -o $@ -m

gfx/c2b.bin: gfx/c2b.bmp
	img16 $< -o $@ -k 13 

gfx/%.bin: gfx/%.bmp
	img16 $< -o $@ -k 4
