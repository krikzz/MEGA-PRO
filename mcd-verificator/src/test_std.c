

#include "main.h"

#define TEST_MIR_OFF

u8 testRamCart();
u8 testVramMapping(u8 slot);
u8 testProgRam();
u8 testWordRam();
u8 testWramPmod();
u8 testX002();
u8 testX000();
u8 testX00C();
u8 test2006();
u8 test8030();
u8 testIRQ();
u8 testVAR();
u8 testColorCalc();
u8 testCDC_regs();
u8 testCDC_dma1xxx();
void qtest();

void testSTD() {

    u8 resp;
    gCleanPlan();

    gConsPrint("        Mega-CD verificator V1.02       ");
    gConsPrint("");

    gConsPrint("CD hardware detected at 0x");
    gAppendHex32((u32) mcd);
    gConsPrint("");

    //qtest();

    resp = testRamCart();
    testPrintResp(resp);

    resp = testColorCalc();
    testPrintResp(resp);

    resp = testVAR();
    testPrintResp(resp);


    resp = testIRQ();
    testPrintResp(resp);

    resp = testX000();
    testPrintResp(resp);

    resp = testX002();
    testPrintResp(resp);

    resp = test2006();
    testPrintResp(resp);

    resp = testX00C();
    testPrintResp(resp);

    resp = test8030();
    testPrintResp(resp);

    resp = testCDC_regs();
    testPrintResp(resp);

    //resp = testCDC_dma1();
    //testPrintResp(resp);
    resp = testProgRam();
    testPrintResp(resp);

    resp = testWordRam();
    testPrintResp(resp);

    resp = testWramPmod();
    testPrintResp(resp);

    resp = testCDC_new();


    gConsPrint("");
    gConsPrint("Diagnostics complete.");

    //sysJoyWait();
}

u8 testRamCart() {

    gConsPrint("RAM CART....");

    u32 i;
    vu8 *cart_id = (u8 *) 0x400001;
    vu16 *cart_ram = (u16 *) 0x600000;
    vu8 *wp_off = (u8 *) 0x700001;
    u32 size;

    if (*cart_id > 6) {
        gAppendString("not present");
        return 0;
    }

    size = 8192 << *cart_id;
    *wp_off = 1;


    cart_ram[0] = 0xaa;
    if ((cart_ram[0] & 0xff) != 0xaa)return 0x01; //ram not work
    cart_ram[0] = 0x55;
    if ((cart_ram[0] & 0xff) != 0x55)return 0x01; //ram not work


    *wp_off = 0;
    cart_ram[0] = 0x2A;
    if ((cart_ram[0] & 0xff) != 0x55)return 0x02; //ram protection not work
    *wp_off = 1;


    for (i = 0; i < 256; i++) {
        cart_ram[i] = i;
    }

    for (i = 0; i < 256; i++) {
        if ((cart_ram[i] & 0xff) != i)return 0x03; //basic memory test fails
    }

    //check actual cart size
    cart_ram[0] = 0xaa;
    for (i = 2; i < 0x80000; i *= 2) {
        cart_ram[i] = 0;
        if ((cart_ram[0] & 0xff) != 0xaa)break;
    }

    if (i != size)return 0x04; //reported size not matches to real size

    for (i = 0; i < 8192; i++) {

        *((vu32 *) 0x600000) = 0x00AA0055;
        *((vu32 *) 0x600100) = 0x00FF0000;
        if ((*((vu32 *) 0x600000) & 0x00ff00ff) != 0x00AA0055)return 0x05; //rw error
        if ((*((vu32 *) 0x600100) & 0x00ff00ff) != 0x00FF0000)return 0x05; //rw error
        *((vu32 *) 0x600100) = 0x00AA0055;
        *((vu32 *) 0x600000) = 0x00FF0000;
        if ((*((vu32 *) 0x600100) & 0x00ff00ff) != 0x00AA0055)return 0x05; //rw error
        if ((*((vu32 *) 0x600000) & 0x00ff00ff) != 0x00FF0000)return 0x05; //rw error
    }

    return 0;
}

void qtest() {
    mcdWR8(0xff8003, 0x04);

    //10620.RD:02-0004 mod 1m sub
    gConsPrint("");
    gAppendHex16(mcdRD16(0xff8002));

    //10623.WR:02-XX05 
    //10624.RD:02-0005 mod 1m main
    mcdWR8(0xff8003, 0x05);
    gConsPrint("");
    gAppendHex16(mcdRD16(0xff8002));

    //10818.WR:02-XX01 
    mcdWR8(0xff8003, 0x01);
    gConsPrint("");
    gAppendHex16(mcdRD16(0xff8002));

    //main WR 03 return to sub? 
    *((u8 *) 0x0A12003) = 0x03;

    //11688.RD:02-0002 mod 2m sub
    //11689.WR:02-XX03
    gConsPrint("");
    gAppendHex16(mcdRD16(0xff8002));
    mcdWR8(0xff8003, 0x03);

    //14263.RD:02-0001 mod 2m main
    //14264.WR:02-0005 1m mod
    gConsPrint("");
    gAppendHex16(mcdRD16(0xff8002));
    mcdWR8(0xff8003, 0x05);

    //final result
    gConsPrint("");
    gAppendHex16(mcdRD16(0xff8002));
    sysJoyWait();
}

