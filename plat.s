TILE_DIM       equ 16
TILES_X        equ 20
TILES_LASTX    equ 19
TILES_Y        equ 15
TILES_LASTY    equ 14

start:         call sub_ldlvl
               bgc 0
               ldi ra, 280
               ldi rb, 33
               spr 0x1008
loop:          ldi r1, TILES_LASTY
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
.loop_end:     
               call sub_dy2blk
               call sub_mvplyr

               spr 0x0804
               drw ra, rb, data.plyr
               mov r0, rb
               addi r0, 8
               drw ra, r0, data.highl 
               spr 0x1008

draw_end:      vblnk
.break:        cls
               jmp loop

spin:          vblnk
               jmp spin

sub_mvplyr:    mov r0, ra
               mov r1, rb
               addi r1, 8
               add r1, rc
               call sub_getblk
               tsti r0, 1
               jz .sub_mvplyr_a
               ldi rc, 0
               jmp .sub_mvplyr_Z
.sub_mvplyr_a: cmpi rc, 8
               jge .sub_mvplyr_b
               addi rc, 1
.sub_mvplyr_b: add rb, rc
.sub_mvplyr_Z: ret 

sub_dy2blk:    mov r0, ra
               mov r1, rb
               call sub_getblk
               tsti r0, 1
               jz .sub_dy2blk_Z
               mov r1, rb
               shr r1, 4
               shl r1, 4
               sub rb, r1, r0
.sub_dy2blk_Z: ret

sub_getblk:    shr r0, 4
               shr r1, 4
               muli r1, TILES_X
               add r1, r0
               addi r1, data.level
               ldm r0, r1
               ret

sub_ldlvl:     ret

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
