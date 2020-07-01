
#include "main.h"




#define CTRL1_SYIEN     0x80
#define CTRL1_SYDEN     0x40
#define CTRL1_DESEN     0x20
#define CTRL1_COWEN     0x10
#define CTRL1_MODRQ     0x08
#define CTRL1_FRMRQ     0x04
#define CTRL1_MBCRQ     0x02
#define CTRL1_SHDEN     0x01

#define CTRL0_DECEN     0x80




#define OK      1
#define TOUT    0

typedef struct {
    u8 IFSTAT;
    u16 DBC;
    u32 HEAD;
    u16 PT;
    u16 WA;
    u8 STAT[4];
} CdcState;

void printIFSTAT();
void printSTAT0();
void printSTAT1();
void printSTAT2();
void printSTAT3();
void cdcPrintFlags();
void cdcRunDMA();
void cdcReset();
void cdcPrepareDMA(u16 len, u16 cdc_addr, u32 dst_addr, u8 dst_mem, u8 flags);
u8 cdcGetIFSTAT();
u8 cdcTestDmaFlags();
void cdcGetState();
void cdcPrintState();

u8 cdcTestDmaOPS();
u8 cdcTestDmaIRQ();
void cdcTestDmaTimings();
u8 cdcTestDecoderIRQ();
void cdcFullReset();
void delay(u16 time);
u8 cdcWaitDECI(u8 state);
void cdcTestPcmDma();
u8 cdcIrqPhase();
void delayNop(u32 time);

CdcState cdc_state;

void testCDC_old() {

    u16 i;

    u8 resp;
    gCleanPlan();
    gConsPrint("--------------CDC benchmark--------------");
    gConsPrint("");
    mcdInit();
    mcdWR16(0xff8036, 0); //turn off HOCK
    for (i = 0; i < 16; i++)gVsync();

    //cdcTestPcmDma();

    //cdcIrqPhase();


    resp = cdcTestDecoderIRQ();
    testPrintResp(resp);

    resp = cdcTestDmaIRQ();
    testPrintResp(resp);

    resp = cdcTestDmaOPS();
    testPrintResp(resp);

    resp = cdcTestDmaFlags();
    testPrintResp(resp);

    gConsPrint("");
    cdcTestDmaTimings();

    sysJoyWait();
}

u8 cdcIrqPhase() {

    u16 i;
    u32 ctr;
    u32 ctr_seq[32];
    u8 irq_seq[32];
    u32 delay = 500;
    u16 joy = 0;

    /*
    mcdWR16(0xff8036, 4); //HOCK
    cddCmd_nop();
    cddUpdate();*/


    mcdWR16(SUB_REG_IEMASK, (1 << 5) | (1 << 4));
    cddInit(0);
    while (1) {

        gCleanPlan();
        gConsPrint("delay: ");
        gAppendNum(delay);

        cdcFullReset();
        cdcDecoderOFF();
        delayNop(2000);

        mcdRD16(0);
        while (ga->COMSTA[3] != 4);
        cdcDecoderON();
                


        for (i = 0; i < 17; i++) {

            mcdRD16(0);
            ctr = 0;
            while (ga->COMSTA[3] == 0)ctr++;
            irq_seq[i] = ga->COMSTA[3];
            ctr_seq[i] = ctr;

        }

        for (i = 0; i < 17; i++) {
            gConsPrint("irq: ");
            gAppendNum(irq_seq[i]);
            gAppendString(".");
            gAppendNum(ctr_seq[i]);
        }

        joy = sysJoyWait();
        if (joy == JOY_L)delay -= 100;
        if (joy == JOY_R)delay += 100;

    }

    return 0;
}

u8 cdcWaitDECI(u8 state) {

    u16 i;
    if (state != 0)state = IFSTAT_DECI;

    for (i = 0; i < 400; i++) {
        if ((cdcGetIFSTAT() & IFSTAT_DECI) == state)return OK;
    }

    return TOUT;
}