u8 testColorCalc() {

    gConsPrint("COLOR CALC..");

    mcdWR16(0xFF804C, 0x0010);

    //base operation
    mcdWR16(0xFF804E, 0x0002);
    if (mcdRD16(0xFF8050) != 0x0000)return 1;
    if (mcdRD16(0xFF8052) != 0x0000)return 1;
    if (mcdRD16(0xFF8054) != 0x0000)return 1;
    if (mcdRD16(0xFF8056) != 0x0010)return 1;

    //byte access
    mcdWR8(0xFF804E, 0xf0);
    if (mcdRD16(0xFF8050) != 0x1111)return 2;
    if (mcdRD16(0xFF8052) != 0x0000)return 2;
    if (mcdRD16(0xFF8054) != 0x0000)return 2;
    if (mcdRD16(0xFF8056) != 0x0010)return 2;

    //var combinations
    mcdWR16(0xFF804E, 0x5A5A);
    if (mcdRD16(0xFF8050) != 0x0101)return 3;
    if (mcdRD16(0xFF8052) != 0x1010)return 3;
    if (mcdRD16(0xFF8054) != 0x0101)return 3;
    if (mcdRD16(0xFF8056) != 0x1010)return 3;

    mcdWR16(0xFF804E, 0xa5a5);
    if (mcdRD16(0xFF8050) != 0x1010)return 3;
    if (mcdRD16(0xFF8052) != 0x0101)return 3;
    if (mcdRD16(0xFF8054) != 0x1010)return 3;
    if (mcdRD16(0xFF8056) != 0x0101)return 3;

    //change colors
    mcdWR16(0xFF804C, 0x00F5);
    if (mcdRD16(0xFF8050) != 0xF5F5)return 4;
    if (mcdRD16(0xFF8052) != 0x5F5F)return 4;
    if (mcdRD16(0xFF8054) != 0xF5F5)return 4;
    if (mcdRD16(0xFF8056) != 0x5F5F)return 4;

    //only word access to color reg
    mcdWR8(0xFF804C, 0x00A8);
    if (mcdRD16(0xFF8050) != 0xA8A8)return 5;

    //read back color reg
    if (mcdRD16(0xFF804C) != 0x00A8)return 6;

    //read back pixel reg
    mcdWR16(0xFF804E, 0x1234);
    if (mcdRD16(0xFF804E) != 0x1234)return 7;

    /*
    gConsPrint("reg: ");
    gAppendHex16(mcdRD16(0xFF804E));

    gConsPrint("");
    gAppendHex16(mcdRD16(0xFF8050));
    gConsPrint("");
    gAppendHex16(mcdRD16(0xFF8052));
    gConsPrint("");
    gAppendHex16(mcdRD16(0xFF8054));
    gConsPrint("");
    gAppendHex16(mcdRD16(0xFF8056));

    sysJoyWait();*/
    return 0;
}

void testPrintResp(u8 resp) {


    if (resp) {
        gAppendString(" ERROR: ");
        gAppendHex8(resp);
    } else {
        gAppendString(" OK");
    }
}

u8 testProgRam() {


    volatile u16 *ram16 = (u16 *) mcd->prog_ram;
    volatile u8 *ram8 = (u8 *) mcd->prog_ram;
    u32 i, u, wp_size;
    u8 val;


    gConsPrint("PROG RAM....");

    mcdBusReq();

    ram16[0] = 0xFFFF;
    if (ram16[0] != 0xFFFF)return 1;
    ram16[0] = 0x1234;
    if (ram16[0] != 0x1234)return 2;
    ram8[1] = 0xCD;
    if (ram16[0] != 0x12CD)return 3;
    ram8[0] = 0xAB;
    if (ram16[0] != 0xABCD)return 4;


    for (i = 0; i < 0x80000; i += 256) {

        if (i % 0x20000 == 0)mcdPrgSetBank(i / 0x20000);
        ram16[i % 0x20000 / 2] = i / 256;
    }

    for (i = 0; i < 0x80000; i += 256) {

        if (i % 0x20000 == 0)mcdPrgSetBank(i / 0x20000);
        if (ram16[i % 0x20000 / 2] != i / 256)return 5;
    }

    mcdInit();


    for (i = 0; i < 9; i++) {

        ga->MEM_WP = (1 << i) - 1;

        wp_size = 0;
        for (u = 0; u < 0x80000; u += 256) {

            val = mcdRD8(u) ^ 0xff;
            mcdWR8(u, val);
            if (mcdRD8(u) != val)wp_size = u + 256;
        }

        if (wp_size != ((1 << i) - 1) * 512) {
            return 0x06;
        }
    }


    for (i = 1; i < 256; i++) {
        ga->MEM_WP = i;

        val = mcdRD8(i * 512 - 1) ^ 0xff;
        mcdWR8(i * 512 - 1, val);
        if (mcdRD8(i * 512 - 1) == val)return 0x07; //wp not workin

        val = mcdRD8(i * 512) ^ 0xff;
        mcdWR8(i * 512, val);
        if (mcdRD8(i * 512) != val)return 0x08; //wp not workin
    }


    //memory on main side souldn't be protected
    ga->MEM_WP = 0xff;
    mcdBusReq();
    val = ram8[0] ^ 0xff;
    ram8[0] ^= 0xff;
    if (val != ram8[8])return 0x09;

    mcdInit();

    return 0;
}

u8 testWordRam() {

    u8 resp;
    u32 i;
    u16 *ram16 = (u16 *) mcd->word_ram;
    u8 *ram8 = (u8 *) mcd->word_ram;
    gConsPrint("WORD RAM....");



    mcdWramSetMode(WRAM_MODE_2M);
    mcdWramToMain();
    mcdWramPriorMode(WRAM_PM_OFF);

    ram16[0] = 0xFFFF;
    if (ram16[0] != 0xFFFF)return 0x01;
    ram16[0] = 0x1234;
    if (ram16[0] != 0x1234)return 0x02;
    ram8[1] = 0xCD;
    if (ram16[0] != 0x12CD)return 0x03;
    ram8[0] = 0xAB;
    if (ram16[0] != 0xABCD)return 0x04;


    for (i = 0; i < 0x40000; i += 256) {
        ram16[i / 2] = i / 256;
    }

    for (i = 0; i < 0x40000; i += 256) {
        if (ram16[i / 2] != i / 256)return 0x05;
    }

    ram16[0] = 0x1234;
    ram16[1] = 0xABCD;

    mcdWramSetMode(WRAM_MODE_1M);
    mcdWramSetBank(0);
    gVsync();

    if (ram16[0] != 0x1234) {
        gAppendHex16(ram16[0]);
        gAppendString(".");
        gAppendHex16(ram16[1]);
        gAppendString(".");
        return 0x06;
    }
    if (mcdRD16(0xC0000) != 0xABCD)return 0x07;


    if (mcdRD16(0x80000) != 0x0A0B || mcdRD16(0x80002) != 0x0C0D) {
        return 0x08;
    }

    for (i = 0; i < 4; i++) {
        mcdWR8(0x80000 + i, 0xF0 + i);
    }

    for (i = 0; i < 4; i++) {

        if (mcdRD8(0x80000 + i) != i) {
            return 0x09;
        }
    }

    if (mcdRD16(0xC0000) != 0x0123) {
        return 0x0A;
    }

    mcdWR16(0x80000, 0xFAFB);
    mcdWR16(0x80002, 0xFCFD);

    if (mcdRD16(0xC0000) != 0xABCD) return 0x0B;

    for (i = 0; i < 256; i++) {
        mcdWR8(0x80000 + i * 2 + 0, 0xF0 + (i >> 4));
        mcdWR8(0x80000 + i * 2 + 1, 0xF0 + i);
    }

    for (i = 0; i < 256; i++) {
        if (mcdRD8(0xC0000 + i) != i)return 0x0D;
    }

    for (i = 0; i < 256; i++) {
        mcdWR8(0xC0000 + i, i);
    }


    for (i = 0; i < 256; i++) {

        resp = mcdRD8(0x80000 + i * 2 + 0) << 4;
        resp |= mcdRD8(0x80000 + i * 2 + 1);
        if (resp != i)return 0x0E;
    }

    for (i = 0; i < 0x10000; i++) {
        ram16[i] = i;
    }

    for (i = 0; i < 5; i++) {
        resp = testVramMapping(i);
        if (resp)return 0x10 + i;
    }



    mcdWramPriorMode(WRAM_PM_OFF);
    mcdWramSetMode(WRAM_MODE_2M);
    mcdWramToMain();

    mcdWR16(0x80000, 0x0001); //sub should be halted
    gVsync();
    if (ga->COMSTA[0] == 0)return 0x20;
    mcdWramToSub();
    gVsync();
    if (ga->COMSTA[0] != 0)return 0x21;


    return 0;
}

