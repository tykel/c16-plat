;------------------------------------------------------------------------------
; plat.s -- Platform game engine
;
; Function call convention:
;  Caller saves any of [r0..r9] they wish to retain
;  Arguments passed in [r0..r9]
;
; Persistent registers:
;  ra: Player X               rd: Scroll X
;  rb: Player Y               re: Scroll Y
;  rc: Player dY (v-speed)    rf: <>
;------------------------------------------------------------------------------

TILE_DIM          equ 16
TILES_X           equ 40
TILES_LASTX       equ 39
TILES_Y           equ 30
TILES_LASTY       equ 29

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
               ldi r0, 60
               call sub_wait
               ldi r0, sub_drwintro
               call sub_fadeout

main_init:     bgc 0                      ; Dark background
               call sub_initregs          ; Initialize persistent regs
               call sub_initdata          ; Initialize memory-resident vars
               ldi r0, data.level0
               call sub_ldlvl             ; Decompress level into tilemap memory
               call sub_rndbg
               call sub_scroll            ; Do initial scrolling adjustment
              
main_fadein:   ldi r0, sub_drwmap
               call sub_fadein            ; Fade-in from black

main_move:     call sub_input             ; Handle input; maybe move L/R or jump
               call sub_mvplyr            ; Move U/D
               call sub_objcol            ; Handle an object beneath player
               call sub_objref            ; Handle timer-bound objects
               call sub_scroll            ; Adjust scrolling

main_draw:     cls                        ; Clear screen
               call sub_drwmap            ; Draw tiles
               call sub_drwplyr           ; Draw player sprite
               call sub_drwdbg            ; DEBUG: draw debug information
               call sub_drwhud            ; Draw interface elements

main_audio:    call sub_sndstep           ; Process one frame of audio

main_updcnt:   vblnk                      ; Wait for vertical blanking
               flip 0,0                   ; Reset sprite flipping
               ldm r0, data.v_anim_c      ; Increment animation counter
               addi r0, 1
               stm r0, data.v_anim_c
               ldi r0, 0                  ; Reset horizontal movement boolean
               stm r0, data.v_hmov
               ldm r0, data.v_vblanks     ; Check if 60 vblank ticks elapsed
               subi r0, 1
               stm r0, data.v_vblanks
               cmpi r0, 0
               jg main_loop
               ldm r0, data.v_time        ; In which case a second has passed
               subi r0, 1                 ; So decrement timer
               stm r0, data.v_time
               ldi r0, 60
               stm r0, data.v_vblanks     ; And reset vblank ticks
main_loop:     jmp main_move

__spin:        vblnk
               jmp __spin

;------------------------------------------------------------------------------
; Initialize the persistent registers to sane values
;------------------------------------------------------------------------------
sub_initregs:  ldi ra, 36                 ; Initial player position
               ldi rb, 40
               ldi rc, 0                  ; No vertical motion initially
               ldi rd, 0                  ; Begin non-scrolled (far left of map)
               ldi re, 0                  ; Begin non-scrolled (top of map)
               ret

;------------------------------------------------------------------------------
; Initialize the variables which do not reside in registers 
;------------------------------------------------------------------------------
sub_initdata:  ldi r0, 200                ; Start with 200 second countdown
               stm r0, data.v_time
               ldi r0, 3                  ; 3 lives seems reasonable
               stm r0, data.v_lives
               ldi r0, 25                 ; 25 coins per level also seems ok
               stm r0, data.v_coins
               ret

;------------------------------------------------------------------------------
; Lighten the palette gradually whilst displaying something
;------------------------------------------------------------------------------
sub_fadein:    cls
               mov rf, r0
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
               pushall
               call rf                    ; Display using provided subfunction
               popall
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
               jz .sub_fadeoutC
               addi r2, 1
               jmp .sub_fadeoutB
.sub_fadeoutC: pal data.paletteA          ; Load our modified palette
               pushall
               call rf                    ; Display using provided subfunction
               popall
               ldi r0, 2                  ; Wait a couple frames to slow effect
               call sub_wait
               cmpi r6, 7
               jz .sub_fadeoutZ
               addi r6, 1
               jmp .sub_fadeoutA
