TILE_DIM          equ 16
TILES_X           equ 20
TILES_LASTX       equ 19
TILES_Y           equ 15
TILES_LASTY       equ 14

CHAR_OFFS         equ 32

PLYR_JP_DY        equ -9
PLYR_JP_DY_FP     equ -36
PLYR_DY_MAX       equ 5
PLYR_DY_MAX_FP    equ 20
FP_SHIFT          equ 2

PLYR_DY_ZERO      equ 0
PLYR_DY_NEG       equ 1
PLYR_DY_NEG_OFFS  equ 256
PLYR_DY_POS       equ 2
PLYR_DY_POS_OFFS  equ 384
PLYR_DY_POS_ROFFS equ 128

data.level        equ 0xa000
data.paletteA     equ 0xf000

;------------------------------------------------------------------------------
; Main program
;------------------------------------------------------------------------------
_start:        jmp main_init              ; DEBUG: skip the intro
main_intro:    sng 0xd2, 0x602a
               ldi r0, data.sfx_intro
               snp r0, 100 
               ldi r0, sub_drwintro       ; Display the intro screen
               call sub_fadein
               ldi r0, 90
               call sub_wait
               ldi r0, sub_drwintro
               call sub_fadeout

main_init:     bgc 0                      ; Dark background
               ldi r0, data.level0
               call sub_ldlvl             ; Decompress level into tilemap memory
               call sub_rndbg
               ldi ra, 260                ; Initial player position
               ldi rb, 192
              
main_fadein:   ldi r0, sub_drwmap
               call sub_fadein            ; Fade-in from black

main_move:     call sub_input             ; Handle input; maybe move L/R or jump
               call sub_mvplyr            ; Move U/D

main_draw:     cls                        ; Clear screen
               call sub_drwmap            ; Draw tiles
               call sub_drwplyr           ; Draw player sprite
               call sub_drwdbg            ; DEBUG: draw debug information

main_updcnt:   vblnk                      ; Wait for vertical blanking
               flip 0,0                   ; Reset sprite flipping
               ldm r0, data.v_anim_c      ; Increment animation counter
               addi r0, 1
               stm r0, data.v_anim_c
               ldi r0, 0                  ; Reset horizontal movement boolean
               stm r0, data.v_hmov
               jmp main_move

__spin:        vblnk
               jmp __spin

;------------------------------------------------------------------------------
; Lighten the palette gradually whilst displaying something
;------------------------------------------------------------------------------
sub_fadein:    mov rf, r0
               ldi r6, 7
.sub_fadeinA:  ldi r0, data.palette       ; First, copy the palette
               ldi r1, data.paletteA
               ldi r2, 0
.sub_fadeinB:  add r0, r2, r3
               ldm r4, r3
               mov r5, r4
               andi r5, 0xff00
               andi r4, 0x00ff
               add r1, r2, r3
               shr r4, r6                 ; Alter the color: gradually less
               or r5, r4
               stm r5, r3
               cmpi r2, 48
               jz .sub_fadeinC
               addi r2, 1
               jmp .sub_fadeinB
.sub_fadeinC:  pal data.paletteA          ; Load our modified palette
               call rf                    ; Display using provided subfunction
               ldi r0, 2                  ; Wait a couple frames to slow effect
               call sub_wait
               cmpi r6, 0
               jz .sub_fadeinZ
               subi r6, 1
               jmp .sub_fadeinA
.sub_fadeinZ:  pal data.palette           ; Reset palette to default
               ret

;------------------------------------------------------------------------------
; Darken the palette gradually whilst displaying something
;------------------------------------------------------------------------------
sub_fadeout:   mov rf, r0
               ldi r6, 0
.sub_fadeoutA: ldi r0, data.palette       ; First, copy the palette
               ldi r1, data.paletteA
               ldi r2, 0
.sub_fadeoutB: add r0, r2, r3
               ldm r4, r3
               mov r5, r4
               andi r5, 0xff00
               andi r4, 0x00ff
               add r1, r2, r3
               shr r4, r6                 ; Alter the color: gradually less
               or r5, r4
               stm r5, r3
               cmpi r2, 48
               jz .sub_fadeinC
               addi r2, 1
               jmp .sub_fadeinB
