|||||||||||||||||||||||||||||||||||||||||||||
||
|| megacolor.s
||
|| 2020/07/01
||
|| ivan
||
|||||||||||||||||||||||||||||||||||||||||||||

.macro  nop2
        nop
        nop
.endm

.macro  nop4
        nop2
        nop2
.endm

.macro  nop8
        nop4
        nop4
.endm

.macro  nop16
        nop8
        nop8
.endm

.macro  nop32
        nop16
        nop16
.endm

.macro  nop6c
        exg     %d0, %d0
.endm

.macro  post_delay
        move.w  %d0, (%a2)
        move.w  %d0, (%a2)
        move.w  %d0, (%a2)
        move.w  %d0, (%a2)
        move.w  %d0, (%a2)
        move.w  %d0, (%a2)
        move.w  %d0, (%a2)
        move.w  %d0, (%a2)
        move.w  %d0, (%a2)
        move.w  %d0, (%a2)
        move.w  %d0, (%a2)
        move.w  %d0, (%a2)
        move.w  %d0, (%a2)
        move.w  %d0, (%a2)
        move.w  %d0, (%a2)
        move.w  %d0, (%a2)
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop6c
.endm

.macro  crmdma0 adr0, adr1
        move.w  %d5, (%a3) | setup DMA
        move.l  \adr0, (%a3)
        move.l  \adr1, (%a3)

        move.w  %d1, (%a3) | turn off screen
        move.l  %d3, (%a3) | fire DMA
        move.w  %d2, (%a3) | turn on screen

        post_delay
.endm

.macro  crmdmb0 adr0, adr1
        move.w  %d5, (%a3) | setup DMA
        move.l  \adr0, (%a3)
        move.l  \adr1, (%a3)

        move.w  %d1, (%a3) | turn off screen
        move.l  %d4, (%a3) | fire DMA
        move.w  %d2, (%a3) | turn on screen

        post_delay
.endm

.macro  crmdma1 adr0
        crmdmb0 #0x94009500, \adr0
        crmdma0 #0x94009520, \adr0
        crmdmb0 #0x94009540, \adr0
        crmdma0 #0x94009560, \adr0
        crmdmb0 #0x94009580, \adr0
        crmdma0 #0x940095a0, \adr0
        crmdmb0 #0x940095c0, \adr0
        crmdma0 #0x940095e0, \adr0
.endm

.macro  vdp_sync
1:
        cmp.w   #0xf00, (%a4)
        ble.b   1b

        move.w  %d0, (%a2)
        move.w  %d0, (%a2)
        move.w  %d0, (%a2)
        move.w  %d0, (%a2)

        move.w  %d0, (%a2)
        move.w  %d0, (%a2)
        move.w  %d0, (%a2)
        move.w  %d0, (%a2)

        move.w  %d0, (%a2)
        move.w  %d0, (%a2)
        move.w  %d0, (%a2)
        move.w  %d0, (%a2)

        move.w  %d0, (%a2)
        move.w  %d0, (%a2)
        move.w  %d0, (%a2)
        move.w  %d0, (%a2)

        move.w  %d0, (%a2)
        move.w  %d0, (%a2)

        nop
        nop
        nop6c
.endm

.macro  crm_dma_frm_0
        crmdma1 #0x96019710
        crmdma1 #0x96029710
        crmdma1 #0x96039710
        crmdma1 #0x96049710
        crmdma1 #0x96059710
        crmdma1 #0x96069710
        crmdma1 #0x96079710
        crmdma1 #0x96089710
        crmdma1 #0x96099710
        crmdma1 #0x960a9710
        crmdma1 #0x960b9710
        crmdma1 #0x960c9710
        crmdma1 #0x960d9710
        crmdma1 #0x960e9710
        crmdma1 #0x960f9710
        crmdma1 #0x96109710
        crmdma1 #0x96119710
        crmdma1 #0x96129710
        crmdma1 #0x96139710
        crmdma1 #0x96149710
        crmdma1 #0x96159710
        crmdma1 #0x96169710
        crmdma1 #0x96179710
        crmdma1 #0x96189710
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
.endm

.macro  crm_dma_frm_1
        crmdma1 #0x96819710
        crmdma1 #0x96829710
        crmdma1 #0x96839710
        crmdma1 #0x96849710
        crmdma1 #0x96859710
        crmdma1 #0x96869710
        crmdma1 #0x96879710
        crmdma1 #0x96889710
        crmdma1 #0x96899710
        crmdma1 #0x968a9710
        crmdma1 #0x968b9710
        crmdma1 #0x968c9710
        crmdma1 #0x968d9710
        crmdma1 #0x968e9710
        crmdma1 #0x968f9710
        crmdma1 #0x96909710
        crmdma1 #0x96919710
        crmdma1 #0x96929710
        crmdma1 #0x96939710
        crmdma1 #0x96949710
        crmdma1 #0x96959710
        crmdma1 #0x96969710
        crmdma1 #0x96979710
        crmdma1 #0x96989710
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
.endm

