|||||||||||||||||||||||||||||||||||||||||||||
||
|| megacolor.s
||
|| 2020/07/01
||
|| ivan
||
|||||||||||||||||||||||||||||||||||||||||||||
.set BUFF_0, 0x00000
.set BUFF_1, 0x10000
|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||| disk read
|non blocked version of ed_cmd_file_read_mem
.macro  ed_file_read dst, len

        move.w  #0x2b, (%a5) |cmd (CMD_F_FRD_MEM)
        move.w  #0xd4, (%a5)
        move.w  #0xcb, (%a5)
        move.w  #0x34, (%a5)

        move.w  #((\dst >> 24) & 0xff), (%a5)
        move.w  #((\dst >> 16) & 0xff), (%a5)
        move.w  #((\dst >> 8) & 0xff),  (%a5)
        move.w  #((\dst >> 0) & 0xff),  (%a5)

        move.w  #((\len >> 24) & 0xff), (%a5)
        move.w  #((\len >> 16) & 0xff), (%a5)
        move.w  #((\len >> 8) & 0xff),  (%a5)
        move.w  #((\len >> 0) & 0xff),  (%a5)

        move.w  #0x00, (%a5) |run transfer from disk

        move.w  #0x02, (%a6)
.endm
|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||| delays
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
|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||| sync
.macro  buff_init   addr
    move.w \addr, %d6
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
        |nop
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
        nop4
        nop
        nop
        nop
        nop6c
        |nop
.endm
|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||| dma
.macro dma_inc_len inc, len
    move.l #0x8f009300 + ((\inc << 16) & 0xff0000) + ((\len >> 1) & 0xff), (%a3)
.endm

.macro dma_len_src len, src
    move.l #0x94009500 + ((\len << 7) & 0xff0000) + ((\src >> 1) & 0xff), (%a3)
.endm

.macro dma_src_src src
    move.l #0x96009700 + ((\src << 7) & 0xff0000) + ((\src >> 17) & 0xff), (%a3)
.endm

.macro dma_dst_vram dst
    move.l #((0x4000 + ((\dst) & 0x3FFF)) << 16) + (((\dst) >> 14) + 0x80), (%a3)
.endm
|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||| vram dma
.macro  dma_vram_int src, dst, len
    dma_inc_len     2,    \len  | ainc, len >> 1
    dma_len_src     \len, \src  | len >> 9, src >> 1
    dma_src_src     \src        | src >> 9, src >> 17
    dma_dst_vram    \dst        | dst    
.endm

.macro  dma_vram src, dst, len
   dma_vram_int (\src + 2), \dst, \len  | plus 2 for dma buffering
.endm
|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||| cram dma
.macro crm_dst_a
    move.l  %d3, (%a3) | fire DMA
.endm

.macro crm_dst_b
    move.l  %d4, (%a3) | fire DMA
.endm

.macro  crm_dma64 src, dst
    move.w  %d5, (%a3)  | setup DMA
    dma_len_src 0,    \src
    dma_src_src \src
    move.w  %d1, (%a3)  | turn off screen
    \dst
    move.w  %d2, (%a3)  | turn on screen
    post_delay
    buff_init \src+0x3E | read last paletter word for linear reading
.endm

.macro crm_dma512 src
    crm_dma64 (\src+0x000), crm_dst_b
    crm_dma64 (\src+0x040), crm_dst_a
    crm_dma64 (\src+0x080), crm_dst_b
    crm_dma64 (\src+0x0C0), crm_dst_a
    crm_dma64 (\src+0x100), crm_dst_b
    crm_dma64 (\src+0x140), crm_dst_a
    crm_dma64 (\src+0x180), crm_dst_b
    crm_dma64 (\src+0x1C0), crm_dst_a
.endm

.macro crm_dma512_8x src
    crm_dma512 (\src + 0x0000)
    crm_dma512 (\src + 0x0200)
    crm_dma512 (\src + 0x0400)
    crm_dma512 (\src + 0x0600)

    crm_dma512 (\src + 0x0800)
    crm_dma512 (\src + 0x0A00)
    crm_dma512 (\src + 0x0C00)
    crm_dma512 (\src + 0x0E00)
.endm

.macro dma_cram_int src
    crm_dma512_8x (\src + 0x0000)
    crm_dma512_8x (\src + 0x1000)
    crm_dma512_8x (\src + 0x2000)
    nop16