.sub_fadeoutC: pal data.paletteA          ; Load our modified palette
               call rf                    ; Display using provided subfunction
               ldi r0, 2                  ; Wait a couple frames to slow effect
               call sub_wait
               cmpi r6, 0
               jz .sub_fadeinZ
               addi r6, 1
               jmp .sub_fadeinA
.sub_fadeoutZ: pal data.palette           ; Reset palette to default
               ret

;------------------------------------------------------------------------------
; Draw the intro screen 
;------------------------------------------------------------------------------
sub_drwintro:  ldi r0, data.str_copy      ; Draw the copyright text
               ldi r1, 32
               ldi r2, 224
               call sub_drwstr
               ; Draw the game logo
               ret

;------------------------------------------------------------------------------
; Draw the tilemap -- iterate over map array
;------------------------------------------------------------------------------
sub_drwmap:    spr 0x1008                 ; Tile sprite size is 16x16
               flip 0,0                   ; Reset flip state
               ldi r1, TILES_LASTY
.sub_drwmapA:  ldi r0, TILES_LASTX
.sub_drwmapB:  call sub_drw_t
               subi r0, 1
               jnn .sub_drwmapB
               subi r1, 1
               jnn .sub_drwmapA
.sub_drwmapZ:  ret

;------------------------------------------------------------------------------
; Draw a tile -- parse metadata bits and display
;------------------------------------------------------------------------------
sub_drw_t:     mov r2, r1
               muli r2, TILES_X
               add r2, r0
               shl r2, 1
               addi r2, data.level
               ldm r3, r2
               mov r5, r3
               andi r5, 0x40
               shr r5, 6
               andi r3, 0x3f           ; tile_index = (tile & 0x3f) - 1
               cmpi r3, 0
               jz .sub_drw_tZ
               mov r4, r3
               mov r2, r0
               mov r3, r1
               muli r2, TILE_DIM
               muli r3, TILE_DIM
               subi r4, 1
               shl r4, 7
               addi r4, data.gfx_tilemap
               cmpi r5, 0
               jz .sub_drw_tA
               ldm r5, data.v_anim_c   ; animated tiles get 1 frame / 32 vblnk
               andi r5, 0x1f
               cmpi r5, 0x10
               jl .sub_drw_tA
               addi r4, 128
.sub_drw_tA:   drw r2, r3, r4
.sub_drw_tZ:   ret
;------------------------------------------------------------------------------
; Make the player jump -- account for continuous button press
;------------------------------------------------------------------------------
sub_jump:      ldm r0, data.v_jump
               cmpi r0, 1
               jz .sub_jump_Z
               cmpi rc, 0
               jnz .sub_jump_Z
               ldm r0, data.v_hitblk
.break:        cmpi r0, 1 
               jnz .sub_jump_Z
               ldi r0, 0
               stm r0, data.v_hitblk
               ldi r0, 1
               stm r0, data.v_jump
               ldi rc, PLYR_JP_DY_FP   ; PLYR_JP_DY << FP_SHIFT
               ldi r0, data.sfx_jump
               sng 0x00, 0x0300
               snp r0, 50 
.sub_jump_Z:   ret

;------------------------------------------------------------------------------
; Move player accounting for jumping, gravity, and collisions
;------------------------------------------------------------------------------
sub_mvplyr:    mov r0, ra                    ; Check block at (x, y+8+dy)
               mov r1, rb
               addi r1, 8
               mov r2, rc
               sar r2, FP_SHIFT
               add r1, r2
               call sub_getblk
               tsti r0, 0x80                 ; Go to SFX if hit
               jnz .sub_mvplyr0
               mov r0, ra                    ; Check block at (x+4, y+8+dy)
               addi r0, 4
               mov r1, rb
               addi r1, 8
               mov r2, rc
               sar r2, FP_SHIFT
               add r1, r2
               call sub_getblk
               tsti r0, 0x80                 ; No further checks if no hit
               jz .sub_mvplyr_a
.sub_mvplyr0:  cmpi rc, 0                    ; No sound if already grounded
               jz .sub_mvplyr_0
               sng 0x00, 0x4300              ; Play short white noise sample
               ldi r0, data.sfx_land
               snp r0, 50
               ldi rc, 0
