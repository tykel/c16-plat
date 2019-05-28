;------------------------------------------------------------------------------
; sf.s -- Second attempt at a star field on Chip16
;
; Copyright (C) 2018, tykel. All rights reserved.
;
; For algorithm:
; See http://freespace.virgin.net/hugo.elias/graphics/x_stars.htm
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; RAM zone to store star data.
LOC_STARS   equ 0x8000

; The approximate number of stars we can process at 60 FPS.
NUM_STARS   equ 320
;NUM_STARS   equ 1
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
sub_sts_init:   call sub_rndstars           ; Generate our initial stars
                pal d_pal
                ret

sub_sts_drw:    cls
                spr 0x0101                  ; Smallest sprite size
                ldi r0, NUM_STARS
                subi r0, 1
.sub_sts_drw1:  call sub_advstar
                subi r0, 1
                jnz .sub_sts_drw1
.sub_sts_drwZ:  ret
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
sub_rndstar:    mov r2, r0
                muli r2, 8
                addi r2, LOC_STARS
                rnd r1, 1024
                subi r1, 512
                stm r1, r2                  ; X
                addi r2, 2
                rnd r1, 1024
                subi r1, 512
                stm r1, r2                  ; Y
                addi r2, 2
                rnd r1, 900
                addi r1, 100
                stm r1, r2                  ; Z
                addi r2, 2
                rnd r1, 8
                addi r1, 1 
                stm r1, r2                  ; Z-speed
                ret
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
sub_rndstars:   ldi r0, 0
.sub_rndstarsA: cmpi r0, NUM_STARS
                jz .sub_rndstarsZ
                call sub_rndstar
                addi r0, 1
                jmp .sub_rndstarsA
.sub_rndstarsZ: ret
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
sub_advstar:    ldi rf, 63                  ; Map from [0..999] to [0..15]
                mov r1, r0
                muli r1, 8
                addi r1, LOC_STARS
                ldm r2, r1                  ; X
                shl r2, 6                   ; To fixed point 10.6
                addi r1, 2
                ldm r3, r1                  ; Y
                shl r3, 6                   ; To fixed point 10.6
                addi r1, 2
                ldm r4, r1                  ; Z
                addi r1, 2
                ldm r5, r1                  ; Z-speed
                subi r1, 2
                sub r4, r5                  ; Move Z
                stm r4, r1                  ; Store Z for next time
.sub_advstarL:  jg .sub_advstarD
.sub_advstarM:  call sub_rndstar            ; Star moved past us, replace it
                jmp sub_advstar
.sub_advstarD:  div r2, r4, ra
                muli ra, 100
                sar ra, 6                   ; From fixed point 10.6
                addi ra, 160
                div r3, r4, rb
                muli rb, 100
                sar rb, 6                   ; From fixed point 10.6
                addi rb, 120
                div r4, rf, rc              ; Normalize Z to [0..15]
                addi rc, d_spr              ; so we can index in palette
                cmpi ra, 319
                jg .sub_advstarM
                cmpi ra, 0
                jl .sub_advstarM
                cmpi rb, 239
                jg .sub_advstarM
                cmpi rb, 0
                jl .sub_advstarM
.sub_advstarZ:  drw ra, rb, rc              ; Draw star pixel!
                ret
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; 2x1 sprites but effectively 1x1 due to transparent right pixel
d_spr:          db 0xf0
                db 0xe0
                db 0xd0
                db 0xc0
                db 0xb0
                db 0xa0
                db 0x90
                db 0x80
                db 0x70
                db 0x60
                db 0x50
                db 0x40
                db 0x30
                db 0x20
                db 0x10
                db 0x00

; A progressive monochrome palette, with an accelerating ramp-up to white.
d_pal:          db 0x00,0x00,0x00
                db 0x04,0x04,0x04
                db 0x0c,0x0c,0x0c
                db 0x1c,0x1c,0x1c
                db 0x2c,0x2c,0x2c
                db 0x38,0x38,0x38
                db 0x4c,0x4c,0x4c
                db 0x58,0x58,0x58
                db 0x6c,0x6c,0x6c
                db 0x6c,0x6c,0x6c
                db 0x80,0x80,0x80
                db 0x9c,0x9c,0x9c
                db 0xb8,0xb8,0xb8
                db 0xc8,0xc8,0xc8
                db 0xe4,0xe4,0xe4
                db 0xff,0xff,0xff
