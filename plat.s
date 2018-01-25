TILE_DIM       equ 16
TILES_X        equ 20
TILES_LASTX    equ 19
TILES_Y        equ 15
TILES_LASTY    equ 14

CHAR_OFFS      equ 32

data.paletteA  equ 0xf000

importbin level/level0.bin 0 300 data.level

;------------------------------------------------------------------------------
; Main program
;------------------------------------------------------------------------------
start:         nop
               ldi r0, sub_drwintro       ; Display the intro screen
               call sub_fadein
               ldi r0, 90
               call sub_wait
               ldi r0, sub_drwintro
               call sub_fadeout

               call sub_ldlvl             ; Decompress level into tilemap memory
               ldi ra, 260                ; Initial player position
               ldi rb, 33
               spr 0x1008                 ; Default sprite size 16x16
              
fade_in:       ldi r0, sub_drwmap
               call sub_fadein            ; Fade-in from black

loop:          call sub_input             ; Handle input; maybe move L/R or jump
               call sub_mvplyr            ; Move U/D

               cls                        ; Clear screen
               bgc 0                      ; Dark background
               call sub_drwmap            ; Draw tiles
               call sub_drwplyr           ; Draw player sprite

draw_end:      vblnk                      ; Wait for vertical blanking
               flip 0,0                   ; Reset sprite flipping
               ldm r0, data.v_anim_c      ; Increment animation counter
               addi r0, 1
               stm r0, data.v_anim_c
               ldi r0, 0                  ; Reset horizontal movement boolean
               stm r0, data.v_hmov
               jmp loop

spin:          vblnk
               jmp spin

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
sub_drwintro:  spr 0x0804
               ldi r0, data.str_copy      ; Draw the copyright text
               ldi r1, 32
               ldi r2, 224
               call sub_drwstr
               ; Draw the game logo
               ret

;------------------------------------------------------------------------------
; Draw the tilemap -- iterate over map array
;------------------------------------------------------------------------------
sub_drwmap:    ldi r1, TILES_LASTY
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
               addi r4, data.gfx_lvl_bg0
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
               ldi rc, -12
.sub_jump_Z:   ret

;------------------------------------------------------------------------------
; Move player accounting for jumping, gravity, and collisions
;------------------------------------------------------------------------------
sub_mvplyr:    mov r0, ra
               mov r1, rb
               addi r1, 8
               add r1, rc
               call sub_getblk
               tsti r0, 0x80
               jz .sub_mvplyr_a
               cmpi rc, 0
               jz .sub_mvplyr_0
               sng 0xf2, 0x4382
               ldi r0, data.sfx_land
               snp r0, 50
               ldi rc, 0
.sub_mvplyr_0: ldi r0, 1
               stm r0, data.v_hitblk
               call sub_dy2blk
               add rb, r0
               jmp .sub_mvplyr_Z
.sub_mvplyr_a: cmpi rc, 8
               jge .sub_mvplyr_b
               addi rc, 1
.sub_mvplyr_b: add rb, rc
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
               jnz .sub_mvleft_Z
               subi ra, 2
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
sub_drwplyr:   ;spr 0x0804
               mov r0, ra
               subi r0, 4
               mov r1, rb
               subi r1, 8
               ldi r2, data.gfx_c2b
               ldm r3, data.v_lor
               cmpi r3, 1
               jnz .sub_drwplyr_A
               flip 1, 0
               jmp .sub_drwplyr_B
.sub_drwplyr_A: cmpi r3, 2
               jnz .sub_drwplyr_B
               flip 0,0
.sub_drwplyr_B: ldm r3, data.v_hmov
               cmpi r3, 0
               jz .sub_drwplyr_Z
               ldm r3, data.v_anim_c
               andi r3, 0x8
               shl r3, 4
               add r2, r3
.sub_drwplyr_Z: drw r0, r1, r2
               ;spr 0x1008
               ret

;------------------------------------------------------------------------------
; Display a string, accounting for newlines too. 
;------------------------------------------------------------------------------
sub_drwstr:    ldm r3, r0
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
               shr r1, 3
               shl r1, 3
               sub r1, ra, r0
               ret

;------------------------------------------------------------------------------
; Return remaining pixels to next 8-aligned x-coordinate
;------------------------------------------------------------------------------
sub_dx2rblk:   mov r1, ra
               addi r1, 7
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
               addi r1, data.level
               ldm r0, r1
               andi r0, 0xff
               ret

;------------------------------------------------------------------------------
; <STUB> Load requested level into memory
;------------------------------------------------------------------------------
sub_ldlvl:     ret                     ; ROM comes with tilemap already mapped

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
.sub_input_Z:  ret

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
; Wait given number of frames
;------------------------------------------------------------------------------
sub_wait:      vblnk
               cmpi r0, 0
               jz .sub_waitZ
               subi r0, 1
               jmp sub_wait
.sub_waitZ:    ret

;------------------------------------------------------------------------------
; DATA 
;------------------------------------------------------------------------------
data.str_copy: db "Copyright (C) T. Kelsall, 2018."
               db 0
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
data.v_jump:   dw 0
data.v_lor:    dw 0
data.v_hmov:   dw 0
data.v_anim_c: dw 0
data.v_hitblk: dw 0
data.sfx_land: dw 1000
