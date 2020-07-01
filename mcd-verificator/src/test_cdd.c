
#include "main.h"

u8 testBootSeq1();
u8 testBootSeq2();
u8 testTimings();
u8 testCddRD1();
u8 testCddRD2();
u8 testCddSync();
void testFastPlay();
void testPlayToPlay();
u8 readSectorFast();

void testCDD() {

    u8 resp;

    gCleanPlan();


   
    //testPlayToPlay();
    //testFastPlay();

    testBootSeq1(); //read from first block once cdd state isn't busy
    testBootSeq2(); //read when required block appear in cdd status
    testTimings();
    resp = readSectorFast();
    testPrintResp(resp);
    sysJoyWait();


    gCleanPlan();
    gConsPrint("mcd init...");
    cddInit(0);
    cdcInit();

    resp = testCddSync();
    testPrintResp(resp);

    resp = testCddRD2();
    testPrintResp(resp);

    resp = testCddRD1();
    testPrintResp(resp);

    

    sysJoyWait();
    gCleanPlan();
}

void testPlayToPlay() {

    u16 i;
    cddInit(0);
    cdcInit();
    cdcDecoderON();



    cddCmd_play(0x360000);
    cddUpdate();
    sysJoyWait();
    cddCmd_seek(0x353000);



    //for (i = 0; i < 8; i++)cddUpdate();


    for (i = 0; i < 25;) {
        cddUpdate();
        //if (cdd_stat.u0 == 0x0f)continue;
        cddPrint();
        i++;
    }

    sysJoyWait();
}

void testFastPlay() {

    u16 i;
    gConsPrint("Fast play...");
    cddInit(0);
    cdcInit();
    cdcDecoderON();


    cddCmd_play(0x300);
    do {
        cddUpdate();
    } while (cdd_stat.status != 1 || cdd_stat.u0 == 0xf);


    cddCmd_playFastF();

    for (i = 0; i < 25; i++) {
        cddUpdate();
        cddPrint();
    }

    sysJoyWait();
}

u8 testBootSeq1() {

    u16 i, u;
    u32 PT;
    static u32 seq[] = {0, 0, 0x00017201, 0x00017301, 0x00017401, 0x00020001, 0x00020101, 0x00020201};

    gConsPrint("Boot seq1...");

    cddInit(1);
    cdcInit();
    cdcDecoderON();

    cddCmd_getToc(4, 0);
    do {
        cddUpdate();
    } while (cdd_stat.u0 == 0xf);

    for (i = 0; i < 16; i++) cddUpdate();

    /*
        gConsPrint("play...");
        cddCmd_play(0x151139);
        cddUpdate();
        gAppendString("!");
        while (1);*/

    cddCmd_seek(0x170);
    do {
        cddUpdate();
    } while (cdd_stat.status != 4 || cdd_stat.u0 == 0xf);



    cddCmd_play(0x173);
    do {
        cddUpdate();
    } while (cdd_stat.status != 1 || cdd_stat.u0 == 0xf);


    for (i = 0; i < 8; i++) {

        cdcRegSelect(CDC_HEAD0 + 4);

        PT = cdcRegRead();
        PT |= cdcRegRead() << 8;

        cdcDma(CDC_DST_PRG, 0x20000 + i * 2048, PT, 2048);
        cdcDmaBusy();

        cddUpdate();
    }

    cddCmd_stop();
    cddUpdate();

    for (i = 0; i < 4; i++) {
        gConsPrint("DAT: ");
        for (u = 0; u < 16; u++) {
            gAppendHex8(mcdRD8(0x20000 + i * 2048 + u));
        }
    }

    u8 seq_ok = 1;
    u32 val;
    for (i = 2; i < 8; i++) {
        val = mcdRD16(0x20000 + i * 2048 + 0) << 16;
        val |= mcdRD16(0x20000 + i * 2048 + 2);
        if (val != seq[i])seq_ok = 0;
    }

    gConsPrint("seq ok: ");
    gAppendNum(seq_ok);

    return 0;
}