u8 cdcTestDecoderIRQ() {

    u16 i;

    gConsPrint("DEC IRQ.....");

    cdcFullReset();

    mcdWR16(SUB_REG_IEMASK, (1 << 5));
    gVsync();
    gVsync();
    if (ga->COMSTA[3] != 0)return 0x01; //no any irq should be there

    if (cdcWaitDECI(0) == OK)return 0x02; //decoder turned off, DECI should be set to 1

    cdcRegSelect(CDC_CTRL0);
    cdcRegWrite(CTRL0_DECEN);
    delay(8);
    if (cdcWaitDECI(0) == OK)return 0x03; //without SYIEN DECI still not be toggled

    cdcRegSelect(CDC_CTRL0);
    cdcRegWrite(CTRL0_DECEN);
    cdcRegWrite(CTRL1_SYIEN | CTRL1_SYDEN | CTRL1_DESEN);
    delay(8);
    /*
    gCleanPlan();
    while(1){
        gSetXY(0,0);
        gConsPrint("deci: ");
        gAppendHex8(cdcGetIFSTAT() & IFSTAT_DECI);
    }*/

    if (cdcWaitDECI(0) != OK)return 0x04; //now DECI should fire
    if (ga->COMSTA[3] != 0)return 0x05; //irq still should be turned off

    cdcRegSelect(CDC_IFCTRL);
    cdcRegWrite(IFCTRL_DECIEN);
    delay(8);
    if (ga->COMSTA[3] != 5)return 0x06; //irq should work now
    mcdRD16(0); //clear COMSTA[3]
    delay(2);
    if (ga->COMSTA[3] != 5)return 0x07; //irq should repeat without DECI acknowledge


    cdcRegSelect(CDC_STAT3); //reset DECI flag
    cdcRegRead();
    mcdRD16(0);
    while (ga->COMSTA[3] != 5); //wait for irq
    cdcGetState();
    if ((cdc_state.IFSTAT & IFSTAT_DECI) != 0)return 0x08; //DECI should be 0 after irq

    mcdRD16(0);
    while (ga->COMSTA[3] != 5); //wait for irq
    cdcRegSelect(CDC_STAT3); //reset DECI flag
    cdcRegRead();
    cdcGetState();
    if ((cdc_state.IFSTAT & IFSTAT_DECI) == 0)return 0x09; //we are reset DECI. it should be 1

    //check DECI phase
    mcdRD16(0);
    while (ga->COMSTA[3] != 5);
    mcdRD16(0);
    while (ga->COMSTA[3] != 5);

    u32 deci_0 = 0;
    u32 deci_1 = 0;
    while ((cdcGetIFSTAT() & IFSTAT_DECI) == 0)deci_0++;
    while ((cdcGetIFSTAT() & IFSTAT_DECI) != 0)deci_1++;
    //actually may float
    /*
    gConsPrint("de0: ");
    gAppendNum(deci_0);
    gConsPrint("de1: ");
    gAppendNum(deci_1);
    gConsPrint(""); 
    if (deci_0 <= (47 - 2) || deci_0 >= (47 + 2)) {
        gAppendNum(deci_0);
        return 0x10;
    }

    if (deci_1 <= (71 - 2) || deci_1 >= (71 + 2)) {
        gAppendNum(deci_1);
        return 0x11;
    } */

    /*
    u32 delta = deci_0 > deci_1 ? deci_0 - deci_1 : deci_1 - deci_0;
    if (delta > 2) {
        gAppendNum(delta);
        return 0x10;
    }*/


    //enable mask for irq5 right after DECI reset to 0 shouldn't trigger irq
    mcdRD16(0);
    while (ga->COMSTA[3] != 5);
    mcdRD16(0);
    mcdWR16(SUB_REG_IEMASK, 0);
    cdcRegSelect(CDC_STAT3); //reset DECI flag
    cdcRegRead();
    if ((cdcGetIFSTAT() & IFSTAT_DECI) == 0)return 0x12; //DECI should be 1 at this point
    while ((cdcGetIFSTAT() & IFSTAT_DECI) != 0);
    mcdWR16(SUB_REG_IEMASK, (1 << 5));
    for (i = 0; i < 16; i++)asm("nop");
    if (ga->COMSTA[3] != 0)return 0x13; //irq souldn't trigger after mask enabling


    mcdRD16(0);
    while (ga->COMSTA[3] != 5);
    cdcRegSelect(CDC_CTRL0);
    cdcRegWrite(0);
    if ((cdcGetIFSTAT() & IFSTAT_DECI) == 0)return 0x14; //with disabled decoder DECI should be set to 1 immediately

    cdcRegSelect(CDC_CTRL0);
    cdcRegWrite(CTRL0_DECEN);
    delay(8);

    //irq period
    u32 ctr = 0;
    mcdRD16(0);
    while (ga->COMSTA[3] != 5);
    mcdRD16(0);
    while (ga->COMSTA[3] != 5);
    mcdRD16(0);
    while (ga->COMSTA[3] != 5)ctr++;

    if (ctr <= (2188 - 5) || ctr >= (2188 + 5)) {
        gAppendNum(ctr);
        return 0x15;
    }

    //gAppendNum(ctr);

    /*
        cdcRegSelect(CDC_CTRL0);
        cdcRegWrite(0);
        cdcRegSelect(CDC_CTRL0);
        cdcRegWrite(0);
        cdcRegWrite(0);

        delay(8);
        ctr = 0;

        cdcRegSelect(CDC_CTRL0);
        cdcRegWrite(CTRL0_DECEN);
        cdcRegSelect(CDC_CTRL0);
        cdcRegWrite(CTRL0_DECEN);
        cdcRegWrite(CTRL1_SYIEN | CTRL1_SYDEN | CTRL1_DESEN);

        while (ga->COMSTA[3] != 5)ctr++;

        gConsPrint("wup time: ");
        gAppendNum(ctr);

        sysJoyWait();*/
    //nedd chech how many time from enabling decoder to first irq

    return 0;
}

