
.text
	.org	0x0000

	dc.l	0,RST
	dc.l	INT,INT,INT,INT,INT,INT,INT
	dc.l	INT,INT,INT,INT,INT,INT,INT,INT
	dc.l	INT,INT,INT,INT,INT,INT,INT,INT
	dc.l	IE1,IE2,IE3,IE4,IE5,IE6
        dc.l    INT,INT
	dc.l	INT,INT,INT,INT,INT,INT,INT,INT
	dc.l	INT,INT,INT,INT,INT,INT,INT,INT
	dc.l	INT,INT,INT,INT,INT,INT,INT,INT
	dc.l	INT,INT,INT,INT,INT,INT,INT

        /* "SEGA EVERDRIVE" it is mark for OS. access for everdrive registers will be stay unlocked if this mark will be detected by OS*/
	.ascii	"SEGA MEGADRIVE  "				    /* Console Name (16) 1 or nothing=ROM, 2=ROM+DATAFILE, 3=RAM*/
	.ascii	"KRIKzz 2019.SEP "				    /* Copyright Information (16) */
	.ascii	"MEGA-CD-TEST                                    "  /* Domestic Name (48) */
	.ascii	"MEGA-CD-TEST                                    "  /* Overseas Name (48) */
	.ascii	"GM 00000000-00"				    /* Serial Number (2, 14) */
	dc.w	0x0000						    /* Checksum (2) */
	.ascii	"JD              "				    /* I/O Support (16) */
	dc.l	0xffffffff 					    /* ROM Start Address (4) */
	dc.l	0x20000 					    /* ROM End Address (4) */
	dc.l	0x00FF0000					    /* Start of Backup RAM (4) */
	dc.l	0x00FFFFFF					    /* End of Backup RAM (4) */
	.ascii	"B                       "                          
        .ascii	"http://krikzz.com                       "	    /* Memo (40) */
	.ascii	"W               "				    /* Country Support (16) */
.org 0x202

.set CFLAG_MC,   0x800E
.set CFLAG_SC,   0x800F

.set CMD_IDX,    0x8010
.set CMD_DAT,    0x8012
.set CMD_ADR,    0x8014
.set CMD_ADR_S,  0x8014
.set CMD_ADR_D,  0x8018

.set STA_BSY,    0x8020
.set STA_RET,    0x8022
.set STA_IRQ,    0x8026
.set STA_ICTR2,  0x8028
.set STA_ICTR3,  0x802A

.set CMD_NOP,   0
.set CMD_RD_B,  1
.set CMD_WR_B,  2
.set CMD_RD_W,  3
.set CMD_WR_W,  4
.set CMD_DELAY, 5
.set CMD_RDRND, 6
.set CMD_RDSEC, 7
.set CMD_CPY,   8


RST:
    move.l  #0x70000, %a7
    move    #0x2000, %sr

cmd_rx:
    move.w  #0, STA_IRQ.w
    cmp.w   #CMD_NOP, CMD_IDX.w
    bne     cmd_rx
    move.w  #CMD_NOP, STA_BSY.w
1:
    cmp.w   #CMD_NOP, CMD_IDX.w
    beq     1b
    move.w  CMD_IDX.w, STA_BSY.w

    cmp     #CMD_RD_B, STA_BSY.w
    beq     rd_b

    cmp     #CMD_WR_B, STA_BSY.w
    beq     wr_b

    cmp     #CMD_RD_W, STA_BSY.w
    beq     rd_w
    
    cmp     #CMD_WR_W, STA_BSY.w
    beq     wr_w

    cmp     #CMD_DELAY, STA_BSY.w
    beq     delay

    cmp     #CMD_RDRND, STA_BSY.w
    beq     read_and_render

    cmp     #CMD_RDSEC, STA_BSY.w
    beq     read_sector

    cmp     #CMD_CPY, STA_BSY.w
    beq     mem_cpy

    bra     cmd_rx


rd_b:
    move.l  CMD_ADR.w, %a0
    move.b  (%a0), STA_RET.w
    bra     cmd_rx

wr_b:
    move.l  CMD_ADR.w, %a0
    move.b  CMD_DAT.w, (%a0)
    bra     cmd_rx

rd_w:
    move.l  CMD_ADR.w, %a0
    move.w  (%a0), STA_RET.w
    bra     cmd_rx

wr_w:
    move.l  CMD_ADR.w, %a0
    move.w  CMD_DAT.w, (%a0)
    bra     cmd_rx

delay:
    move.l  CMD_ADR.w, %a0
    move.w  #0xffff, %d0
1:
    move.w  (%a0), %d1
    dbra    %d0, 1b
    bra     cmd_rx

read_and_render:
    move.l  CMD_ADR.w, %a0
    move.w  #256, %d0
    move.w  CMD_DAT.w, 0x8066.w
1:
    MOVEM.L (%a0),%d1-%d7
    MOVEM.L (%a0),%d1-%d7
    MOVEM.L (%a0),%d1-%d7
    MOVEM.L (%a0),%d1-%d7
    dbra    %d0, 1b
    bra     cmd_rx

read_sector:
    move.l  #0xff8008, %a0
    move.l  CMD_ADR.w, %a1
    move.w  #2352/8-1, %d0
1:
    MOVE.w (%a0),%d1
    MOVE.w (%a0),%d2
    MOVE.w (%a0),%d3
    MOVE.w (%a0),%d4

    MOVE.w %d1,(%a1)+
    MOVE.w %d2,(%a1)+
    MOVE.w %d3,(%a1)+
    MOVE.w %d4,(%a1)+
    dbra    %d0, 1b
    bra     cmd_rx

mem_cpy:
    move.l  CMD_ADR_S.w, %a0 
    move.l  CMD_ADR_D.w, %a1
    move.w  CMD_DAT.w, %d0
    sub.w   #1, %d0
1:
    move.b  (%a0)+, (%a1)+
    dbra    %d0, 1b
    bra     cmd_rx

IE1:
    move.w  #1, STA_IRQ.w
    rte
IE2:
    move.w  #2, STA_IRQ.w
    add.w   #1, STA_ICTR2.w
    rte
IE3:
    move.w  #3, STA_IRQ.w
    add.w   #1, STA_ICTR3.w
    rte
IE4:
    btst    #1, 0x8037.w
    bne     IE4

    move.w  0x8038.w, 0x01F0
    move.w  0x803A.w, 0x01F2
    move.w  0x803C.w, 0x01F4
    move.w  0x803E.w, 0x01F6
    move.w  0x8040.w, 0x01F8
    move.w  #4, STA_IRQ.w
    rte

IE5:
    move.w  #5, STA_IRQ.w
    rte
IE6:
    move.w  #6, STA_IRQ.w
    rte
INT:
    move.w  #255, STA_IRQ.w
    rte
    

