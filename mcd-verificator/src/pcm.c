

#include "main.h"



u8 testPcmOPS();

u16 pcmGetAddr(u8 chan);
void pcmMakeSample(u16 addr, u16 len);

extern u8 pcm[32768];

void pcmX();

void testPCM() {

    u8 resp;

    mcdInit();
    gCleanPlan();


    while (1) {
        gCleanPlan();
        pcmX();
    }

    resp = pcmTestRam();
    testPrintResp(resp);

    resp = pcmTestClocking();
    testPrintResp(resp);



    //pcmBeepTest();
    //pcmTmp();

    sysJoyWait();
}

void pcmX() {

    u32 i;
    PcmChan chan = {0};
    u8 sample[9];
    u16 addr_db[512];
    u16 reload_addr = 0x204;

    memSet(addr_db, 0, sizeof (addr_db));


    memSet(sample, 0, sizeof (sample));
    sample[0] = 0x00;

    sample[sizeof (sample) - 1] = 0xff;
    pcmMemWrite(sample, 0x100, sizeof (sample));
    sample[0] = 0; //0xff;
    pcmMemWrite(sample, reload_addr, sizeof (sample));


    pcmWrite(PCM_OFF_SW, 0xff);
    pcmWrite(PCM_CTRL, CTRL_ON);


    pcmWrite(PCM_CTRL, CTRL_ON | CTRL_MOD_CHAN);
    chan.st = 0x01;
    chan.ls = reload_addr;
    chan.fd = 20;
    chan.pan = 0xff;
    chan.env = 0x80;
    pcmChanSet(0, &chan);


    pcmWrite(PCM_OFF_SW, 0xfe);

    u16 addr1 = pcmRead(16);
    u16 addr2 = pcmRead(16);
    gConsPrint("addr: ");
    gAppendHex16(addr1);
    gConsPrint("addr: ");
    gAppendHex16(addr2);

    /*
    u8 buffx[32];
    pcmMemRead(buffx, 0x100, 32);
    gPrintHex(buffx, 32);
    gConsPrint("");
    pcmMemRead(buffx, 0x204, 32);
    gPrintHex(buffx, 32);
    sysJoyWait();*/



    for (i = 0; i < 512; i++) {
        addr_db[i] = (pcmRead(17) << 8) | pcmRead(16);
        if (addr_db[i] == 0x104) {
            pcmWrite(PCM_CTRL, CTRL_OFF | CTRL_MOD_CHAN | 1);
            pcmWrite(PCM_CTRL, CTRL_ON | CTRL_MOD_CHAN | 1);

        }
    }


    u16 pos = 0;
    u16 skip = 0;
    for (i = 0; i < 24 + skip; i++) {


        u16 val = addr_db[pos];
        u16 ctr = 0;
        while (val == addr_db[pos]) {
            pos++;
            ctr++;
            if (pos >= 512)break;
        }
        if (pos >= 512)break;

        if (i < skip)continue;
        gConsPrint("val ");
        gAppendHex8(i);
        gAppendString(": ");
        gAppendHex16(val);
        gAppendString("=");
        gAppendNum(ctr);

        /*
        gConsPrint("ctr ");
        gAppendNum(i);
        gAppendString(": ");
        gAppendHex16(ctr[0][i]);
        gAppendString(", ");
        gAppendHex16(ctr[1][i]);
        gAppendString(", ");
        gAppendHex16(ctr[2][i]);*/
    }

    sysJoyWait();
}

void pcmChanSet(u8 chan, PcmChan *pcm) {

    pcmWrite(PCM_CTRL, CTRL_ON | CTRL_MOD_CHAN | chan);
    pcmWrite(PCMC_ENV, pcm->env);
    pcmWrite(PCMC_PAN, pcm->pan);
    pcmWrite(PCMC_FDH, pcm->fd >> 8);
    pcmWrite(PCMC_FDL, pcm->fd & 0xff);
    pcmWrite(PCMC_LSH, pcm->ls >> 8);
    pcmWrite(PCMC_LSL, pcm->ls & 0xff);
    pcmWrite(PCMC_ST, pcm->st & 0xff);
}

