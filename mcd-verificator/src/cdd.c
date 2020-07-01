

#include "main.h"

typedef struct {
    u8 cmd;
    u8 u0;
    u8 arg[6];
    u8 u1;
    u8 crc;
} CddCmd;



void cddCmdTX();
void cddStatusRX();
void cddControls();
void cddPrint();
void readDisk();



CddCmd cdd_cmd;
CddStatus cdd_stat;
u16 ctr;
u16 joy, old_joy;



void cdcDmaBusy() {

    while (1) {
        cdcRegSelect(CDC_IFCTRL); //DTBSY
        if ((cdcRegRead() & 8))break;
    }
}

void cddInit(u8 skip_toc_loading) {

    u16 i;
    mcdInit(); 
    gVsync();
    mcdWR16(SUB_REG_IEMASK, (1 << 4) | (1 << 5)); //enable cdc and cdd interrupts
    mcdWR16(0xff8036, 4); //HOCK
    cddCmd_nop();
    cddUpdate();

    if (skip_toc_loading)return;

    i = 0;
    cddCmd_getToc(4, 0);
    do {
        cddUpdate();
    } while (cdd_stat.u0 == 0xf);



    for (i = 0; i < 16; i++)cddUpdate();
}

u8 cddInitToc() {

    u32 timeout = 0;
    u16 i;

    mcdWR16(SUB_REG_IEMASK, (1 << 4)); //enable cdc and cdd interrupts
    mcdWR16(0xff8036, 4); //HOCK
    cddCmd_nop();
    cddUpdate();

    cddCmd_getToc(4, 0);

    do {
        cddUpdate();
        if (timeout++ >= 300) {
            return 1;
        }
    } while (cdd_stat.u0 == 0xf);

    for (i = 0; i < 16; i++)cddUpdate();

    return 0;
}

void cddReadCD(u32 disk_addr, u32 mem_addr, u32 len, u8 dst_mem) {

    u16 i = 0;
    u32 cdc_hdr = 0;
    u16 PT = 0;
    u32 hdr_val = (disk_addr << 8) | 0x01;
    u8 sync = 0;

    cddCmd_play(disk_addr);
    cddUpdate();


    while (len) {

        u16 block = 2352;
        if (block > len)block = len;
        if (dst_mem == CDC_DST_MAIN || dst_mem == CDC_DST_SUB)block = len;

        while (ga->COMSTA[3] != 0x05);

        //head 4-7
        //pt 8-9
        //wa 10-11
        cdcRegSelect(CDC_HEAD0);
        for (i = 0; i < 4; i++) {
            cdc_hdr <<= 8;
            cdc_hdr |= cdcRegRead();
        }

        PT = cdcRegRead();
        PT |= cdcRegRead() << 8;

        if (!sync && cdc_hdr != hdr_val)continue;

        cdcDma(dst_mem, mem_addr, PT, block);
        if (dst_mem == CDC_DST_MAIN || dst_mem == CDC_DST_SUB)return;
        cdcDmaBusy();

        len -= block;
        mem_addr += block;
        sync = 1;
    }
}

void cddUpdate() {

    mcdRD16(0);
    while (ga->COMSTA[3] != 4);
    cddCmdTX();
    cddStatusRX();
    cddCmd_nop();
}

void cddPrint() {

    u8 *ptr8 = (u8 *) & cdd_stat;
    u16 i;

    gConsPrint("cdd: ");

    for (i = 0; i < 10; i++) {
        if (i == 2 || i == 8)gAppendString(".");
        gAppendHex4(ptr8[i]);
    }

}

void cddCmdTX() {

    u16 i;
    u8 *ptr8 = (u8 *) & cdd_cmd;

    cdd_cmd.crc = 0;
    for (i = 0; i < 9; i++) {
        cdd_cmd.crc += ptr8[i];
    }

    cdd_cmd.crc ^= 0x0f;
    cdd_cmd.crc &= 0x0f;


    mcdWR16(0xff8042, ((u16) ptr8[0] << 8) | ptr8[1]);
    mcdWR16(0xff8044, ((u16) ptr8[2] << 8) | ptr8[3]);
    mcdWR16(0xff8046, ((u16) ptr8[4] << 8) | ptr8[5]);
    mcdWR16(0xff8048, ((u16) ptr8[6] << 8) | ptr8[7]);
    mcdWR16(0xff804A, ((u16) ptr8[8] << 8) | ptr8[9]);
}

void cddStatusRX() {

    u16 i;
    u16 *ptr16 = (u16 *) & cdd_stat;


    for (i = 0; i < 5; i++) {
        ptr16[i] = mcdRD16(0x1F0 + i * 2);
    }


}

void cddCmd_nop() {
    memSet(&cdd_cmd, 0, sizeof (CddCmd));
}

void cddCmd_stop() {

    cdd_cmd.cmd = 0x01;
}

void cddCmd_getToc(u8 toc_cmd, u16 arg) {

    cdd_cmd.cmd = 0x02;
    cdd_cmd.arg[1] = toc_cmd;

    cdd_cmd.arg[2] = (arg >> 12) & 15;
    cdd_cmd.arg[3] = (arg >> 8) & 15;
    cdd_cmd.arg[4] = (arg >> 4) & 15;
    cdd_cmd.arg[5] = (arg >> 0) & 15;
}

void cddCmd_play(u32 msf) {

    cdd_cmd.cmd = 0x03;

    cdd_cmd.arg[0] = (msf >> 20) & 15;
    cdd_cmd.arg[1] = (msf >> 16) & 15;
    cdd_cmd.arg[2] = (msf >> 12) & 15;
    cdd_cmd.arg[3] = (msf >> 8) & 15;
    cdd_cmd.arg[4] = (msf >> 4) & 15;
    cdd_cmd.arg[5] = (msf >> 0) & 15;
}

void cddCmd_playFastF() {

    cdd_cmd.cmd = 0x08;
}

void cddCmd_seek(u32 msf) {

    cdd_cmd.cmd = 0x04;

    cdd_cmd.arg[0] = (msf >> 20) & 15;
    cdd_cmd.arg[1] = (msf >> 16) & 15;
    cdd_cmd.arg[2] = (msf >> 12) & 15;
    cdd_cmd.arg[3] = (msf >> 8) & 15;
    cdd_cmd.arg[4] = (msf >> 4) & 15;
    cdd_cmd.arg[5] = (msf >> 0) & 15;
}

void cddCmd_pause() {

    cdd_cmd.cmd = 0x06;
}

void cddCmd_resume() {

    cdd_cmd.cmd = 0x07;
}