void cdcTestDmaTimings() {

    static u16 ctr;
    u16 i;

    gConsPrint("DMA timings: ");
    cdcRegSelect(1);
    for (i = 1; i < 16; i++) {
        if (i == CDC_DTTRG)continue;
        cdcRegWrite(0);
    }
    mcdWramToSub();

    mcdWR16(SUB_REG_IEMASK, (1 << 5));
    gVsync();

    //check dma timings
    ctr = 0;
    cdcDTACK();
    cdcPrepareDMA(2048, 0, 0, CDC_DST_WRAM, IFCTRL_DOUTEN | IFCTRL_DTEIEN);
    cdcDTTRG();
    while (ga->COMSTA[3] != 5)ctr++;
    gConsPrint("WRAM..");
    gAppendNum(ctr);
    gAppendString(" (target val 158) ");
    if (ctr <= (158 - 10) || ctr >= (158 + 10)) {
        gAppendString("ERR");
    } else {
        gAppendString("OK");
    }

    ctr = 0;
    cdcDTACK();
    cdcPrepareDMA(2048, 0, 0x20000, CDC_DST_PRG, IFCTRL_DOUTEN | IFCTRL_DTEIEN);
    cdcDTTRG();
    while (ga->COMSTA[3] != 5)ctr++;
    gConsPrint("PRG...");
    gAppendNum(ctr);
    gAppendString(" (target val 194) ");
    if (ctr <= (194 - 10) || ctr >= (194 + 10)) {
        gAppendString("ERR");
    } else {
        gAppendString("OK");
    }

    ctr = 0;
    cdcDTACK();
    cdcPrepareDMA(2048, 0, 0x20000, CDC_DST_PCM, IFCTRL_DOUTEN | IFCTRL_DTEIEN);
    cdcDTTRG();
    while (ga->COMSTA[3] != 5)ctr++;
    gConsPrint("PCM...");
    gAppendNum(ctr);
    gAppendString(" (target val 717) ");
    if (ctr <= (717 - 10) || ctr >= (717 + 10)) {
        gAppendString("ERR");
    } else {
        gAppendString("OK");
    }



}

u8 cdcTestDmaIRQ() {

    u16 i;
    vu16 tmp;

    gConsPrint("DMA IRQ.....");
    cdcRegSelect(1);
    for (i = 1; i < 16; i++) {
        if (i == CDC_DTTRG)continue;
        cdcRegWrite(0);
    }
    mcdWramToSub();

    mcdWR16(SUB_REG_IEMASK, (1 << 5));
    gVsync();
    gVsync();
    if (ga->COMSTA[3] != 0)return 1; //no any irq should be there

    cdcDTACK();
    cdcPrepareDMA(256, 0, 0, CDC_DST_WRAM, IFCTRL_DOUTEN);
    cdcDTTRG();
    gVsync();
    if (ga->COMSTA[3] != 0)return 2; //no any irq should be there

    cdcRegSelect(CDC_IFCTRL);
    cdcRegWrite(IFCTRL_DOUTEN | IFCTRL_DTEIEN);
    gVsync();
    if (ga->COMSTA[3] != 0)return 3; //no any irq should be there even with turned on DTEIEN

    cdcGetState();
    if ((cdc_state.IFSTAT & IFSTAT_DTEI) != 0)return 4; //but DTEI should be asserted to 0 anyway

    cdcPrepareDMA(256, 0, 0, CDC_DST_WRAM, IFCTRL_DOUTEN | IFCTRL_DTEIEN);
    cdcDTTRG();
    gVsync();
    if (ga->COMSTA[3] != 0)return 5; //irq will not fire untill DTEI will not be cleared

    cdcDTACK();
    cdcPrepareDMA(256, 0, 0, CDC_DST_WRAM, IFCTRL_DOUTEN | IFCTRL_DTEIEN);
    cdcDTTRG();
    gVsync();
    if (ga->COMSTA[3] != 5)return 0x06; //finally irq should fire


    mcdWR16(SUB_REG_IEMASK, 0);
    cdcDTACK();
    cdcPrepareDMA(256, 0, 0, CDC_DST_WRAM, IFCTRL_DOUTEN | IFCTRL_DTEIEN);
    cdcDTTRG();
    gVsync();
    if (ga->COMSTA[3] != 0)return 0x07; //no irq if turned off at irq mask

    mcdWR16(SUB_REG_IEMASK, (1 << 5));
    gVsync();
    if (ga->COMSTA[3] != 0)return 0x08; //should not fire after mask enabling


    mcdWramToMain();
    cdcDTACK();
    cdcPrepareDMA(256, 0, 0, CDC_DST_WRAM, IFCTRL_DOUTEN | IFCTRL_DTEIEN);
    cdcDTTRG();
    gVsync();
    if (ga->COMSTA[3] != 0)return 0x09; //no irq if memory asserted to main
    mcdWramToSub();
    gVsync();
    if (ga->COMSTA[3] != 5)return 0x0A; //after memory been returned dma and irq should go ahead

    //check point of dma during software streaming via io register to main
    cdcDTACK();
    cdcPrepareDMA(256, 0, 0, CDC_DST_MAIN, IFCTRL_DOUTEN | IFCTRL_DTEIEN);
    cdcDTTRG();
    for (i = 0; i < 256 - 4; i += 2) {
        while ((ga->CDC_MOD & 0x40) == 0); //wait for DSR
        tmp = ga->CDCDAT;
    }
    gVsync();
    if (ga->COMSTA[3] != 0)return 0x0B; //no irq if more than 1 word left
    tmp = ga->CDCDAT;
    gVsync();
    if (ga->COMSTA[3] != 5)return 0x0C; //now irq fire when last word left
    tmp = ga->CDCDAT;




    //cdcPrintState();
    //gConsPrint("");

    return 0;
}

