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

CHAR_OFFS         equ 32

PLYR_JP_DY        equ -9
PLYR_JP_DY_FP     equ -36
PLYR_DY_MAX       equ 5
PLYR_DY_MAX_FP    equ 20
FP_SHIFT          equ 2

LVL_INTRO         equ 0
LVL_MENU          equ 1
LVL_LEVEL0        equ 2

PLYR_DY_ZERO      equ 0
PLYR_DY_NEG       equ 1
PLYR_DY_NEG_OFFS  equ 256
PLYR_DY_POS       equ 2
PLYR_DY_POS_OFFS  equ 384
PLYR_DY_POS_ROFFS equ 128

MUSNOTE_C1        equ 32
MUSNOTE_C3        equ 131
MUSNOTE_D3        equ 146
MUSNOTE_E3        equ 164
MUSNOTE_F3        equ 174
MUSNOTE_G3        equ 195
MUSNOTE_A4        equ 220
MUSNOTE_B4        equ 247
MUSNOTE_C4        equ 261
MUSNOTE_D4        equ 293
MUSNOTE_E4        equ 329
MUSNOTE_F4        equ 349
MUSNOTE_G4        equ 391
MUSNOTE_A5        equ 440
MUSNOTE_B5        equ 493
MUSNOTE_C5        equ 523
MUSNOTE_D5        equ 587
MUSNOTE_E5        equ 659
MUSNOTE_F5        equ 698
MUSNOTE_G5        equ 783
MUSNOTE_D6        equ 1174
MUSNOTE_E6        equ 1318

;------------------------------------------------------------------------------
; Current memory map:
;
;  0000 ... 7fff : Game code, variables, gfx data, sfx data, level data
;  c000 ... cfff : Decompressed level data
;  d000 ... efff : Decompression buffer
;------------------------------------------------------------------------------
data.level        equ 0xc000
data.rlebuf       equ 0xd000
data.paletteA     equ 0xf000

;------------------------------------------------------------------------------
; Main program
;------------------------------------------------------------------------------
_start:        ;jmp menu_init              ; DEBUG: skip the intro
;--------------------
; Intro screen logic
;--------------------
intro:         ldi r0, 0
               ldm r1, data.sfx_intro
               ldi r2, 6 
               ldi r3, 0x0af2
               call sub_sndq
               call sub_sts_init
               ldi r0, sub_drwintro       ; Display the intro screen
               call sub_fadein
               ldi r0, 60
               ldi r1, sub_drwintro
               call sub_wait_draw
               ldi r0, sub_drwintro
               call sub_fadeout

;--------------------
; Menu logic
;--------------------
menu_init:     bgc 0
               ldi r0, data.sfx_mus_menu  ; Decompress music into RLE buffer
               ldi r1, data.rlebuf
               ldi r2, 1                  ; Music to be dec'd to indiv. bytes
               call sub_deswe
               ldi r0, data.rlebuf
               ldi r1, 1
               ldi r2, sub_cb_music
               call sub_sndstrm
               ldi r0, LVL_MENU
               stm r0, data.v_level
               call sub_ldlvl             ; Decompress level into tilemap memory
               ldi r0, sub_drwmenu
               call sub_fadein
menu_loop:     cls
               call sub_menuinp
               call sub_drwmenu
               call sub_drwdbg
               call sub_sndstep
               vblnk
               ldm r0, data.v_menu_vblnk
               addi r0, 1
               stm r0, data.v_menu_vblnk
               ldm r0, data.v_menu_start
               cmpi r0, 1
               jnz menu_loop
               ldm r0, data.v_menu_sel
               cmpi r0, 1
               jz .menu_initZ
               call sub_sndreset
               ldi r0, sub_drwmenu
               call sub_fadeout
               jmp star_mode
.menu_initZ:   call sub_sndreset          ; Reset audio driver state
               ldi r0, sub_drwmenu        ; Fade-out to next screen
               call sub_fadeout
               ldi r0, LVL_LEVEL0         ; Set level counter here, as we go to
               stm r0, data.v_level       ; lvlst_init for each level
               ldi r0, 3                  ; Set lives counter here, as we got to
               stm r0, data.v_lives       ; main_init for each level

;--------------------
; Level start screen
;--------------------
lvlst_init:    snd0
               bgc 0
               ldi r0, 40
               stm r0, data.v_lvlst_vblnk
               ldi r0, sub_drwlvlst
               call sub_fadein
               call sub_lvlstmus
lvlst_loop:    cls
               call sub_drwlvlst
               call sub_sndstep
               vblnk
               ldm r0, data.v_lvlst_vblnk
               subi r0, 1
               stm r0, data.v_lvlst_vblnk
               cmpi r0, 0
               jnz lvlst_loop
               ldi r0, sub_drwlvlst
               call sub_fadeout