u16 pcmGetAddr(u8 chan) {

    return pcmRead(PCM_ADDR + chan * 2 + 0) | pcmRead(PCM_ADDR + chan * 2 + 1) << 8;
}

void pcmMakeSample(u16 addr, u16 len) {

    pcmWrite(PCM_CTRL, CTRL_ON | CTRL_MOD_ADDR | addr / 4096);
    addr %= 4096;
    addr += PCM_RAM;


    while (len--) {
        pcmWrite(addr++, 0x00);
    }

    pcmWrite(addr, 0xff);
}

u8 testPcmOPS() {

    u16 i;
    PcmChan pcm;
    gConsPrint("PCM OPS.....");

    pcm.env = 0x80;
    pcm.pan = 0xff;
    pcm.fd = 256;
    pcm.ls = 0; //reload addr
    pcm.st = 0; //start addr
    /*
        pcmWrite(PCM_OFF_SW, ~0x00);
        pcmMakeSample(0, 60);
        pcmWrite(PCM_RAM + 1, 0x7f);
        pcmWrite(PCM_RAM + 20, 0x7f);

        pcmChanSet(0, &pcm);
        pcmWrite(PCM_OFF_SW, ~0x01);

        //while (1);


        while (1) {


        }*/


    pcmWrite(PCM_OFF_SW, ~0x00);
    gVsync();
    pcmChanSet(0, &pcm);
    gVsync();
    pcmMakeSample(0, 2048);
    pcmWrite(PCM_OFF_SW, ~0x01);

    gConsPrint("");
    for (i = 0; i < 32; i++) {
        if (i % 8 == 0)gConsPrint("");
        gAppendHex16(pcmGetAddr(0));
        gAppendString(".");
    }

    u32 ctr = 0;

    while (pcmGetAddr(0) != 32);
    JOY_DATA_2 = 0x40;
    while (pcmGetAddr(0) == 32)ctr++;
    while (pcmGetAddr(0) != 32)ctr++;
    JOY_DATA_2 = 0x00;

    gConsPrint("stime: ");
    gAppendNum(ctr);




    pcmWrite(PCM_CTRL, CTRL_OFF);
    sysJoyWait();

    return 0;
}

void pcmWrite(u16 reg, u8 val) {

    mcdWR8(PCM_BASE + reg * 2 + 1, val);
}

u8 pcmRead(u16 reg) {

    return mcdRD8(PCM_BASE + reg * 2 + 1);

}

void pcmTmp() {

    u16 i;

    pcmWrite(PCM_CTRL, CTRL_OFF | CTRL_MOD_ADDR);

    for (i = 0; i < 4096; i++) {
        //if(i % 4 >= 2) continue;
        pcmWrite(PCM_RAM + i, (i & 1) ? 254 : 0);
    }

    pcmWrite(PCM_RAM + 4095, 0xff);


    pcmWrite(PCM_CTRL, CTRL_OFF | CTRL_MOD_CHAN | 0);

    pcmWrite(PCMC_ST, 0);
    pcmWrite(PCMC_LSH, 0);
    pcmWrite(PCMC_LSL, 0);
    pcmWrite(PCMC_FDH, 0);
    pcmWrite(PCMC_FDL, 1);
    pcmWrite(PCMC_PAN, 0xff); //0x0F-L, 0xF0-R
    pcmWrite(PCMC_ENV, 0xFF);

    pcmWrite(PCM_OFF_SW, ~1);
    pcmWrite(PCM_CTRL, CTRL_ON);

    gCleanPlan();
    while (1) {
        gSetXY(0, 0);
        for (i = 0; i < 8; i++) {
            gConsPrint("addr: ");
            gAppendHex16(pcmAddrRead(i));
        }
    }

    gConsPrint("");

    for (i = 0; i < 8; i++) {

        gConsPrint("xx:");
        gAppendHex16(mcdRD16(0xFF0020 + i * 4));
        gAppendString(".");
        gAppendHex16(mcdRD16(0xFF0022 + i * 4));
    }

    gConsPrint("");

    mcdWR16(0xFF0000 + PCM_RAM * 2, 0x1234);
    mcdWR16(0xFF0000 + PCM_RAM * 2 + 2, 0xabcd);
    mcdWR16(0xFF0000 + 0xFF0000, 0xaa55);


    gConsPrint("reg: ");
    gAppendHex16(mcdRD16(0xFF0000));
    gConsPrint("ram: ");
    gAppendHex16(mcdRD16(0xFF0000 + PCM_RAM * 2));
    gAppendString(".");
    gAppendHex16(mcdRD16(0xFF0000 + PCM_RAM * 2 + 2));

}

