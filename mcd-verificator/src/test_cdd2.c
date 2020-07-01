
#include "main.h"

u32 seekSector(u32 sector);
u32 playSector(u32 sector);
void testPauseResume();
void testLatency();
void testREX();
void testSeqStat();
void testCddCmd();

void testCDD2() {


    u16 i;
    u32 addr = SUB_BRAM + 16384 - 512;
    int ctr = 0;

    cddInit(0);
    cdcInit();
    cdcDecoderON();

    while (1) {

        while (ga->COMSTA[3] != 5);
        gSetXY(0, 8);
        gAppendNum(ctr++);
        gConsPrint("0x8000: ");
        gAppendHex16(mcdRD16(0xff8000));

        mcdRD16(SUB_BRAM);
        for (i = 0; i < 8; i++)gVsync();

        mcdRD16(SUB_BRAM + 2);
        for (i = 0; i < 8; i++)gVsync();

        mcdWR16(SUB_BRAM + 4, 0x1234);
        for (i = 0; i < 8; i++)gVsync();

        mcdWR8(SUB_BRAM + 8, 0xab);
        for (i = 0; i < 8; i++)gVsync();
    }

    for (i = 0; i < 256; i++) {
        if (i % 16 == 0)gConsPrint("");
        gAppendHex8(mcdRD8(addr + 1));
        addr += 2;
    }
    sysJoyWait();


    testCddCmd();

    testSeqStat();
    //testREX();
    testPauseResume();

    testLatency();
    sysJoyWait();
}

void testCddCmd() {

    u16 i;
    gCleanPlan();
    mcdInit();
    u8 old_state[2];
    u16 ctr = 0;

    // gVsync();
    mcdWR16(SUB_REG_IEMASK, (1 << 4) | (1 << 5)); //enable cdc and cdd interrupts
    mcdWR16(0xff8036, 4); //HOCK
    cddCmd_nop();

    old_state[0] = 0xaa;
    old_state[1] = 0x55;
    for (i = 0; i < 20;) {
        cddUpdate();
        ctr++;

        if (old_state[0] == cdd_stat.status && old_state[1] == cdd_stat.u0)continue;
        if (cdd_stat.status == 0x9 && cdd_stat.u0 == 0xf)continue;
        if (cdd_stat.status == 0x2 && cdd_stat.u0 == 0xf)continue;
        old_state[0] = cdd_stat.status;
        old_state[1] = cdd_stat.u0;


        if (old_state[0] == 0x0 && old_state[1] == 0xf) {
            cddCmd_getToc(4, 0);
        }

        if (old_state[0] == 0x9 && old_state[1] == 0x4) {
            cddCmd_getToc(3, 0);
        }

        if (old_state[0] == 0x9 && old_state[1] == 0x3) {
            cddCmd_getToc(5, 0x0100);
        }

        if (old_state[0] == 0x9 && old_state[1] == 0x5) {
            cddCmd_seek(0x170);
        }

        if (old_state[0] == 0x4 && old_state[1] == 0x0) {
            cddCmd_play(0x173);
        }



        cddPrint();
        gAppendString(", ");
        gAppendNum(ctr - 1);
        i++;


        if (old_state[0] == 0x1 && old_state[1] == 0x0) {
            cddCmd_stop();
            break;
        }
    }


    for (; i < 20;) {
        cddUpdate();
        ctr++;

        if (old_state[0] == 0x0 && old_state[1] == 0xf) {
            cddCmd_getToc(5, 0);
        }

        if (old_state[0] == cdd_stat.status && old_state[1] == cdd_stat.u0)continue;
        if (cdd_stat.status == 0x9 && cdd_stat.u0 == 0xf)continue;
        if (cdd_stat.status == 0x2 && cdd_stat.u0 == 0xf)continue;
        if (cdd_stat.status == 0x7 && cdd_stat.u0 == 0xf)continue;
        old_state[0] = cdd_stat.status;
        old_state[1] = cdd_stat.u0;


        cddPrint();
        gAppendString(", ");
        gAppendNum(ctr - 1);
        i++;
    }

    sysJoyWait();
}

