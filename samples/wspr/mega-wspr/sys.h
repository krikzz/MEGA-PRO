/* 
 * File:   sys.h
 * Author: krik
 *
 * Created on October 22, 2014, 9:02 PM
 */

#ifndef SYS_H
#define	SYS_H

#define s8      char
#define s16     short
#define s32     long

#define u8      unsigned char
#define u16     unsigned short
#define u32     unsigned long
#define u64     unsigned long long


#define vu8      volatile unsigned char
#define vu16     volatile unsigned short
#define vu32     volatile unsigned long
#define vu64     volatile unsigned long long

//******************************************************************************sega spec
void gSetPal(u16 pal);
void gSetPlan(u16 plan);
void gCleanPlan();
void gAppendChar(u8 val);
void gAppendString(u8 *str);
void gConsPrint(u8 *str);
void gAppendHex4(u8 val);
void gAppendHex8(u8 val);
void gAppendHex16(u16 val);
void gAppendHex32(u32 val);
void gPrintHex(void *src, u16 len);
void gAppendNum(u32 num);
void gSetXY(u16 x, u16 y);
void sysInitZ80();
//******************************************************************************
void gVsync();
void sysInit();
u16 sysJoyWait();
u16 sysJoyRead();
void gSetColor(u16 color, u16 val);

void mem_copy(void *src, void *dst, u16 len);
u32 min(u32 v1, u32 v2);

typedef struct {
    s16 y;
    u8 size;
    u8 link;
    u16 attr;
    s16 x;
} Sprite;

#define SPRITE_SIZE(w, h)   ((((w) - 1) << 2) | ((h) - 1))
#define TILE_ATTR(pal, pri, flipV, flipH)   (((flipH) << 11) + ((flipV) << 12) + ((pal) << 13) + ((pri) << 15))

#define WPLAN           (TILE_MEM_END + 0x0000)
#define HSCRL           (TILE_MEM_END + 0x0800)
#define SLIST           (TILE_MEM_END + 0x0C00)
#define APLAN           (TILE_MEM_END + 0x1000)
#define BPLAN           (TILE_MEM_END + 0x3000)

#define JOY_A   0x0040
#define JOY_B   0x0010
#define JOY_C   0x0020
#define JOY_STA 0x0080
#define JOY_U   0x0001
#define JOY_D   0x0002
#define JOY_L   0x0004
#define JOY_R   0x0008



#define CONSOLE_REGION *(volatile u16*) 0xa10000
#define GFX_HV_CTR      *((volatile u16 *)0xC00008)

#define JOY_DATA_1 *((volatile u8 *) 0xa10003)
#define JOY_CONTROL_1 *((volatile u8 *) 0xa10009)

#define JOY_DATA_2 *((volatile u8 *) 0xa10005)
#define JOY_CONTROL_2 *((volatile u8 *) 0xa1000B)
//****************************************************************************** YM2612
//******************************************************************************
//******************************************************************************
#define YM2612_BASEPORT     0xA04000
#define YM2612_A0   	0xa04000
#define YM2612_D0   	0xa04001
#define YM2612_A1   	0xa04002
#define YM2612_D1   	0xa04003

#define PSG_ENVELOPE_MIN    15
#define PSG_ENVELOPE_MAX    0

#define YM2612_IS_BUSY (*((volatile u8*) YM2612_BASEPORT) & 0x80)

void YM2612_reset();
void ym2612_write(u8 reg, u8 val, u8 bank);
//****************************************************************************** PSG
//******************************************************************************
//******************************************************************************

#define PSG_PORT            0xC00011
#define PSG_ENVELOPE_MIN    15
#define PSG_ENVELOPE_MAX    0

void PSG_init();

void PSG_write(u8 data);

void PSG_setEnvelope(u8 channel, u8 value);
void PSG_setTone(u8 channel, u16 value);
void PSG_setFrequency(u8 channel, u16 value);

//****************************************************************************** Z80
//******************************************************************************
//******************************************************************************
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

#define G_SCREEN_W 40
#define G_SCREEN_H 28
#define G_PLAN_W 64

#endif	/* SYS_H */