;--------------------
;--------------------
; In-level game logic
;--------------------
main_init:     bgc 0                      ; Dark background
               call sub_initregs          ; Initialize persistent regs
               call sub_initdata          ; Initialize memory-resident vars
               call sub_sndreset          ; Reset audio driver state
               call sub_ldlvl             ; Decompress level into tilemap memory
               call sub_ldgfx             ; Decompress graphics
               call sub_rndbg             ; Sprinkle some background tiles
               call sub_scroll            ; Do initial scrolling adjustment
              
main_fadein:   ldi r0, sub_drwmap
               call sub_fadein            ; Fade-in from black

main_move:     call sub_maininp           ; Handle input; maybe move L/R or jump
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
               jn main_timeup             ; If time drops down past zero, over!
               stm r0, data.v_time
               ldi r0, 60
               stm r0, data.v_vblanks     ; And reset vblank ticks
main_loop:     jmp main_move

;--------------------
; Death logic zone
;--------------------
main_fallout:  pop r0                     ; We got here from sub_scroll...
               ldm r1, data.v_lives
               push r1
               subi r1, 1                 ; But remember the old score!
               jn main_gameover
               ldi r0, data.str_fallout
               ldi r1, 100
               ldi r2, 112
               call sub_drwstr 
               jmp main_flsh_die

main_timeup:   ldm r1, data.v_lives
               push r1
               subi r1, 1                 ; But remember the old score!
               jn main_gameover
               ldi r0, data.str_timeup
               ldi r1, 100
               ldi r2, 112
               call sub_drwstr
main_flsh_die: bgc 3                      ; Flicker red background rapidly
               ldi r0, 6
               ldi r1, 5
               call sub_drwflash
               cls
               ldi r0, sub_drwmap         ; Then fade to black
               call sub_fadeout
               call sub_initregs          ; Reset the player position
               call sub_initdata          ; Reset the scores
               pop r1
               subi r1, 1
               stm r1, data.v_lives
               call sub_ldlvl             ; Decompress level into tilemap memory
               call sub_rndbg
               jmp main_fadein            

main_gameover: ldi r0, data.str_gameover
               ldi r1, 100
               ldi r2, 112
               call sub_drwstr
               ldi r0, 3
               ldi r1, 15
               call sub_drwflash
               bgc 3
               ldi r0, 90
               call sub_wait
               cls
               ldi r0, sub_drwmap         ; Then fade to black
               call sub_fadeout
               jmp _start                 ; Then "reset" the game

__spin:        vblnk
               jmp __spin

star_mode:     snd0
.star_modeL:   vblnk
               call sub_sts_drw
               jmp star_mode

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
               ldi r0, 0
               stm r0, data.v_coins
               stm r0, data.obj_cb_bf
               stm r0, data.v_fallingout  ; We aren't falling out when we start
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
               ldi r0, 3                  ; Wait a few frames to slow effect
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
               ldi r0, 3                  ; Wait a few frames to slow effect
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
sub_drwintro:  call sub_sts_drw           ; Draw star field
               ldi r0, data.str_copy      ; Draw the copyright text
               ldi r1, 32
               ldi r2, 224
               call sub_drwstr
               ret

;------------------------------------------------------------------------------
; Draw the level start screen - e.g. "Level 1"
;------------------------------------------------------------------------------
sub_drwlvlst:  ldi r0, data.str_level     ; Draw "Level "
               ldi r1, 100
               ldi r2, 112
               call sub_drwstr
               ldm r0, data.v_level
               subi r0, 1
               ldi r1, data.str_bcd3
               call sub_r2bcd3
               ldi r0, data.str_bcd3
               ldi r1, 192
               ldi r2, 112
               call sub_drwstr
               ret

;------------------------------------------------------------------------------
; Draw the interface -- coins, time, lives, etc.
;------------------------------------------------------------------------------
sub_drwhud:    ldi r0, data.str_lives     ; Draw "Lives: "
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
               ldi r1, 104
               ldi r2, 2
               call sub_drwstr
               ldm r0, data.v_coins
               ldi r1, data.str_bcd3
               call sub_r2bcd3
               ldi r0, data.str_bcd3
               ldi r1, 192
               ldi r2, 2
               call sub_drwstr
               ldi r0, data.str_time      ; Draw "Time: "
               ldi r1, 252
               ldi r2, 2
               call sub_drwstr
               ldm r0, data.v_time
               ldi r1, data.str_bcd3
               call sub_r2bcd3
               ldi r0, data.str_bcd3
               ldi r1, 292
               ldi r2, 2
               call sub_drwstr
.sub_drwhudZ:  ret