u8 cdcTestDmaOPS() {

    u16 i;
    vu16 tmp;

    gConsPrint("DMA OPS.....");
    cdcRegSelect(1);
    for (i = 1; i < 16; i++) {
        if (i == CDC_DTTRG)continue;
        cdcRegWrite(0);
    }

    mcdWramSetMode(WRAM_MODE_2M);
    mcdWramToMain();
    mcd->word_ram[2048 - 2] = 0x2A;
    mcd->word_ram[2048 - 1] = 0xA5;
    mcd->word_ram[2048 + 0] = 0x55;
    mcd->word_ram[2048 + 1] = 0xAA;

    cdcDTACK();
    cdcPrepareDMA(2048, 0, 0, CDC_DST_WRAM, IFCTRL_DOUTEN);
    cdcDTTRG();
    for (i = 0; i < 16; i++)gVsync();
    cdcGetState();
    if ((cdc_state.IFSTAT & IFSTAT_DTEI) == 0)return 0x01; //dma should be halted till memory assigned to main
    mcdWramToSub();
    for (i = 0; i < 16; i++)gVsync();
    cdcGetState();
    if ((cdc_state.IFSTAT & IFSTAT_DTEI) != 0)return 0x02; //dma will continue and complete when memory returned

    //make sure dma was complete
    mcdWramToMain();
    if (mcd->word_ram[2048 - 2] == 0x2A && mcd->word_ram[2048 - 1] == 0xA5)return 0x03;
    if (mcd->word_ram[2048 + 0] != 0x55 || mcd->word_ram[2048 + 1] != 0xAA)return 0x04;
    mcdWramToSub();

    //now we check points where flags should fire
    cdcDTACK();
    cdcPrepareDMA(256 + 1, 0, 0, CDC_DST_MAIN, IFCTRL_DOUTEN);
    cdcDTTRG();
    gVsync();
    for (i = 0; i < 256 - 6; i += 2) {
        while ((ga->CDC_MOD & DSR) == 0); //wait for DSR
        tmp = ga->CDCDAT;
    }

    //1,3,5,7,9 DBC seq
    cdcGetState();
    if (cdc_state.DBC != 0x0003) {
        gAppendNum(cdc_state.DBC);
        return 0x06; //number of bytes for read -3
    }
    tmp = ga->CDCDAT;
    cdcGetState();
    if (cdc_state.DBC != 0x0001)return 0x07; //number of bytes for read -3
    if ((cdc_state.IFSTAT & IFSTAT_DTEI) == 0)return 0x08; //DTEI flag should not fire yet
    tmp = ga->CDCDAT;
    cdcGetState();
    if (cdc_state.DBC != 0xffff)return 0x09; //number of bytes for read -3
    if ((cdc_state.IFSTAT & IFSTAT_DTEI) != 0)return 0x0A; //DTEI flag should not fire yet
    tmp = ga->CDCDAT;


    //the same check but for sub
    cdcDTACK();
    cdcPrepareDMA(256 + 1, 0, 0, CDC_DST_SUB, IFCTRL_DOUTEN);
    cdcDTTRG();
    gVsync();
    for (i = 0; i < 256 - 4; i += 2) {
        while ((mcdRD8(0xff8004) & DSR) == 0); //wait for DSR
        tmp = mcdRD16(0xff8008);
    }

    cdcGetState();
    if (cdc_state.DBC != 0x0001)return 0x0B; //number of bytes for read -3
    if ((cdc_state.IFSTAT & IFSTAT_DTEI) == 0)return 0x0C; //DTEI flag should not fire yet
    tmp = mcdRD16(0xff8008);
    cdcGetState();
    if (cdc_state.DBC != 0xffff)return 0x0D; //number of bytes for read -3
    if ((cdc_state.IFSTAT & IFSTAT_DTEI) != 0)return 0x0E; //DTEI flag should not fire yet
    tmp = mcdRD16(0xff8008);


    //check EDT/DSR flags
    cdcDTACK();
    cdcPrepareDMA(8, 0, 0, CDC_DST_MAIN, IFCTRL_DOUTEN);
    cdcDTTRG();
    for (i = 0; i < 8 - 2; i += 2) {
        gVsync();
        if ((ga->CDC_MOD & DSR) == 0)return 0x10;
        if ((ga->CDC_MOD & EDT) != 0)return 0x11;
        tmp = ga->CDCDAT;
    }
    gVsync();
    if ((ga->CDC_MOD & DSR) == 0)return 0x12;
    if ((ga->CDC_MOD & EDT) == 0)return 0x13; //EDT should be set when last word in the buffer
    tmp = ga->CDCDAT;
    gVsync();
    if ((ga->CDC_MOD & DSR) != 0)return 0x14; //DSR clears when last word transfered
    if ((ga->CDC_MOD & EDT) == 0)return 0x15; //EDT should be set when last word in the buffer
    if ((ga->CDC_MOD & 0x7) != CDC_DST_MAIN)return 0x16; //check if requested destination can be readed back


    //check EDT/DSR flags for sub ops
    cdcDTACK();
    cdcPrepareDMA(8, 0, 0, CDC_DST_SUB, IFCTRL_DOUTEN);
    cdcDTTRG();

    for (i = 0; i < 8 - 2; i += 2) {
        gVsync();
        if ((mcdRD8(0xff8004) & DSR) == 0)return 0x17;
        if ((mcdRD8(0xff8004) & EDT) != 0)return 0x18;
        tmp = mcdRD16(0xff8008);
    }
    gVsync();
    if ((mcdRD8(0xff8004) & DSR) == 0)return 0x19;
    if ((mcdRD8(0xff8004) & EDT) == 0)return 0x1A; //EDT should be set when last word in the buffer
    tmp = mcdRD16(0xff8008);
    gVsync();
    if ((mcdRD8(0xff8004) & DSR) != 0)return 0x1B; //DSR clears when last word transfered
    if ((mcdRD8(0xff8004) & EDT) == 0)return 0x1C; //EDT should be set when last word in the buffer
    if ((mcdRD8(0xff8004) & 0x7) != CDC_DST_SUB)return 0x1D; //check if requested destination can be readed back

    //dma len test for odd numbers
    cdcDTACK();
    cdcPrepareDMA(8 + 1, 0, 0, CDC_DST_MAIN, IFCTRL_DOUTEN);
    cdcDTTRG();
    i = 0;
    while (1) {
        gVsync();
        if ((ga->CDC_MOD & DSR) == 0)break;
        tmp = ga->CDCDAT;
        i += 2;
    }
    if (i != 8)return 0x20;

    cdcDTACK();
    cdcPrepareDMA(7 + 1, 0, 0, CDC_DST_MAIN, IFCTRL_DOUTEN);
    cdcDTTRG();
    i = 0;
    while (1) {
        gVsync();
        if ((ga->CDC_MOD & DSR) == 0)break;
        tmp = ga->CDCDAT;
        i += 2;
    }
    if (i != 8)return 0x21;

    cdcDTACK();
    cdcPrepareDMA(9 + 1, 0, 0, CDC_DST_MAIN, IFCTRL_DOUTEN);
    cdcDTTRG();
    i = 0;
    while (1) {
        gVsync();
        if ((ga->CDC_MOD & DSR) == 0)break;
        tmp = ga->CDCDAT;
        i += 2;
    }
    if (i != 10)return 0x22;



    //check if memory protection working for dma. protection should not work for dma
    int ctr = 0;
    ga->MEM_WP = 0xff; //memory protected
    mcdBusReq();
    memSet(&mcd->prog_ram[0x10000], 0xaa, 256);
    mcdBusRelease();
    cdcDTACK();
    cdcPrepareDMA(256, 0, 0x10000, CDC_DST_PRG, IFCTRL_DOUTEN);
    cdcDTTRG();
    gVsync();

    mcdBusReq();
    ctr = 0;
    for (i = 0; i < 256; i++) {
        if (mcd->prog_ram[0x10000 + i] == 0xaa)ctr++;
    }
    mcdBusRelease();
    ga->MEM_WP = 0x00;
    if (ctr == 256)return 0x23;


    ga->MEM_WP = 0x00; //memory unprotected
    mcdBusReq();
    memSet(&mcd->prog_ram[0x10000], 0xaa, 256);
    mcdBusRelease();
    cdcDTACK();
    cdcPrepareDMA(256, 0, 0x10000, CDC_DST_PRG, IFCTRL_DOUTEN);
    cdcDTTRG();
    gVsync();

    mcdBusReq();
    ctr = 0;
    for (i = 0; i < 256; i++) {
        if (mcd->word_ram[0x10000 + i] == 0xaa)ctr++;
    }
    mcdBusRelease();
    if (ctr == 256)return 0x24;

    return 0;
}