u16 pcmAddrRead(u8 channel) {

    u16 addr;
    channel *= 2;

    addr = pcmRead(PCM_ADDR + channel + 0);
    addr |= pcmRead(PCM_ADDR + channel + 1) << 8;

    return addr;
}

void pcmMemRead(u8 *dst, u16 addr, u16 len) {

    //pcmWrite(PCM_CTRL, CTRL_OFF | CTRL_MOD_ADDR | (addr / 4096));
    pcmSetBank(addr / 4096);

    while (len--) {

        if (addr % 4096 == 0) {
            //pcmWrite(PCM_CTRL, CTRL_OFF | CTRL_MOD_ADDR | (addr / 4096));
            pcmSetBank(addr / 4096);
        }

        *dst++ = pcmRead(PCM_RAM + addr % 4096);

        addr++;
    }



}

void pcmMemWrite(u8 *src, u16 addr, u16 len) {

    //pcmWrite(PCM_CTRL, CTRL_OFF | CTRL_MOD_ADDR | (addr / 4096));
    pcmSetBank(addr / 4096);

    while (len--) {

        if (addr % 4096 == 0) {
            //pcmWrite(PCM_CTRL, CTRL_OFF | CTRL_MOD_ADDR | (addr / 4096));
            pcmSetBank(addr / 4096);
        }

        pcmWrite(PCM_RAM + addr % 4096, *src++);

        addr++;
    }

}

void pcmSetBank(u8 bank) {

    pcmWrite(PCM_CTRL, CTRL_OFF | CTRL_MOD_ADDR | bank);

}

void pcmSampleWrite(u8 *src, u16 addr, u16 len, u8 state) {


    while (len--) {

        if (addr % 4096 == 0) {
            pcmWrite(PCM_CTRL, state | CTRL_MOD_ADDR | (addr / 4096));
        }

        u8 val = *src++;


        if (val == 0xff) {
        } else if (val & 0x80) {
            //val = 127 - (val & 0x7F);
            //val = 128 - val;
            //val |= 0x80;

        } else {

            val = 128 - val;
            val &= 0x7E;
        }

        pcmWrite(PCM_RAM + addr % 4096, val);

        //pcmRegWrite(PCM_RAM + addr % 4096, *src++);
        addr++;
    }

}

u8 pcmTestRam() {

    u32 i;
    u8 resp;

    gConsPrint("PCM RAM.....");
    pcmWrite(PCM_CTRL, CTRL_OFF | CTRL_MOD_ADDR);


    //check 256B block
    for (i = 0; i < 256; i++) {
        pcmWrite(PCM_RAM + i, i);
    }

    for (i = 0; i < 256; i++) {
        resp = pcmRead(PCM_RAM + i);
        if (resp != i) {
            return 1;
        }
    }


    //check one frame
    for (i = 0; i < 4096; i += 256) {
        pcmWrite(PCM_RAM + i, i / 256);
    }

    for (i = 0; i < 4096; i += 256) {
        resp = pcmRead(PCM_RAM + i);
        if (resp != i / 256) {
            return 2;
        }
    }

    //check whole ram
    for (i = 0; i < 0x10000; i += 256) {
        if (i % 4096 == 0) {
            pcmWrite(PCM_CTRL, CTRL_OFF | CTRL_MOD_ADDR | (i / 4096));
        }

        pcmWrite(PCM_RAM + i % 4096, i / 256);
    }

    for (i = 0; i < 0x10000; i += 256) {

        if (i % 4096 == 0) {
            pcmWrite(PCM_CTRL, CTRL_OFF | CTRL_MOD_ADDR | (i / 4096));
        }

        resp = pcmRead(PCM_RAM + i % 4096);
        if (resp != i / 256) {
            return 3;
        }
    }

    return 0;
}

