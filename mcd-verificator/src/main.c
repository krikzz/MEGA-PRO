
#include "main.h"

void tst();

int main() {

    u16 i;
    sysInit();

    for (i = 0; i < 16; i++) {
        //gSetColor(i, i == 0 ? 0 : 0x4444);
        gSetColor(i, i == 0 ? 0 : 0x8888);
    }

    gConsPrint("System init...");

/*
    gConsPrint("id: ");
    gAppendHex16(*(u16 *) 0x400000);
    sysJoyWait();*/


    while (1) {


        mcdInit();
        gVsync();
        gCleanPlan();

        //audioTune();

        //pcmTest();

        //cdcTest();
        //cdcTest2();
        //cddTest();

        //testAsic();
        //cddTest2();

        //testCDD();
        //testPCM();

        //testCDC();
        testSTD();
        sysJoyWait();
    }

    while (1);

    return 0;
}

void tst() {

    u16 i;
    u16 *ram16 = (u16 *) mcd->word_ram;
    mcdWramToMain();
    mcdWramSetMode(WRAM_MODE_2M);
    mcdWramPriorMode(WRAM_PM_OFF);

    for (i = 0; i < 16; i++)mcd->word_ram[i] = 0xaa;


    ram16[0] = 0x1234;
    ram16[1] = 0xABCD;
    ram16[2] = 0x5678;
    mcdWramToSub();
    /*
    mcdWR16(SUB_WRAM + 0, 0x1234);
    mcdWR16(SUB_WRAM + 2, 0xABCD);
    mcdWR16(SUB_WRAM + 4, 0x5678);*/
    //for (i = 0; i < 16; i++)mcdWR8(SUB_WRAM + i, i);
    mcdWramToMain();

    //for (i = 0; i < 16; i++)mcd->word_ram[i] = i;


    gConsPrint("");
    for (i = 0; i < 8; i++) {
        gAppendHex16(ram16[i]);
        gAppendString(".");
    }
    gConsPrint("");

    for (i = 0; i < 8; i++) {
        gAppendHex16(ram16[i]);
        gAppendString(".");
    }
    gConsPrint("");

    gPrintHex(mcd->word_ram, 256);


    sysJoyWait();

}