u8 testVramMapping(u8 slot) {

    u16 i, addr, len, addr_base;
    u16 *ptr;
    u8 sr;
    u16 msk_hi, msk_lo;

    addr_base = 0;
    for (i = 0; i < slot; i++) {
        addr_base += 0x8000 >> i;
    }

    i = slot;
    if (slot > 3)slot = 3;
    sr = 8 - slot;
    msk_hi = 0x1FE & (0x1FE >> slot);
    msk_lo = 0x7E00 >> slot;
    len = 0x8000 >> slot;
    slot = i;

    ptr = (u16 *) & mcd->word_ram[0x20000 + addr_base * 2];
    for (i = 0; i < len; i++) {
        addr = addr_base;
        addr += ((i & msk_hi) << 6) | ((i & msk_lo) >> sr) | (i & 1);
        if (ptr[i] != addr)return 1;
    }

    return 0;
}

u8 testWramPmod() {


    gConsPrint("WRAM PMOD...");

    mcdWramSetMode(WRAM_MODE_1M);
    mcdWramPriorMode(WRAM_PM_OFF);

    mcdWR16(0x80000, 0x0001);
    mcdWramPriorMode(WRAM_PM_WD); //non zero pixels should not be overridden
    mcdSubBusy();

    mcdWR16(0x80000, 0x0000);
    if (mcdRD16(0x80000) != 0x0001)return 0x01;
    mcdWR16(0x80000, 0xFFFF);
    if (mcdRD16(0x80000) != 0x0F01)return 0x02;


    mcdWramPriorMode(WRAM_PM_OFF);
    mcdWR16(0x80000, 0x0001);
    mcdWramPriorMode(WRAM_PM_WU); //zero pixels sould not override non zero pizels

    mcdWR16(0x80000, 0x0000);
    if (mcdRD16(0x80000) != 0x0001)return 0x03;
    mcdWR16(0x80000, 0xFFFF);
    if (mcdRD16(0x80000) != 0x0F0F)return 0x04;


    mcdWramPriorMode(WRAM_PM_OFF);
    mcdWR16(0x80000, 0x0001);
    mcdWramPriorMode(WRAM_PM_WD);

    mcdWR16(0xC0000, 0x0000);
    if (mcdRD16(0x80000) != 0x0000)return 0x05;
    mcdWR16(0xC0000, 0xFFFF);
    if (mcdRD16(0x80000) != 0x0F0F)return 0x06;

    mcdWramPriorMode(WRAM_PM_OFF);
    mcdWR16(0x80000, 0x0001);
    mcdWramPriorMode(WRAM_PM_WU);

    mcdWR16(0xC0000, 0x0000);
    if (mcdRD16(0x80000) != 0x0000)return 0x07;
    mcdWR16(0xC0000, 0xFFFF);
    if (mcdRD16(0x80000) != 0x0F0F)return 0x08;

    mcdWramPriorMode(WRAM_PM_OFF);
    mcdWramSetMode(WRAM_MODE_2M);
    mcdWramToSub();

    mcdWR16(0x80000, 0x0001);
    mcdWramPriorMode(WRAM_PM_WD);

    if (mcdRD16(0x80000) != 0x0001) {
        return 0x09;
    }

    mcdWR16(0x80000, 0x0000);

    if (mcdRD16(0x80000) != 0x0000) {
        return 0x0A;
    }


    //mcdWramPriorMode(WRAM_PM_WD);

    //gAppendHex16(mcdRD16(0x80000));
    //gConsPrint("");


    return 0;
}

