.text
    .org	0x0000

    .long   0,   RST, BER, AER, IER, INT, INT, INT
    .long   INT, INT, INT, INT, INT, INT, INT, INT
    .long   INT, INT, INT, INT, INT, INT, INT, INT
    .long   INT, INT, INT, INT, HBL, INT, VBL, INT
    .long   INT, INT, INT, INT, INT, INT, INT, INT
    .long   INT, INT, INT, INT, INT, INT, INT, INT
    .long   INT, INT, INT, INT, INT, INT, INT, INT
    .long   INT, INT, INT, INT, INT, INT, INT, INT

    .ascii  "SEGA EVERDRIVE99"      | SEGA must be the first four chars for TMSS
    .ascii  "(C)2020.AUG     "
    .ascii  "MEGAVIDEOPLAYER "      | export name
    .ascii  "                "
    .ascii  "                "
    .ascii  "MEGAVIDEOPLAYER "      | domestic (Japanese) name
    .ascii  "                "
    .ascii  "                "
    .ascii  "GM MK-0000 -00"
    .word   0x0000                  | checksum - not needed
    .ascii  "J6              "
    .long   0x00000000, 0x0007ffff   | ROM start, end
    .long   0x00ff0000, 0x00ffffff   | RAM start, end
    .ascii  "            "           | no SRAM
    .ascii  "    "
    .ascii  "        "
    .ascii  "        "               | memo
    .ascii  "                "
    .ascii  "                "
    .ascii  "F               "       | enable any hardware configuration


RST:
    move.w  #0x2700, %sr            
    tst.l   0xa10008                | check CTRL1 and CTRL2 setup
    bne.b   1f
    tst.w   0xa1000c                | check CTRL3 setup
1:
    bne.b   skip_tmss               | if any controller control port is setup, skip TMSS handling
    move.b  0xa10001, %d0
    andi.b  #0x0f, %d0              | check hardware version
    beq.b   skip_tmss               | 0 = original hardware, TMSS not present
    move.l  #0x53454741, 0xa14000   | Store Sega Security Code "SEGA" to TMSS
skip_tmss:
    lea     0, %sp

| clear the RAM
    lea     0x00ff0000, %a0
    move.w  #4096-1, %d0
    move.l  #0, %d1
1:
    move.l  %d1, (%a0)+
    move.l  %d1, (%a0)+
    move.l  %d1, (%a0)+
    move.l  %d1, (%a0)+
    dbra    %d0, 1b

|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
    lea     0xc00008, %a4 | the default global VDP hvcounter port
    lea     0xc00004, %a5 | the default global VDP ctrl port
    lea     0xc00000, %a6 | the default global VDP data port

    move.w  #0x8104, (%a5)  | disable display to speed up vdp transfers
    move.w  #0x8f02, (%a5)

| clear cram
    move.l  #0xc0000000, (%a5)
    move.w  #0x40-1, %d0
    moveq   #0, %d1
1:
    move.w  %d1, (%a6)
    dbra    %d0, 1b

| clear vram
    move.l  #0x40000000, (%a5)
    move.w  #0x2000-1, %d0
    moveq   #0, %d1
1:
    move.w  %d1, (%a6)
    move.w  %d1, (%a6)
    move.w  %d1, (%a6)
    move.w  %d1, (%a6)
    dbra    %d0, 1b

| clear vsram
    move.l  #0x40000010, (%a5)
    move.w  #0x50-1, %d0
    moveq   #0, %d1
1:
    move.w  %d1, (%a6)
    dbra    %d0, 1b

| default vdp reg values
    move.w  #0x8004, (%a5)

    move.w  #0x8154, (%a5) | display enabled | dma disabled | vblank disabled | ntsc
    move.w  #0x8200, (%a5)
    move.w  #0x8300, (%a5)
    move.w  #0x8400, (%a5)
    move.w  #0x855e, (%a5)
    move.w  #0x8600, (%a5)
    move.w  #0x8700, (%a5)
    move.w  #0x8800, (%a5)
    move.w  #0x8900, (%a5)
    move.w  #0x8a00, (%a5)
    move.w  #0x8b00, (%a5)
    move.w  #0x8c81, (%a5)
    move.w  #0x8d00, (%a5)
    move.w  #0x8e00, (%a5)
    move.w  #0x8f02, (%a5)
    move.w  #0x9011, (%a5)
    move.w  #0x9100, (%a5)
    move.w  #0x9200, (%a5)

    jmp     main


VBL:
HBL:
INT:
    rte

BER:
    move.l  #0xc0000000, 0xc00004
    move.w  #0x00e, 0xc00000
    rte

AER:
    move.l  #0xc0000000, 0xc00004
    move.w  #0x0ee, 0xc00000
    rte

IER:
    move.l  #0xc0000000, 0xc00004
    move.w  #0x0e0, 0xc00000
    rte

.include "megacolor.s"


.global tile_map_0_36x24
.global tile_map_1_36x24
.global font_base
.global bg_rgb
.global bg_pal

tile_map_0_36x24:
.incbin "res/tile_map_0_36x24.dat"

tile_map_1_36x24:
.incbin "res/tile_map_1_36x24.dat"
    
font_base:
.incbin "res/font.dat"

bg_rgb:
.incbin "res/bg-rgb.bin"

bg_pal:
.incbin "res/bg-pal.bin"