.macro  rd_frm_0
        move.w  #0x2b, (%a5)
        move.w  #0xd4, (%a5)
        move.w  #0xcb, (%a5)
        move.w  #0x34, (%a5)

        move.w  #0x01, (%a5)
        move.w  #0xf8, (%a5)
        move.w  #0x00, (%a5)
        move.w  #0x00, (%a5)

        move.w  #0x00, (%a5)
        move.w  #0x00, (%a5)
        move.w  #0xb4, (%a5)
        move.w  #0xf8, (%a5)

        move.w  #0x00, (%a5)
        move.w  #0x02, (%a6)
.endm

.macro  rd_frm_1
        move.w  #0x2b, (%a5)
        move.w  #0xd4, (%a5)
        move.w  #0xcb, (%a5)
        move.w  #0x34, (%a5)

        move.w  #0x01, (%a5)
        move.w  #0xf9, (%a5)
        move.w  #0x00, (%a5)
        move.w  #0x00, (%a5)

        move.w  #0x00, (%a5)
        move.w  #0x00, (%a5)
        move.w  #0xb4, (%a5)
        move.w  #0xf8, (%a5)

        move.w  #0x00, (%a5)
        move.w  #0x02, (%a6)
.endm

.macro skip_frame
2:
        btst    #3, 1(%a3)
        beq.b   2b | wait for VB
3:
        btst    #3, 1(%a3)
        bne.b   3b | wait for not VB
.endm

.macro  skp_prt_frm
1:
        move.w (%a4), %d6
        lsr.w   #8, %d6
        cmp.w   #180, %d6
        bne.s   1b
.endm


||||||||||||||||||||||||||||||||||||||||||||

    .global megacolor_play
megacolor_play:
    movem.l %d0-%d7/%a0-%a7,-(%sp)    
    moveq	#0, %d0
    lea		0xc00000, %a2
    lea		0xc00004, %a3
    lea		0xc00008, %a4
    lea     0xa130d0, %a5
    lea     0xa130d4, %a6
    move.w	#0x8004, (%a3) | disable horizontal interrupt
    move.w  #0x8154, (%a3) | turn on the screen
    move.l  #0x40000000, (%a3) | set write to VRAM 0

    move.w	#0x8114, %d1 | not original
    move.w	#0x8154, %d2 | not original
    move.l	#0xc0020080, %d3 | not original
    move.l	#0xc0420080, %d4 | not original
    move.w	#0x931f, %d5

    move.w	#0x8f02, (%a3) | original

main_loop:

|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
    btst.b  #0, pb_pause
    bne     pause0
    rd_frm_1    | non blocked version of bi_cmd_file_read_mem. read to buff1
pause0:
    vdp_sync
    crm_dma_frm_0

    move.w  %d1, (%a3)
    move.l  #0x8f029300, (%a3)
    move.l  #0x941b9500, (%a3)
    move.l  #0x96999710, (%a3)
    move.l  #0x50000082, (%a3)
    move.w  #0x8200, (%a3)
    move.w  #0x8400, (%a3)
    move.w  %d2, (%a3)

||||||||||||||||||||||||||||||||||||||||||||||||

    vdp_sync
    crm_dma_frm_0

    move.w  %d1, (%a3)
    move.l  #0x8f029300, (%a3)
    move.l  #0x941b9500, (%a3)
    move.l  #0x96b49710, (%a3)
    move.l  #0x46000083, (%a3)
    move.w  #0x8220, (%a3)
    move.w  #0x8404, (%a3)
    move.w  %d2, (%a3)

|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
    btst.b  #0, pb_pause
    bne     pause1
    rd_frm_0    | non blocked version of bi_cmd_file_read_mem. read to buff0
pause1:
    vdp_sync
    crm_dma_frm_1

    move.w  %d1, (%a3)
    move.l  #0x8f029300, (%a3)
    move.l  #0x941b9500, (%a3)
    move.l  #0x96199710, (%a3)
    move.l  #0x50000080, (%a3)
    move.w  #0x8220, (%a3)
    move.w  #0x8404, (%a3)
    move.w  %d2, (%a3)

||||||||||||||||||||||||||||||||||||||||||||||||

    vdp_sync
    crm_dma_frm_1

    move.w  %d1, (%a3)
    move.l  #0x8f029300, (%a3)
    move.l  #0x941b9500, (%a3)
    move.l  #0x96349710, (%a3)
    move.l  #0x46000081, (%a3)
    move.w  #0x8200, (%a3)
    move.w  #0x8400, (%a3)
    move.w  %d2, (%a3)

|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
    btst.b  #0, pb_pause
    bne     pause3
    sub.l   #1, pb_size
    beq     stop
pause3:

    move.b  0xa10003, %d7  
    cmp.b   pb_joy, %d7
    bne     ctrl 

    jmp     main_loop

ctrl:
    move.b  %d7, pb_joy
    btst.b  #4, %d7
    beq     pause
    btst.b  #5, %d7
    beq     stop
    jmp     main_loop

pause:
    eor.b   #1, pb_pause
    jmp     main_loop

stop:
    movem.l (%sp)+,%d0-%d7/%a0-%a7
    rts
        