u8 testX002() {

    volatile u8 val;

    gConsPrint("REG X002....");

    mcdWramPriorMode(WRAM_PM_OFF);
    mcdWramSetMode(WRAM_MODE_2M);
    mcdWramToSub();

    //check dmna and ret flags on main side
    if ((ga->MEMMOD & GA_MEMMOD_DMNA) == 0)return 0x01;
    if ((ga->MEMMOD & GA_MEMMOD_RET) != 0)return 0x02;

    val = mcdRD8(SUB_REG_MEMMOD + 1);

    //check dmna and ret flags on sub size
    if ((val & GA_MEMMOD_DMNA) == 0)return 0x01;
    if ((val & GA_MEMMOD_RET) != 0)return 0x02;

    //make sure that no access to memory on sub side
    //val = mcd->word_ram[0];
    //mcd->word_ram[0] ^= 0xAA;
    mcd->word_ram[0] = 0xaa;
    mcd->word_ram[2] = 0x55;
    if (mcd->word_ram[0] == 0xaa && mcd->word_ram[2] == 0x55)return 0x03;

    //make sure that no access sub has access to memory
    val = mcdRD8(0x8000) ^ 0xff;
    mcdWR8(0x8000, val);
    if (val != mcdRD8(0x8000))return 0x04;

    //main can't take back access to wram until sub not release it
    mcdWR8(0x8000, 0);
    val = ga->MEMMOD;
    ga->MEMMOD &= ~GA_MEMMOD_DMNA;
    gVsync();
    if (val != ga->MEMMOD)return 0x04;
    mcdWR8(0x8000, 1);
    if (mcdRD8(0x8000) != 1)return 0x05;
    ga->MEMMOD |= GA_MEMMOD_DMNA;
    gVsync();
    if (val != ga->MEMMOD)return 0x06;
    mcdWR8(0x8000, 2);
    if (mcdRD8(0x8000) != 2)return 0x07;

    //set wram to main
    mcdWR16(SUB_REG_MEMMOD, GA_MEMMOD_MOD2M | GA_MEMMOD_RET);
    gVsync();

    //check dmna and ret flags on main side
    if ((ga->MEMMOD & GA_MEMMOD_DMNA) != 0)return 0x08;
    if ((ga->MEMMOD & GA_MEMMOD_RET) == 0)return 0x09;

    val = mcdRD8(SUB_REG_MEMMOD + 1);

    //check dmna and ret flags on sub side
    if ((val & GA_MEMMOD_DMNA) != 0)return 0x0A;
    if ((val & GA_MEMMOD_RET) == 0)return 0x0B;

    mcd->word_ram[0] = 0xAA;
    if (mcd->word_ram[0] != 0xAA)return 0x0C;
    mcd->word_ram[0]++;
    if (mcd->word_ram[0] != 0xAB)return 0x0D;

    mcdWR16(SUB_REG_MEMMOD, GA_MEMMOD_MOD2M); //wram shouldn't switch back
    gVsync();

    if (val != ga->MEMMOD)return 0x0E;
    if (val != mcdRD8(SUB_REG_MEMMOD + 1))return 0x0F;

    mcdWR16(SUB_REG_MEMMOD, GA_MEMMOD_MOD2M | GA_MEMMOD_RET); //wram shouldn't switch back
    gVsync();

    if (val != ga->MEMMOD)return 0x10;
    if (val != mcdRD8(SUB_REG_MEMMOD + 1))return 0x11;

    mcd->word_ram[0]++;
    if (mcd->word_ram[0] != 0xAC)return 0x12;


    mcdWR16(SUB_REG_MEMMOD, GA_MEMMOD_MOD1M); //swithc to 1m mode
    mcdWR16(SUB_REG_MEMMOD, GA_MEMMOD_MOD1M);
    gVsync();

    //chekc bank switching
    if ((mcdRD16(SUB_REG_MEMMOD) & GA_MEMMOD_RET) != 0)return 0x13;
    mcdWR16(SUB_REG_MEMMOD, GA_MEMMOD_MOD1M | GA_MEMMOD_RET);
    gVsync();
    if ((mcdRD16(SUB_REG_MEMMOD) & GA_MEMMOD_RET) == 0)return 0x14;

    //dmna should rise
    ga->MEMMOD = 0;
    if ((mcdRD16(SUB_REG_MEMMOD) & GA_MEMMOD_DMNA) == 0)return 0x15;
    if ((ga->MEMMOD & GA_MEMMOD_DMNA) == 0)return 0x16;

    //dmna should fall
    mcdWR16(SUB_REG_MEMMOD, GA_MEMMOD_MOD1M);
    gVsync();
    if ((mcdRD16(SUB_REG_MEMMOD) & GA_MEMMOD_DMNA) != 0)return 0x17;
    if ((ga->MEMMOD & GA_MEMMOD_DMNA) != 0)return 0x18;


    //dmna should stay as is
    ga->MEMMOD = GA_MEMMOD_DMNA;
    if ((mcdRD16(SUB_REG_MEMMOD) & GA_MEMMOD_DMNA) != 0)return 0x19;
    if ((ga->MEMMOD & GA_MEMMOD_DMNA) != 0)return 0x1A;

    //send switch request, but sub will rewrite RET bit with same value. dmna should stay rised
    ga->MEMMOD = 0;
    mcdWR16(SUB_REG_MEMMOD, GA_MEMMOD_MOD1M);
    gVsync();
    if ((mcdRD16(SUB_REG_MEMMOD) & GA_MEMMOD_DMNA) == 0)return 0x1B;
    if ((ga->MEMMOD & GA_MEMMOD_DMNA) == 0)return 0x1C;
    mcdWR16(SUB_REG_MEMMOD, GA_MEMMOD_MOD1M | GA_MEMMOD_RET); //now dmna flag should fall
    gVsync();
    if ((ga->MEMMOD & GA_MEMMOD_DMNA) != 0)return 0x1D;
    gVsync();

    //some tests were removed cuz dnma/ret bit logic still not fully clear.
    //at least two games hangs if follow this logic. (stellar fire and darkwizard)
    //checking tricky DMNA/RET logic
    //manipulating 1m mode bits in 2m mode
    //when return from 2m to 1m mode dmna wil equ to last_ret ^ new_ret
    mcdWR16(SUB_REG_MEMMOD, GA_MEMMOD_MOD2M | GA_MEMMOD_RET); //2m
    gVsync();
    mcdWR16(SUB_REG_MEMMOD, GA_MEMMOD_MOD1M); //1m. last ret was 1. dmna should be set
    gVsync();
    //if (ga->MEMMOD != (GA_MEMMOD_MOD1M | GA_MEMMOD_DMNA))return 0x20;

    mcdWR16(SUB_REG_MEMMOD, GA_MEMMOD_MOD2M | GA_MEMMOD_RET); //2m
    gVsync();
    mcdWR16(SUB_REG_MEMMOD, GA_MEMMOD_MOD1M | GA_MEMMOD_RET); //1m+ret
    gVsync();
    if (ga->MEMMOD != (GA_MEMMOD_MOD1M | GA_MEMMOD_RET))return 0x21;

    mcdWR16(SUB_REG_MEMMOD, GA_MEMMOD_MOD2M);
    gVsync();
    mcdWR16(SUB_REG_MEMMOD, GA_MEMMOD_MOD1M | GA_MEMMOD_RET);
    gVsync();
    //if (ga->MEMMOD != (GA_MEMMOD_MOD1M | GA_MEMMOD_RET | GA_MEMMOD_DMNA))return 0x22;

    mcdWR16(SUB_REG_MEMMOD, GA_MEMMOD_MOD2M);
    gVsync();
    mcdWR16(SUB_REG_MEMMOD, GA_MEMMOD_MOD1M);
    gVsync();
    if (ga->MEMMOD != (GA_MEMMOD_MOD1M))return 0x23;

    mcdWR16(SUB_REG_MEMMOD, GA_MEMMOD_MOD2M);
    mcdWR16(SUB_REG_MEMMOD, GA_MEMMOD_MOD2M | GA_MEMMOD_RET); //behaviour should be same even if we manipulating ret during 2m mode
    gVsync();
    mcdWR16(SUB_REG_MEMMOD, GA_MEMMOD_MOD1M);
    gVsync();
    //if (ga->MEMMOD != (GA_MEMMOD_MOD1M | GA_MEMMOD_DMNA))return 0x24;

    //manipulating 2m mode bits in 1m mode
    mcdWR16(SUB_REG_MEMMOD, GA_MEMMOD_MOD2M);
    gVsync();
    if (ga->MEMMOD != GA_MEMMOD_RET)return 0x25;

    mcdWR16(SUB_REG_MEMMOD, GA_MEMMOD_MOD1M);
    gVsync();
    ga->MEMMOD = GA_MEMMOD_DMNA; //2m switching mechanism should work even in 1m mode
    gVsync();
    mcdWR16(SUB_REG_MEMMOD, 0);
    gVsync();
    if (ga->MEMMOD != GA_MEMMOD_DMNA)return 0x26;
    mcdWR16(SUB_REG_MEMMOD, 0);
    gVsync();
    ga->MEMMOD = 0; //should be ignored
    gVsync();
    if (ga->MEMMOD != GA_MEMMOD_DMNA)return 0x27;
    mcdWR16(SUB_REG_MEMMOD, GA_MEMMOD_RET); //switch back to main
    gVsync();
    mcdWR16(SUB_REG_MEMMOD, 0);
    gVsync();
    if (ga->MEMMOD != GA_MEMMOD_RET)return 0x28;

    //memory mode register not support byte writes
    mcdWR16(SUB_REG_MEMMOD, GA_MEMMOD_MOD1M);
    gVsync();
    mcdWR8(SUB_REG_MEMMOD, GA_MEMMOD_MOD1M | GA_MEMMOD_RET);
    gVsync();
    if ((ga->MEMMOD & GA_MEMMOD_RET) == 0)return 0x29;
    gVsync();
    mcdWR8(SUB_REG_MEMMOD + 1, GA_MEMMOD_MOD1M);
    gVsync();
    if ((ga->MEMMOD & GA_MEMMOD_RET) != 0)return 0x2A;

    //PM regs should not be visible for main
    mcdWR16(SUB_REG_MEMMOD, 0xFF00 | WRAM_PM_MSK); //0xFF00 shoild be ignored. only main have access
    gVsync();
    if (ga->MEMMOD != (GA_MEMMOD_RET))return 0x2B;
    if (mcdRD16(SUB_REG_MEMMOD) != (GA_MEMMOD_RET | WRAM_PM_MSK))return 0x2C;

    ga->MEM_WP = 0xff;
    if (mcdRD16(SUB_REG_MEMMOD) != (0xFF00 | GA_MEMMOD_RET | WRAM_PM_MSK))return 0x2D;
    if (ga->MEM_WP != 0xff)return 0x2E;


    *((u8 *) 0xA12002) = 0xaa;
    if (ga->MEM_WP != 0xaa)return 0x2E;
    if ((mcdRD16(SUB_REG_MEMMOD) & 0xff00) != 0xaa00)return 0x2F;
    *((u16 *) 0xA12002) = 0x5500;
    if (ga->MEM_WP != 0x55)return 0x30;
    if ((mcdRD16(SUB_REG_MEMMOD) & 0xff00) != 0x5500)return 0x31;

    u16 i;
    for (i = 0; i < 256; i++) {
        ga->MEM_WP = i;
        if ((mcdRD16(SUB_REG_MEMMOD) & 0xff00) != i << 8)return 0x32;
    }

    ga->MEM_WP = 0xaa;
    *((u8 *) 0xA12003) = 0x00;
    if (ga->MEM_WP != 0xaa)return 0x33;
    ga->MEM_WP = 0;

    /*
    ga->MEM_WP = 0x2A;
    sysJoyWait();
    ga->MEM_WP = 0;*/
    /*
     *((u16 *) 0xA12002) = 0xaa00;
    if (*((u8 *) 0xA12002) != 0xaa)return 0x40;
    if (mcdRD8(0xff8002) != 0xaa)return 0x41;
     *((u8 *) 0xA12002) = 0x55;
    if (*((u8 *) 0xA12002) != 0x55)return 0x42;
    if (mcdRD8(0xff8002) != 0x55)return 0x43;
     *((u8 *) 0xA12003) = 0x00;
    if (*((u8 *) 0xA12002) != 0x55)return 0x44;
    if (mcdRD8(0xff8002) != 0x55)return 0x45;
    mcdWR16(0xff8002, 0);
    if (*((u8 *) 0xA12002) != 0x55)return 0x46;
    if (mcdRD8(0xff8002) != 0x55)return 0x47;

     *((u16 *) 0xA12002) = 0xfff0;
    gAppendHex16(*((u16 *) 0xA12002));
    gAppendString(".");
    gAppendHex16(mcdRD16(0xff8002));*/

    ga->MEM_WP = 0;
    return 0;
}