;------------------------------------------------------------------------------
; Draw the menu
;------------------------------------------------------------------------------
sub_drwmenu:   ldi r0, data.str_start
               ldi r1, 100
               ldi r2, 156
               ldm r3, data.v_menu_sel
               shl r3, 1
               sub r0, r3
               call sub_drwstr
               ldi r0, data.str_demo
               ldi r1, 100
               ldi r2, 188
               ldm r3, data.v_menu_sel
               not r3
               andi r3, 1
               shl r3, 1
               sub r0, r3
               call sub_drwstr
               call sub_drwmap
               ret

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
sub_drw_t:     ldm r2, data.v_level_w
               mul r2, r1
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
               cmp ra, r0
               jge .sub_scrollF
               subi r0, 176               ; (320/2)-16
               ldm r1, data.v_level_h
               shl r1, 4
               cmp rb, r1
               ;jge .sub_scrollZZ
               jge .sub_scrollF
               subi r1, 104               ; (240/2)-16
               cmpi ra, 0
               jl .sub_scrollF 
               cmpi ra, 160
               jl .sub_scrollA
               cmp ra, r0
               jge .sub_scrollA
               mov rd, ra
               subi rd, 160
.sub_scrollA:  cmpi rb, 0
               jl .sub_scrollF
               cmpi rb, 120
               jl .sub_scrollZ
               cmp rb, r1
               jge .sub_scrollZ
.sub_scrollC:  mov re, rb
               subi re, 120
.sub_scrollZ:  ret
.sub_scrollF:  ldm r0, data.v_fallingout
               cmpi r0, 1
               jz .sub_scrollFZ
               ldi r0, 6
               ldi r1, main_fallout
               call sub_objcbq
               ldi r0, 1
               stm r0, data.v_fallingout
.sub_scrollFZ: ret
.sub_scrollZZ: ldi rc, PLYR_JP_DY_FP
               ret

;------------------------------------------------------------------------------
; Play the level-start screen jingle
;------------------------------------------------------------------------------
sub_lvlstmus:  ldi r0, 0
               ldi r1, MUSNOTE_C4
               ldi r2, 4
               ldi r3, 0x0403
               call sub_sndq
               ldi r0, 6
               ldi r1, MUSNOTE_C4
               ldi r2, 4
               ldi r3, 0x0403
               call sub_sndq
               ldi r0, 6
               ldi r1, MUSNOTE_C4
               ldi r2, 4
               ldi r3, 0x0403
               call sub_sndq
               ldi r0, 6
               ldi r1, MUSNOTE_C4
               ldi r2, 4
               ldi r3, 0x0403
               call sub_sndq
               ldi r0, 15
               ldi r1, MUSNOTE_G4
               ldi r2, 15
               ldi r3, 0x0403
               call sub_sndq
.sub_lvlstmusZ: ret 

;------------------------------------------------------------------------------
; Make the player jump -- account for continuous button press
;------------------------------------------------------------------------------
sub_jump:      ldm r0, data.v_jump     ; Do not jump again if already jumping
               cmpi r0, 1
               jz .sub_jump_Z
               cmpi rc, 0              ; Do not jump if falling
               jnz .sub_jump_Z
               ldm r0, data.v_hitblk   ; Do not jump if we have not hit a floor
               cmpi r0, 1 
               jnz .sub_jump_Z
               ldi r0, 0
               stm r0, data.v_hitblk
               ldi r0, 1
               stm r0, data.v_jump
               ldi rc, PLYR_JP_DY_FP   ; PLYR_JP_DY << FP_SHIFT
               ldi r0, 0
               ldm r1, data.sfx_jump
               ldi r2, 4
               ldi r3, 0x0003
               call sub_sndq
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
               ldi r0, 0
               ldm r1, data.sfx_land
               ldi r2, 4
               ldi r3, 0x0003
               call sub_sndq
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
sub_drwdbg:    ret
               mov r0, ra
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

               ldm r0, data.snd_pos
               ldi r1, data.str_bcd3
               call sub_r2bcd3
               ldi r0, data.str_bcd3
               ldi r1, 96
               ldi r2, 228
               call sub_drwstr

               ldm r0, data.v_level
               ldi r1, data.str_bcd3
               call sub_r2bcd3
               ldi r0, data.str_bcd3
               ldi r1, 144
               ldi r2, 228
               call sub_drwstr

               ldm r0, data.v_menu_sel
               ldi r1, data.str_bcd3
               call sub_r2bcd3
               ldi r0, data.str_bcd3
               ldi r1, 192
               ldi r2, 228
               call sub_drwstr

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
; Flash the screen red a given number of times, with given duration.
;------------------------------------------------------------------------------
sub_drwflash:  cmpi r0, 0
               jz .sub_drwflashZ
               bgc 3
               push r0
               push r1
               mov r0, r1
               call sub_wait
               ldi r0, 5
               ldi r1, 500
               ldi r2, 4
               ldi r3, 0x0a63
               call sub_sndq
               bgc 0
               pop r0
               push r0
               call sub_wait
               ldi r0, 5
               ldi r1, 600
               ldi r2, 4
               ldi r3, 0x0663
               call sub_sndq
               pop r1
               pop r0
               subi r0, 1
               jmp sub_drwflash
