
#include "main.h"
#include "mcd.h"


GateArray *ga = (GateArray *) 0x0A12000;
McdMemory *mcd;

volatile u16 *cmd_idx, *sta_bsy;
volatile u32 *cmd_adr;
volatile u32 *cmd_adr_src;
volatile u32 *cmd_adr_dst;

volatile u8 *cmd_dat8, *sta_rsp8;
volatile u16 *cmd_dat16, *sta_rsp16;

void mcdInit() {

    u16 i;

    if (*((u32 *) 0x400100) == 0x53454741) {
        mcd = (McdMemory *) 0x400000;
    } else {
        mcd = (McdMemory *) 0;
    }

    cmd_idx = (u16 *) & ga->COMCMD[0];
    cmd_dat8 = (u8 *) & ga->COMCMD[1];
    cmd_dat16 = (u16 *) & ga->COMCMD[1];
    cmd_adr = (u32 *) & ga->COMCMD[2];
    cmd_adr_src = (u32 *) & ga->COMCMD[2];
    cmd_adr_dst = (u32 *) & ga->COMCMD[4];

    sta_bsy = (u16 *) & ga->COMSTA[0];
    sta_rsp8 = (u8 *) & ga->COMSTA[1];
    sta_rsp16 = (u16 *) & ga->COMSTA[1];

    mcdReset();
    mcdLoadPrg(sub_bios, 0, sizeof (sub_bios));
    mcdExec();

    for (i = 0; i < 7; i++)gVsync(); //wait for RES0

    *cmd_idx = 0;
}

void mcdReset() {

    *(u16 *)&ga->MEM_WP = 0xFF00;
    ga->RST = GA_RST_BUSREQ | GA_RST_RES0;
    ga->RST = GA_RST_BUSREQ;
    ga->RST = 0;
    //gVsync();
}

void mcdBusReq() {

    ga->RST |= GA_RST_BUSREQ;
    while ((ga->RST & GA_RST_BUSREQ) == 0);
}

void mcdBusRelease() {
    ga->RST &= ~GA_RST_BUSREQ;
    while ((ga->RST & GA_RST_BUSREQ) != 0);
}

void mcdLoadPrg(void *src, u32 dst, u32 len) {

    u16 *src16 = src;
    u16 *dst16 = (u16 *) & mcd->prog_ram[dst];

    while (len--) {
        *dst16++ = *src16++;
    }
}

void mcdExec() {

    ga->CFLAG_MC = 0x00; // clear main comm port
    ga->MEM_WP = 0; // write-protect
    ga->RST = GA_RST_RES0;

    while ((ga->RST & GA_RST_RES0) == 0);
}

void mcdCMD(u16 cmd) {

    while (*sta_bsy != 0);
    *cmd_idx = cmd;
    while (*sta_bsy == 0);
    *cmd_idx = 0;
}

u8 mcdResp8() {

    while (*sta_bsy != 0);
    return *sta_rsp8;
}

u16 mcdResp16() {

    while (*sta_bsy != 0);
    return *sta_rsp16;
}

void mcdWR8(u32 addr, u8 val) {

    while (*sta_bsy != 0);
    *cmd_adr = addr;
    *cmd_dat8 = val;
    mcdCMD(MCD_CMD_WR_8);
}

void mcdWR16(u32 addr, u16 val) {

    while (*sta_bsy != 0);
    *cmd_adr = addr;
    *cmd_dat16 = val;
    mcdCMD(MCD_CMD_WR_16);
}

u8 mcdRD8(u32 addr) {

    while (*sta_bsy != 0);
    *cmd_adr = addr;
    mcdCMD(MCD_CMD_RD_8);
    return mcdResp8();
}

u16 mcdRD16(u32 addr) {

    while (*sta_bsy != 0);
    *cmd_adr = addr;
    mcdCMD(MCD_CMD_RD_16);
    return mcdResp16();
}

void mcdPrgSetBank(u8 bank) {

    u16 val = ga->MEMMOD;

    val &= ~(GA_MEMMOD_BNK0 | GA_MEMMOD_BNK1);
    if (bank & 1)val |= GA_MEMMOD_BNK0;
    if (bank & 2)val |= GA_MEMMOD_BNK1;

    ga->MEMMOD = val;

}

void mcdWramSetMode(u8 mode) {

    u16 val = mcdRD16(SUB_REG_MEMMOD);

    if (mode == WRAM_MODE_2M) {
        val &= ~(GA_MEMMOD_MOD | GA_MEMMOD_PM1);
    } else {
        val |= GA_MEMMOD_MOD;
    }

    mcdWR16(SUB_REG_MEMMOD, val);
}

void mcdWramSetBank(u8 bank) {

    u16 val = mcdRD16(SUB_REG_MEMMOD);

    if (bank == 0) {
        val &= ~GA_MEMMOD_RET;
    } else {
        val |= GA_MEMMOD_RET;
    }
    mcdWR16(SUB_REG_MEMMOD, val);
}

void mcdWramToSub() {

    ga->MEMMOD |= GA_MEMMOD_DMNA;
    gVsync();
}

void mcdWramToMain() {

    u16 val = mcdRD16(SUB_REG_MEMMOD);

    val |= GA_MEMMOD_RET;
    mcdWR16(SUB_REG_MEMMOD, val);
    gVsync();
}

void mcdWramPriorMode(u8 mode) {

    u16 val = mcdRD16(SUB_REG_MEMMOD);

    val &= ~WRAM_PM_MSK;
    val |= mode & WRAM_PM_MSK;
    mcdWR16(SUB_REG_MEMMOD, val);
}

void mcdDelay(u32 addr) {

    *cmd_adr = addr;
    mcdCMD(MCD_CMD_DELAY);

}

void mcdRenderAndRead(u32 rd_addr, u16 vector_addr) {

    *cmd_adr = rd_addr;
    *cmd_dat16 = vector_addr;
    mcdCMD(MCD_CMD_RDRND);

}

void mcdSubBusy() {
    while (*sta_bsy != 0);
}

void mcdReadSector(u32 rd_addr) {

    *cmd_adr = rd_addr;
    mcdCMD(MCD_CMD_RDSEC);

}

void mcdCpy(u32 src, u32 dst, u16 len) {

    *cmd_adr_src = src;
    *cmd_adr_dst = dst;
    *cmd_dat16 = len;
    mcdCMD(MCD_CMD_CPY);
}