u8 testBootSeq2() {

    u16 i, u;
    u32 PT;
    static u32 seq[] = {0x00020001, 0x00020101, 0x00020201, 0x00020301, 0x00020401, 0x00020501, 0x00020601, 0x00020701};

    gConsPrint("Boot seq2...");

    cddInit(1);
    cdcInit();
    cdcDecoderON();

    cddCmd_getToc(4, 0);
    do {
        cddUpdate();
    } while (cdd_stat.u0 == 0xf);

    for (i = 0; i < 16; i++) cddUpdate();

    cddCmd_seek(0x170);
    do {
        cddUpdate();
    } while (cdd_stat.status != 4 || cdd_stat.u0 == 0xf);


    cddCmd_play(0x173);
    while (1) {
        cddUpdate();
        if (cdd_stat.status != 1 || cdd_stat.u0 == 0xf)continue;
        if (cdd_stat.arg[3] == 2 && cdd_stat.arg[4] == 0 && cdd_stat.arg[5] == 0)break;
    }


    for (i = 0; i < 8; i++) {

        cdcRegSelect(CDC_HEAD0 + 4);

        PT = cdcRegRead();
        PT |= cdcRegRead() << 8;

        cdcDma(CDC_DST_PRG, 0x20000 + i * 2048, PT, 2048);
        cdcDmaBusy();

        cddUpdate();
    }

    cddCmd_stop();
    cddUpdate();

    for (i = 0; i < 4; i++) {
        gConsPrint("DAT: ");
        for (u = 0; u < 16; u++) {
            gAppendHex8(mcdRD8(0x20000 + i * 2048 + u));
        }
    }

    u8 seq_ok = 1;
    u32 val;
    for (i = 0; i < 8; i++) {
        val = mcdRD16(0x20000 + i * 2048 + 0) << 16;
        val |= mcdRD16(0x20000 + i * 2048 + 2);
        if (val != seq[i])seq_ok = 0;
    }

    gConsPrint("seq ok: ");
    gAppendNum(seq_ok);

    return 0;
}

void tstAppendREF(u32 ref) {

    gAppendString(" (");
    if (ref < 0x100) {
        gAppendHex8(ref);
    } else {
        gAppendHex16(ref);
    }
    gAppendString(")");
}

u8 testTimings() {

    u16 irq, i;
    u8 seq_irq[8];
    u32 seq_time[8];
    u8 seq_ctr = 0;
    u32 timer = 0;
    u32 seek_time = 0;
    u32 play_time = 0;
    u32 paus_time = 0;
    u32 resu_time = 0;
    u32 stop_time = 0;

    gConsPrint("Timings.....");

    cdcDecoderON();


    cddCmd_stop();
    do {
        cddUpdate();
    } while (cdd_stat.status != 0);

    cddCmd_seek(0x170);
    do {
        cddUpdate();
        seek_time++;
    } while (cdd_stat.status != 4 || cdd_stat.u0 == 0xf);


    cddCmd_play(0x173);
    do {
        cddUpdate();
        play_time++;
    } while (cdd_stat.status != 1 || cdd_stat.u0 == 0xf);


    while (seq_ctr < 8) {

        timer++;
        irq = ga->COMSTA[3];
        if (irq != 5 && irq != 4)continue;
        mcdRD16(0);
        if (irq == 4) {
            cddCmdTX();
            cddStatusRX();
            cddCmd_nop();
        }

        seq_irq[seq_ctr] = irq;
        seq_time[seq_ctr] = timer;

        timer = 0;
        seq_ctr++;
    }


    cddCmd_pause();
    do {
        cddUpdate();
        paus_time++;
    } while (cdd_stat.status != 4 || cdd_stat.u0 == 0xf);

    cddCmd_resume();
    do {
        cddUpdate();
        resu_time++;
    } while (cdd_stat.status != 1 || cdd_stat.u0 == 0xf);

    cddCmd_stop();
    do {
        cddUpdate();
        stop_time++;
    } while (cdd_stat.status != 0);

    for (i = 0; i < sizeof (seq_irq); i++) {
        gConsPrint("seq: ");
        gAppendHex8(seq_irq[i]);
        gAppendString(".");
        gAppendHex32(seq_time[i]);

        if (i % 2 == 0)tstAppendREF(5);
        if (i % 2 == 1)tstAppendREF(4);
        if (seq_irq[i] == 5)tstAppendREF(0x335);
        if (seq_irq[i] == 4)tstAppendREF(0xEA);
    }

    gConsPrint("seek time: ");
    gAppendNum(seek_time);
    tstAppendREF(0x198);

    gConsPrint("play time: ");
    gAppendNum(play_time);
    tstAppendREF(0x5);

    gConsPrint("paus time: ");
    gAppendNum(paus_time);
    tstAppendREF(0x4);

    gConsPrint("resu time: ");
    gAppendNum(resu_time);
    tstAppendREF(0x7);

    gConsPrint("stop time: ");
    gAppendNum(stop_time);
    tstAppendREF(0x2);

    return 0;
}