.sub_drwflashZ: ret

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
               ldm r2, data.v_level_w
               mul r1, r2
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
               push r2
               ldm r2, data.v_level_w
               mul r1, r2
               pop r2
               add r1, r0
               shl r1, 1
               addi r1, data.level
               stm r2, r1
               ret

;------------------------------------------------------------------------------
; Load current level into memory. Decode using eithe RLE or SWE scheme.
;------------------------------------------------------------------------------
sub_ldlvl:     ldm r0, data.v_level
               shl r0, 1
               addi r0, data.v_level_offs
               ldm r0, r0                 ; Read address of current level
               ldm r1, r0                 ; Read level width (in tiles)
               stm r1, data.v_level_w
               addi r0, 2
               ldm r1, r0                 ; Read level height (in tiles)
               stm r1, data.v_level_h
               addi r0, 2
               ldi r1, data.level
;               call sub_derle             ; Decompress the tile data
               ldi r2, 2                  ; Music to be dec'd to words 
               call sub_deswe             ; Decompress the tile data
               call sub_o_parse           ; Read in the level object data
.sub_ldlvlZ:   ret

;------------------------------------------------------------------------------
; Load the tile graphics into memory. Decode using the same RLE scheme.
; Handles 16x16 tiles only.
;------------------------------------------------------------------------------
sub_ldgfx:     nop
               ret

;------------------------------------------------------------------------------
; Decompress SWE data (sliding window encoding)
;
; This LZ-like encoding scheme exploits repeated sequences that are common in
; data (e.g. levels have groups of tiles that are repeated throughout).
; Sequences are encoded either directly (repeat byte N times), or as block
; copies from a previous position in the decoded output.
;
; Data layout (example): 10 00 84 00 81 f8 04 04
; Meaning: 
; - Section is 0x0010 (16) bytes long.
; - Write byte '0x00' 4 times.
; - Write byte '0xf8' once.
; - Copy 4 bytes from decode buffer, from current position minus 4.
;------------------------------------------------------------------------------
sub_deswe:     mov r5, r1                 ; Destination pointer initial value
               mov r8, r2                 ; Decoded data increment size
               ldm r1, r0                 ; Load tiles' SWE section size
               ldi r2, 2                  ; Section input byte counter
.sub_desweA:   cmp r2, r1                 ; If we read all section bytes, end
               jge .sub_desweZ
               mov r3, r2
               addi r2, 2
               add r3, r0                 ; Current offset into section
               ldm r3, r3                 ; Read either value + reps, or...
               mov r4, r3                 ; ...copy size + offs. bkw'ds for src
               andi r3, 0xff
               shr r4, 8
               tsti r3, 0x80              ; Bit 7 set means value + reps
               jz .sub_desweC
               andi r3, 0x7f
.sub_desweB:   stm r4, r5                 ; Write repeated byte
               add r5, r8
               subi r3, 1                 ; Input is byte based so move 1
               jnz .sub_desweB
               jmp .sub_desweA
.sub_desweC:   andi r3, 0x7f
               mov r6, r5                 ; Copy start addr. is cur. offset...
               mul r4, r8                 ;
               sub r6, r4                 ; ... minus N words.
.sub_desweD:   ldm r7, r6                 ; Load word from input
               stm r7, r5                 ; Store it.
               add r5, r8
               add r6, r8
               subi r3, 1                 ; Input is byte based so move 1
               jnz .sub_desweD
               jmp .sub_desweA
.sub_desweZ:   add r0, r1                 ; Add input length to start address
               addi r0, 2                 ; Plus 2 to account for size variable
               ret
;------------------------------------------------------------------------------
; Decompress RLE data (run-length encoding)
;
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
sub_derle:     mov r5, r1                 ; Destination pointer initial value
               ldm r1, r0                 ; Load tiles' RLE section size
               ldi r2, 0                  ; Section input byte counter
               ldi r6, 2                  ; Last input size
.sub_derleA:   cmp r2, r1                 ; If we read all section bytes, end
               jge .sub_derleZ
               add r2, r6                 ; Increment input byte counter
               ldi r6, 2
               mov r3, r2
               add r3, r0                 ; Current offset into section
               ldm r3, r3                 ; Read value (lo) and reps (hi)
               mov r4, r3
               andi r3, 0xff              ; Byte value to repeat
               shr r4, 8                  ; Number of repetitions (max. 255)
               cmpi r3, 0
               jz .sub_derleB
               ldi r4, 1
               ldi r6, 1