u8 cdcTestDmaFlags() {

    u16 i;

    gConsPrint("DMA FLAGS...");
    mcdWramToSub();

    cdcRegSelect(1);
    for (i = 1; i < 16; i++) {
        if (i == CDC_DTTRG)continue;
        cdcRegWrite(0);
        //gVsync();
    }

    cdcPrepareDMA(2048 + 1, 0, 0x20000, CDC_DST_WRAM, IFCTRL_DOUTEN | IFCTRL_DTEIEN);
    cdcGetState();
    if ((cdc_state.IFSTAT & IFSTAT_1111) == 0)return 1;
    if ((cdc_state.IFSTAT & IFSTAT_DTEI) == 0)return 2;
    if ((cdc_state.DBC & 0xf000) != 0)return 3;
    if (cdc_state.DBC != 2048)return 4;

    //execute dma and check busy state
    cdcDTTRG();
    cdcGetState();
    if ((cdc_state.IFSTAT & IFSTAT_DTEI) == 0)return 5;
    if ((cdc_state.DBC & 0xf000) != 0)return 6; //check deti mirror
    if ((cdc_state.IFSTAT & IFSTAT_DTBSY) != 0)return 7;

    //wait for completion and check flags
    for (i = 0; i < 8; i++)gVsync();
    cdcGetState();
    if ((cdc_state.IFSTAT & IFSTAT_DTEI) != 0)return 8;
    if ((cdc_state.DBC & 0xf000) != 0xf000)return 9; //check deti mirror
    if (cdc_state.DBC != 0xffff)return 0xa; //counter should be wrapped to 0xfff

    cdcRegSelect(CDC_DBCL);
    cdcRegWrite(0x23);
    cdcRegWrite(0xa1);
    cdcGetState();
    if (cdc_state.DBC != 0xf123)return 0xb; //DBC update should not affect DTEI mirror

    //dtack should reset deti mirror and deti itself
    cdcDTACK();
    cdcGetState();
    if (cdc_state.DBC != 0x0123)return 0xc;
    if ((cdc_state.IFSTAT & IFSTAT_DTEI) == 0)return 0xd;

    //DTIEN disabling after dma should not affect DTEI
    cdcDTACK();
    cdcPrepareDMA(2048, 0, 0x20000, CDC_DST_WRAM, IFCTRL_DOUTEN | IFCTRL_DTEIEN);
    cdcDTTRG();
    for (i = 0; i < 8; i++)gVsync();
    cdcRegSelect(CDC_IFCTRL);
    cdcRegWrite(IFCTRL_DOUTEN);
    cdcGetState();
    if ((cdc_state.IFSTAT & IFSTAT_DTEI) != 0)return 0x0E;
    if (cdc_state.DBC != 0xffff)return 0x0F;
    cdcRegSelect(CDC_DTACK);
    cdcRegWrite(0);

    //DOUTEN disabling after dma should reset flgags
    cdcDTACK();
    cdcPrepareDMA(2048, 0, 0x20000, CDC_DST_WRAM, IFCTRL_DOUTEN | IFCTRL_DTEIEN);
    cdcDTTRG();
    for (i = 0; i < 8; i++)gVsync();
    cdcRegSelect(CDC_IFCTRL);
    cdcRegWrite(IFCTRL_DTEIEN);
    cdcGetState();
    if ((cdc_state.IFSTAT & IFSTAT_DTEI) == 0)return 0x10;
    if (cdc_state.DBC != 0x0fff)return 0x11;

    //DTBSY and DTEIEN flags still should work without DTEIEN
    cdcDTACK();
    cdcPrepareDMA(2048, 0, 0x20000, CDC_DST_WRAM, IFCTRL_DOUTEN);
    cdcDTTRG();
    cdcGetState();
    if ((cdc_state.IFSTAT & IFSTAT_DTBSY) != 0)return 0x12;
    for (i = 0; i < 8; i++)gVsync();
    cdcGetState();
    if ((cdc_state.IFSTAT & IFSTAT_DTEI) != 0)return 0x13;
    if (cdc_state.DBC != 0xffff)return 0x14;

    //dma should be aborted id DOUTEN turned off
    cdcDTACK();
    cdcPrepareDMA(2048, 0, 0x20000, CDC_DST_WRAM, IFCTRL_DOUTEN);
    cdcDTTRG();
    cdcRegSelect(CDC_IFCTRL);
    cdcRegWrite(0); //turn off DOUTEN
    for (i = 0; i < 8; i++)gVsync();
    cdcGetState();
    if ((cdc_state.IFSTAT & IFSTAT_DTEI) == 0)return 0x15;
    if ((cdc_state.DBC & 0xf000) == 0xf000)return 0x16;


    //another dma soudn't set DTEI to 1
    cdcDTACK();
    cdcPrepareDMA(2048, 0, 0x20000, CDC_DST_WRAM, IFCTRL_DOUTEN | IFCTRL_DTEIEN);
    cdcDTTRG();
    for (i = 0; i < 8; i++)gVsync();
    cdcGetState();
    if ((cdc_state.IFSTAT & IFSTAT_DTEI) != 0)return 0x17;
    cdcPrepareDMA(2048, 0, 0x20000, CDC_DST_WRAM, IFCTRL_DOUTEN | IFCTRL_DTEIEN);
    cdcDTTRG();
    cdcGetState();
    if ((cdc_state.IFSTAT & IFSTAT_DTEI) != 0)return 0x18;
    for (i = 0; i < 8; i++)gVsync();

    //************************************************************************** another batch of tests

    cdcFullReset();
    cdcDTACK();
    cdcPrepareDMA(2048 + 4, 0, 0, CDC_DST_SUB, IFCTRL_DOUTEN | IFCTRL_DTEIEN);
    cdcDTTRG();

    mcdWR16(0xff8004, 0x0000);
    mcdWR16(0xff8004, 0x0700);
    cdcDTTRG();
    gVsync();
    gVsync();


    /*
    cdcRegSelect(15);
    cdcRegWrite(0);*/
    /*
        gConsPrint("flags: ");
        gAppendHex16(mcdRD16(0xff8004));
        gConsPrint("");

        sysJoyWait();*/

    return 0;
}