u8 testCddSync() {

    u32 i;
    u16 irq;
    u32 cdc_hdr = 0;
    u32 hdr_ctr = 0;
    u32 irq_ctr = 0;
    //u16 WA = 0;
    //u16 PT = 0;
    u32 stat = 0;
    u8 *ptr;


    gConsPrint("CDD SYNC....");

    cddCmd_stop();
    cddUpdate();

    cdcInit();
    cdcDecoderON(); //enable decoder and buffer writes

    cddCmd_play(0x300);
    cddUpdate();

    while (1) {

        irq = ga->COMSTA[3];
        if (irq != 5)continue; //wait cdc irq

        cdcRegSelect(CDC_HEAD0);
        for (i = 0; i < 4; i++) {
            cdc_hdr <<= 8;
            cdc_hdr |= cdcRegRead();
        }

        if ((cdc_hdr & 0xff0000ff) == 0x00000001) {
            hdr_ctr++;
        }

        irq_ctr++;

        if (cdc_hdr == 0x00030001)break;
    }

    cddUpdate();
    ptr = (u8 *) & cdd_stat;
    for (i = 0; i < 8; i++) {
        stat <<= 4;
        stat |= *ptr++;
    }

    /*
        gConsPrint("hdr_ctr: ");
        gAppendNum(hdr_ctr);
        gConsPrint("irq_ctr: ");
        gAppendNum(irq_ctr);

        //cddPrint();

        gConsPrint("stat: ");
        gAppendHex32(stat);
        gConsPrint("");*/

    if (stat != 0x10000300) {
        gAppendHex32(stat);
        gAppendString(".");
        return 1; //status in cdd should match to cdc head
    }
    if (cdd_stat.u1 != 4)return 2; //status bit shown if this is data track
    if (cdd_stat.crc != 7)return 3; //check cmd crc
    if (hdr_ctr < 1 || hdr_ctr > 4) {
        gAppendNum(hdr_ctr);
        gAppendString(".");
        return 4; //cdc should receive sectors at 1-2 sectores proir required
    }
    //if (irq_ctr < 100)return 5; //very rough check. seek time shoudn't be too short. cdx shown 0xf3 usually

    cddCmd_pause();
    for (i = 0; i < 8; i++) {
        cddUpdate();
    }

    while (1) {
        irq = ga->COMSTA[3];
        if (irq != 5)continue; //will hang if cdc irq isn't work when read stopped
        cdcRegSelect(CDC_HEAD0);
        for (i = 0; i < 4; i++) {
            cdc_hdr <<= 8;
            cdc_hdr |= cdcRegRead();
        }
        break;
    }

    if (cdc_hdr != 0x01800060)return 6; //this value should be in head registers when transfer off



    cddCmd_stop();
    for (i = 0; i < 16; i++)cddUpdate();


    for (i = 0;; i++) {
        if (ga->COMSTA[3] == 5)break; //cdc irq should work even if transfer stopped
        //gVsync();
        if (i == 0x10000)return 7;
    }


    i = 0;
    mcdRD16(0); //reset COMSTA[3]
    while (ga->COMSTA[3] != 5);
    mcdRD16(0);
    while (ga->COMSTA[3] != 5)i++;
    if (i < 2178 || i > 2198) {
        if (i < 2600 || i > 2700)return 8; //cdc irq time. regular time is 2188 or around 2652
    }

    /*
     gConsPrint("irq time: ");
     gAppendNum(i);
     gConsPrint("");*/


    cddCmd_seek(0x400);
    for (i = 0; i < 64; i++)cddUpdate();
    hdr_ctr = 0;
    irq_ctr = 0;

    cddCmd_resume();
    cddUpdate();

    while (1) {

        irq = ga->COMSTA[3];
        if (irq != 5)continue; //wait cdc irq

        cdcRegSelect(CDC_HEAD0);
        for (i = 0; i < 4; i++) {
            cdc_hdr <<= 8;
            cdc_hdr |= cdcRegRead();
        }

        if ((cdc_hdr & 0xff0000ff) == 0x00000001) {
            hdr_ctr++;
        }

        irq_ctr++;
        /*
                if(irq_ctr < 16){
                    gConsPrint("cdc_hdr: ");
                    gAppendHex32(cdc_hdr);
                }*/

        if (cdc_hdr == 0x00040001)break;
    }

    /*
        gConsPrint("hdr_ctr: ");
        gAppendNum(hdr_ctr);
        gConsPrint("irq_ctr: ");
        gAppendNum(irq_ctr);*/

    //if (irq_ctr < 100 || irq_ctr > 300)return 9; //very rough check. seek time shoudn't be too short. cdx shown 180 usually
    if (hdr_ctr < 1 || hdr_ctr > 4)return 10; //2 usualy



    return 0;
}