.sub_fadeoutZ: pal data.palette           ; Reset palette to default
               cls
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
; Draw the interface -- coins, time, lives, etc.
;------------------------------------------------------------------------------
sub_drwhud:    
               ldi r0, data.str_lives     ; Draw "Lives: "
               ldi r1, 4
               ldi r2, 2
               call sub_drwstr
               ldm r0, data.v_lives
               ldi r1, data.str_bcd3
               call sub_r2bcd3
               ldi r0, data.str_bcd3
               ldi r1, 52
               ldi r2, 2
               call sub_drwstr
               ldi r0, data.str_coins     ; Draw "Coins Left: "
               ldi r1, 96
               ldi r2, 2
               call sub_drwstr
               ldm r0, data.v_coins
               ldi r1, data.str_bcd3
               call sub_r2bcd3
               ldi r0, data.str_bcd3
               ldi r1, 184
               ldi r2, 2
               call sub_drwstr
               ldi r0, data.str_time      ; Draw "Time: "
               ldi r1, 240
               ldi r2, 2
               call sub_drwstr
               ldm r0, data.v_time
               ldi r1, data.str_bcd3
               call sub_r2bcd3
               ldi r0, data.str_bcd3
               ldi r1, 280
               ldi r2, 2
               call sub_drwstr
.sub_drwhudZ:  ret

;------------------------------------------------------------------------------
; Draw the tilemap -- iterate over map array
;------------------------------------------------------------------------------
sub_drwmap:    spr 0x1008                 ; Tile sprite size is 16x16
               flip 0,0                   ; Reset flip state
               ldi r9, 15
               mov r1, re
               addi r1, 240
               shr r1, 4
.sub_drwmapA:  ldi r8, 20
               mov r0, rd
               addi r0, 320
               shr r0, 4
.sub_drwmapB:  call sub_drw_t
               subi r0, 1
               subi r8, 1
               jnn .sub_drwmapB
               subi r1, 1
               subi r9, 1
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
               mov r6, r3
               shr r6, 15                 ; is-object? bit
               mov r5, r3
               andi r5, 0x40
               shr r5, 6
               andi r3, 0x3f              ; tile_index = (tile & 0x3f) - 1
               cmpi r3, 0
               jz .sub_drw_tZ
               mov r4, r3
               mov r2, r0
               mov r3, r1
               muli r2, TILE_DIM
               muli r3, TILE_DIM
               subi r4, 1
               shl r4, 7
               cmpi r6, 0                 ; use either object/tiles gfx offset
               jz .sub_drw_t0
               addi r4, data.gfx_objects
               jmp .sub_drw_t1
.sub_drw_t0:   addi r4, data.gfx_tilemap
.sub_drw_t1:   cmpi r5, 0
               jz .sub_drw_tA
               ldm r5, data.v_anim_c      ; anim'd tiles get 1 frame / 32 vblnk
               andi r5, 0x1f
               cmpi r5, 0x10
               jl .sub_drw_tA
               addi r4, 128
.sub_drw_tA:   sub r2, rd, r6
               sub r3, re, r7
               drw r6, r7, r4
.sub_drw_tZ:   ret

;------------------------------------------------------------------------------
; Adjust the scrolling register based on player position
;------------------------------------------------------------------------------
sub_scroll:    ldm r0, data.v_level_w
               shl r0, 4                  ; Tile to pixel coordinates
               subi r0, 176               ; (320/2)-16
               ldm r1, data.v_level_h
               shl r1, 4
               subi r1, 104               ; (240/2)-16
               cmpi ra, 160
               jl .sub_scrollA
               cmp ra, r0
               jge .sub_scrollA
               mov rd, ra
               subi rd, 160
.sub_scrollA:  cmpi rb, 120
               jl .sub_scrollZ
               cmp rb, r1
               jge .sub_scrollZ
.sub_scrollC:  mov re, rb
               subi re, 120
