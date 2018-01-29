;------------------------------------------------------------------------------
; Tile structure:
;
; bit(s)   || 7      | 6                  | 5..0
; ---------++--------+--------------------+-----------------
; meaning  || solid? | Num. frames (-1)   | tile number (+1)
;
; A tilemap entry of 0 means there is nothing, skip.
; Therefore tile 0 is entered with a tile number of 1 to differentiate them.
; Number of animation frames is always >= 1. So add 1 to stored num. frames.
;
; Examples:
; 0x01      0 0 000001     Non-solid, 1-frame (no anim.), tile 0
; 0x8a      1 0 001010     Solid, 1-frame (no anim.), tile 10
; 0x50      0 1 100000     Non-solid, 2-frame, tile 16
;------------------------------------------------------------------------------

; Player sprites
importbin gfx/c2b.bin 0 512 data.gfx_c2b

; Level tiles
importbin gfx/tilemap.bin 0 6272 data.gfx_tilemap

; Misc.
importbin gfx/font.bin 0 3072 data.gfx_font