u8 testCddRD1() {

    u16 i;
    u8 buff[2352 + 32];
    u32 mem_off = 0x20000;
    u16 *ptr16;

    gConsPrint("CDD RD1.....");


    for (i = 0; i < sizeof (buff); i += 2) {
        mcdWR16(mem_off + i, 0xAAAA);
    }


    mcdWramSetMode(WRAM_MODE_2M);
    mcdWramToMain();
    memSet(&mcd->word_ram[mem_off], 0xaa, sizeof (buff));
    mcdWramToSub();


    cdcDecoderON(); //enable decoder and buffer writes
    cddReadCD(0x300, mem_off, 2352 + 5, CDC_DST_PRG);
    cddReadCD(0x300, mem_off, 2352 + 5, CDC_DST_WRAM);


    mcdWramToMain();
    for (i = 0; i < sizeof (buff); i++) {
        buff[i] = mcdRD8(mem_off + i);
    }

    /*
    gPrintHex(&buff[2352 - 16], 16);
    gPrintHex(&buff[2352], 16);
    gConsPrint("");*/

    //check sector header
    if (buff[0] != 0x00)return 1;
    if (buff[1] != 0x03)return 1;
    if (buff[2] != 0x00)return 1;
    if (buff[3] != 0x01)return 1;


    //check next sector header
    if (buff[0 + 2352] != 0x00)return 2;
    if (buff[1 + 2352] != 0x03)return 2;
    if (buff[2 + 2352] != 0x01)return 2;
    if (buff[3 + 2352] != 0x01)return 2;

    //dma len is correct? should ignore odd numbers
    if (buff[4 + 2352] != 0xaa)return 3;
    if (buff[5 + 2352] != 0xaa)return 3;


    /*
        gPrintHex(buff, 32);
        gConsPrint("");
        gPrintHex(&mcd->word_ram[mem_off], 32);*/

    //compare same sector readed to wordram and prgram
    for (i = 0; i < sizeof (buff); i++) {
        if (buff[i] != mcd->word_ram[mem_off + i]) {
            return 4;
        }
    }

    //read via io port to main cpu
    cddReadCD(0x300, mem_off, 2352 + 5, CDC_DST_MAIN);

    ptr16 = (u16 *) buff;
    for (i = 0; i < 2352 + 4; i += 2) {
        while ((*((vu16 *) 0x0A12004) & 0x4000) == 0); //will hang if dma is too short
        *ptr16++ = *((u16 *) 0x0A12008);
    }
    if ((*((vu16 *) 0x0A12004) & 0x4000) == 0x4000)return 6; //dma len too long


    //compare same sector readed to wordram and via main cpu io
    for (i = 0; i < sizeof (buff); i++) {
        if (buff[i] != mcd->word_ram[mem_off + i])return 7;
    }



    //read via io port to sub cpu
    cddReadCD(0x300, mem_off, 2352 + 5, CDC_DST_SUB);
    ptr16 = (u16 *) buff;
    for (i = 0; i < 2352 + 4; i += 2) {
        while ((*((vu16 *) 0x0A12004) & 0x4000) == 0); //will hang if dma is too short
        *ptr16++ = mcdRD16(SUB_REG_CDC_HDAT);
    }
    if ((*((vu16 *) 0x0A12004) & 0x4000) == 0x4000)return 8; //dma len too long

    //compare same sector readed to wordram and via sub cpu io
    for (i = 0; i < sizeof (buff); i++) {
        if (buff[i] != mcd->word_ram[mem_off + i])return 9;
    }

    return 0;
}