void testSeqStat() {

    gCleanPlan();
    cdcInit();
    cddInit(0);
    cdcDecoderON();
    u32 seq[32];
    u32 stat[32];
    u8 ifstat[32];

    gConsPrint("xxx...");

    u16 i = 0;
    u16 u = 0;
    u32 PT = 0;
    u32 cdc_hdr = 0;

    mcdWramToSub();
    cddCmd_play(0x173);
    cddUpdate();

    gAppendString("!");

    for (u = 0; u < 20;) {



        while (ga->COMSTA[3] != 5);


        //cdcRegSelect(CDC_HEAD0);
        cdcRegSelect(1);
        ifstat[u] = cdcRegRead();
        cdcRegRead();
        cdcRegRead();

        for (i = 0; i < 4; i++) {
            cdc_hdr <<= 8;
            cdc_hdr |= cdcRegRead();
        }

        PT = cdcRegRead();
        PT |= cdcRegRead() << 8;

        cdcRegRead();
        cdcRegRead();

        stat[u] = 0;
        for (i = 0; i < 4; i++) {
            stat[u] <<= 8;
            stat[u] |= cdcRegRead();
        }

        //gConsPrint("zz: ");
        //gAppendHex32(cdc_hdr);
        if ((cdc_hdr & 0xff0000ff) != 0x00000001)continue;


        cdcDma(CDC_DST_WRAM, u * 2352, PT, 2352);
        seq[u] = cdc_hdr;
        u++;
    }

    mcdWramToMain();
    for (i = 0; i < 8; i++) {

        //gConsPrint("");
        //gAppendHex32(seq[i]);
        gPrintHex(&mcd->word_ram[i * 2352], 8);
        gAppendString(" ");
        gAppendHex8(ifstat[i]);
        gAppendString(".");
        gAppendHex32(seq[i]);
        gAppendString(".");
        gAppendHex32(stat[i]);


        gPrintHex(&mcd->word_ram[i * 2352 + 2352 - 16], 8);
        gConsPrint("");
    }


    sysJoyWait();
}

void testREX() {

    gCleanPlan();
    cdcInit();
    cddInit(0);
    cdcDecoderON();


    gConsPrint("test rex...");

    cddCmd_stop();
    do {
        cddUpdate();
    } while (cdd_stat.status != 0);



    cddCmd_pause();
    do {
        cddUpdate();
    } while (cdd_stat.status != 4 || cdd_stat.u0 != 0);


    cddUpdate();
    cddCmd_play(0x10570);

    while (1) {
        cddUpdate();
        if (cdd_stat.status != 1)continue;
        if (cdd_stat.u0 != 0)continue;

        if (cdd_stat.arg[3] != 5)continue;
        if (cdd_stat.arg[4] != 6)continue;
        if (cdd_stat.arg[5] != 9)continue;

        break;
    }

    u16 i = 0;
    while (1) {

        cddCmd_getToc(i++ % 3, 0);
        cddUpdate();
    }

    gConsPrint("ok");
    sysJoyWait();
}

void testPauseResume() {

    u32 cdc_hdr = 0;
    u16 i;
    u16 u = 0;
    u8 loop;

    gConsPrint("test pause");

    gCleanPlan();
    cdcInit();
    cddInit(0);
    cdcDecoderON();

    cddCmd_play(0x300);
    do {
        cddUpdate();
    } while (cdd_stat.status != 1);



    while (1) {

        while (ga->COMSTA[3] != 5);

        cdcRegSelect(CDC_HEAD0);
        for (i = 0; i < 4; i++) {
            cdc_hdr <<= 8;
            cdc_hdr |= cdcRegRead();
        }

        cddUpdate();
        if (cdd_stat.arg[4] == 2 && cdd_stat.arg[5] == 0)break;

        /*
                cddPrint();
                gAppendString(", ");
                gAppendHex32(cdc_hdr);
                if (u++ == 16)break;*/
    }

    cddCmd_pause();
    loop = 0;
    while (1) {

        while (ga->COMSTA[3] != 5);

        cdcRegSelect(CDC_HEAD0);
        for (i = 0; i < 4; i++) {
            cdc_hdr <<= 8;
            cdc_hdr |= cdcRegRead();
        }

        cddUpdate();
        if (cdd_stat.u0 == 15)continue;

        if (cdd_stat.arg[4] == 1 && cdd_stat.arg[5] == 9)loop++;
        if (loop == 2)break;

        /*
                cddPrint();
                gAppendString(", ");
                gAppendHex32(cdc_hdr);
                if (u++ == 23)break;*/
    }
    //while(1);

    cddCmd_resume();

    while (1) {

        while (ga->COMSTA[3] != 5);

        cdcRegSelect(CDC_HEAD0);
        for (i = 0; i < 4; i++) {
            cdc_hdr <<= 8;
            cdc_hdr |= cdcRegRead();
        }

        cddUpdate();

        cddPrint();
        gAppendString(", ");
        gAppendHex32(cdc_hdr);
        if (u++ == 23)break;
    }

    sysJoyWait();
}