u8 pcmTestClocking() {

    u16 i;
    u8 buff[4096];

    gConsPrint("PCM CLOCK...");

    for (i = 0; i < 4096; i++) {
        buff[i] = 0;
    }

    for (i = 0; i < 2; i++) {
        pcmSampleWrite(buff, i * 4096, 4096, CTRL_OFF);
    }


    for (i = 0; i < 8; i++) {

        pcmWrite(PCM_CTRL, CTRL_OFF | CTRL_MOD_CHAN | i);

        pcmWrite(PCMC_ST, 0);
        pcmWrite(PCMC_LSH, 0);
        pcmWrite(PCMC_LSL, 0);
        if (i < 4) {
            pcmWrite(PCMC_FDH, 0);
            pcmWrite(PCMC_FDL, 4 << i);
        } else if (i == 7) {

            pcmWrite(PCMC_FDH, 15);
            pcmWrite(PCMC_FDL, 15);
        } else {
            pcmWrite(PCMC_FDH, 1 << (i - 4));
            pcmWrite(PCMC_FDL, 0);
        }
        pcmWrite(PCMC_PAN, 0xff); //0x0F-L, 0xF0-R
        pcmWrite(PCMC_ENV, 0xFF);
    }

    pcmWrite(PCM_OFF_SW, 0);
    pcmWrite(PCM_CTRL, CTRL_ON | CTRL_MOD_CHAN);


    for (i = 0; i < 8192; i++)asm("nop");


    pcmWrite(PCM_CTRL, CTRL_OFF | CTRL_MOD_CHAN);

    /*
    gConsPrint("");
    for (i = 0; i < 8; i++) {
        gConsPrint("addr: ");
        gAppendNum(pcmAddrRead(i));
    }
    gConsPrint("");*/


    if (pcmAddrRead(1) != 2)return 1;
    if (pcmAddrRead(2) != 4)return 2;
    if (pcmAddrRead(3) != 9)return 3;
    if (pcmAddrRead(4) != 79)return 4;
    if (pcmAddrRead(5) != 159)return 5;
    if (pcmAddrRead(6) % 318 > 2)return 6;
    //if (pcmAddrRead(7) % 1199 > 4)return 7;





    return 0;
}

u8 pcmTestVar() {

    u16 tst_addr = 0;
    u16 i;
    u16 min, max, val;
    gConsPrint("PCM VAR.....");


    //check sample range
    pcmWrite(PCM_CTRL, CTRL_OFF | CTRL_MOD_ADDR);

    for (i = 0; i < 16; i++) {
        pcmWrite(PCM_RAM + tst_addr + i, 0);
    }

    pcmWrite(PCM_RAM + tst_addr + 15, 0xff);


    pcmWrite(PCM_CTRL, CTRL_OFF | CTRL_MOD_CHAN | 0);
    pcmWrite(PCMC_ST, tst_addr >> 8);
    pcmWrite(PCMC_LSH, tst_addr >> 8);
    pcmWrite(PCMC_LSL, tst_addr & 0xff);
    pcmWrite(PCMC_FDH, 0);
    pcmWrite(PCMC_FDL, 8);
    pcmWrite(PCMC_PAN, 0xff); //0x0F-L, 0xF0-R
    pcmWrite(PCMC_ENV, 0xFF);

    pcmWrite(PCM_OFF_SW, ~1);
    pcmWrite(PCM_CTRL, CTRL_ON | CTRL_MOD_CHAN | 0);
    val = pcmAddrRead(0);
    gVsync();

    min = 255;
    max = 0;

    for (i = 0; i < 4096; i++) {

        val = pcmAddrRead(0);
        if (val < min)min = val;
        if (val > max)max = val;
    }


    /*
        gConsPrint("");
        gConsPrint("min: ");
        gAppendNum(min);
        gConsPrint("max: ");
        gAppendNum(max);
        gConsPrint("");*/


    if (min != 0)return 1;
    if (max != 14)return 2;


    //if ctrl_on and PCM_ONOFF off - address should be reset to PCM_ST
    for (i = 0; i < 8; i++) {
        pcmWrite(PCM_CTRL, CTRL_OFF | CTRL_MOD_CHAN | i);
        pcmWrite(PCMC_ST, i);
        pcmWrite(PCMC_LSH, 0xbb);
        pcmWrite(PCMC_LSL, 0xaa);
        pcmWrite(PCMC_FDH, 1);
        pcmWrite(PCMC_FDL, 128);
    }

    pcmWrite(PCM_OFF_SW, 0xff);
    pcmWrite(PCM_CTRL, CTRL_ON);
    pcmWrite(PCM_OFF_SW, 0x00);
    gVsync();
    pcmWrite(PCM_OFF_SW, 0xff);


    /*
    gConsPrint("");
    for (i = 0; i < 8; i++) {
        gConsPrint("addr: ");
        gAppendHex16( pcmAddrRead(i));
    }
    gConsPrint("");*/

    for (i = 0; i < 8; i++) {

        pcmAddrRead(i); //may not read properly first time

        if (pcmAddrRead(i) != (i << 8)) {
            return 3;
        }
    }


    return 0;
}

