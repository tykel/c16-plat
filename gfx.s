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
importbin gfx/c2b.bin 0 256 data.gfx_c2b

; Level tiles
importbin gfx/lvl_bg0.bin 0 128 data.gfx_lvl_bg0
importbin gfx/lvl_bg1.bin 0 128 data.gfx_lvl_bg1
importbin gfx/lvl_bg2.bin 0 128 data.gfx_lvl_bg2
importbin gfx/lvl_bg3.bin 0 128 data.gfx_lvl_bg3
importbin gfx/lvl_bg4.bin 0 128 data.gfx_lvl_bg4
importbin gfx/lvl_bg5.bin 0 128 data.gfx_lvl_bg5
importbin gfx/lvl_bg6.bin 0 128 data.gfx_lvl_bg6
importbin gfx/lvl_bg7.bin 0 128 data.gfx_lvl_bg7
importbin gfx/lvl_candle0.bin 0 128 data.gfx_lvl_candle0
importbin gfx/lvl_candle1_0.bin 0 128 data.gfx_lvl_candle1_0
importbin gfx/lvl_candle1_1.bin 0 128 data.gfx_lvl_candle1_1
importbin gfx/lvl_Eo0.bin 0 128 data.gfx_lvl_Eo0
importbin gfx/lvl_Eo1.bin 0 128 data.gfx_lvl_Eo1
importbin gfx/lvl_Eo2.bin 0 128 data.gfx_lvl_Eo2
importbin gfx/lvl_NEio.bin 0 128 data.gfx_lvl_NEio
importbin gfx/lvl_NEo.bin 0 128 data.gfx_lvl_NEo
importbin gfx/lvl_No0.bin 0 128 data.gfx_lvl_No0
importbin gfx/lvl_No1.bin 0 128 data.gfx_lvl_No1
importbin gfx/lvl_No2.bin 0 128 data.gfx_lvl_No2
importbin gfx/lvl_No4.bin 0 128 data.gfx_lvl_No4
importbin gfx/lvl_NWio.bin 0 128 data.gfx_lvl_NWio
importbin gfx/lvl_NWo.bin 0 128 data.gfx_lvl_NWo
importbin gfx/lvl_SEo.bin 0 128 data.gfx_lvl_SEo
importbin gfx/lvl_So0.bin 0 128 data.gfx_lvl_So0
importbin gfx/lvl_So1.bin 0 128 data.gfx_lvl_So1
importbin gfx/lvl_So2.bin 0 128 data.gfx_lvl_So2
importbin gfx/lvl_So3.bin 0 128 data.gfx_lvl_So3
importbin gfx/lvl_SWo.bin 0 128 data.gfx_lvl_SWo
importbin gfx/lvl_Wo0.bin 0 128 data.gfx_lvl_Wo0
importbin gfx/lvl_Wo1.bin 0 128 data.gfx_lvl_Wo1
importbin gfx/lvl_Ni0.bin 0 128 data.gfx_lvl_Ni0
importbin gfx/lvl_SEi.bin 0 128 data.gfx_lvl_SEi
importbin gfx/lvl_Ni1.bin 0 128 data.gfx_lvl_Ni1
importbin gfx/lvl_Si1.bin 0 128 data.gfx_lvl_Si1
importbin gfx/lvl_Ei0.bin 0 128 data.gfx_lvl_Ei0
importbin gfx/lvl_Wi1.bin 0 128 data.gfx_lvl_Wi1
importbin gfx/lvl_NEi.bin 0 128 data.gfx_lvl_NEi
importbin gfx/lvl_Wi0.bin 0 128 data.gfx_lvl_Wi0
importbin gfx/lvl_Ei1.bin 0 128 data.gfx_lvl_Ei1
importbin gfx/lvl_Si0.bin 0 128 data.gfx_lvl_Si0
importbin gfx/lvl_SWi.bin 0 128 data.gfx_lvl_SWi

; Misc.
importbin gfx/font.bin 0 3072 data.gfx_font