void cdcPrepareDMA(u16 len, u16 cdc_addr, u32 dst_addr, u8 dst_mem, u8 flags) {

    len--;
    mcdWR8(SUB_REG_CDC_DST, dst_mem);
    mcdWR16(SUB_REG_CDC_DADR, dst_addr >> 3);
    cdcRegSelect(CDC_IFCTRL);
    cdcRegWrite(flags);
    cdcRegWrite(len & 0xff); //DBCL
    cdcRegWrite(len >> 8); //DBCH
    cdcRegWrite(cdc_addr & 0xff); //DACL
    cdcRegWrite(cdc_addr >> 8); //DACH
}



void cdcReset() {
    cdcRegSelect(CDC_RST);
    cdcRegWrite(0);
    cdcDTACK();
}

void printIFSTAT() {

    u8 ifstat;
    u16 i;

    cdcRegSelect(CDC_IFCTRL);
    ifstat = cdcRegRead();
    gConsPrint("CMDI DTEI DECI 1 DTBSY STBSY DTEN STEN");

    gConsPrint("");
    for (i = 0; i < 8; i++) {
        gAppendNum(ifstat >> 7);
        gAppendString("    ");
        ifstat <<= 1;
    }
}

void printSTAT0() {

    u8 stat;
    u16 i;

    cdcRegSelect(CDC_STAT0);
    stat = cdcRegRead();
    gConsPrint("CRCK ILSY NSYN LBLK WSHO SBLK ERAB UBLK");

    gConsPrint("");
    for (i = 0; i < 8; i++) {
        gAppendNum(stat >> 7);
        gAppendString("    ");
        stat <<= 1;
    }
}