.sub_mvplyr_0: ldi r0, 1                     ; Register hit variable
               stm r0, data.v_hitblk
               call sub_dy2blk               ; Move to block
               add rb, r0
               jmp .sub_mvplyr_Z
.sub_mvplyr_a: cmpi rc, PLYR_DY_MAX_FP       ; Increase dy if below maximum
               jge .sub_mvplyr_b
               addi rc, 3
.sub_mvplyr_b: mov r2, rc
               sar r2, FP_SHIFT
               add rb, r2                    ; Add dy to y
.sub_mvplyr_Z: ret 

;------------------------------------------------------------------------------
; Move player left accounting for collisions
;------------------------------------------------------------------------------
sub_mvleft:    mov r0, ra
               subi r0, 2
               mov r1, rb
               addi r1, 4
               call sub_getblk
               tsti r0, 0x80
               jz .sub_mvleftA
               call sub_dx2lblk
               add ra, r0
               jmp .sub_mvleft_Z
.sub_mvleftA:  subi ra, 2
               ldi r0, 1
               stm r0, data.v_lor
               stm r0, data.v_hmov
.sub_mvleft_Z: ret

;------------------------------------------------------------------------------
; Move player right accounting for collisions
;------------------------------------------------------------------------------
sub_mvright:   mov r0, ra
               addi r0, 10
               mov r1, rb
               addi r1, 4
               call sub_getblk
               tsti r0, 0x80
               jz .sub_mvright_A
               call sub_dx2rblk
               add ra, r0
               jmp .sub_mvright_Z
.sub_mvright_A: addi ra, 2
               ldi r0, 2
               stm r0, data.v_lor
               ldi r0, 1
               stm r0, data.v_hmov
.sub_mvright_Z: ret

;------------------------------------------------------------------------------
; Draw player accounting for direction, movement and animation counter
;------------------------------------------------------------------------------
sub_drwplyr:   spr 0x1008                    ; Player sprite size is 16x16
               flip 0,0                      ; Reset flip state
               mov r0, ra
               subi r0, 4
               mov r1, rb
               subi r1, 7
               ldi r2, data.gfx_c2b
               ldm r3, data.v_lor
               cmpi r3, 1                    ; If left-facing, flip horiz.
               jnz .sub_drwplyrA
               flip 1, 0
               jmp .sub_drwplyrB
.sub_drwplyrA: cmpi r3, 2                    ; If right-facing, reset flip
               jnz .sub_drwplyrB
               flip 0,0
.sub_drwplyrB: cmpi rc, 0                    ; If no y motion, running anim.
               jz .sub_drwplyrD              ; Else if non-zero y motion...
               addi r2, PLYR_DY_NEG_OFFS     ; ... Offset to jump sprite
               cmpi rc, 0
               jl .sub_drwplyrZ
               addi r2, PLYR_DY_POS_ROFFS    ; If dy>0, offset to fall sprite
               jmp .sub_drwplyrZ
.sub_drwplyrD: ldm r3, data.v_hmov           ; Cycle through running frames
               cmpi r3, 0                    ; using animation counter
               jz .sub_drwplyrZ
               ldm r3, data.v_anim_c         ; Each anim. frame lasts 8 vblnks
               andi r3, 0x8                  ; 8/60 = 0.133... so 7.5 Hz
               shl r3, 4
               add r2, r3
.sub_drwplyrZ: drw r0, r1, r2
               ret

;------------------------------------------------------------------------------
; Display debug info: player x, y. 
;------------------------------------------------------------------------------
sub_drwdbg:    mov r0, ra
               ldi r1, data.str_bcd3
               call sub_r2bcd3
               ldi r0, data.str_bcd3
               ldi r1, 0
               ldi r2, 0
               call sub_drwstr            ; Draw x value at (0,0)
               mov r0, rb
               ldi r1, data.str_bcd3
               call sub_r2bcd3
               ldi r0, data.str_bcd3
               ldi r1, 48
               ldi r2, 0
               call sub_drwstr            ; Draw y value at (48, 0)
               ret

