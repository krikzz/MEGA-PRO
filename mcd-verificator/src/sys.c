
#include "sys.h"






#define GFX_DATA_PORT           0xC00000
#define GFX_CTRL_PORT           0xC00004
#define GFX_DATA_PORT16 *((volatile u16 *)GFX_DATA_PORT)
#define GFX_DATA_PORT32 *((volatile u32 *)GFX_DATA_PORT)
#define GFX_CTRL_PORT16 *((volatile u16 *)GFX_CTRL_PORT)
#define GFX_CTRL_PORT32 *((volatile u32 *)GFX_CTRL_PORT)

#define GFX_WRITE_VRAM_ADDR(adr)    ((0x4000 + ((adr) & 0x3FFF)) << 16) + (((adr) >> 14) | 0x00)
#define GFX_READ_VRAM_ADDR(adr)     ((0x0000 + ((adr) & 0x3FFF)) << 16) + (((adr) >> 14) | 0x00)
#define GFX_WRITE_CRAM_ADDR(adr)    ((0xC000 + ((adr) & 0x3FFF)) << 16) + (((adr) >> 14) | 0x00)
#define GFX_WRITE_VSRAM_ADDR(adr)   ((0x4000 + ((adr) & 0x3FFF)) << 16) + (((adr) >> 14) | 0x10)

#define GFX_DMA_VRAM_ADDR(adr)      ((0x4000 + ((adr) & 0x3FFF)) << 16) + (((adr) >> 14) | 0x80)
#define GFX_DMA_CRAM_ADDR(adr)      ((0xC000 + ((adr) & 0x3FFF)) << 16) + (((adr) >> 14) | 0x80)
#define GFX_DMA_VSRAM_ADDR(adr)     ((0x4000 + ((adr) & 0x3FFF)) << 16) + (((adr) >> 14) | 0x90)

#define GETVDPSTATUS(flag)          ((*(volatile u16*)(GFX_CTRL_PORT)) & (flag))
#define VDP_DMABUSY_FLAG        (1 << 1)

#define VDP_VBLANK_FLAG (1 << 3)

#define Z80_HALT_PORT       0xA11100
#define Z80_RESET_PORT      0xA11200

#define Z80_RAM             0xA00000
#define Z80_YM2612          0xA04000
#define Z80_BANK_REGISTER   0xA06000
#define Z80_PSG             0xA07F11

#define Z80_BUSREQ_ON *((volatile u16 *) Z80_HALT_PORT) = 0x0100
#define Z80_BUSREQ_OFF *((volatile u16 *) Z80_HALT_PORT) = 0x0000
#define Z80_IS_BUSREQ_OFF (*((volatile u16 *) Z80_HALT_PORT) & 0x0100)

#define Z80_RESET_ON *((volatile u16 *) Z80_RESET_PORT) = 0
#define Z80_RESET_OFF *((volatile u16 *) Z80_RESET_PORT) = 0x0100


void vdpVramWrite(u16 *src, u16 dst, u16 len);
void vdpVramRead(u16 src, u16 *dst, u16 len);
void vdpSetReg(u8 reg, u16 val);



extern u16 font_base[];

void sysInit() {

    vdpSetReg(15, 0x02); //autoinc
    vdpSetReg(16, 0x11); //plan size 64x64

    vdpSetReg(0, 0x04);
    vdpSetReg(1, 0x54);

    JOY_CONTROL_1 = 0x40;
    JOY_DATA_1 = 0x00;
    JOY_CONTROL_2 = 0x40;
    JOY_DATA_2 = 0x00;

    vdpVramWrite(font_base, 1024, 4096);

    gSetPlan(APLAN);
}

u16 sysJoyRead() {

    u8 joy;

    JOY_DATA_1 = 0x40;
    asm("nop");
    asm("nop");
    asm("nop");
    joy = (JOY_DATA_1 & 0x3F);
    JOY_DATA_1 = 0x00;
    asm("nop");
    asm("nop");
    asm("nop");
    joy |= (JOY_DATA_1 & 0x30) << 2;


    joy ^= 0xff;

    return joy & 0xff;
}

u16 sysJoyWait() {

    u16 joy = 0;

    do {
        gVsync();
        joy = sysJoyRead();
    } while (joy != 0);


    do {
        gVsync();
        joy = sysJoyRead();
    } while (joy == 0);

    return joy;
}

void gVsync() {

    u16 vdp_state = VDP_VBLANK_FLAG;

    while (vdp_state & VDP_VBLANK_FLAG) {
        vdp_state = GFX_CTRL_PORT16;
    }

    while (!(vdp_state & VDP_VBLANK_FLAG)) vdp_state = GFX_CTRL_PORT16;
}