u8 testX000() {

    gConsPrint("REG X000....");

    //register should support byte writes. 
    mcdWR8(SUB_REG_RESET, 0);
    if ((mcdRD16(SUB_REG_RESET) & GA_RST_RES0) == 0)return 0x01;

    //led bits r/w
    mcdWR8(SUB_REG_RESET, 3);
    if ((mcdRD8(SUB_REG_RESET)) != 3)return 0x02;

    if (ga->RST != GA_RST_RES0)return 0x03;


    //seems like bit 7 indcates if ie2 enabled
    mcdWR16(SUB_REG_IEMASK, 0);
    gVsync();
    if ((ga->IFL2 & 0x80) != 0)return 0x04;
    mcdWR16(SUB_REG_IEMASK, (1 << 2)); //enable interrupt 2
    gVsync();
    if ((ga->IFL2 & 0x80) == 0)return 0x05;

    //check irq2 
    //by some reasons irq will not fire if try to trigger it right after writting to SUB_REG_IEMASK
    //may be unknown flag in bit 7 indicates if it ready to use
    mcdRD8(0); //clean COMSTA[3]
    ga->IFL2 = 1;
    gVsync();
    if (ga->COMSTA[3] != 2)return 0x06; //COMSTA[3] shown last irq event. any cmd transmitted to sub will reset this value to 0

    mcdRD8(0);
    ga->IFL2 = 1;
    gVsync();
    if (ga->COMSTA[3] != 2)return 0x07;

    mcdRD8(0);
    ga->IFL2 = 0;
    gVsync();
    if (ga->COMSTA[3] != 0)return 0x08; //irq should fire only if bit is 1

    mcdWR16(SUB_REG_IEMASK, 0);
    gVsync();
    mcdRD8(0);
    ga->IFL2 = 1; //should not fire this time
    gVsync();
    if (ga->COMSTA[3] == 2)return 0x09;



    /*
    static u8 val;
    val = ga->CDCDAT;
    gConsPrint("IFL: ");
    gAppendHex8(val & 1);*/





    return 0;
}

u8 testX00C() {

    u32 i;
    volatile u16 timer;
    gConsPrint("REG X00C....");


    //check if timer working at all
    timer = ga->TIMER;
    for (i = 0; i < 1024; i++)asm("nop");
    if (timer == ga->TIMER)return 0x01;

    for (i = 0; i < 32; i++) {
        mcdWR16(SUB_REG_SWATCH, 0xffff); //should be reset by writting any value
        mcdSubBusy();
        timer = ga->TIMER;
        if (timer == 0)break;
    }


    if (timer != 0) {
        gAppendNum(timer);
        gAppendString(" ");
        return 0x02;
    }

    i = 0;
    while (ga->TIMER < 10)asm("nop");
    while (ga->TIMER < 20)i++;

    if (i < 59 || i > 63) {
        gAppendNum(i);
        gAppendString(" ");
        return 0x03; //61 usually. approx value. can be affected by compiler options
    }

    /*
    gConsPrint("");
    gConsPrint("time: ");
    gAppendNum(i);
    gConsPrint("");*/

    return 0;
}