;------------------------------------------------------------------------------
; Display a string, accounting for newlines too. 
;------------------------------------------------------------------------------
sub_drwstr:    spr 0x0804                 ; Font sprite size is 8x8
               flip 0,0                   ; Reset flip state
               ldm r3, r0
               andi r3, 0xff
               cmpi r3, 0
               jz .sub_drwstrZ
               cmpi r1, 320
               jl .sub_drwstrA
               ldi r1, 0
               addi r2, 12
.sub_drwstrA:  subi r3, CHAR_OFFS
               muli r3, 32
               addi r3, data.gfx_font
               drw r1, r2, r3
               addi r0, 1
               addi r1, 8
               jmp sub_drwstr
.sub_drwstrZ:  ret

;------------------------------------------------------------------------------
; Return remaining pixels to next 8-aligned y-coordinate
;------------------------------------------------------------------------------
sub_dy2blk:    mov r1, rb
               addi r1, 7 
               shr r1, 3
               shl r1, 3
               sub r1, rb, r0
.sub_dy2blk_Z: ret

;------------------------------------------------------------------------------
; Return remaining pixels to previous 8-aligned x-coordinate
;------------------------------------------------------------------------------
sub_dx2lblk:   mov r1, ra
               addi r1, 7
               shr r1, 3
               shl r1, 3
               sub r1, ra, r0
               ret

;------------------------------------------------------------------------------
; Return remaining pixels to next 8-aligned x-coordinate
;------------------------------------------------------------------------------
sub_dx2rblk:   mov r1, ra
               addi r1, 3
               shr r1, 3
               shl r1, 3
               sub r1, ra, r0
               ret

;------------------------------------------------------------------------------
; Return contents of block in level map
;------------------------------------------------------------------------------
sub_getblk:    shr r0, 4
               shr r1, 4
               muli r1, TILES_X
               add r1, r0
               shl r1, 1
               addi r1, data.level
               ldm r0, r1
               andi r0, 0xff
               ret

;------------------------------------------------------------------------------
; Load requested level into memory. Decode using a simple RLE scheme.
;
; Data layout (example): 10 00 00 03 ff 0d
; Meaning: 
; - Section is 0x0010 (16) bytes long.
; - Repeat byte '0x00' 3 times. Repeat byte '0xff' 13 times.
;------------------------------------------------------------------------------
sub_ldlvl:     ;ret                       ; DEBUG: Return before decompressing
               ldi r5, data.level         ; Destination pointer initial value
               ldm r1, r0                 ; Load tiles' RLE section size
               ldi r2, 0                  ; Section input byte counter
.sub_ldlvlA:   cmp r2, r1                 ; If we read all section bytes, end
               jz .sub_ldlvlC
               addi r2, 2                 ; Increment input byte counter
               mov r3, r2
               add r3, r0                 ; Current offset into section
               ldm r3, r3                 ; Read value (lo) and reps (hi)
               mov r4, r3
               andi r3, 0xff              ; Byte value to repeat
               shr r4, 8                  ; Number of repetitions (max. 255)
.sub_ldlvlB:   stm r3, r5                 ; Write repeated byte
               addi r5, 2                 ; Increment destination pointer
               subi r4, 1                 ; Decrement counter
               jz .sub_ldlvlA
               jmp .sub_ldlvlB
.sub_ldlvlC:   ret 
;------------------------------------------------------------------------------
; Add some random background tiles to level map
;------------------------------------------------------------------------------
sub_rndbg:     ldi r0, data.level
               ldi r1, data.level
               addi r1, 600               ; 15 x 20 x 2 bytes
.sub_rndbgA:   cmp r0, r1
               jz .sub_rndbgZ
               ldm r2, r0
               cmpi r2, 0                 ; Only look at empty tiles
               jnz .sub_rndbgC
               rnd r3, 5
               cmpi r3, 0                 ; Maybe overwrite this existing tile
               jnz .sub_rndbgC
.sub_rndbgB:   rnd r3, 4                  ; Choose random tile from bgtiles
               shl r3, 1
               addi r3, data.bgtiles
               ldm r3, r3                 ; Look up that tile
               addi r3, 1
               stm r3, r0                 ; And store it at the empty tile loc.
.sub_rndbgC:   addi r0, 2
               jmp .sub_rndbgA
.sub_rndbgZ:   ret
;------------------------------------------------------------------------------
; Manage controller input and resulting actions
;------------------------------------------------------------------------------
sub_input:     call sub_btn_a
               cmpi r0, 1
               jnz .sub_input_A
               call sub_jump
               jmp .sub_input_B