u8 testCddRD2() {

    u32 addr = 0;
    u32 i;
    u32 cdc_hdr = 0;
    u8 sync_req = 1;
    u16 PT = 0;


    gConsPrint("CDD RD2.....");

    mcdWramToSub();
    cddCmd_stop();
    for (i = 0; i < 32; i++)cddUpdate();

    cdcDecoderON();
    cddCmd_play(0x200);
    cddUpdate();

    while (addr < 0x40000 - MCD_SECTOR_SIZE) {

        while (ga->COMSTA[3] != 5);
        cdcRegSelect(CDC_HEAD0);

        for (i = 0; i < 4; i++) {
            cdc_hdr <<= 8;
            cdc_hdr |= cdcRegRead();
        }

        PT = cdcRegRead();
        PT |= cdcRegRead() << 8;

        if (cdc_hdr == 0x00020001)sync_req = 0;
        if (sync_req)continue;

        cdcDma(CDC_DST_WRAM, addr, PT, MCD_SECTOR_SIZE);
        addr += MCD_SECTOR_SIZE;
        //cdcDmaBusy();
    }

    cdcDmaBusy();
    mcdWramToMain();

    /*
        gConsPrint("");
        for (i = 0; i < 16; i++) {
            gPrintHex(&mcd->word_ram[i * MCD_SECTOR_SIZE], 16);
        }
        gConsPrint("");*/

    u8 sec = 2;
    u8 fra = 0;

    for (i = 0; i < 0x40000 - MCD_SECTOR_SIZE; i += MCD_SECTOR_SIZE) {

        if (mcd->word_ram[i + 0] != 0)return 1;
        if (mcd->word_ram[i + 1] != sec)return 2;
        if (mcd->word_ram[i + 2] != fra)return 3;
        if (mcd->word_ram[i + 3] != 1)return 4;

        fra++;
        if ((fra & 0x0f) == 0x0A) {
            fra &= 0xf0;
            fra += 0x10;
        }

        if (fra == 0x75) {
            fra = 0;
            sec++;
        }
    }


    return 0;
}

u8 readSectorFast() {

    // u16 ctr = 0;
    u16 PT;
    u32 i;
    u32 cdc_hdr = 0;

    gConsPrint("CDD QRD.....");

    cddInit(0);
    cdcInit();
    cdcDecoderON();
    mcdWramSetMode(WRAM_MODE_2M);
    mcdWramToSub();

    //cddCmd_play(0x15631);
    cddCmd_play(0x173);
    cddUpdate();

    while (1) {

        if (ga->COMSTA[3] != 5)continue;
        cdcRegSelect(CDC_HEAD0);
        for (i = 0; i < 4; i++) {
            cdc_hdr <<= 8;
            cdc_hdr |= cdcRegRead();
        }

        PT = cdcRegRead();
        PT |= cdcRegRead() << 8;

        //if (cdc_hdr == 0x01563301)break;
        if (cdc_hdr == 0x020001)break;
    }


    cdcDma(CDC_DST_SUB, 0, PT, MCD_SECTOR_SIZE);

    mcdReadSector(0x80000);
    mcdRD16(0);
    if ((ga->CDC_MOD & 0xC0) != 0x80)return 1; //check data transfer flags

    cddCmd_play(0x173);
    cddUpdate();

    while (1) {

        if (ga->COMSTA[3] != 5)continue;
        cdcRegSelect(CDC_HEAD0);
        for (i = 0; i < 4; i++) {
            cdc_hdr <<= 8;
            cdc_hdr |= cdcRegRead();
        }

        PT = cdcRegRead();
        PT |= cdcRegRead() << 8;

        //if (cdc_hdr == 0x01563301)break;
        if (cdc_hdr == 0x020001)break;
    }

    cdcDma(CDC_DST_WRAM, MCD_SECTOR_SIZE, PT, MCD_SECTOR_SIZE);
    while ((ga->CDC_MOD & 0xC0) != 0x80);

    mcdWramToMain();
    //compare readed via dma and via sub
    for (i = 0; i < MCD_SECTOR_SIZE; i++) {
        if (mcd->word_ram[i] != mcd->word_ram[i + MCD_SECTOR_SIZE]) {
            mcdWramToSub();
            return 2;
        }
    }


    mcdWramToSub();


    return 0;
    //sysJoyWait();
    /*
    gConsPrint("statrus: ");
    gAppendHex8(ga->CDC_MOD);

    gConsPrint("sector: ");
    gPrintHex(mcd->word_ram, 256);*/
    /*
    cddCmd_play(0x173);
    cddUpdate();

    while (1) {

        if (ga->COMSTA[3] != 5)continue;
        cdcRegSelect(CDC_HEAD0);
        for (i = 0; i < 4; i++) {
            cdc_hdr <<= 8;
            cdc_hdr |= cdcRegRead();
        }

        PT = cdcRegRead();
        PT |= cdcRegRead() << 8;

        //if (cdc_hdr == 0x01563301)break;
        if (cdc_hdr == 0x020001)break;
    }


    cdcDma(CDC_DST_WRAM, 2352, PT, MCD_SECTOR_SIZE);

    mcdWramToMain();

    for (i = 0; i < MCD_SECTOR_SIZE; i++) {
    }*/


}