.sub_derleB:   stm r3, r5                 ; Write repeated byte
               addi r5, 2                 ; Increment destination pointer
               subi r4, 1                 ; Decrement counter
               jz .sub_derleA
               jmp .sub_derleB
.sub_derleZ:   add r0, r1
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
               mov r5, r2
               cmpi r5, 5
               jnz .sub_o_parseB
               nop
.sub_o_parseB: addi r0, 2
               ldm r3, r0                 ; Object x
               addi r0, 2
               ldm r4, r0                 ; Object y
               pushall
               mov r0, r3
               shl r0, 4                  ; Object X in pixel-coords
               mov r1, r4
               shl r1, 4                  ; Object Y in pixel-coords
               mov r3, r2
               subi r3, 1
               shl r3, 1
               addi r3, data.obj_data
               ldm r3, r3
               or r2, r3                  ; Add in object data (solid, anim)
               ori r2, 0x8000             ; Set highest bit to signify object
               call sub_setblk
               popall
               subi r1, 1
               cmpi r5, 1
               jnz .sub_o_parseA
               ldm r2, data.v_coins
               addi r2, 1
               stm r2, data.v_coins
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
               rnd r3, 3
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
; Manage controller input for menu screen
;------------------------------------------------------------------------------
sub_menuinp:   call sub_btn_select
               cmpi r0, 1
               jnz .sub_menuinpA
               ldm r0, data.v_menu_vblnk
               cmpi r0, 15
               jl .sub_menuinpZ
               ldi r0, 0
               stm r0, data.v_menu_vblnk
               ldm r0, data.v_menu_sel
               addi r0, 1
               andi r0, 1
               stm r0, data.v_menu_sel
               jmp .sub_menuinpZ
.sub_menuinpA: call sub_btn_start
               cmpi r0, 1
               jnz .sub_menuinpZ
               stm r0, data.v_menu_start
.sub_menuinpZ: ret

;------------------------------------------------------------------------------
; Manage controller input for main game
;------------------------------------------------------------------------------
sub_maininp:   call sub_btn_a
               cmpi r0, 1
               jnz .sub_maininpA
               call sub_jump
               jmp .sub_maininpB
.sub_maininpA: ldi r0, 0
               stm r0, data.v_jump
.sub_maininpB: call sub_btn_left
               cmpi r0, 1
               jnz .sub_maininpC
               call sub_mvleft
               jmp .sub_maininpZ
.sub_maininpC: call sub_btn_right
               cmpi r0, 1
               jnz .sub_maininpZ
               call sub_mvright
.sub_maininpZ: call sub_btn_start         ; DEBUG: Start button resets the game
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
; Return whether button Select is pressed
;------------------------------------------------------------------------------
sub_btn_select: ldm r0, 0xfff0
               andi r0, 0x10
               shr r0, 4
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
sub_wait:      push r0
               call sub_sndstep
               pop r0
               vblnk
               cmpi r0, 0
               jz .sub_waitZ
               subi r0, 1
               jmp sub_wait
.sub_waitZ:    ret

sub_wait_draw: push r0
               push r1
               call r1
               call sub_sndstep
               pop r1
               pop r0
               vblnk
               cmpi r0, 0
               jz .sub_wait_drZ
               subi r0, 1
               jmp sub_wait_draw
.sub_wait_drZ: ret

;------------------------------------------------------------------------------
; Increase lives count by 1 and play jingle
;------------------------------------------------------------------------------
sub_1up:       ldm r0, data.v_lives       ; Increase lives count
               addi r0, 1
               stm r0, data.v_lives
               
               ldi r0, 0                  ; Play 1-up jingle
               ldi r1, MUSNOTE_F4
               ldi r2, 3
               ldi r3, 0x0440
               call sub_sndq

               ldi r0, 4
               ldi r1, MUSNOTE_C4
               ldi r2, 3 
               ldi r3, 0x0440
               call sub_sndq
               
               ldi r0, 3
               ldi r1, MUSNOTE_F4
               ldi r2, 4 
               ldi r3, 0x0440
               call sub_sndq
               
               ldi r0, 3
               ldi r1, MUSNOTE_C4
               ldi r2, 4 
               ldi r3, 0x0440
               call sub_sndq
               
               ldi r0, 3
               ldi r1, MUSNOTE_B5
               ldi r2, 4 
               ldi r3, 0x0440
               call sub_sndq
               
               ret

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
; Refresh the objects bound to the object timer, using a bitfield for status.
;------------------------------------------------------------------------------
sub_objref:    ldm r0, data.obj_cb_bf
               cmpi r0, 0
               jz .sub_objrefZ                  ; If bf is 0, short-circuit
               ldi r2, 8