void pcmBeepTest() {

    u16 i, joy;
    u8 buff[4096];
    u8 vol = 128;

    for (i = 0; i < sizeof (buff); i++) {
        buff[i] = (i & 1) ? 64 : 127;
    }

    //buff[sizeof (buff) - 1] = 0xff;
    buff[128] = 0xff;

    pcmSampleWrite(buff, 0, sizeof (buff), CTRL_OFF);

    while (1) {

        gSetXY(0, 8);
        gConsPrint("env: ");
        gAppendNum(vol);
        gAppendString("   ");

        joy = sysJoyWait();

        if (joy == JOY_STA) {
            pcmWrite(PCM_OFF_SW, 0xff);
            pcmWrite(PCM_CTRL, CTRL_OFF);
            pcmWrite(PCMC_PAN, 0xff);
            continue;
        }

        if (joy == JOY_L) {
            pcmWrite(PCMC_PAN, 0x0F);
            continue;
        }

        if (joy == JOY_R) {
            pcmWrite(PCMC_PAN, 0xF0);
            continue;
        }

        if (joy == JOY_U) {
            vol += 16;
            pcmWrite(PCMC_ENV, vol);
            continue;
        }

        if (joy == JOY_D) {
            vol -= 16;
            pcmWrite(PCMC_ENV, vol);
            continue;
        }

        pcmWrite(PCM_OFF_SW, 0xff);
        vol = 128;

        //for (i = 0; i < 8; i++) {

        pcmWrite(PCM_CTRL, CTRL_OFF | CTRL_MOD_CHAN | 1);
        pcmWrite(PCMC_ST, 0);
        pcmWrite(PCMC_LSH, 0);
        pcmWrite(PCMC_LSL, 0);

        if (joy == JOY_A) {
            pcmWrite(PCMC_FDH, 1);
            pcmWrite(PCMC_FDL, 0);
        } else if (joy == JOY_B) {
            pcmWrite(PCMC_FDH, 0);
            pcmWrite(PCMC_FDL, 128);
        } else if (joy == JOY_C) {
            pcmWrite(PCMC_FDH, 0);
            pcmWrite(PCMC_FDL, 32);
        } else {
            return;
        }
        // }

        pcmWrite(PCMC_PAN, 0xff); //0x0F-L, 0xF0-R
        pcmWrite(PCMC_ENV, vol);

        pcmWrite(PCM_CTRL, CTRL_ON);
        pcmWrite(PCM_OFF_SW, ~2);
    }

}

void pcmSample() {

    pcmWrite(PCM_OFF_SW, 0xff);

    pcmSampleWrite(pcm, 0, sizeof (pcm), CTRL_OFF);


    pcmWrite(PCM_CTRL, CTRL_OFF | CTRL_MOD_CHAN | 1);
    pcmWrite(PCMC_ST, 0);
    pcmWrite(PCMC_LSH, 0);
    pcmWrite(PCMC_LSL, 0);
    pcmWrite(PCMC_FDH, 5);
    pcmWrite(PCMC_FDL, 132);

    pcmWrite(PCMC_PAN, 0xff);
    pcmWrite(PCMC_ENV, 0xff);

    pcmWrite(PCM_CTRL, CTRL_ON);
    pcmWrite(PCM_OFF_SW, ~2);


    sysJoyWait();
}