u8 test2006() {

    volatile u32 *hint = (u32 *) & mcd->bios[0x70];
    gConsPrint("REG 2006....");

    ga->HIVECT = 0x1234;
    if (ga->HIVECT != 0x1234)return 0x01;
    if (*hint != 0xFFFF1234)return 0x02;
    ga->HIVECT = 0xabcd;
    if (ga->HIVECT != 0xabcd)return 0x02;
    if (*hint != 0xFFFFabcd)return 0x03;

    //seems like this reg does not actually resets
    mcdInit();
    if (ga->HIVECT != 0xabcd)return 0x04;
    if (*hint != 0xFFFFabcd)return 0x05;

    /*
    gConsPrint("");
    gConsPrint("hint: ");
    gAppendHex32(*hint);
    gConsPrint("");*/

    return 0;
}

u8 test8030() {

    u32 i;
    gConsPrint("REG 8030....");


    mcdWR16(SUB_REG_IEMASK, 0); //turn off all irq
    mcdWR16(SUB_REG_ITIMER, 0xaa);
    if (mcdRD16(SUB_REG_ITIMER) != 0xaa)return 0x01; //check if read returns previously written val

    //register not supports byte access. any writes should hit low byte
    mcdWR8(SUB_REG_ITIMER, 0x55);
    if (mcdRD16(SUB_REG_ITIMER) != 0x55)return 0x02;
    mcdWR8(SUB_REG_ITIMER, 0xbb);
    if (mcdRD16(SUB_REG_ITIMER) != 0xbb)return 0x03;


    mcdWR16(SUB_REG_ITIMER, 0);
    mcdWR16(SUB_REG_IEMASK, (1 << 3));
    mcdWR16(SUB_REG_ITIMER, 255);

    gVsync();
    if (ga->COMSTA[3] != 3)return 0x04; //check if irq3 occurs
    mcdRD16(SUB_REG_ITIMER); //clear COMSTA[3]
    gVsync();
    if (ga->COMSTA[3] != 3)return 0x05; //check if irq3 occurs again 
    mcdWR16(SUB_REG_ITIMER, 0);
    mcdRD16(SUB_REG_ITIMER); //clear COMSTA[3]
    if (ga->COMSTA[3] == 3)return 0x06; //timer should be stopped if it set to 0

    //check timings
    i = 0;
    mcdWR16(SUB_REG_ITIMER, 255);
    mcdRD16(SUB_REG_ITIMER);
    while (ga->COMSTA[3] != 3); //make sure we start measuring from begin of timer cycle
    mcdRD16(SUB_REG_ITIMER);
    while (ga->COMSTA[3] != 3)i++;

    if (i < 1286 || i > 1288) {//1287 if timer 255, 1282 if timer 254 or 1277 if timer 253
        gAppendNum(i);
        gAppendString(" ");
        return 0x07;
    }


    //timer should reset phase if SUB_REG_ITIMER were written
    mcdRD16(SUB_REG_ITIMER);
    while (ga->COMSTA[3] != 3);

    //time spent on this cycle shouldn't be reflected in total time to next irq. we still should get value close to previous timings test
    for (i = 0; i < 128; i++) {
        mcdWR16(SUB_REG_ITIMER, 255); //reset timer phase
    }

    i = 0;
    mcdRD16(SUB_REG_ITIMER);
    while (ga->COMSTA[3] != 3)i++;

    if (i < 1283 || i > 1290) {
        gAppendNum(i);
        gAppendString(" ");
        return 0x08;
    }

    mcdWR16(SUB_REG_ITIMER, 0);
    mcdWR16(SUB_REG_IEMASK, 0);


    /*
    gConsPrint("");
    gConsPrint("hint: ");
    gAppendNum(i);
    gConsPrint("");*/

    return 0;
}