.sub_objrefA:  subi r2, 1
               jn .sub_objrefZ
               ldi r1, 1
               shl r1, r2
               tst r0, r1
               jz .sub_objrefA                  ; Keep looking
.sub_objrefB:  push r2
               muli r2, 10
               addi r2, data.obj_cbs
               ldm r0, r2                       ; Delay for cb in this slot
               cmpi r0, 0
               jnz .sub_objrefC                 ; If delay>0, decrement and loop
               mov r4, r2                       ; If delay==0, call cb
               addi r4, 2
               ldm r5, r4                       ; Callback
               addi r4, 2
               ldm r0, r4                       ; Arg 0
               addi r4, 2
               push r1
               ldm r1, r4                       ; Arg 1
               addi r4, 2
               ldm r2, r4                       ; Arg 2
               call r5
               ldm r0, data.obj_cb_bf           ; Clear cb entry in bitfield
               pop r1
               not r1
               and r0, r1
               stm r0, data.obj_cb_bf
               pop r2
               jmp .sub_objrefA
.sub_objrefC:  subi r0, 1
               stm r0, r2
               pop r2
               jmp .sub_objrefA
.sub_objrefZ:  ret

;------------------------------------------------------------------------------
; Get a free slot in the object callback table
;------------------------------------------------------------------------------
sub_objslot:   ldm r0, data.obj_cb_bf
               ldi r1, 0
.sub_objslotA: mov r2, r0
               shr r2, r1
               andi r2, 1
               cmpi r2, 0
               jz .sub_objslotZ
               addi r1, 1
               cmpi r1, 16
               jl .sub_objslotA
.sub_objslot8: ldi r1, -1
.sub_objslotZ: mov r0, r1
               ret

;------------------------------------------------------------------------------
; Insert a future callback into a free slot in the object callback table
;
; Arguments: r0: delay, r1: callback, r2,3,4: callback args
;------------------------------------------------------------------------------
sub_objcbq:    push r0
               push r1
               push r2
               call sub_objslot           ; Get a free slot in the table
               mov r5, r0                 ; Save it
               pop r2
               pop r1
               pop r0
               cmpi r5, -1                ; If no slot could be found,
               jz .sub_objcbqZ            ; abort.
               ldi r6, 10
               mul r6, r5                 ; Offset (bytes) into callback table
               addi r6, data.obj_cbs      ; Callback table entry pointer
               stm r0, r6                 ; Write delay
               addi r6, 2
               stm r1, r6                 ; Write callback handle
               addi r6, 2
               stm r2, r6                 ; Write args
               addi r6, 2
               stm r3, r6
               addi r6, 2
               stm r4, r6
               addi r6, 2
               ldi r6, 1                  ; Write slot into bitfield
               shl r6, r5
               ldm r0, data.obj_cb_bf
               or r0, r6
               stm r0, data.obj_cb_bf
.sub_objcbqZ:  ret

;------------------------------------------------------------------------------
; Coin object handler
;------------------------------------------------------------------------------
sub_obj0:      pushall
               ldi r2, 0x8043             ; Coin consumed, replace with sparkle
               call sub_setblk
               popall

               mov r3, r1                 ; Cb arg 1: coin y
               mov r2, r0                 ; Cb arg 0: coin x
               ldi r0, 10                 ; Cb timer
               ldi r1, sub_obj2           ; Cb pointer
               call sub_objcbq
               
               ldi r0, 0                  ; 0 delay
               ldm r1, data.sfx_coin0
               ldi r2, 3                  ; 3 Vblnks = 50 ms duration
               ldi r3, 0x0402             ; Med. release, low attack, square
               call sub_sndq
               ldi r0, 4                  ; 5 Vblnks = 83 ms delay
               ldm r1, data.sfx_coin1
               ldi r2, 3                  ; 3 Vblnks = 48 ms duration
               ldi r3, 0x0702             ; Med. release, low attack, square
               call sub_sndq
               
               ldm r0, data.v_coins       ; Decrements "coins remaining"
               subi r0, 1
               stm r0, data.v_coins
               cmpi r0, 0                 ; If all collected, 1-up lives count
               jg .sub_obj0Z
               call sub_1up
.sub_obj0Z:    ret

;------------------------------------------------------------------------------
; Coin sparkle object handler
;------------------------------------------------------------------------------
sub_obj2:      ldi r2, 0                  ; Clear from tilemap
               call sub_setblk
.sub_obj2Z:    ret