.sub_input_A:  ldi r0, 0
               stm r0, data.v_jump
.sub_input_B:  call sub_btn_left
               cmpi r0, 1
               jnz .sub_input_C
               call sub_mvleft
               jmp .sub_input_Z
.sub_input_C:  call sub_btn_right
               cmpi r0, 1
               jnz .sub_input_Z
               call sub_mvright
.sub_input_Z:  call sub_btn_start         ; DEBUG: Start button resets the game
               cmpi r0, 1
               jz reset
               ret

;------------------------------------------------------------------------------
; Return whether button A is pressed
;------------------------------------------------------------------------------
sub_btn_a:     ldm r0, 0xfff0
               andi r0, 0x40
               shr r0, 6
               ret

;------------------------------------------------------------------------------
; Return whether button Left is pressed
;------------------------------------------------------------------------------
sub_btn_left:  ldm r0, 0xfff0
               andi r0, 0x04
               shr r0, 2
               ret

;------------------------------------------------------------------------------
; Return whether button Right is pressed
;------------------------------------------------------------------------------
sub_btn_right: ldm r0, 0xfff0
               andi r0, 0x08
               shr r0, 3
               ret

;------------------------------------------------------------------------------
; Return whether button Start is pressed
;------------------------------------------------------------------------------
sub_btn_start: ldm r0, 0xfff0
               andi r0, 0x20
               shr r0, 5
               ret

;------------------------------------------------------------------------------
; Output the contents of r0 to given BCD string - up to 999 supported
;------------------------------------------------------------------------------
sub_r2bcd3:    mov r2, r0
               divi r2, 100
               muli r2, 100               ; r2 contains the 100's digit, x100
               mov r3, r0
               sub r3, r2
               divi r3, 10
               muli r3, 10                ; r3 contains the 10's digit, x10
               mov r4, r3
               divi r4, 10
               addi r4, 0x10
               addi r4, CHAR_OFFS
               shl r4, 8
               mov r5, r2
               divi r5, 100
               addi r5, 0x10
               add r4, r5
               addi r4, CHAR_OFFS         ; Shift and combine 100's & 10's
               stm r4, r1                 ; Store to string's first 2 bytes
               addi r1, 2
               sub r0, r2                 ; Subtract 100's from original
               sub r0, r3                 ; Then subtract 10's
               addi r0, 0x10
               addi r0, CHAR_OFFS
               stm r0, r1                 ; Store to string's last 2 bytes
               ret

;------------------------------------------------------------------------------
; Wait given number of frames
;------------------------------------------------------------------------------
sub_wait:      vblnk
               cmpi r0, 0
               jz .sub_waitZ
               subi r0, 1
               jmp sub_wait
.sub_waitZ:    ret

;------------------------------------------------------------------------------
; Reset the program
;------------------------------------------------------------------------------
reset:         pop r0                     ; The jmp here was from a call
               cls
               jmp _start

;------------------------------------------------------------------------------
; DATA 
;------------------------------------------------------------------------------
data.str_copy: db "Copyright (C) T. Kelsall, 2018."
               db 0
data.str_bcd3: db 0,0,0,0
data.palette:  db 0x00,0x00,0x00
               db 0x00,0x00,0x00
               db 0x88,0x88,0x88
               db 0xbf,0x39,0x32
               db 0xde,0x7a,0xae
               db 0x4c,0x3d,0x21
               db 0x90,0x5f,0x25
               db 0xe4,0x94,0x52
               db 0xea,0xd9,0x79
               db 0x53,0x7a,0x3b
               db 0xab,0xd5,0x4a
               db 0x25,0x2e,0x38
               db 0x00,0x46,0x7f
               db 0x68,0xab,0xcc
               db 0xbc,0xde,0xe4
               db 0xff,0xff,0xff
data.bgtiles:  dw 5, 6, 28, 29, 30
data.v_jump:   dw 0
data.v_lor:    dw 0
data.v_hmov:   dw 0
data.v_anim_c: dw 0
data.v_hitblk: dw 0
data.sfx_jump: dw 700
data.sfx_land: dw 1000
data.sfx_intro: dw 500