.endm

.macro dma_cram src
   dma_cram_int (\src+2)    | plus 2 for dma buffering
.endm

||||||||||||||||||||||||||||||||||||||||||||

    .global megacolor_play
megacolor_play:
    movem.l %d0-%d7/%a0-%a7,-(%sp)    
    moveq   #0, %d0
    lea     0xc00000, %a2
    lea     0xc00004, %a3
    lea     0xc00008, %a4
    lea     0xa130d0, %a5
    lea     0xa130d4, %a6
    move.w  #0x8004, (%a3) | disable horizontal interrupt
    move.w  #0x8154, (%a3) | turn on the screen
    move.l  #0x40000000, (%a3) | set write to VRAM 0

    move.w  #0x8114, %d1 | not original
    move.w  #0x8154, %d2 | not original
    move.l  #0xc0020080, %d3 | not original
    move.l  #0xc0420080, %d4 | not original
    move.w  #0x931F, %d5

    move.w  #0x8f02, (%a3) | original
main_loop:
||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
    btst.b  #0, pb_pause
    bne     skip_rd1
    ed_file_read    (0x1F80000 + BUFF_1), 46328
skip_rd1:
    buff_init       (0x200200 + BUFF_0)
    vdp_sync

    dma_cram        (0x200200 + BUFF_0)
    
    buff_init       (0x203200 + BUFF_1)
    move.w  %d1, (%a3)          | screen off
    dma_vram        (0x203200 + BUFF_1), 0x9000, 13824
    move.w  #0x8200, (%a3)      | plan-a addr
    move.w  #0x8400, (%a3)      | plan-b addr
    move.w  %d2, (%a3)          | screen on

||||||||||||||||||||||||||||||||||||||||||||||||
    buff_init       (0x200200 + BUFF_0)
    vdp_sync

    dma_cram        (0x200200 + BUFF_0)
    
    buff_init       (0x206800 + BUFF_1)
    move.w  %d1, (%a3)          | screen off
    dma_vram        (0x206800 + BUFF_1), 0xC600, 13824
    move.w  #0x8220, (%a3)      | plan-a addr
    move.w  #0x8404, (%a3)      | plan-b addr
    move.w  %d2, (%a3)          | screen on

||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
    btst.b  #0, pb_pause
    bne     skip_rd0
    ed_file_read    (0x1F80000 + BUFF_0), 46328
skip_rd0:
    buff_init       (0x200200 + BUFF_1)
    vdp_sync
    
    dma_cram        (0x200200 + BUFF_1)
    
    buff_init       (0x203200 + BUFF_0)
    move.w  %d1, (%a3)          | screen off
    dma_vram        (0x203200 + BUFF_0), 0x1000, 13824
    move.w  #0x8220, (%a3)      | plan-a addr
    move.w  #0x8404, (%a3)      | plan-b addr
    move.w  %d2, (%a3)          | screen on

||||||||||||||||||||||||||||||||||||||||||||||||
    buff_init       (0x200200 + BUFF_1)
    vdp_sync

    dma_cram        (0x200200 + BUFF_1)
    
    buff_init       (0x206800 + BUFF_0)
    move.w  %d1, (%a3)          | screen off
    dma_vram        (0x206800 + BUFF_0), 0x4600, 13824
    move.w  #0x8200, (%a3)      | plan-a addr
    move.w  #0x8400, (%a3)      | plan-b addr
    move.w  %d2, (%a3)          | screen on
    
||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
    btst.b  #0, pb_pause
    bne     skip_len_ctr
    sub.l   #1, pb_size
    beq     stop
skip_len_ctr:
    move.b  #0x00, 0xa10003
    nop
    move.b  0xa10003, %d7
    move.b  #0x40, 0xa10003
    nop
    btst.b  #4, 0xa10003    | B state
    beq     stop

    cmp.b   pb_joy, %d7
    bne     ctrl 
    jmp     main_loop

ctrl:
    move.b  %d7, pb_joy
    btst.b  #4, %d7
    beq     pause_invert
    jmp     main_loop

pause_invert:
    eor.b   #1, pb_pause
    jmp     main_loop

stop:
    movem.l (%sp)+,%d0-%d7/%a0-%a7
    rts
        