;------------------------------------------------------------------------------
; Exit doorway object handlers 
;------------------------------------------------------------------------------
sub_obj4:      ldi r0, 5                  ; Schedule callback 5 frames from now
               ldi r1, sub_obj4d
               call sub_objcbq
               ret

sub_obj4d:     pop r0                     ; Goto next level
               ldm r0, data.v_level       ; Increment level counter
               addi r0, 1
               stm r0, data.v_level
               ldi r0, sub_drwmap         ; Fadeout the screen
               call sub_fadeout
               jmp lvlst_init             ; And go to level start screen.


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
sub_sndstep:   ldm r1, data.snd_pos
               cmpi r1, 16
               jnz .sub_sndstepA
               ldm r0, data.snd_cb
               cmpi r0, 0
               jz .sub_sndstepZ
               call r0
               jmp .sub_sndstepZ
.sub_sndstepA: ldm r0, data.snd_remaining ; No sounds remaining -> do nothing
               cmpi r0, 0
               jnz .sub_sndstepB
               call sub_sndreset          ; Reset audio state for good measure
               jmp .sub_sndstepZ
.sub_sndstepB: ldm r1, data.snd_pos
               shl r1, 3
               addi r1, data.snd_track
               ldm r0, r1                 ; Read delay remaining
               cmpi r0, 0                 ; If 0, ready for playback
               jz .sub_sndstepC
               subi r0, 1                 ; Decrement delay
               stm r0, r1                 ; Write back
               stm r0, data.snd_delay_left ; Write back here too for debug
               jmp .sub_sndstepZ
.sub_sndstepC: ldm r0, data.snd_pos
               shl r0, 3
               addi r0, data.snd_track
               addi r0, 2                 ; Skip delay, we already dealt with it
               ldm r1, r0                 ; Note
               addi r0, 2
               ldm r2, r0                 ; Duration
               shl r2, 4
               stm r2, .sub_sndstepP
               addi r0, 2
               ldm r2, r0                 ; Flags
               mov r3, r2
               shr r3, 8                  ; SNG Release
               mov r4, r2
               andi r4, 3                 ; SNG Type
               shl r4, 8
               add r3, r4
               addi r3, 0x8080            ; Add Volume 15 and Sustain 15
               stm r3, .sub_sndstepH      ; Write to SNG word 2
               andi r2, 0x00f0            ; SNG Attack
               shl r2, 8
               addi r2, 0x0e              ; Add in SNG opcode
               stm r2, .sub_sndstepG      ; Write to SNG word 1
.sub_sndstepG: db 0x0e, 0x00              ; SNG instruction
.sub_sndstepH: db 0x80, 0x80
               db 0x0d, 0x01              ; SNP instruction
.sub_sndstepP: db 0x00, 0x00
               ldm r0, data.snd_pos       ; Point to next sound in track
               addi r0, 1
               stm r0, data.snd_pos
               ldm r0, data.snd_remaining ; Decrement number of sounds left
               subi r0, 1
               stm r0, data.snd_remaining
.sub_sndstepZ: ret

;------------------------------------------------------------------------------
; Helper subroutine to reset audio player state.
;------------------------------------------------------------------------------
sub_sndreset:  ldi r0, 0
               stm r0, data.snd_pos
               stm r0, data.snd_last_pos
               stm r0, data.snd_remaining
               stm r0, data.snd_qpos
               stm r0, data.snd_delay_left
               stm r0, data.snd_cb
               ret

;------------------------------------------------------------------------------
; Helper subroutine to queue a sound to the track
;
; Args: r0: delay, r1: note, r2: duration, r3: flags
;------------------------------------------------------------------------------
sub_sndq:      ldm r4, data.snd_qpos
               push r4
               shl r4, 3
               addi r4, data.snd_track
               stm r0, r4
               addi r4, 2
               stm r1, r4
               addi r4, 2
               stm r2, r4
               addi r4, 2
               stm r3, r4
               pop r4
               cmpi r4, 0
               jnz .sub_sndqA
               stm r0, data.snd_delay_left
.sub_sndqA:    addi r4, 1
               stm r4, data.snd_qpos
               ldm r0, data.snd_remaining
               addi r0, 1
               stm r0, data.snd_remaining
.sub_sndqZ:    ret 


;------------------------------------------------------------------------------
; Subroutine to stream music from a buffer.
;
; Queues notes until the buffer is filled, then call into a callback if
; provided.
;
; Args: r0: src buffer, r1: loop, r2: callback?
;------------------------------------------------------------------------------
sub_sndstrm:   pushall
               call sub_sndreset
               popall
               stm r0, data.snd_strm_src
               stm r1, data.snd_strm_loop
               stm r2, data.snd_cb
               ldi r3, data.snd_track     ; Destination pointer
               ldi r4, 16
               stm r4, data.snd_remaining