u8 testIRQ() {

    u32 i;
    gConsPrint("IRQ TEST....");



    mcdWR16(SUB_REG_IEMASK, 0);
    mcdWR16(SUB_REG_ITIMER, 0);

    //check masking for irq2
    gVsync();
    ga->IFL2 = 1;
    gVsync();
    if (ga->COMSTA[3] != 0)return 0x01;

    mcdWR16(SUB_REG_IEMASK, (1 << 2));
    gVsync();
    ga->IFL2 = 1;
    gVsync();
    if (ga->COMSTA[3] != 2)return 0x02;

    //check masking for irq3
    mcdWR16(SUB_REG_IEMASK, (1 << 3));
    gVsync();
    if (ga->COMSTA[3] != 0)return 0x03;

    mcdWR16(SUB_REG_ITIMER, 127);
    gVsync();
    if (ga->COMSTA[3] != 3)return 0x04;
    mcdWR16(SUB_REG_ITIMER, 0);


    mcdWR16(SUB_REG_ITIMER, 0);
    mcdWR16(SUB_REG_IEMASK, (1 << 2));

    mcdWR16(SUB_REG_ICTR2, 0); //reset irq counter

    //likely not match to real system due minor speed difference related to refresh cycles
    /*
        //now we check extreme irq timings. with wuch intensive irq request some should be skipped
        for (i = 0; i < 128; i++) {
            ga->IFL2 = 1;
        }
        gVsync();

        //should be 96 +/- 1
        if (ga->COMSTA[4] < 95 || ga->COMSTA[4] > 97) {
            gAppendNum(ga->COMSTA[4]);
            gAppendString(" ");
            return 0x05;
        }
     */

    //with such delay all irq should be handled
    mcdWR16(SUB_REG_ICTR2, 0);
    for (i = 0; i < 128; i++) {
        ga->IFL2 = 1;
        asm("nop");
        asm("nop");
        asm("nop");
        asm("nop");
        asm("nop");

    }
    gVsync();

    if (ga->COMSTA[4] != 128) {
        gAppendNum(ga->COMSTA[4]);
        gAppendString(" ");
        return 0x06;
    }


    /*
        //this time only one irq should be skipped
        mcdWR16(SUB_REG_ICTR2, 0);
        for (i = 0; i < 128; i++) {
            ga->IFL2 = 1;
            asm("nop");
            asm("nop");
            asm("nop");
            asm("nop");
            //asm("nop");
        }
        gVsync();

        if (ga->COMSTA[4] != 127) {
            gAppendNum(ga->COMSTA[4]);
            gAppendString(" ");
            return 0x07;
        }
     */

    mcdWR16(SUB_REG_ICTR2, 0);
    mcdWR16(SUB_REG_ICTR3, 0);
    mcdWR16(SUB_REG_ITIMER, 1);

    mcdWR16(SUB_REG_IEMASK, (1 << 2) | (1 << 3));

    for (i = 0; i < 1024; i++) {

        ga->IFL2 = 1;
        asm("nop");
        asm("nop");
        asm("nop");
        asm("nop");
        asm("nop");
        asm("nop");
        asm("nop");
        asm("nop");
        asm("nop");
        asm("nop");
        asm("nop");
        asm("nop");
        asm("nop");

    }

    mcdWR16(SUB_REG_IEMASK, 0);
    mcdWR16(SUB_REG_ITIMER, 0);

    //1024
    if (ga->COMSTA[4] != 1024) {
        gAppendNum(ga->COMSTA[4]);
        gAppendString(" ");
        return 0x08;
    }

    //225
    if (ga->COMSTA[5] < 224 || ga->COMSTA[5] > 226) {
        gAppendNum(ga->COMSTA[5]);
        gAppendString(" ");
        return 0x09;
    }



    mcdWR16(SUB_REG_IEMASK, (1 << 2)); //enable interrupt 2    

    for (i = 0; i < 256; i++) {
        mcdRD8(0);
        ga->IFL2 = 1;
        asm("nop");
        asm("nop");
        asm("nop");
        asm("nop");
        asm("nop");
        asm("nop");
        if (ga->COMSTA[3] != 2)return 0x0A;
    }

    mcdRD8(0);
    for (i = 0; i < 256; i++) {
        ga->IFL2 = 0;
        asm("nop");
        asm("nop");
        asm("nop");
        asm("nop");
        asm("nop");
        asm("nop");
        if (ga->COMSTA[3] != 0)return 0x0B;
    }

    //check irq busy flag
    for (i = 0; i < 16; i++)asm("nop");
    ga->IFL2 = 1;
    if (ga->IFL2 != 0x80)return 0x0C; //should not busy
    for (i = 0; i < 16; i++)asm("nop");
    ga->IFL2 = 1;
    ga->IFL2 = 1;
    if (ga->IFL2 != 0x81)return 0x0D; //should be busy
    for (i = 0; i < 16; i++)asm("nop");

    //irq request overload
    mcdWR16(SUB_REG_ICTR2, 0);
    for (i = 0; i < 16; i++)asm("nop");
    ga->IFL2 = 1;
    ga->IFL2 = 1;
    ga->IFL2 = 1;
    for (i = 0; i < 64; i++)asm("nop");
    if (ga->COMSTA[4] != 2)return 0x0E;


    //toggling irq with checking busy state. all irq should triggers. prbably not enough cpu speed for bit check anyway
    mcdWR16(SUB_REG_ICTR2, 0); //reset counter
    for (i = 0; i < 16; i++)asm("nop");
    for (i = 0; i < 2048; i++) {
        if (ga->IFL2 == 0x80)ga->IFL2 = 1;
        if (ga->IFL2 == 0x80)ga->IFL2 = 1;
        if (ga->IFL2 == 0x80)ga->IFL2 = 1;
        if (ga->IFL2 == 0x80)ga->IFL2 = 1;
    }


    for (i = 0; i < 16; i++)asm("nop");
    if (ga->COMSTA[4] != 8192)return 0x0F;



    //massive overload. (can't pass it)
    mcdWR16(SUB_REG_ICTR2, 0); //reset counter
    for (i = 0; i < 16; i++)asm("nop");
    for (i = 0; i < 1024; i++) {
        ga->IFL2 = 1;
    }
    //if (ga->COMSTA[4] >= (768 + 1) || ga->COMSTA[4] <= (768 - 1))return 0x1E;

    /*
        gConsPrint("CTR: ");
        gAppendNum(ga->COMSTA[4]);
        gConsPrint("");*/

    return 0;

}

