TILE_DIM       equ 16
TILES_X        equ 20
TILES_LASTX    equ 19
TILES_Y        equ 15
TILES_LASTY    equ 14

importbin gfx/c2b.bin 0 256 data.gfx_c2b

;------------------------------------------------------------------------------
; Main program
;------------------------------------------------------------------------------
start:         call sub_ldlvl
               ldi ra, 280
               ldi rb, 33
               spr 0x1008
loop:          cls
               bgc 11
               ldi r1, TILES_LASTY
.loop_y:       ldi r0, TILES_LASTX
.loop_x:       mov r2, r1
               muli r2, TILES_X
               add r2, r0
               addi r2, data.level
               ldm r3, r2
               andi r3, 1
               jz .loop_xepi
               mov r2, r0
               mov r3, r1
               muli r2, TILE_DIM
               muli r3, TILE_DIM
               drw r2, r3, data.tile

.loop_xepi:    subi r0, 1
               jnn .loop_x
.loop_yepi:    subi r1, 1
               jnn .loop_y
.loop_end:     nop
               
               call sub_input
               call sub_mvplyr

               call sub_drwplyr

draw_end:      vblnk
               flip 0,0
               ldm r0, data.v_anim_c
               addi r0, 1
               stm r0, data.v_anim_c
               ldi r0, 0
               stm r0, data.v_hmov
               jmp loop

spin:          vblnk
               jmp spin

;------------------------------------------------------------------------------
; Make the player jump -- account for continuous button press
;------------------------------------------------------------------------------
sub_jump:      ldm r0, data.v_jump
               cmpi r0, 1
               jz .sub_jump_Z
               cmpi rc, 0
               jnz .sub_jump_Z
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
               tsti r0, 1
               jz .sub_mvplyr_a
               ldi rc, 0
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
               tsti r0, 1
               jnz .sub_mvleft_Z
.break:        subi ra, 2
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
               tsti r0, 1
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
sub_ldlvl:     ret

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
; DATA 
;------------------------------------------------------------------------------
data.level:    db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
               db 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1 
               db 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1 
               db 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1 
               db 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1 
               db 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1 
               db 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1 
               db 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1 
               db 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1 
               db 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1 
               db 1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1 
               db 1,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,1 
               db 1,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,1 
               db 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1 
               db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1

data.tile:     db 0x55,0x55,0x55,0x55,0x55,0x55,0x55,0x55
               db 0x55,0x55,0x55,0x55,0x55,0x55,0x55,0x55
               db 0x55,0x55,0x55,0x55,0x55,0x55,0x55,0x55
               db 0x55,0x55,0x55,0x55,0x55,0x55,0x55,0x55
               db 0x55,0x55,0x55,0x55,0x55,0x55,0x55,0x55
               db 0x55,0x55,0x55,0x55,0x55,0x55,0x55,0x55
               db 0x55,0x55,0x55,0x55,0x55,0x55,0x55,0x55
               db 0x55,0x55,0x55,0x55,0x55,0x55,0x55,0x55
               db 0x55,0x55,0x55,0x55,0x55,0x55,0x55,0x55
               db 0x55,0x55,0x55,0x55,0x55,0x55,0x55,0x55
               db 0x55,0x55,0x55,0x55,0x55,0x55,0x55,0x55
               db 0x55,0x55,0x55,0x55,0x55,0x55,0x55,0x55
               db 0x55,0x55,0x55,0x55,0x55,0x55,0x55,0x55
               db 0x55,0x55,0x55,0x55,0x55,0x55,0x55,0x55
               db 0x55,0x55,0x55,0x55,0x55,0x55,0x55,0x55
               db 0x55,0x55,0x55,0x55,0x55,0x55,0x55,0x55

data.plyr:     db 0x99,0x99,0x99,0x99
               db 0x99,0x99,0x99,0x99
               db 0x99,0x99,0x99,0x99
               db 0x99,0x99,0x99,0x99
               db 0x99,0x99,0x99,0x99
               db 0x99,0x99,0x99,0x99
               db 0x99,0x99,0x99,0x99
               db 0x99,0x99,0x99,0x99

data.highl:    db 0x33,0x33,0x33,0x33
               db 0x33,0x33,0x33,0x33
               db 0x33,0x33,0x33,0x33
               db 0x33,0x33,0x33,0x33
               db 0x33,0x33,0x33,0x33
               db 0x33,0x33,0x33,0x33
               db 0x33,0x33,0x33,0x33
               db 0x33,0x33,0x33,0x33

data.v_jump:   dw 0
data.v_lor:    dw 0
data.v_hmov:   dw 0
data.v_anim_c: dw 0