void printSTAT1() {

    u8 stat;
    u16 i;

    cdcRegSelect(CDC_STAT1);
    stat = cdcRegRead();
    gConsPrint("MERA SERA BERA MERA SERA S1RA S2RA S3RA");

    gConsPrint("");
    for (i = 0; i < 8; i++) {
        gAppendNum(stat >> 7);
        gAppendString("    ");
        stat <<= 1;
    }
}

void printSTAT2() {

    u8 stat;
    u16 i;

    cdcRegSelect(CDC_STAT2);
    stat = cdcRegRead();
    gConsPrint(".... .... .... .... MODE FORM .... ....");

    gConsPrint("");
    for (i = 0; i < 8; i++) {
        gAppendNum(stat >> 7);
        gAppendString("    ");
        stat <<= 1;
    }
}

void printSTAT3() {

    u8 stat;
    u16 i;

    cdcRegSelect(CDC_STAT3);
    stat = cdcRegRead();
    gConsPrint("VALS VLNG .... .... .... .... .... ....");

    gConsPrint("");
    for (i = 0; i < 8; i++) {
        gAppendNum(stat >> 7);
        gAppendString("    ");
        stat <<= 1;
    }
}

void cdcPrintFlags() {

    printIFSTAT();
    gConsPrint("");

    printSTAT0();
    gConsPrint("");

    printSTAT1();
    gConsPrint("");

    printSTAT2();
    gConsPrint("");

    printSTAT3();
    gConsPrint("");

    /*
    u16 i;
    u16 dbc;
    cdcRegSelect(CDC_DBCL);
    dbc = cdcRegRead() | (cdcRegRead() << 8);
    gConsPrint("cdc dbcx: ");
    gAppendHex16(dbc);

    gConsPrint("cdc head: ");
    for (i = 0; i < 4; i++) {
        gAppendHex8(cdcRegRead());
    }*/

}