.sub_scrollZ:  ret

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
.sub_drwplyrZ: sub r0, rd
               sub r1, re
               drw r0, r1, r2
               ret

;------------------------------------------------------------------------------
; Display debug info: player x, y. 
;------------------------------------------------------------------------------
sub_drwdbg:    mov r0, ra
               ldi r1, data.str_bcd3
               call sub_r2bcd3
               ldi r0, data.str_bcd3
               ldi r1, 0
               ldi r2, 228
               call sub_drwstr            ; Draw x value at (0,0)
               mov r0, rb
               ldi r1, data.str_bcd3
               call sub_r2bcd3
               ldi r0, data.str_bcd3
               ldi r1, 48
               ldi r2, 228
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
               ret

;------------------------------------------------------------------------------
; Set contents of block in level map
;------------------------------------------------------------------------------
sub_setblk:    shr r0, 4
               shr r1, 4
               muli r1, TILES_X
               add r1, r0
               shl r1, 1
               addi r1, data.level
               stm r2, r1
               ret

;------------------------------------------------------------------------------
; Load requested level into memory. Decode using a simple RLE scheme.
; Zero runs are encoded as '0x00' + run length byte.
; Non-zero values are encoded literally.
;
; This custom encoding scheme exploits the long zero runs that result from
; randomly-generated backgrounds.
;
; Data layout (example): 10 00 00 03 ff 0d
; Meaning: 
; - Section is 0x0010 (16) bytes long.
; - Repeat byte '0x00' 3 times.
; - Repeat byte '0xff' once.
; - Repeat byte '0x0d' once.
;------------------------------------------------------------------------------
sub_ldlvl:     ldm r1, r0                 ; Read level width (in tiles)
               stm r1, data.v_level_w
               addi r0, 2
               ldm r1, r0                 ; Read level height (in tiles)
               stm r1, data.v_level_h
               addi r0, 2
               call sub_t_derle           ; Decompress the tile data
               call sub_o_parse           ; Read in the level object data
.sub_ldlvlZ:   ret

;------------------------------------------------------------------------------
; Decompress the RLE level tiles
;------------------------------------------------------------------------------
sub_t_derle:   ldi r5, data.level         ; Destination pointer initial value
               ldm r1, r0                 ; Load tiles' RLE section size
               ldi r2, 0                  ; Section input byte counter
               ldi r6, 2                  ; Last input size
.sub_t_derleA: cmp r2, r1                 ; If we read all section bytes, end
               jge .sub_t_derleZ
               add r2, r6                 ; Increment input byte counter
               ldi r6, 2
               mov r3, r2
               add r3, r0                 ; Current offset into section
               ldm r3, r3                 ; Read value (lo) and reps (hi)
               mov r4, r3
               andi r3, 0xff              ; Byte value to repeat
               shr r4, 8                  ; Number of repetitions (max. 255)
               cmpi r3, 0
               jz .sub_t_derleB
               ldi r4, 1
               ldi r6, 1
.sub_t_derleB: stm r3, r5                 ; Write repeated byte
               addi r5, 2                 ; Increment destination pointer
               subi r4, 1                 ; Decrement counter
               jz .sub_t_derleA
               jmp .sub_t_derleB
.sub_t_derleZ: add r0, r1
               addi r0, 2
               ret 

;------------------------------------------------------------------------------
; Read in level objects and position them in tilemap
;------------------------------------------------------------------------------
sub_o_parse:   ldm r1, r0                 ; Number of objects
.sub_o_parseA: cmpi r1, 0
               jz .sub_o_parseZ
               addi r0, 2
               ldm r2, r0                 ; Object index (+1)
               addi r0, 2
               ldm r3, r0                 ; Object x
               addi r0, 2
               ldm r4, r0                 ; Object y
               pushall
               mov r0, r3
               shl r0, 4                  ; Object X in pixel-coords
               mov r1, r4
               shl r1, 4                  ; Object Y in pixel-coords
               ldi r3, data.obj_data
               add r3, r2
               subi r3, 1
               ldm r3, r3
               or r2, r3                  ; Add in object data (solid, anim)
               ori r2, 0x8000             ; Set highest bit to signify object
               call sub_setblk
               popall
               subi r1, 1
               jmp .sub_o_parseA
