/* 
 * File:   mcd.h
 * Author: igor
 *
 * Created on September 22, 2019, 3:15 AM
 */

#ifndef MCD_H
#define	MCD_H

#define MCD_CMD_NOP     0
#define MCD_CMD_RD_8    1
#define MCD_CMD_WR_8    2
#define MCD_CMD_RD_16   3
#define MCD_CMD_WR_16   4
#define MCD_CMD_DELAY   5
#define MCD_CMD_RDRND  6
#define MCD_CMD_RDSEC  7
#define MCD_CMD_CPY     8

#define MCD_SECTOR_SIZE 2352



#define SUB_REG_RESET   0xFF8000
#define SUB_REG_MEMMOD  0xFF8002

#define SUB_REG_CDC_DST  0xFF8004
#define SUB_REG_CDC_RADR 0xFF8005
#define SUB_REG_CDC_RDAT 0xFF8007
#define SUB_REG_CDC_HDAT 0xFF8008
#define SUB_REG_CDC_DADR 0xFF800A

#define SUB_REG_SWATCH  0xFF800C
#define SUB_REG_CCLAGS  0xFF800E
#define SUB_REG_ICTR2   0xFF8028
#define SUB_REG_ICTR3   0xFF802A
#define SUB_REG_ITIMER  0xFF8030
#define SUB_REG_IEMASK  0xFF8032

#define SUB_BRAM        0xFE0000
#define SUB_WRAM        0x80000

#define SUB_REG

#define WRAM_MODE_2M    0
#define WRAM_MODE_1M    4

#define WRAM_PM_OFF     0
#define WRAM_PM_WD      GA_MEMMOD_PM0
#define WRAM_PM_WU      GA_MEMMOD_PM1
#define WRAM_PM_MSK     (GA_MEMMOD_PM0 | GA_MEMMOD_PM1)



typedef struct {
    volatile u8 IFL2;
    volatile u8 RST;
    volatile u8 MEM_WP;
    volatile u8 MEMMOD;
    volatile u8 CDC_MOD;
    volatile u8 reserved1;
    volatile u16 HIVECT;
    volatile u16 CDCDAT;
    volatile u16 reserved2;
    volatile u16 TIMER;
    volatile u8 CFLAG_MC;
    volatile u8 CFLAG_SC;
    volatile u16 COMCMD[8];
    volatile u16 COMSTA[8];
} GateArray;

typedef struct {
    u8 bios[0x20000];
    u8 prog_ram[0x20000];
    u8 reserved[0x1C0000];
    u8 word_ram[0x40000];
} McdMemory;

#define GA_RST_RES0     (1 << 0)
#define GA_RST_BUSREQ   (1 << 1)
#define GA_RST_IFL2     (1 << 0)

#define GA_MEMMOD_RET   (1 << 0)
#define GA_MEMMOD_DMNA  (1 << 1)
#define GA_MEMMOD_MOD   (1 << 2)
#define GA_MEMMOD_PM0   (1 << 3)
#define GA_MEMMOD_PM1   (1 << 4)
#define GA_MEMMOD_BNK0  (1 << 6)
#define GA_MEMMOD_BNK1  (1 << 7)

#define GA_MEMMOD_MOD2M  0
#define GA_MEMMOD_MOD1M  (1 << 2)


void mcdInit();
void mcdReset();
void mcdBusReq();
void mcdBusRelease();
void mcdLoadPrg(void *src, u32 dst, u32 len);
void mcdExec();

void mcdCMD(u16 cmd);
u8 mcdResp8();
u16 mcdResp16();
void mcdWR8(u32 addr, u8 val);
void mcdWR16(u32 addr, u16 val);
u8 mcdRD8(u32 addr);
u16 mcdRD16(u32 addr);

void mcdPrgSetBank(u8 bank);
void mcdWramSetMode(u8 mode);
void mcdWramSetBank(u8 bank);
void mcdWramToSub();
void mcdWramToMain();
void mcdWramPriorMode(u8 mode);
void mcdDelay(u32 addr);
void mcdRenderAndRead(u32 rd_addr, u16 vector_addr);
void mcdSubBusy();
void mcdReadSector(u32 rd_addr);
void mcdCpy(u32 src, u32 dst, u16 len);

extern GateArray *ga;
extern McdMemory *mcd;
extern u32 sub_bios_sega[22528 / 4];
extern u32 sub_bios[8192 / 4];
extern u32 sub_app[4096 / 4];

#endif	/* MCD_H */