u8 cdcGetIFSTAT() {

    cdcRegSelect(CDC_IFSTAT);
    return cdcRegRead();
}

void cdcGetState() {

    cdcRegSelect(CDC_IFSTAT);

    cdc_state.IFSTAT = cdcRegRead();
    cdc_state.DBC = cdcRegRead() | (cdcRegRead() << 8);
    cdc_state.HEAD = cdcRegRead() << 24;
    cdc_state.HEAD |= cdcRegRead() << 16;
    cdc_state.HEAD |= cdcRegRead() << 8;
    cdc_state.HEAD |= cdcRegRead();
    cdc_state.PT = cdcRegRead() | (cdcRegRead() << 8);
    cdc_state.WA = cdcRegRead() | (cdcRegRead() << 8);
    cdc_state.STAT[0] = cdcRegRead();
    cdc_state.STAT[1] = cdcRegRead();
    cdc_state.STAT[2] = cdcRegRead();
    cdc_state.STAT[3] = cdcRegRead();
}

void cdcPrintState() {

    cdcGetState();
    gConsPrint("IFTAT: ");
    gAppendHex8(cdc_state.IFSTAT);
    gConsPrint("DBC:   ");
    gAppendHex16(cdc_state.DBC);
    gConsPrint("HEAD:  ");
    gAppendHex32(cdc_state.HEAD);
    gConsPrint("PT:    ");
    gAppendHex16(cdc_state.PT);
    gConsPrint("WA:    ");
    gAppendHex16(cdc_state.WA);
    gConsPrint("STAT0: ");
    gAppendHex8(cdc_state.STAT[0]);
    gConsPrint("STAT1: ");
    gAppendHex8(cdc_state.STAT[1]);
    gConsPrint("STAT2: ");
    gAppendHex8(cdc_state.STAT[2]);
    gConsPrint("STAT3: ");
    gAppendHex8(cdc_state.STAT[3]);
}

void cdcFullReset() {

    u16 i;
    cdcRegSelect(1);
    for (i = 1; i < 16; i++) {
        if (i == CDC_DTTRG)continue;
        cdcRegWrite(0);
    }

    for (i = 0; i < 8; i++)gVsync();
}

void delay(u16 time) {

    u32 i;
    while (time--) {
        for (i = 0; i < 8192; i++)asm("nop");
    }
}

void cdcTestPcmDma() {

    u16 i;
    u8 buff[512];

    cdcFullReset();


    mcdWR16(SUB_REG_IEMASK, (1 << 5));

    mcdWramToMain();
    for (i = 0; i < 512; i++) {
        pcmWrite(PCM_RAM + i, 0xaa);
        mcd->word_ram[i] = 0xaa;
    }
    mcdWramToSub();

    int off = 8;

    cdcDTACK();
    cdcPrepareDMA(128, 0, off, CDC_DST_PCM, IFCTRL_DOUTEN | IFCTRL_DTEIEN);
    cdcDTTRG();
    while (ga->COMSTA[3] != 5);
    cdcGetState();

    for (i = 0; i < 512; i++) {
        buff[i] = pcmRead(PCM_RAM + i);
    }
    gPrintHex(buff, 128 + 16);
    gConsPrint("stat: ");
    gAppendHex16(cdc_state.DBC);
    gAppendString(".");
    gAppendHex8(cdc_state.IFSTAT);
    gAppendString(".");
    gAppendHex16(mcdRD16(0xFF800A));
    gConsPrint("");

    cdcDTACK();
    cdcPrepareDMA(128, 0, off, CDC_DST_WRAM, IFCTRL_DOUTEN | IFCTRL_DTEIEN);
    cdcDTTRG();
    while (ga->COMSTA[3] != 5);
    cdcGetState();

    mcdWramToMain();
    gPrintHex(mcd->word_ram, 128 + 16);
    gConsPrint("stat: ");
    gAppendHex16(cdc_state.DBC);
    gAppendString(".");
    gAppendHex8(cdc_state.IFSTAT);
    gAppendString(".");
    gAppendHex16(mcdRD16(0xFF800A));
    gConsPrint("");


    sysJoyWait();
}

void delayNop(u32 time) {
    while (time--)asm("nop");
}

/*
void testCdcFlags() {

    gConsPrint("DMA FLAGS...");
}*/