.sub_o_parseZ: ret
;------------------------------------------------------------------------------
; Add some random background tiles to level map
;------------------------------------------------------------------------------
sub_rndbg:     ldi r0, data.level
               ldm r1, data.v_level_h
               ldm r2, data.v_level_w
               mul r1, r2
               shl r1, 1
               addi r1, data.level
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
               cmpi r3, 0
               jnz .sub_r2bcd3A
               cmpi r2, 0
               jz .sub_r2bcd3B
.sub_r2bcd3A:  addi r4, 0x10
.sub_r2bcd3B:  addi r4, CHAR_OFFS
               shl r4, 8
               mov r5, r2
               divi r5, 100
               cmpi r2, 0
               jz .sub_r2bcd3C
               addi r5, 0x10
.sub_r2bcd3C:  add r4, r5
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
; Check for player-object collision, and call handler if necessary 
;------------------------------------------------------------------------------
sub_objcol:    mov r0, ra
               mov r1, rb
               call sub_getblk
               tsti r0, 0x8000
               jz .sub_objcolZ
               andi r0, 0x3f
               subi r0, 1
               shl r0, 1
               addi r0, data.obj_handlers
               ldm r2, r0
               mov r0, ra
               mov r1, rb
               call r2
.sub_objcolZ:  ret

;------------------------------------------------------------------------------
; Refresh the objects bound to the object timer
;------------------------------------------------------------------------------
sub_objref:    ldm r0, data.v_obj_timer
               cmpi r0, -1
               jz .sub_objrefZ
               subi r0, 1
               stm r0, data.v_obj_timer
               cmpi r0, -1
               jz .sub_objrefA
               jmp .sub_objrefZ
.sub_objrefA:  ldi r3, data.v_obj_cb_args
               ldm r0, r3
               addi r3, 2
               ldm r1, r3
               addi r3, 2
               ldm r2, r3
               ldm r3, data.v_obj_cb
               call r3
.sub_objrefZ:  ret

;------------------------------------------------------------------------------
; Coin object handler
;------------------------------------------------------------------------------
sub_obj0:      pushall
               ldi r2, 0x8043             ; Coin consumed, replace with sparkle
               call sub_setblk
               popall
               ldi r2, data.v_obj_cb_args
               stm r0, r2                 ; Store object x
               addi r2, 2
               stm r1, r2                 ; Store object y
               ldi r0, sub_obj2
               stm r0, data.v_obj_cb      ; Store object's callback (sparkle)
               ldi r0, 10
               stm r0, data.v_obj_timer   ; Set a one second timer
               
               ;sng 0x00, 0x8284           ; Short high-pitched beep
               ;ldi r0, data.sfx_land
               ;snp r0, 50
               
               ldi r0, data.snd_track
               ldi r1, 0                  ; 0 delay
               stm r1, r0
               addi r0, 2
               ldm r1, data.sfx_land      ; 1000 Hz note
               stm r1, r0
               addi r0, 2
               ldi r1, 3                  ; 3 Vblnks = 48 ms duration
               stm r1, r0
               addi r0, 2
               ldi r1, 0x0402             ; Medium release, no attack, square
               stm r1, r0
               ldi r1, 1
               stm r1, data.snd_remaining ; 1 note to play
               
               ldm r0, data.v_coins       ; Decrements "coins remaining"
               subi r0, 1
               stm r0, data.v_coins
               ret

;------------------------------------------------------------------------------
; Coin sparkle object handler
;------------------------------------------------------------------------------
sub_obj2:      ldi r2, 0                  ; Clear from tilemap
               call sub_setblk
.sub_obj2Z:    ret


;------------------------------------------------------------------------------
; Default (no-op) handler
;------------------------------------------------------------------------------
sub_nop:       ret