void testLatency() {

    u16 i;
    u32 time;
    u32 time_min, time_max, time_mid;
    u32 sector;

    gCleanPlan();
    cdcInit();
    cddInit(1);


    time = 0;
    cddCmd_getToc(4, 0);

    do {
        cddUpdate();
        time++;
    } while (cdd_stat.u0 != 0x4);

    for (i = 0; i < 16; i++) cddUpdate();
    cddCmd_getToc(0, 0);
    for (i = 0; i < 16; i++) cddUpdate();

    gConsPrint("toc init:  ");
    gAppendNum(time);



    time = seekSector(0x200);
    gConsPrint("seek 200:  ");
    gAppendNum(time);

    time = seekSector(0x200);
    gConsPrint("seek 200:  ");
    gAppendNum(time);

    time = seekSector(0x400);
    gConsPrint("seek 400:  ");
    gAppendNum(time);

    time = seekSector(0x10200);
    gConsPrint("seek 01M:  ");
    gAppendNum(time);

    time = seekSector(0x110200);
    gConsPrint("seek 10M:  ");
    gAppendNum(time);

    time = seekSector(0x210200);
    gConsPrint("seek 10M:  ");
    gAppendNum(time);

    seekSector(0x300);
    time = playSector(0x300);
    gConsPrint("play 300:  ");
    gAppendNum(time);

    time = playSector(0x300);
    gConsPrint("play 300:  ");
    gAppendNum(time);

    time = playSector(0x400);
    gConsPrint("play 400:  ");
    gAppendNum(time);

    time = playSector(0x300);
    gConsPrint("play 300:  ");
    gAppendNum(time);

    seekSector(0x10000);

    sector = 0x10000;
    time_min = 0xffff;
    time_max = 0;
    time_mid = 0;
    for (i = 0; i < 8; i++) {

        sector += 0x00100;
        time = seekSector(sector);
        if (time_min > time)time_min = time;
        if (time_max < time)time_max = time;
        time_mid += time;

    }

    gConsPrint("");
    gConsPrint("seek 01Sx8");
    gConsPrint("time min:  ");
    gAppendNum(time_min);
    gConsPrint("time max:  ");
    gAppendNum(time_max);
    gConsPrint("time mid:  ");
    gAppendNum(time_mid / 8);


    time_min = 0xffff;
    time_max = 0;
    time_mid = 0;
    for (i = 0; i < 4; i++) {

        sector += 0x01000;
        time = seekSector(sector);
        if (time_min > time)time_min = time;
        if (time_max < time)time_max = time;
        time_mid += time;
    }

    gConsPrint("");
    gConsPrint("seek 10Sx4");
    gConsPrint("time min:  ");
    gAppendNum(time_min);
    gConsPrint("time max:  ");
    gAppendNum(time_max);
    gConsPrint("time mid:  ");
    gAppendNum(time_mid / 4);

}

u32 seekSector(u32 sector) {

    u32 time = 0;

    cddCmd_seek(sector);
    do {
        time++;
        cddUpdate();
    } while (cdd_stat.status == 4);

    do {
        cddUpdate();
        time++;
    } while (cdd_stat.status != 0x4 || cdd_stat.u0 == 0xf);

    return time;
}

u32 playSector(u32 sector) {

    u32 time = 0;

    cddCmd_play(sector);
    do {
        time++;
        cddUpdate();
    } while (cdd_stat.status == 1);


    do {
        cddUpdate();
        time++;
    } while (cdd_stat.status != 0x1 || cdd_stat.u0 == 0xf);

    return time;
}
