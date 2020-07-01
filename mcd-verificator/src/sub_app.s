
.set cflag_mc,  0x800E
.set cflag_sc,  0x800F

.set com_cmd,  0x8010
.set com_sta,  0x8020

.set cdd_cnt,  0x8036
.set cdd_sta,  0x8038
.set cdd_cmd,  0x8042

.set _CDBIOS,   0x5F22

.set MSCSTOP,   0x0002 
.set ROMPAUSEON,0x0008 
.set DRVINIT,   0x0010
.set MSCPLAY1,  0x0012 
.set ROMREAD,   0x0017 
.set ROMREADN,  0x0020
.set CDCSTART,  0x0087
.set CDCSTOP,   0x0089
.set CDCSTAT,   0x008A 
.set CDCREAD,   0x008B 
.set CDCACK,    0x008D 
.set SCDSTOP,   0x0090 
.set LEDSET,    0x0095


       .text
Sub_Start:

| Standard MegaCD Sub-CPU Program Header (copied to 0x6000)

SPHeader:
        .asciz  "MAIN-SUBCPU"
        .word   0x0001,0x0000
        .long   0x00000000
        .long   0x00000000
        .long   SPHeaderOffsets-SPHeader
        .long   0x00000000

SPHeaderOffsets:
        .word   SPInit-SPHeaderOffsets
        .word   SPMain-SPHeaderOffsets
        .word   SPInt2-SPHeaderOffsets
        .word   SPNull-SPHeaderOffsets
        .word   0x0000

.org 0x80
SPInit:
    move.b  #'I,0x800F.w            /* sub comm port = INITIALIZING */
    andi.b  #0xE2,0x8003.w          /* Priority Mode = off, 2M mode, Sub-CPU has access */
    rts


SPMain:
    lea     drive_init_parms(%pc),%a0
    move.w  #DRVINIT,%d0
    jsr     _CDBIOS.w
    move.b  #0x00, cflag_sc.w   /*clean busy flag*/
    jmp     wait_cmd
/*----------------------------------------------------------------------------*/
.org 0x100
     move.b  #0x00, cflag_sc.w
wait_cmd:
    
    move.b  cflag_mc.w, %d0
    cmp.b   #0x00, %d0
    beq     wait_cmd
    move.b  #0x01, cflag_sc.w   /*set busy flag*/
    
    cmp.b   #'P', %d0
    beq     msc_play
    
    cmp.b   #'S', %d0
    beq     msc_stop

    cmp.b   #'O', %d0
    beq     rom_rd_open

    cmp.b   #'N', %d0
    beq     rom_rd_next

    cmp.b   #'C', %d0
    beq     rom_rd_close


    bra     ack
/*----------------------------------------------------------------------------*/ 


/*----------------------------------------------------------------------------*/  
msc_play:   /*mpay music cd*/
    move.w  #MSCSTOP, %d0    /* MSCSTOP - stop playing */
    jsr     _CDBIOS.w

    lea.l   msc_table(%pc), %a0
    move.w  #MSCPLAY1, %d0   /* MSCPLAY1 - play once */
    jsr     _CDBIOS.w 
    bra     ack
/*----------------------------------------------------------------------------*/
msc_stop:
    move.w  #MSCSTOP, %d0    /* MSCSTOP - stop playing */
    jsr     _CDBIOS.w
    bra     ack
/*----------------------------------------------------------------------------*/
rom_rd_open:
    move.b  #0x02, 0x8004.w

    move.w  #CDCSTOP, %d0
    jsr     _CDBIOS.w

    lea.l   rom_table(%pc), %a0
    move.w  #ROMREAD, %d0
    jsr     _CDBIOS.w

    bra     ack
/*----------------------------------------------------------------------------*/
rom_rd_next:

    move.w  #CDCREAD, %d0
    jsr     _CDBIOS.w
    bcs.b   rom_rd_next     /* not ready to xfer data */

    move.w  #CDCACK, %d0
    jsr     _CDBIOS.w

    bra     ack
/*----------------------------------------------------------------------------*/
rom_rd_close:
    move.w  #ROMPAUSEON, %d0
    jsr     _CDBIOS.w

    move.w  #CDCSTOP, %d0
    jsr     _CDBIOS.w
    
    lea     0x8100.w, %a0
    lea     com_sta.w, %a1
    move.w  #7, %d0
1:
    move.w  (%a0)+, (%a1)+
    dbra    %d0, 1b

    bra     ack
/*----------------------------------------------------------------------------*/
ack:
    cmp.b   #0x00, cflag_mc.w 
    bne     ack
    move.b  #0x00, cflag_sc.w
    bra     wait_cmd

SPInt2:
        rts
| Sub-CPU program Reserved Function
SPNull:
        rts

.align  2
msc_table:
    .word 7

drive_init_parms:
    .byte   0x01, 0xFF              /* first track (1), last track (all) */

rom_table:
    .long 0 /*start sector*/
    .long 7 /*number of sectors*/