.sub_sndstrmB: cmpi r4, 0
               jz .sub_sndstrmZ
               ldm r1, r0                 ; Read word 1
               stm r1, r3                 ; Store it
               addi r0, 2
               addi r3, 2
               ldm r1, r0                 ; Word 2...
               stm r1, r3
               addi r0, 2
               addi r3, 2
               ldm r1, r0                 ; Word 3...
               stm r1, r3
               addi r0, 2
               addi r3, 2
               ldm r1, r0                 ; Word 4...
               stm r1, r3
               addi r0, 2
               addi r3, 2
               subi r4, 1
               jmp .sub_sndstrmB
.sub_sndstrmZ: ret

sub_cb_music:  ldm r0, data.snd_strm_src
               addi r0, 128
               ldi r1, 1
               ldi r2, sub_cb_music
               call sub_sndstrm
               ret

;------------------------------------------------------------------------------
; DATA 
;------------------------------------------------------------------------------
data.str_copy:       db "Copyright (C) T. Kelsall, 2018."
                     db 0
data.str_level:      db "L E V E L  "
                     db 0
data.str_lives:      db "Lives: "
                     db 0
data.str_coins:      db "Coins Left: "
                     db 0
data.str_time:       db "Time: "
                     db 0
data.str_timeup:     db "T I M E   U P !"
                     db 0
data.str_fallout:    db "F A L L   O U T !"
                     db 0
data.str_gameover:   db "G A M E   O V E R"
                     db 0
                     db "> "
data.str_start:      db "Start"
                     db 0
                     db "> "
data.str_demo:       db "Switch to Intro"
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
data.snd_qpos:       dw 0
data.snd_delay_left: dw 0
data.snd_last_pos:   dw 0
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
data.snd_strm_loop:  dw 0
data.snd_strm_src:   dw 0

data.obj_data:       dw 0x0040
                     dw 0
                     dw 0x0042
                     dw 0
                     dw 0x0004
data.obj_handlers:   dw sub_obj0          ; Coin
                     dw sub_nop           ; Coin +1
                     dw sub_nop           ; Coin sparkle
                     dw sub_nop           ; Coin sparkle +1
                     dw sub_obj4          ; Exit doorway

data.obj_cb_bf:      dw 0
data.obj_cbs:        dw 0, 0, 0, 0, 0
                     dw 0, 0, 0, 0, 0
                     dw 0, 0, 0, 0, 0
                     dw 0, 0, 0, 0, 0
                     dw 0, 0, 0, 0, 0
                     dw 0, 0, 0, 0, 0
                     dw 0, 0, 0, 0, 0
                     dw 0, 0, 0, 0, 0
                     dw 0, 0, 0, 0, 0
                     dw 0, 0, 0, 0, 0
                     dw 0, 0, 0, 0, 0
                     dw 0, 0, 0, 0, 0
                     dw 0, 0, 0, 0, 0
                     dw 0, 0, 0, 0, 0
                     dw 0, 0, 0, 0, 0
                     dw 0, 0, 0, 0, 0

data.v_menu_vblnk:   dw 0
data.v_menu_start:   dw 0
data.v_menu_sel:     dw 1 

data.v_level:        dw 0
data.v_lvlst_vblnk:  dw 0

data.v_level_offs:   dw data.intro, data.menu, data.level0, data.level1

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
data.v_fallingout:   dw 0
data.sfx_jump:       dw 800
data.sfx_land:       dw 1000
data.sfx_intro:      dw 500
data.sfx_coin0:      dw 987
data.sfx_coin1:      dw 1318

; Sample music buffer
data.sfx_music:      dw  8,MUSNOTE_D3,8, 0x0830
                     dw  8,MUSNOTE_F3,8, 0x0830
                     dw  8,MUSNOTE_D4,20,0x0830
                     dw 30,MUSNOTE_D3,8, 0x0830
                     dw  8,MUSNOTE_F3,8, 0x0830
                     dw  8,MUSNOTE_D4,20,0x0830
                     dw 30,MUSNOTE_E4,30,0x0830
                     dw 46,MUSNOTE_F4,8, 0x0830
                     dw 15,MUSNOTE_E4,5, 0x0830
                     dw 15,MUSNOTE_F4,5, 0x0830
                     dw 30,MUSNOTE_E4,5, 0x0830
                     dw 15,MUSNOTE_C4,5, 0x0830
                     dw 15,MUSNOTE_A4,5, 0x0830
                     dw  8,MUSNOTE_A4,5, 0x0830
                     dw 45,MUSNOTE_D3,5, 0x0830
                     dw  8,MUSNOTE_F3,5, 0x0830