u8 testVAR() {


    u32 i = 0;
    gConsPrint("VAR TESTS...");

    mcdWramSetMode(WRAM_MODE_2M);
    mcdWramToSub();


    i = 0;

    //memory delays
    mcdDelay(0x80000); //read wram
    while (ga->COMSTA[0] != 0)i++;
    if (i < 23753 || i > 23980) {
        gAppendNum(i);
        gAppendString(" ");
        return 0x02;
    }

    i = 0;
    mcdDelay(0xFF8000); //read regs
    while (ga->COMSTA[0] != 0)i++;
    if (i < 23753 || i > 23980) {
        gAppendNum(i);
        gAppendString(" ");
        return 0x03;
    }


    //check bram
    //if ((mcdRD16(SUB_BRAM) & 0xFF00) != 0x8000)return 0x04;//seems this behavior not applied to mcd1
    mcdWR16(SUB_BRAM, 0xFFFF);
    if ((mcdRD16(SUB_BRAM) & 0xff) != 0x00FF)return 0x05;

    mcdWR16(SUB_BRAM, 0xFFAA);
    if ((mcdRD16(SUB_BRAM) & 0xff) != 0x00AA)return 0x06;
    mcdWR8(SUB_BRAM, 0x00);
    if ((mcdRD16(SUB_BRAM) & 0xff) != 0x00AA)return 0x07;
    mcdWR8(SUB_BRAM + 1, 0x55);
    if ((mcdRD16(SUB_BRAM) & 0xff) != 0x0055)return 0x08;

    //bram size
    for (i = 0; i < 16384; i += 64) {
        mcdWR16(SUB_BRAM + i, i / 64);
    }
    for (i = 0; i < 16384; i += 64) {
        if ((mcdRD16(SUB_BRAM + i) & 0xff) != (i / 64))return 0x09;
    }

    //bram mirroring in 64K window
    for (i = 0; i < 0x10000; i += 16384) {
        mcdWR16(SUB_BRAM + i, i / 16384);
        if ((mcdRD16(SUB_BRAM) & 0xff) != (0x0000 | i / 16384)) {
            return 0x0A;
        }
    }

    //check access type to communication flag. should be work only
    *((u16 *) 0x0A1200E) = 0xffff;
    if ((*((u16 *) 0x0A1200E) & 0xff00) != 0xff00)return 0x0B;
    *((u16 *) 0x0A1200E) = 0x0000;
    if ((*((u16 *) 0x0A1200E) & 0xff00) != 0x0000)return 0x0C;
    *((u8 *) 0x0A1200F) = 0xaa;
    if ((*((u16 *) 0x0A1200E) & 0xff00) != 0xAA00)return 0x0E;
    *((u8 *) 0x0A1200E) = 0x55;
    if ((*((u16 *) 0x0A1200E) & 0xff00) != 0x5500)return 0x0F;

    if ((mcdRD16(SUB_REG_CCLAGS) & 0xff00) != 0x5500)return 0x10;
    mcdWR16(SUB_REG_CCLAGS, 0x0012);
    if (mcdRD16(SUB_REG_CCLAGS) != 0x5512)return 0x11;
    mcdWR8(SUB_REG_CCLAGS, 0xAA);
    if (mcdRD16(SUB_REG_CCLAGS) != 0x55AA)return 0x12;
    mcdWR8(SUB_REG_CCLAGS + 1, 0x2A);
    if (mcdRD16(SUB_REG_CCLAGS) != 0x552A)return 0x13;


#ifdef TEST_MIR_ON 
    //test mirroring
    mcdWramSetMode(WRAM_MODE_2M);
    mcdWramToMain();
    mcdBusReq();
    *((u32*) & mcd->prog_ram[0x10100]) = 0xAA550001;
    *((u32*) & mcd->word_ram[0x00100]) = 0xAA550002;
    *((u32*) & mcd->word_ram[0x20100]) = 0xAA550003;


    u8 resp = 0;
    for (i = 0; i < 0x400000; i += 0x20000) {

        if (i < 0x200000) {
            if ((i & 0x20000) == 0 && *((u32*) & mcd->bios[0x00100 + i]) != 0x53454741)resp = 0x14;
            if ((i & 0x20000) != 0 && *((u32*) & mcd->bios[0x10100 + i]) != 0xAA550001)resp = 0x15;
        } else {
            if ((i & 0x20000) == 0 && *((u32*) & mcd->bios[0x00100 + i]) != 0xAA550002)resp = 0x16;
            if ((i & 0x20000) != 0 && *((u32*) & mcd->bios[0x00100 + i]) != 0xAA550003)resp = 0x17;
        }
        if (resp)break;
    }

    mcdBusRelease();
    if (resp)return resp;
    //bios should be mappet to whole upper area
    for (i = 0; i < 0x400000; i += 0x20000) {

        if (i < 0x200000) {
            if (*((u32*) & mcd->bios[0x00100 + i]) != 0x53454741)return 0x18;
        } else {
            if ((i & 0x20000) == 0 && *((u32*) & mcd->bios[0x00100 + i]) != 0xAA550002)return 0x19;
            if ((i & 0x20000) != 0 && *((u32*) & mcd->bios[0x00100 + i]) != 0xAA550003)return 0x20;
        }
    }

    mcdWramToSub();
    for (i = 0; i < 0x400000; i += 0x20000) {

        if (i < 0x200000) {
            if (*((u32*) & mcd->bios[0x00100 + i]) != 0x53454741)return 0x21;
        } else {
            if (*((u32*) & mcd->bios[0x00100 + i]) == 0xAA550002)return 0x22;
            if (*((u32*) & mcd->bios[0x00100 + i]) == 0xAA550003)return 0x23;
        }
    }
#endif


    return 0;
}

#define REG16_A12004 *((u16 *) 0xA12004)
#define REG08_A12004 *((u8*) 0xA12004)
#define REG16_A12008 *((u16 *) 0xA12008)

u8 testCDC_regs() {

    volatile u8 val;
    u32 i;

    gConsPrint("CDC REGS....");

    mcdWR16(0xff8004, 0x0000);
    mcdWR16(0xff8004, 0xffff);


    if (mcdRD16(0xff8004) != 0x071f)return 0x01; //RS bit[4] shpuld be writable
    if (REG16_A12004 != 0x0700)return 0x02;

    mcdWR16(0xff8004, 0x0000);

    if (mcdRD16(0xff8004) != 0x0000)return 0x02;
    if (REG16_A12004 != 0x0000)return 0x03;

    //main should not have access
    REG16_A12004 = 0xffff;
    if (mcdRD16(0xff8004) != 0x0000)return 0x04;
    if (REG16_A12004 != 0x0000)return 0x05;


    //register should support byte access
    mcdWR16(0xff8004, 0xffff);
    mcdWR8(0xff8004, 0);
    if (mcdRD16(0xff8004) != 0x001f)return 0x06;
    mcdWR16(0xff8004, 0xffff);
    mcdWR8(0xff8005, 0);
    if (mcdRD16(0xff8004) != 0x0700)return 0x07;


    //check cdc registers increment
    mcdWR16(0xff8004, 0x0001);
    for (i = 1; i < 32 + 8; i++) {
        val = mcdRD8(0xff8005) & 0x1F;
        if (i < 32) {
            if (val != i)return 0x08; //address should increment up to 31 (including RS bit)
        } else {
            if (val != 0)return 0x09; //should stop incrementing at 0
        }
        mcdRD8(0xff8007);
    }

    //check again if reg 0 isn't increment
    mcdWR16(0xff8004, 0x0000);
    mcdRD8(0xff8007);
    mcdRD8(0xff8007);
    if (mcdRD16(0xff8004) != 0)return 0x0A;


    //try set DBC and read it back
    mcdWR16(0xff8004, 0x0002);
    mcdWR16(0xff8006, 0x0095);
    mcdWR16(0xff8006, 0x00FA);
    mcdWR16(0xff8004, 0x0002);
    if (mcdRD16(0xff8006) != 0x95)return 0x0B;
    if (mcdRD16(0xff8006) != 0x0A)return 0x0B;

    //with RS=1 no access
    mcdWR16(0xff8004, 0x0012);
    if (mcdRD16(0xff8006) == 0x95)return 0x0C;
    if (mcdRD16(0xff8006) == 0x0A)return 0x0C;

    //not try to write with RS=1
    mcdWR16(0xff8004, 0x0012);
    mcdWR16(0xff8006, 0x0000);
    mcdWR16(0xff8006, 0x0000);
    mcdWR16(0xff8004, 0x0002);
    if (mcdRD16(0xff8006) != 0x95)return 0x0B;
    if (mcdRD16(0xff8006) != 0x0A)return 0x0B;


    //make sure there is no increment on wr in 0
    mcdWR16(0xff8004, 0x0000);
    mcdWR16(0xff8006, 0x00aa);
    if (mcdRD16(0xff8004) != 0)return 0x0C;




    /*
    for (i = 0; i < 32 + 8; i++) {

        if (i % 8 == 0)gConsPrint("");
        gAppendHex8(mcdRD8(0xff8005));
        gAppendHex8(mcdRD8(0xff8007));
        gAppendString(".");
        //mcdRD16(0xff8006);

    }

    gConsPrint("");*/

    return 0;
}