;------------------------------------------------------------------------------
; Audio driver
;
; Notes are stored in the following format in the track:
; - word 0: delay (in Vblnks) since previous note
; - word 1: note, in Hz
; - word 2: duration, in ms
; - word 3: flags:
;
; | 15..12 | 11..8   | 7..4   | 3..2   | 1..0  |
; +--------+---------+--------+--------+-------+
; | Unused | Release | Attack | Unused | Type  |
;
;------------------------------------------------------------------------------
sub_sndstep:   ldm r0, data.snd_remaining ; Continue only if notes remain
               cmpi r0, 0
               jz .sub_sndstepZ
               ldm r1, data.snd_pos
               mov r2, r1
               shl r2, 3
               addi r2, data.snd_track
               ldm r3, r2                 ; Delay
               addi r2, 2
               mov r4, r2                 ; Note
               addi r2, 2
               ldm r5, r2                 ; Duration
               shl r5, 4
               stm r5, .sub_sndstepP
               addi r2, 2
               ldm r6, r2                 ; Flags
               ldi r7, 0x000e             ; First instruction word
               mov r8, r6
               shr r8, 4
               andi r8, 0xf
               shl r8, 8
               or r7, r8
               stm r7, .sub_sndstepX
               ldi r7, 0x8080
               mov r8, r6
               shr r8, 8
               or r7, r8
               mov r8, r6
               andi r8, 3
               shl r8, 8
               or r7, r8
               stm r7, .sub_sndstepY 
.sub_sndstepX: db 0x0e, 0x00              ; SNG instr. to rewrite
.sub_sndstepY: db 0x00, 0x00
               db 0x0d, 0x04              ; SNP instr. to rewrite
.sub_sndstepP: db 0x00, 0x00
               subi r0, 1
               stm r0, data.snd_remaining
               mov r0, r1
               addi r0, 1
.sub_sndstepZ: stm r0, data.snd_pos       ; Reset audio position to 0
               ret

;------------------------------------------------------------------------------
; DATA 
;------------------------------------------------------------------------------
data.str_copy:       db "Copyright (C) T. Kelsall, 2018."
                     db 0
data.str_lives:      db "Lives: "
                     db 0
data.str_coins:      db "Coins Left: "
                     db 0
data.str_time:       db "Time: "
                     db 0
data.str_bcd3:       db 0,0,0,0
data.palette:        db 0x00,0x00,0x00
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
data.bgtiles:        dw 5, 6, 28, 29, 30

data.snd_remaining:  dw 0
data.snd_cb:         dw 0
data.snd_pos:        dw 0
data.snd_track:      dw 0,0,0,0
                     dw 0,0,0,0
                     dw 0,0,0,0
                     dw 0,0,0,0
                     dw 0,0,0,0
                     dw 0,0,0,0
                     dw 0,0,0,0
                     dw 0,0,0,0
                     dw 0,0,0,0
                     dw 0,0,0,0
                     dw 0,0,0,0
                     dw 0,0,0,0
                     dw 0,0,0,0
                     dw 0,0,0,0
                     dw 0,0,0,0
                     dw 0,0,0,0

data.obj_data:       dw 0x0040
                     dw 0x0040
data.obj_handlers:   dw sub_obj0          ; Coin
                     dw sub_nop           ; Coin +1
                     dw sub_nop           ; Coin sparkle
                     dw sub_nop           ; Coin sparkle +1
data.v_obj_timer:    dw -1
data.v_obj_cb:       dw 0
data.v_obj_cb_args:  dw 0, 0, 0

data.v_lives:        dw 0
data.v_vblanks:      dw 0
data.v_time:         dw 0
data.v_coins:        dw 0

data.v_level_w:      dw 0
data.v_level_h:      dw 0
data.v_jump:         dw 0
data.v_lor:          dw 0
data.v_hmov:         dw 0
data.v_anim_c:       dw 0
data.v_hitblk:       dw 0
data.sfx_jump:       dw 700
data.sfx_land:       dw 1000
data.sfx_intro:      dw 500