void gSetColor(u16 color, u16 val) {

    GFX_CTRL_PORT32 = GFX_WRITE_CRAM_ADDR(color << 1);
    GFX_DATA_PORT16 = val;
}

//****************************************************************************** internal HV funcsions

void vdpSetReg(u8 reg, u16 val) {
    GFX_CTRL_PORT16 = 0x8000 | (reg << 8) | val;
}

void vdpVramWrite(u16 *src, u16 dst, u16 len) {

    len >>= 1;
    GFX_CTRL_PORT32 = GFX_WRITE_VRAM_ADDR(dst);
    while (len--)GFX_DATA_PORT16 = *src++;
}

void vdpVramWriteDma(u16 *src, u16 dst, u16 len) {

    u32 src32 = (u32) src;

    //len in words
    len >>= 1;
    *((vu16 *) GFX_CTRL_PORT) = 0x9300 | (len & 0xff);
    len >>= 8;
    *((vu16 *) GFX_CTRL_PORT) = 0x9400 | (len & 0xff);


    src32 >>= 1;
    *((vu16 *) GFX_CTRL_PORT) = 0x9500 + (src32 & 0xff);
    src32 >>= 8;
    *((vu16 *) GFX_CTRL_PORT) = 0x9600 + (src32 & 0xff);
    src32 >>= 8;
    *((vu16 *) GFX_CTRL_PORT) = 0x9700 + (src32 & 0xff);

    *((vu32 *) GFX_CTRL_PORT) = GFX_DMA_VRAM_ADDR(dst);

    while (GETVDPSTATUS(VDP_DMABUSY_FLAG));
}

void vdpVramRead(u16 src, u16 *dst, u16 len) {

    len >>= 1;

    *((volatile u32 *) GFX_CTRL_PORT) = GFX_READ_VRAM_ADDR(src);
    while (len--)*dst++ = GFX_DATA_PORT16;
}
//****************************************************************************** gfx base
u16 g_plan;
u16 g_pal;
u16 g_addr;

void gSetPal(u16 pal) {
    g_pal = 0; //pal;
}

void gSetPlan(u16 plan) {
    g_plan = plan;
    GFX_CTRL_PORT32 = GFX_WRITE_VRAM_ADDR(g_plan + g_addr);
}

void gCleanPlan() {

    u16 len = (G_PLAN_W * G_SCREEN_H);
    g_addr = 0;

    GFX_CTRL_PORT32 = GFX_WRITE_VRAM_ADDR(g_plan);
    while (len--) {
        GFX_DATA_PORT32 = 0;
    }
    GFX_CTRL_PORT32 = GFX_WRITE_VRAM_ADDR(g_plan);
}

void gAppendString(u8 *str) {

    while (*str != 0) {
        GFX_DATA_PORT16 = *str++ | g_pal;
    }
}

void gAppendChar(u8 val) {

    GFX_DATA_PORT16 = val | g_pal;
}

void gConsPrint(u8 *str) {
    g_addr += G_PLAN_W * 2;
    GFX_CTRL_PORT32 = GFX_WRITE_VRAM_ADDR(g_plan + g_addr);
    gAppendString(str);
}

void gAppendHex4(u8 val) {
    val &= 15;
    val += (val < 10 ? '0' : '7');
    GFX_DATA_PORT16 = val | g_pal;
}

void gAppendHex8(u8 val) {

    gAppendHex4(val >> 4);
    gAppendHex4(val & 15);
}

void gAppendHex16(u16 val) {

    gAppendHex8(val >> 8);
    gAppendHex8(val);
}

void gAppendHex32(u32 val) {

    gAppendHex16(val >> 16);
    gAppendHex16(val);

}

void gPrintHex(void *src, u16 len) {

    u8 *ptr8 = src;
    u16 i;

    for (i = 0; i < len; i++) {
        if (i % 16 == 0)gConsPrint("");
        if (i % 2 == 0 && i % 16 != 0) {
            // gAppendString(".");
        }
        gAppendHex8(*ptr8++);

    }
}

void gAppendNum(u32 num) {

    u16 i;
    u8 buff[11];
    u8 *str = (u8 *) & buff[10];


    *str = 0;
    if (num == 0)*--str = '0';
    for (i = 0; num != 0; i++) {

        *--str = num % 10 + '0';
        num /= 10;
    }

    gAppendString(str);

}

void gSetXY(u16 x, u16 y) {

    g_addr = (x + y * G_PLAN_W) * 2;
    GFX_CTRL_PORT32 = GFX_WRITE_VRAM_ADDR(g_plan + g_addr);
}

void memSet(void *dst, u8 val, u32 len) {

    u8 *ptr8 = (u8 *) dst;
    while (len--)*ptr8++ = val;

}

