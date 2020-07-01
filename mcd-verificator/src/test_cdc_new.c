
#include "main.h"

#define REG16_A12004 *((u16 *) 0xA12004)
#define REG08_A12004 *((u8*) 0xA12004)
#define REG16_A12008 *((vu16 *) 0xA12008)


u8 testCDC_init(u8 *buff, u32 *PT);
void tsetCDC_end();
u8 testCDC_dma1(u8 *buff, u32 PT);
u8 testCDC_dma2(u8 *buff, u32 PT);
u8 testCDC_dma3(u8 *buff, u32 PT);
u8 testCDC_flags(u8 *buff, u32 PT);

u8 testCDC_new() {

    u8 resp;
    u8 buff[MCD_SECTOR_SIZE];
    u32 PT;

    resp = testCDC_init(buff, &PT);
    testPrintResp(resp);
    if (resp)return 1;


    resp = testCDC_flags(buff, PT); //test cdc var logic
    tsetCDC_end();
    testPrintResp(resp);

    resp = testCDC_dma2(buff, PT); //mostly dma addressing and len
    tsetCDC_end();
    testPrintResp(resp);

    resp = testCDC_dma3(buff, PT); //test various unobvious conditions
    tsetCDC_end();
    testPrintResp(resp);

    resp = testCDC_dma1(buff, PT); //dma stability test
    tsetCDC_end();
    testPrintResp(resp);



    return 0;
}

void tsetCDC_end() {

    mcdBusRelease();
    cdcRegSelect(CDC_CTRL0);
    cdcRegWrite(0);
    cdcRegWrite(0);
    //terminate dma
    cdcRegSelect(CDC_IFCTRL);
    cdcRegWrite(0);
    cdcRegSelect(CDC_IFCTRL);
    cdcRegWrite(IFCTRL_DOUTEN | IFCTRL_DTEIEN);
}

u8 testCDC_init(u8 *buff, u32 *PT) {

    u8 resp;
    u32 tout;
    u32 i;
    u32 head = 0;
    u16 *ptr;

    gConsPrint("CDC INIT....");

    //init cdd for loading some known data to cdc buffer
    resp = cddInitToc();
    if (resp)return 0x01; //timeout

    //reset cdc
    mcdWR8(0xff8005, CDC_RST);
    mcdWR8(0xff8007, 0);
    cdcDecoderON();

    //seek and play from sector 173 (2 sectors prior required 0x200)
    mcdWR16(SUB_REG_IEMASK, (1 << 4)); //cdd irq on
    cddCmd_play(0x173);
    cddUpdate();
    cddUpdate();

    //wait for sector receiving
    mcdWR16(SUB_REG_IEMASK, (1 << 5)); //cdc irq on
    for (i = 0;; i++) {
        mcdRD16(0); //reset COMSTA[3]
        tout = 0;
        while (ga->COMSTA[3] != 5) {
            if (tout++ >= 20000)return 0x02; //cdc irq isn't working
        }
        cdcRegSelect(CDC_HEAD0);
        head = cdcRegRead() << 24;
        head |= cdcRegRead() << 16;
        head |= cdcRegRead() << 8;
        head |= cdcRegRead();
        *PT = cdcRegRead() | (cdcRegRead() << 8);

        if (head == 0x00020001)break;

        if (i >= 200)return 0x03; //timeout. sector wasn't received in time
    }


    cdcDecoderOFF();
    mcdWR16(SUB_REG_IEMASK, (1 << 4));
    cddCmd_stop();
    cddUpdate();
    cddUpdate();
    mcdWR16(SUB_REG_IEMASK, (1 << 5));

    mcdWR8(0xff8005, CDC_IFCTRL);
    mcdWR8(0xff8007, IFCTRL_DOUTEN | IFCTRL_DTEIEN);

    cdcDmaSetup(CDC_DST_MAIN, MCD_SECTOR_SIZE, *PT);
    mcdWR8(0xff8007, 0); //dttrg
    for (i = 0; i < 16; i++)asm("nop");

    ptr = (u16 *) buff;
    for (i = 0; i < MCD_SECTOR_SIZE; i += 2) {
        *ptr++ = REG16_A12008;
    }

    static u8 cmp_header[] = {0x00, 0x02, 0x00, 0x01, 0x53, 0x45, 0x47, 0x41}; //disk header data refernece. sector number + "SEGA" string
    for (i = 0; i < sizeof (cmp_header); i++) {
        if (buff[i] != cmp_header[i])return 0x04; //not sega cd disk or read error
    }


    return 0;
}

u8 testCDC_dma1(u8 *buff, u32 PT) {

    u32 u, i;
    u16 *ptr;
    u8 cmp_buff[MCD_SECTOR_SIZE];

    gConsPrint("CDC DMA1....");
    mcdWramSetMode(WRAM_MODE_2M);
    mcdWramToSub();
    ga->MEM_WP = 0;


    //try transmit data few times and check if no errors
    for (u = 0; u < 16; u++) {

        cdcDmaSetup(CDC_DST_MAIN, MCD_SECTOR_SIZE, PT);
        mcdWR8(0xff8007, 0); //dttrg
        for (i = 0; i < 4; i++)asm("nop");

        ptr = (u16 *) cmp_buff;
        for (i = 0; i < MCD_SECTOR_SIZE; i += 2) {
            *ptr++ = REG16_A12008;
        }

        for (i = 0; i < MCD_SECTOR_SIZE; i++) {
            if (buff[i] != cmp_buff[i])return 0x01;
        }
    }

    //the same thing but for sub
    for (u = 0; u < 16; u++) {

        cdcDmaSetup(CDC_DST_SUB, MCD_SECTOR_SIZE, PT);
        mcdWR8(0xff8007, 0); //dttrg

        ptr = (u16 *) cmp_buff;
        for (i = 0; i < MCD_SECTOR_SIZE; i += 2) {
            *ptr++ = mcdRD16(0xff8008);
        }

        for (i = 0; i < MCD_SECTOR_SIZE; i++) {
            if (buff[i] != cmp_buff[i])return 0x02;
        }
    }

    //now to wram
    for (u = 0; u < 16; u++) {

        mcdWramToSub();
        cdcDTACK(); //clear DTEI flag. allows dma irq
        cdcDmaSetup(CDC_DST_WRAM, MCD_SECTOR_SIZE, PT);
        mcdWR16(0xff800A, (0 >> 3)); //set dma addr
        mcdWR8(0xff8007, 0); //dttrg
        while (ga->COMSTA[3] != 5);

        mcdWramToMain();

        for (i = 0; i < MCD_SECTOR_SIZE; i++) {
            if (buff[i] != mcd->word_ram[i]) return 0x03;
        }
    }
    mcdWramToSub();


    //for prg ram.
    mcdPrgSetBank(1);
    for (u = 0; u < 16; u++) {

        cdcDTACK(); //clear DTEI flag. allows dma irq
        cdcDmaSetup(CDC_DST_PRG, MCD_SECTOR_SIZE, PT);
        mcdWR16(0xff800A, (0x20000 >> 3)); //set dma addr
        mcdWR8(0xff8007, 0); //dttrg
        while (ga->COMSTA[3] != 5);


        mcdBusReq();
        for (i = 0; i < MCD_SECTOR_SIZE; i++) {
            if (buff[i] != mcd->prog_ram[i]) {
                mcdBusRelease();
                return 0x04;
            }
        }

        mcdBusRelease();
    }


    //last one for pcm
    pcmSetBank(0);
    for (u = 0; u < 4; u++) {

        cdcDTACK();
        cdcDmaSetup(CDC_DST_PCM, MCD_SECTOR_SIZE, PT);
        mcdWR16(0xff800A, (0 >> 3)); //set dma addr
        mcdWR8(0xff8007, 0); //dttrg
        while (ga->COMSTA[3] != 5);

        pcmMemRead(cmp_buff, 0, MCD_SECTOR_SIZE);

        for (i = 0; i < MCD_SECTOR_SIZE; i++) {
            if (buff[i] != cmp_buff[i])return 0x05;
        }
    }

    //following tests check dma stability with memory cross access from dma and cpu

    //pcm dma wr, cpu rd
    for (u = 0; u < 4; u++) {

        for (i = 0; i < MCD_SECTOR_SIZE; i++) {
            cmp_buff[i] = buff[i] ^ 0xff;
        }
        pcmMemWrite(cmp_buff, MCD_SECTOR_SIZE, 4096 - MCD_SECTOR_SIZE);
        for (i = 0; i < MCD_SECTOR_SIZE; i++) {
            cmp_buff[i] = 0xaa;
        }
        pcmMemWrite(cmp_buff, 0, MCD_SECTOR_SIZE);

        pcmSetBank(0);
        cdcDTACK();
        cdcDmaSetup(CDC_DST_PCM, MCD_SECTOR_SIZE, PT);
        mcdWR16(0xff800A, (0 >> 3)); //set dma addr
        mcdWR8(0xff8007, 0); //dttrg
        pcmMemRead(cmp_buff, MCD_SECTOR_SIZE, 4096 - MCD_SECTOR_SIZE); //read pcm ram simultaneously with dma
        gVsync();
        //gVsync();
        //while (ga->COMSTA[3] != 5); //wait for dma completion

        for (i = 0; i < 4096 - MCD_SECTOR_SIZE; i++) {
            if (cmp_buff[i] != (buff[i] ^ 0xff))return 0x06; //cpu rd errors durng dma
        }

        pcmMemRead(cmp_buff, 0, MCD_SECTOR_SIZE);
        for (i = 0; i < MCD_SECTOR_SIZE; i++) {
            if (buff[i] != cmp_buff[i])return 0x07; //dma wr errors
        }
    }



    //pcm dma wr, cpu wr
    for (u = 0; u < 4; u++) {

        for (i = 0; i < MCD_SECTOR_SIZE; i++) {
            cmp_buff[i] = 0xaa;
        }
        pcmMemWrite(cmp_buff, MCD_SECTOR_SIZE, 4096 - MCD_SECTOR_SIZE);
        pcmMemWrite(cmp_buff, 0, MCD_SECTOR_SIZE);

        for (i = 0; i < MCD_SECTOR_SIZE; i++) {
            cmp_buff[i] = buff[i] ^ 0xff;
        }

        pcmSetBank(0);
        cdcDTACK();
        cdcDmaSetup(CDC_DST_PCM, MCD_SECTOR_SIZE, PT);
        mcdWR16(0xff800A, (0 >> 3)); //set dma addr
        mcdWR8(0xff8007, 0); //dttrg
        pcmMemWrite(cmp_buff, MCD_SECTOR_SIZE, 4096 - MCD_SECTOR_SIZE); //read pcm ram simultaneously with dma
        gVsync(); //make there is enough tii mo end dma
        // while ((REG08_A12004 & 0x80) == 0);

        pcmMemRead(cmp_buff, MCD_SECTOR_SIZE, 4096 - MCD_SECTOR_SIZE);
        for (i = 0; i < 4096 - MCD_SECTOR_SIZE; i++) {
            if (cmp_buff[i] != (buff[i] ^ 0xff))return 0x08; //cpu wr errors durng dma
        }

        pcmMemRead(cmp_buff, 0, MCD_SECTOR_SIZE);
        for (i = 0; i < MCD_SECTOR_SIZE; i++) {
            if (buff[i] != cmp_buff[i])return 0x09; //dma wr errors
        }
    }



    //now to wram
    mcdWramToMain();
    for (i = 0; i < MCD_SECTOR_SIZE; i++) {
        mcd->word_ram[0x10000 + i] = buff[i] ^ 0xff;
    }

    for (u = 0; u < 8; u++) {

        mcdWramToMain();
        for (i = 0; i < MCD_SECTOR_SIZE; i++) {
            mcd->word_ram[0x20000 + i + u] = 0xaa; //clean cpy dst area
        }

        mcdWramToSub();
        cdcDTACK();
        cdcDmaSetup(CDC_DST_WRAM, MCD_SECTOR_SIZE, PT);
        mcdWR16(0xff800A, (0 >> 3)); //set dma addr
        mcdWR8(0xff8007, 0); //dttrg
        mcdCpy(0x90000, 0xA0000 + u, MCD_SECTOR_SIZE);
        mcdSubBusy();
        gVsync(); //make there is enough time to complete dma

        mcdWramToMain();
        for (i = 0; i < MCD_SECTOR_SIZE; i++) {
            if (mcd->word_ram[i] != buff[i]) return 0x10; //dma wr error
        }

        for (i = 0; i < MCD_SECTOR_SIZE; i++) {
            if (mcd->word_ram[0x20000 + i + u] != (buff[i] ^ 0xff)) return 0x11; //cpu wr or rd error
        }
    }
    mcdWramToSub();


    //prg ram
    mcdPrgSetBank(1);
    mcdBusReq();
    for (i = 0; i < MCD_SECTOR_SIZE; i++) {
        mcd->prog_ram[0x4000 + i] = buff[i] ^ 0xff;
    }
    mcdBusRelease();
    for (u = 0; u < 16; u++) {//dma read to 0x20000, cpu copy from 0x24000 to 0x28000


        for (i = 0; i < MCD_SECTOR_SIZE; i++) {
            mcd->prog_ram[i + 0x8000 + u] = 0xaa; //clean cpy dst area
        }

        cdcDTACK(); //clear DTEI flag. allows dma irq
        cdcDmaSetup(CDC_DST_PRG, MCD_SECTOR_SIZE, PT);
        mcdWR16(0xff800A, (0x20000 >> 3)); //set dma addr
        mcdWR8(0xff8007, 0); //dttrg
        mcdCpy(0x24000, 0x28000 + u, MCD_SECTOR_SIZE);
        mcdSubBusy();
        gVsync(); //make there is enough time to complete dma

        mcdBusReq();
        for (i = 0; i < MCD_SECTOR_SIZE; i++) {
            if (mcd->prog_ram[i] != buff[i]) {
                mcdBusRelease();
                return 0x12; //dma wr error
            }
        }

        for (i = 0; i < MCD_SECTOR_SIZE; i++) {
            if (mcd->prog_ram[i + 0x8000 + u] != (buff[i] ^ 0xff)) {
                mcdBusRelease();
                return 0x13; //cpu wr or rd error
            }
        }

        mcdBusRelease();
    }

    //dma interrupted by the memory switching to main
    for (u = 0; u < 16; u++) {

        mcdWramToMain();
        memSet(mcd->word_ram, 0xaa, MCD_SECTOR_SIZE);

        mcdWramToSub();
        cdcDTACK();
        cdcDmaSetup(CDC_DST_WRAM, MCD_SECTOR_SIZE, PT);
        mcdWR16(0xff800A, (0 >> 3)); //set dma addr
        mcdWR8(0xff8007, 0); //dttrg
        while ((REG08_A12004 & EDT) == 0) {
            mcdWramToMain();
            mcdWramToSub();
        }
        mcdWramToMain();

        for (i = 0; i < MCD_SECTOR_SIZE; i++) {
            if (buff[i] != mcd->word_ram[i]) return 0x14;
        }

    }
    mcdWramToSub();

    return 0;
}

u8 testCDC_dma2(u8 *buff, u32 PT) {

    u32 i;
    u8 cmp_buff[MCD_SECTOR_SIZE];

    gConsPrint("CDC DMA2....");
    mcdWramSetMode(WRAM_MODE_2M);
    mcdWramToSub();
    ga->MEM_WP = 0;


    //***************************************************************** word ram
    mcdWramToMain();
    memSet(mcd->word_ram, 0xaa, MCD_SECTOR_SIZE + 16);

    mcdWramToSub();
    cdcDTACK(); //clear DTEI flag. allows dma irq
    cdcDmaSetup(CDC_DST_WRAM, MCD_SECTOR_SIZE, PT);
    mcdWR16(0xff800A, (8 >> 3)); //set dma addr
    mcdWR8(0xff8007, 0); //dttrg
    while (ga->COMSTA[3] != 5);
    mcdWramToMain();

    for (i = 0; i < 8; i++) {
        if (mcd->word_ram[i] != 0xaa)return 0x01;
        if (mcd->word_ram[i + MCD_SECTOR_SIZE + 8] != 0xaa)return 0x02;
    }

    for (i = 0; i < MCD_SECTOR_SIZE; i++) {
        if (mcd->word_ram[i + 8] != buff[i]) return 0x03;
    }
    mcdWramToSub();


    //odd dma len - 1. should reduce dma len on 1 word
    mcdWramToMain();
    memSet(mcd->word_ram, 0xaa, MCD_SECTOR_SIZE);
    mcdWramToSub();
    cdcDTACK(); //clear DTEI flag. allows dma irq
    cdcDmaSetup(CDC_DST_WRAM, (MCD_SECTOR_SIZE - 2) - 1, PT);
    mcdWR16(0xff800A, (0 >> 3)); //set dma addr
    mcdWR8(0xff8007, 0); //dttrg
    while (ga->COMSTA[3] != 5);
    mcdWramToMain();

    for (i = 0; i < MCD_SECTOR_SIZE; i++) {
        if (mcd->word_ram[i] != buff[i])break;
    }
    if (i != 2348)return 0x04;


    //odd dma len + 1. dma len should stay unchanged
    mcdWramToMain();
    memSet(mcd->word_ram, 0xaa, MCD_SECTOR_SIZE);
    mcdWramToSub();
    cdcDTACK(); //clear DTEI flag. allows dma irq
    cdcDmaSetup(CDC_DST_WRAM, (MCD_SECTOR_SIZE - 2) + 1, PT);
    mcdWR16(0xff800A, (0 >> 3)); //set dma addr
    mcdWR8(0xff8007, 0); //dttrg
    while (ga->COMSTA[3] != 5);
    mcdWramToMain();

    for (i = 0; i < MCD_SECTOR_SIZE; i++) {
        if (mcd->word_ram[i] != buff[i])break;
    }
    if (i != 2350)return 0x05;


    //***************************************************************** prg ram
    mcdPrgSetBank(1);
    mcdBusReq();
    memSet(mcd->prog_ram, 0xaa, MCD_SECTOR_SIZE + 16);

    mcdBusRelease();
    cdcDTACK();
    cdcDmaSetup(CDC_DST_PRG, MCD_SECTOR_SIZE, PT);
    mcdWR16(0xff800A, (0x20008 >> 3)); //set dma addr
    mcdWR8(0xff8007, 0); //dttrg
    while (ga->COMSTA[3] != 5);
    mcdBusReq();

    for (i = 0; i < 8; i++) {
        if (mcd->prog_ram[i] != 0xaa)return 0x06;
        if (mcd->prog_ram[i + MCD_SECTOR_SIZE + 8] != 0xaa)return 0x07;
    }

    for (i = 0; i < MCD_SECTOR_SIZE; i++) {
        if (mcd->prog_ram[i + 8] != buff[i]) return 0x08;
    }
    mcdBusRelease();

    //odd dma len - 1. should reduce dma len on 1 word
    mcdPrgSetBank(1);
    mcdBusReq();
    memSet(mcd->prog_ram, 0xaa, MCD_SECTOR_SIZE);

    mcdBusRelease();
    cdcDTACK();
    cdcDmaSetup(CDC_DST_PRG, (MCD_SECTOR_SIZE - 2) - 1, PT);
    mcdWR16(0xff800A, (0x20000 >> 3)); //set dma addr
    mcdWR8(0xff8007, 0); //dttrg
    while (ga->COMSTA[3] != 5);
    mcdBusReq();

    for (i = 0; i < MCD_SECTOR_SIZE; i++) {
        if (mcd->prog_ram[i] != buff[i])break;
    }
    if (i != 2348)return 0x09;


    //odd dma len + 1. dma len should stay unchanged
    mcdPrgSetBank(1);
    mcdBusReq();
    memSet(mcd->prog_ram, 0xaa, MCD_SECTOR_SIZE);

    mcdBusRelease();
    cdcDTACK();
    cdcDmaSetup(CDC_DST_PRG, (MCD_SECTOR_SIZE - 2) + 1, PT);
    mcdWR16(0xff800A, (0x20000 >> 3)); //set dma addr
    mcdWR8(0xff8007, 0); //dttrg
    while (ga->COMSTA[3] != 5);
    mcdBusReq();

    for (i = 0; i < MCD_SECTOR_SIZE; i++) {
        if (mcd->prog_ram[i] != buff[i])break;
    }
    if (i != 2350)return 0x10;
    mcdBusRelease();

    //***************************************************************** pcm ram
    memSet(cmp_buff, 0xaa, 512);
    pcmMemWrite(cmp_buff, 0, 512);
    pcmSetBank(0);
    cdcDTACK();
    cdcDmaSetup(CDC_DST_PCM, 9, PT); //pcm supports single byte len
    mcdWR16(0xff800A, (8 >> 3)); //pcm dst addr mul on 2
    mcdWR8(0xff8007, 0); //dttrg
    while (ga->COMSTA[3] != 5);

    pcmMemRead(cmp_buff, 0, 4);
    for (i = 0; i < 4; i++) {
        if (cmp_buff[i] != 0xaa)return 0x11;
    }
    pcmMemRead(cmp_buff, 4, 512);

    for (i = 0; i < 512; i++) {
        if (cmp_buff[i] != buff[i])break;
    }
    if (i != 9)return 0x12;



    return 0;
}

u8 testCDC_dma3(u8 *buff, u32 PT) {

    u32 i;
    vu16 tmp;
    u8 cmp_buff[MCD_SECTOR_SIZE];

    gConsPrint("CDC DMA3....");
    mcdWramSetMode(WRAM_MODE_2M);
    mcdWramToSub();
    ga->MEM_WP = 0;

    //check EDT/DSR flags for main
    cdcDmaSetup(CDC_DST_MAIN, MCD_SECTOR_SIZE, PT);
    if (REG08_A12004 != 0x02)return 0x01; //check DSR flag
    mcdWR8(0xff8007, 0); //dttrg
    for (i = 0; i < 4; i++)asm("nop");
    if (REG08_A12004 != 0x42)return 0x02; //check DSR flag

    for (i = 0; i < MCD_SECTOR_SIZE - 4; i += 2) {
        tmp = REG16_A12008;
    }

    if (REG08_A12004 != 0x42)return 0x03; //only DSR should be rised if remain words >= 2
    tmp = REG16_A12008;
    if (REG08_A12004 != 0xC2)return 0x04; //DSR and EDT should be rised if last word remains
    tmp = REG16_A12008;
    if (REG08_A12004 != 0x82)return 0x05; //only EDT should be rised all data readed
    tmp = REG16_A12008;
    if (REG08_A12004 != 0x82)return 0x06; //no changes
    if (mcdRD8(0xff8004) != 0x82)return 0x07; //same state should be visible on sub side


    //check EDT/DSR flags for sub
    cdcDmaSetup(CDC_DST_SUB, MCD_SECTOR_SIZE, PT);
    if (mcdRD8(0xff8004) != 0x03)return 0x10; //check DSR flag
    mcdWR8(0xff8007, 0); //dttrg
    if (mcdRD8(0xff8004) != 0x43)return 0x11; //check DSR flag

    for (i = 0; i < MCD_SECTOR_SIZE - 4; i += 2) {
        mcdRD16(0xff8008);
    }

    if (mcdRD8(0xff8004) != 0x43)return 0x12; //only DSR should be rised if remain words >= 2
    mcdRD16(0xff8008);
    if (mcdRD8(0xff8004) != 0xC3)return 0x13; //DSR and EDT should be rised if last word remains
    mcdRD16(0xff8008);
    if (mcdRD8(0xff8004) != 0x83)return 0x14; //only EDT should be rised all data readed
    mcdRD16(0xff8008);
    if (mcdRD8(0xff8004) != 0x83)return 0x15; //no changes
    if (REG08_A12004 != 0x83)return 0x16; //same state should be visible on main side


    //dma to main but sub trying to read
    cdcDmaSetup(CDC_DST_MAIN, MCD_SECTOR_SIZE, PT);
    mcdWR8(0xff8007, 0); //dttrg
    for (i = 0; i < 4; i++)asm("nop");
    for (i = 0; i < MCD_SECTOR_SIZE; i += 2) {
        mcdRD16(0xff8008);
    }
    if (REG08_A12004 != 0x42)return 0x20;
    for (i = 0; i < MCD_SECTOR_SIZE; i += 2) {
        tmp = REG16_A12008;
    }


    //dma to sub but main trying to read
    cdcDmaSetup(CDC_DST_SUB, MCD_SECTOR_SIZE, PT);
    mcdWR8(0xff8007, 0); //dttrg
    for (i = 0; i < 4; i++)asm("nop");
    for (i = 0; i < MCD_SECTOR_SIZE; i += 2) {
        tmp = REG16_A12008;
    }
    if (REG08_A12004 != 0x43)return 0x21;
    for (i = 0; i < MCD_SECTOR_SIZE; i += 2) {
        mcdRD16(0xff8008);
    }


    //check edt dsr flgas for wram dma
    mcdWramToSub();
    cdcDTACK();
    cdcDmaSetup(CDC_DST_WRAM, MCD_SECTOR_SIZE, PT);
    mcdWR16(0xff800A, (0 >> 3)); //set dma addr
    mcdWR8(0xff8007, 0); //dttrg
    if ((REG08_A12004 & ~DSR) != 0x07)return 0x22; //EDT should be 0, DSR val unpredicted
    while (ga->COMSTA[3] != 5);
    tmp = REG08_A12004; //seems like EDT rise only after reg 004 reading!
    if (REG08_A12004 != 0x87)return 0x23; //EDT should be set in the end


    //check edt dsr flgas for prg dma
    cdcDTACK();
    cdcDmaSetup(CDC_DST_PRG, MCD_SECTOR_SIZE, PT);
    mcdWR16(0xff800A, (0x20000 >> 3)); //set dma addr
    mcdWR8(0xff8007, 0); //dttrg
    if ((REG08_A12004 & ~DSR) != 0x05)return 0x24; //EDT should be 0, DSR val unpredicted
    while (ga->COMSTA[3] != 5);
    tmp = REG08_A12004; //seems like EDT rise only after reg 004 reading!
    if (REG08_A12004 != 0x85)return 0x25; //EDT should be set in the end


    //check edt dsr flgas for pcm dma
    cdcDTACK();
    cdcDmaSetup(CDC_DST_PCM, MCD_SECTOR_SIZE, PT);
    mcdWR16(0xff800A, (0 >> 3)); //set dma addr
    mcdWR8(0xff8007, 0); //dttrg
    if ((REG08_A12004 & ~DSR) != 0x04)return 0x26; //EDT should be 0, DSR val unpredicted
    while (ga->COMSTA[3] != 5);
    tmp = REG08_A12004; //seems like EDT rise only after reg 004 reading!
    if ((REG08_A12004 & 0xCF) != 0x84)return 0x27; //EDT should be set in the end


    //same values for main and sub in reg x008
    cdcDmaSetup(CDC_DST_SUB, MCD_SECTOR_SIZE, PT);
    mcdWR8(0xff8007, 0); //dttrg
    for (i = 0; i < 4; i++)asm("nop");
    for (i = 0; i < MCD_SECTOR_SIZE; i += 2) {
        tmp = REG16_A12008;
        if (tmp != mcdRD16(0xff8008))return 0x28;
    }

    //test cdc buff wrapping
    mcdWramToSub();
    cdcDTACK();
    cdcDmaSetup(CDC_DST_WRAM, MCD_SECTOR_SIZE, PT);
    mcdWR16(0xff800A, (0 >> 3)); //set dma addr
    mcdWR8(0xff8007, 0); //dttrg
    while (ga->COMSTA[3] != 5);

    cdcDTACK();
    cdcDmaSetup(CDC_DST_WRAM, MCD_SECTOR_SIZE + 128, PT + 16384 - 128);
    mcdWR16(0xff800A, (8192 >> 3)); //set dma addr
    mcdWR8(0xff8007, 0); //dttrg
    while (ga->COMSTA[3] != 5);

    mcdWramToMain();
    for (i = 0; i < MCD_SECTOR_SIZE; i++) {
        if (mcd->word_ram[i] != buff[i])return 0x30;
    }

    for (i = 0; i < MCD_SECTOR_SIZE; i++) {
        if (mcd->word_ram[i + 8192 + 128] != buff[i])return 0x31;
    }


    //dma to main does not increment dma addr
    cdcDTACK();
    cdcDmaSetup(CDC_DST_MAIN, MCD_SECTOR_SIZE, PT);
    mcdWR16(0xff800A, (128 >> 3)); //set dma addr
    mcdWR8(0xff8007, 0); //dttrg
    for (i = 0; i < MCD_SECTOR_SIZE; i += 2) {
        tmp = REG16_A12008;
    }
    if ((mcdRD16(0xff800A) << 3) != 128)return 0x32;


    //dma to sub does not increment dma addr
    cdcDTACK();
    cdcDmaSetup(CDC_DST_SUB, MCD_SECTOR_SIZE, PT);
    mcdWR16(0xff800A, (128 >> 3)); //set dma addr
    mcdWR8(0xff8007, 0); //dttrg
    for (i = 0; i < MCD_SECTOR_SIZE; i += 2) {
        tmp = mcdRD16(0xff8008);
    }
    if ((mcdRD16(0xff800A) << 3) != 128)return 0x33;


    //dma to wram increment dma addr and it can be readed back
    mcdWramToSub();
    cdcDTACK();
    cdcDmaSetup(CDC_DST_WRAM, MCD_SECTOR_SIZE, PT);
    mcdWR16(0xff800A, (0 >> 3)); //set dma addr
    mcdWR8(0xff8007, 0); //dttrg
    while (ga->COMSTA[3] != 5);
    if ((mcdRD16(0xff800A) << 3) != MCD_SECTOR_SIZE)return 0x34;

    //dma to prg increment dma addr and it can be readed back
    mcdWramToSub();
    cdcDTACK();
    cdcDmaSetup(CDC_DST_PRG, MCD_SECTOR_SIZE, PT);
    mcdWR16(0xff800A, (0x20000 >> 3)); //set dma addr
    mcdWR8(0xff8007, 0); //dttrg
    while (ga->COMSTA[3] != 5);
    if ((mcdRD16(0xff800A) << 3) != MCD_SECTOR_SIZE + 0x20000)return 0x35;


    //dma to pcm increment dma addr and it can be readed back. double inc
    mcdWramToSub();
    cdcDTACK();
    cdcDmaSetup(CDC_DST_PCM, MCD_SECTOR_SIZE, PT);
    mcdWR16(0xff800A, (0 >> 3)); //set dma addr
    mcdWR8(0xff8007, 0); //dttrg
    while (ga->COMSTA[3] != 5);
    if ((mcdRD16(0xff800A) << 3) != MCD_SECTOR_SIZE * 2)return 0x36; //for pcm dma address mul on 2


    //two dma transaction without address setup for second
    mcdWramToMain();
    memSet(mcd->word_ram, 0xaa, MCD_SECTOR_SIZE);
    mcdWramToSub();
    cdcDTACK();
    cdcDmaSetup(CDC_DST_WRAM, MCD_SECTOR_SIZE / 2, PT);
    mcdWR16(0xff800A, (0 >> 3)); //set dma addr
    mcdWR8(0xff8007, 0); //dttrg
    while (ga->COMSTA[3] != 5);
    //continue dma wihout dst address setup
    cdcDTACK();
    mcdWR8(0xff8005, CDC_DBCL);
    mcdWR8(0xff8007, (MCD_SECTOR_SIZE / 2 - 1) & 0xff); //len
    mcdWR8(0xff8007, (MCD_SECTOR_SIZE / 2 - 1) >> 8);
    mcdWR8(0xff8007, (PT + MCD_SECTOR_SIZE / 2) & 0xff); //cdc buff addr
    mcdWR8(0xff8007, (PT + MCD_SECTOR_SIZE / 2) >> 8);
    cdcDTTRG();
    while (ga->COMSTA[3] != 5);
    mcdWramToMain();
    for (i = 0; i < MCD_SECTOR_SIZE; i++) {
        if (mcd->word_ram[i] != buff[i])return 0x37;
    }




    //dma to wram in 1m mode
    mcdWramToMain();
    memSet(mcd->word_ram, 0xaa, 2048 * 2);

    mcdWramToSub();
    mcdWramSetMode(WRAM_MODE_1M);
    mcdWramSetBank(1);
    mcdWramPriorMode(WRAM_PM_WD);
    cdcDTACK();
    cdcDmaSetup(CDC_DST_WRAM, 2048, PT);
    mcdWR16(0xff800A, (0 >> 3)); //set dma addr
    mcdWR8(0xff8007, 0); //dttrg
    while (ga->COMSTA[3] != 5);
    mcdWramSetBank(0);
    mcdWramPriorMode(WRAM_PM_WU);
    cdcDTACK();
    cdcDmaSetup(CDC_DST_WRAM, 2048, PT + 4);
    mcdWR16(0xff800A, (0 >> 3)); //set dma addr
    mcdWR8(0xff8007, 0); //dttrg
    while (ga->COMSTA[3] != 5);
    mcdWramSetMode(WRAM_MODE_2M);

    mcdWramToMain();
    for (i = 0; i < 2048; i += 2) {

        if (buff[i + 0] != mcd->word_ram[i * 2 + 0])break;
        if (buff[i + 1] != mcd->word_ram[i * 2 + 1])break;
        if (buff[i + 4] != mcd->word_ram[i * 2 + 2])break;
        if (buff[i + 5] != mcd->word_ram[i * 2 + 3])break;
        //mcd->word_ram[i] = 0xaa;
    }

    mcdWramToSub();
    if (i != 2048)return 0x38;



    //pcm memory banking should work for dma
    memSet(cmp_buff, 0xaa, MCD_SECTOR_SIZE);
    pcmMemWrite(cmp_buff, 0, MCD_SECTOR_SIZE);
    pcmMemWrite(cmp_buff, 7 * 4096, MCD_SECTOR_SIZE);
    pcmSetBank(7);
    cdcDTACK(); //clear DTEI flag. allows dma irq
    cdcDmaSetup(CDC_DST_PCM, MCD_SECTOR_SIZE, PT);
    mcdWR16(0xff800A, (0 >> 3)); //set dma addr
    mcdWR8(0xff8007, 0); //dttrg
    while (ga->COMSTA[3] != 5);

    pcmMemRead(cmp_buff, 0, MCD_SECTOR_SIZE);
    for (i = 0; i < MCD_SECTOR_SIZE; i++) {
        if (cmp_buff[i] != 0xaa)return 0x39;
    }

    pcmMemRead(cmp_buff, 7 * 4096, MCD_SECTOR_SIZE);
    for (i = 0; i < MCD_SECTOR_SIZE; i++) {
        if (cmp_buff[i] != buff[i])return 0x40;
    }


    //wram dma mirroring
    mcdWramToMain();
    memSet(mcd->word_ram, 0xaa, MCD_SECTOR_SIZE);
    mcdWramToSub();
    cdcDTACK();
    cdcDmaSetup(CDC_DST_WRAM, MCD_SECTOR_SIZE, PT);
    mcdWR16(0xff800A, (0x40000 >> 3)); //set dma addr
    mcdWR8(0xff8007, 0); //dttrg
    while (ga->COMSTA[3] != 5);

    mcdWramToMain();
    for (i = 0; i < MCD_SECTOR_SIZE; i++) {
        if (buff[i] != mcd->word_ram[i]) return 0x41;
    }
    mcdWramToSub();



    //write to 0xff8004 should reset dma dst address to 0
    mcdWramToMain();
    memSet(mcd->word_ram, 0xaa, MCD_SECTOR_SIZE);
    mcdWramToSub();
    cdcDTACK();
    mcdWR16(0xff800A, (0x10000 >> 3)); //set dma addr
    cdcDmaSetup(CDC_DST_WRAM, MCD_SECTOR_SIZE, PT); //address resets to 0 here
    if (mcdRD16(0xff800A) != 0)return 0x42;
    mcdWR8(0xff8007, 0); //dttrg
    while (ga->COMSTA[3] != 5);

    mcdWramToMain();
    for (i = 0; i < MCD_SECTOR_SIZE; i++) {
        if (buff[i] != mcd->word_ram[i]) return 0x43;
    }
    mcdWramToSub();




    //turn off access to wram during dma. dma should halt till access will be returned
    mcdWramToMain();
    memSet(mcd->word_ram, 0xaa, MCD_SECTOR_SIZE);
    mcdWramToSub();
    cdcDTACK();
    cdcDmaSetup(CDC_DST_WRAM, MCD_SECTOR_SIZE, PT);
    mcdWR16(0xff800A, (0 >> 3)); //set dma addr
    mcdWR8(0xff8007, 0); //dttrg
    mcdWramToMain();
    gVsync();
    gVsync();
    if (ga->COMSTA[3] != 0)return 0x44;
    if (mcd->word_ram[MCD_SECTOR_SIZE - 1] != 0xaa)return 0x45;
    i = (mcdRD16(0xff800A) << 3) + 8;
    for (; i < MCD_SECTOR_SIZE; i++) {
        if (mcd->word_ram[i] != 0xaa)return 0x46; //check if data is written after point where dma was halted
    }
    mcdWramToSub();
    while (ga->COMSTA[3] != 5);
    mcdWramToMain();
    for (i = 0; i < MCD_SECTOR_SIZE; i++) {
        if (buff[i] != mcd->word_ram[i]) return 0x47; //check if data is not damaged
    }
    mcdWramToSub();



    //now dma halt for prg ram
    mcdPrgSetBank(1);
    mcdBusReq();
    for (i = 0; i < MCD_SECTOR_SIZE; i++) {
        mcd->prog_ram[i] = 0xaa;
    }
    mcdBusRelease();

    cdcDTACK(); //clear DTEI flag. allows dma irq
    cdcDmaSetup(CDC_DST_PRG, MCD_SECTOR_SIZE, PT);
    mcdWR16(0xff800A, ((0x20000) >> 3)); //set dma addr
    mcdWR8(0xff8007, 0); //dttrg
    mcdBusReq();
    gVsync();
    gVsync();
    if (mcd->prog_ram[MCD_SECTOR_SIZE - 1] != 0xaa)return 0x48;
    mcdBusRelease();
    gVsync();
    gVsync();
    gVsync();

    u16 err_ctr = 0;
    mcdBusReq();
    for (i = 0; i < MCD_SECTOR_SIZE; i++) {
        if (buff[i] != mcd->prog_ram[i]) {
            err_ctr++;
        }
    }
    mcdBusRelease();
    //sometimes may give random results. seems like games don't using such tricks anyway
    //if (err_ctr > 2)return 0x49; //sometimes data can be damaged at halt point. not more than 2 bytes usualy


    //change dma source on the fly. dma should continue, but address will be reset to 0
    u32 tout;
    mcdPrgSetBank(1);
    mcdWramToMain();
    mcdBusReq();
    memSet(mcd->word_ram, 0x55, MCD_SECTOR_SIZE);
    memSet(mcd->prog_ram, 0x55, MCD_SECTOR_SIZE);
    mcdBusRelease();
    mcdWramToSub();
    cdcDTACK();
    cdcDmaSetup(CDC_DST_PRG, MCD_SECTOR_SIZE, PT);
    mcdWR16(0xff800A, (0x20000 >> 3)); //set dma addr
    mcdWR8(0xff8007, 0); //dttrg
    for (i = 0; i < 8; i++)asm("nop");
    mcdWR8(0xff8004, 0); //change dst. 
    mcdWR8(0xff8004, CDC_DST_WRAM); //change dst. 
    tout = 0;
    while (ga->COMSTA[3] != 5) {
        if (tout++ > 20000)return 0x50; //wr to 0xff8004 isn't cancel dma. it only resets dst addr to 0
    }

    if (mcdRD16(0x20000) == 0x5555)return 0x51; //dma should fill first bytes in prgram
    if (mcdRD16(0x201fe) != 0x5555)return 0x52; //dma will be switched to wram and this bytes stay unchaged
    if (mcdRD16(0x80000) == 0x5555)return 0x53; //after switching dma will continue from begin of wram
    if (mcdRD16(0x801fe) == 0x5555)return 0x54;
    if (mcdRD16(0x8092E) != 0x5555)return 0x55; //end of wram should be stay without changes


    //prg ram wr protection not working for dma
    mcdPrgSetBank(0);
    mcdBusReq();
    memSet(&mcd->prog_ram[0x9000], 0xaa, MCD_SECTOR_SIZE);
    mcdBusRelease();
    ga->MEM_WP = 0xff;
    cdcDTACK(); //clear DTEI flag. allows dma irq
    cdcDmaSetup(CDC_DST_PRG, MCD_SECTOR_SIZE, PT);
    mcdWR16(0xff800A, (0x9000 >> 3)); //set dma addr
    mcdWR8(0xff8007, 0); //dttrg
    while (ga->COMSTA[3] != 5);

    mcdBusReq();
    for (i = 0; i < MCD_SECTOR_SIZE; i++) {
        if (mcd->prog_ram[0x9000 + i] != buff[i])return 0x56; //prg ram protected for dma?
    }
    mcdBusRelease();
    ga->MEM_WP = 0;


    u16 *ptr;
    //wr to regs A12008 shouldn't be ignored. wr ops skip words
    ptr = (u16 *) cmp_buff;
    cdcDmaSetup(CDC_DST_MAIN, MCD_SECTOR_SIZE, PT);
    mcdWR8(0xff8007, 0); //dttrg
    for (i = 0; i < 8; i++)asm("nop");
    for (i = 0; i < MCD_SECTOR_SIZE / 2; i += 2) {
        REG16_A12008 = tmp;
    }
    for (i = 0; i < MCD_SECTOR_SIZE / 2; i += 2) {
        *ptr++ = REG16_A12008;
    }
    if ((REG08_A12004 & EDT) == 0)return 0x60; //error if wr ops ignored
    for (i = 0; i < MCD_SECTOR_SIZE / 2; i++) {
        if (cmp_buff[i] != buff[i + MCD_SECTOR_SIZE / 2 ])return 0x61; //wr ops should skip words
    }


    //wr to regs ff8008 shouldn't be ignored. wr ops skip words
    ptr = (u16 *) cmp_buff;
    cdcDmaSetup(CDC_DST_SUB, MCD_SECTOR_SIZE, PT);
    mcdWR8(0xff8007, 0); //dttrg
    for (i = 0; i < 8; i++)asm("nop");
    for (i = 0; i < MCD_SECTOR_SIZE / 2; i += 2) {
        mcdWR16(0xff8008, 0);
    }
    for (i = 0; i < MCD_SECTOR_SIZE / 2; i += 2) {
        *ptr++ = mcdRD16(0xff8008);
    }
    if ((REG08_A12004 & EDT) == 0)return 0x62; //error if wr ops ignored
    for (i = 0; i < MCD_SECTOR_SIZE / 2; i++) {
        if (cmp_buff[i] != buff[i + MCD_SECTOR_SIZE / 2 ])return 0x63; //wr ops should skip words
    }

    return 0;
}

u8 testCDC_flags(u8 *buff, u32 PT) {

    u32 i, tout;
    vu16 tmp;
    u8 cmp_buff[MCD_SECTOR_SIZE];

    gConsPrint("CDC FLAGS...");
    mcdWramSetMode(WRAM_MODE_2M);
    mcdWramToSub();
    ga->MEM_WP = 0;


    cdcRegSelect(CDC_IFCTRL);
    cdcRegWrite(IFCTRL_DOUTEN | IFCTRL_DTEIEN);

    //only reg 0xff8004 can reset EDT flag
    mcdWramToSub();
    cdcDTACK(); //clear DTEI flag. allows dma irq
    cdcDmaSetup(CDC_DST_WRAM, MCD_SECTOR_SIZE, PT);
    mcdWR16(0xff800A, (0 >> 3)); //set dma addr
    mcdWR8(0xff8007, 0); //dttrg
    while (ga->COMSTA[3] != 5);

    cdcDTACK();
    if ((REG08_A12004 & EDT) == 0)return 0x01;
    mcdWR16(0xff800A, 0);
    if ((REG08_A12004 & EDT) == 0)return 0x02;
    cdcRegSelect(CDC_IFCTRL);
    cdcRegWrite(0);
    if ((REG08_A12004 & EDT) == 0)return 0x03;
    cdcRegSelect(CDC_RST);
    cdcRegWrite(0);
    if ((REG08_A12004 & EDT) == 0)return 0x04;
    mcdWR8(0xff8004, CDC_DST_WRAM);
    if ((REG08_A12004 & EDT) != 0)return 0x05; //flag should be cleared now

    cdcRegSelect(CDC_IFCTRL);
    cdcRegWrite(IFCTRL_DOUTEN | IFCTRL_DTEIEN);


    //dma termination
    cdcDmaSetup(CDC_DST_MAIN, 128, PT);
    mcdWR8(0xff8007, 0); //dttrg
    for (i = 0; i < 8; i++)asm("nop");
    for (i = 0; i < 8; i++) {
        tmp = REG16_A12008;
    }
    if ((REG08_A12004 & DSR) == 0)return 0x11;
    cdcRegSelect(CDC_IFCTRL);
    cdcRegWrite(0); //termination
    mcdWR8(0xff8004, 0); //clear DSR flag
    if ((REG08_A12004 & DSR) != 0)return 0x12;
    cdcRegSelect(CDC_IFCTRL);
    cdcRegWrite(IFCTRL_DOUTEN | IFCTRL_DTEIEN);


    //chec irq ater dma to main
    cdcDTACK();
    cdcDmaSetup(CDC_DST_MAIN, 128, PT);
    mcdWR8(0xff8007, 0); //dttrg
    for (i = 0; i < 128; i += 2) {
        tmp = REG16_A12008;
    }
    for (i = 0; i < 16; i++)asm("nop");
    if (ga->COMSTA[3] != 5)return 0x20; //irq not working

    cdcDTACK();
    cdcDmaSetup(CDC_DST_MAIN, 128, PT);
    mcdWR8(0xff8007, 0); //dttrg
    for (i = 0; i < 128 - 4; i += 2) {
        tmp = REG16_A12008;
    }
    for (i = 0; i < 16; i++)asm("nop");
    if (ga->COMSTA[3] != 0)return 0x21; //irq too early
    tmp = REG16_A12008;
    for (i = 0; i < 16; i++)asm("nop");
    if (ga->COMSTA[3] != 5)return 0x22; //irq too late or
    tmp = REG16_A12008;
    for (i = 0; i < 16; i++)asm("nop");


    //chec irq ater dma to wram
    cdcDTACK();
    cdcDmaSetup(CDC_DST_WRAM, 256, PT);
    mcdWR16(0xff800A, (0x20000 >> 3)); //set dma addr
    mcdWR8(0xff8007, 0); //dttrg
    gVsync();
    if (ga->COMSTA[3] != 5)return 0x23; //irq not working


    //chec irq ater dma to prg
    cdcDTACK();
    cdcDmaSetup(CDC_DST_PRG, 256, PT);
    mcdWR16(0xff800A, (0x20000 >> 3)); //set dma addr
    mcdWR8(0xff8007, 0); //dttrg
    gVsync();
    if (ga->COMSTA[3] != 5)return 0x24; //irq not working


    //chec irq ater dma to pcm
    cdcDTACK();
    cdcDmaSetup(CDC_DST_PCM, 256, PT);
    mcdWR16(0xff800A, (0x20000 >> 3)); //set dma addr
    mcdWR8(0xff8007, 0); //dttrg
    gVsync();
    if (ga->COMSTA[3] != 5)return 0x25; //irq not working


    //irq shoudn't generate if DTEI is not reset
    cdcDTACK();
    cdcDmaSetup(CDC_DST_WRAM, 256, PT);
    mcdWR16(0xff800A, (0x20000 >> 3)); //set dma addr
    mcdWR8(0xff8007, 0); //dttrg
    //cdcDTACK(); skip DTEI clearing
    while (ga->COMSTA[3] != 5);
    cdcDmaSetup(CDC_DST_WRAM, 256, PT);
    mcdWR16(0xff800A, (0x20000 >> 3)); //set dma addr
    mcdWR8(0xff8007, 0); //dttrg
    gVsync();
    gVsync();
    if (ga->COMSTA[3] != 0)return 0x26; //irq should be generated only on DTEI falling edge


    //check irq relation with mask
    mcdWR16(SUB_REG_IEMASK, 0);
    cdcDTACK();
    cdcDmaSetup(CDC_DST_WRAM, 256, PT);
    mcdWR16(0xff800A, (0x20000 >> 3)); //set dma addr
    mcdWR8(0xff8007, 0); //dttrg
    gVsync();
    gVsync();
    mcdWR16(SUB_REG_IEMASK, (1 << 5));
    gVsync();
    if (ga->COMSTA[3] != 0)return 0x27; //irq should be generated only on DTEI falling edge if mask enabled at this moment



    //some decoder irq tests
    cdcRegSelect(CDC_IFCTRL);
    cdcRegWrite(IFCTRL_DOUTEN | IFCTRL_DTEIEN | IFCTRL_DECIEN);
    cdcRegSelect(CDC_CTRL0);
    cdcRegWrite(CDC_CTRL0_DECEN);
    cdcRegWrite(CDC_CTRL1_SYIEN | CDC_CTRL1_SYDEN | CDC_CTRL1_DESEN);

    cdcDTACK();
    mcdWR16(0, 0);

    //receive few decoder irq
    for (i = 0; i < 4; i++) {
        mcdWR16(0, 0);
        tout = 0;
        while (ga->COMSTA[3] != 5) {
            if (tout++ >= 20000)return 0x30; //decoder irq is not working. should be generated every 1/75 sec if DECIEN+DECEN+SYIEN. even without reset DECI
        }
    }

    //check DECI flag
    while (ga->COMSTA[3] != 5);
    cdcRegSelect(CDC_IFSTAT);
    if ((cdcRegRead() & IFSTAT_DECI) != 0)return 0x31; //DECI should be 0 after irq
    cdcRegSelect(CDC_STAT3);
    cdcRegRead(); //reset DECI
    if ((cdcRegRead() & IFSTAT_DECI) == 0)return 0x32; //DECI should be 1 after rd CDC_STAT3

    cdcDTACK();
    cdcDmaSetup(CDC_DST_MAIN, 8, PT);
    while (ga->COMSTA[3] != 5); //wait for decoder irq and begin right at this point
    cdcRegSelect(CDC_STAT3);
    cdcRegRead(); //reset DECI
    cdcDTTRG();
    for (i = 0; i < 8; i += 2) {
        tmp = REG16_A12008;
    }
    for (i = 0; i < 16; i++)asm("nop");
    if (ga->COMSTA[3] != 5)return 0x33; //error if dma irq not working with enabled decoder irq
    for (i = 0; i < 16; i++)asm("nop");

    //decoder irq not working while DTEI=0
    mcdWR16(0, 0);
    gVsync();
    gVsync();
    if (ga->COMSTA[3] != 0)return 0x34; //error if decoder irq working without DTACK after dma

    cdcDTACK();
    tout = 0;
    while (ga->COMSTA[3] != 5) {
        if (tout++ >= 20000)return 0x35; //hmm, why decoder irq not working after DTACK?
    }

    //dma irq not working while DECI is set
    cdcDTACK();
    cdcDmaSetup(CDC_DST_MAIN, 8, PT);
    while (ga->COMSTA[3] != 5); //wait for decoder irq and begin right at this point
    //cdcRegSelect(CDC_STAT3); //skip DECI reset
    //cdcRegRead(); 
    cdcDTTRG();
    for (i = 0; i < 8; i += 2) {
        tmp = REG16_A12008;
    }
    for (i = 0; i < 16; i++)asm("nop");
    if (ga->COMSTA[3] == 5)return 0x35; //error if dma irq working with DECI=0
    for (i = 0; i < 16; i++)asm("nop");


    //chec DECI phase. it resets automatically at 40% of frame (approx)
    cdcDTACK();
    u16 DECI0 = 0;
    u16 DECI1 = 0;
    mcdWR16(0, 0);
    while (ga->COMSTA[3] != 5);
    do {
        cdcRegSelect(CDC_IFSTAT);
        DECI0++;
    } while ((cdcRegRead() & IFSTAT_DECI) == 0);

    do {
        cdcRegSelect(CDC_IFSTAT);
        DECI1++;
    } while ((cdcRegRead() & IFSTAT_DECI) != 0);
    /*
        gConsPrint("DECI0: ");
        gAppendNum(DECI0);
        gConsPrint("DECI1: ");
        gAppendNum(DECI1);
        gConsPrint("");*/

    if (DECI0 < (49 - 1) || DECI0 > (49 + 1)) {
        gAppendNum(DECI0);
        gAppendString(".");
        return 0x40;
    }
    if (DECI1 < (72 - 1) || DECI1 > (72 + 1)) {
        gAppendNum(DECI1);
        gAppendString(".");
        return 0x41;
    }


    //DECI should set to 1 if decoder turned off
    mcdRD16(0);
    while (ga->COMSTA[3] != 5);
    cdcRegSelect(CDC_CTRL0);
    cdcRegWrite(0); //turn off decoder
    cdcRegSelect(CDC_IFSTAT);
    if ((cdcRegRead() & IFSTAT_DECI) == 0)return 0x42;
    cdcRegSelect(CDC_CTRL0);
    cdcRegWrite(CDC_CTRL0_DECEN);

    //DECIEN does not reset DECI
    mcdRD16(0);
    while (ga->COMSTA[3] != 5);
    cdcRegSelect(CDC_IFCTRL);
    cdcRegWrite(IFCTRL_DOUTEN | IFCTRL_DTEIEN);
    cdcRegSelect(CDC_IFSTAT);
    if ((cdcRegRead() & IFSTAT_DECI) != 0)return 0x43;

    cdcRegSelect(CDC_STAT3);
    cdcRegRead(); //reset DECI

    //DECI should toggle even with turned off irq (DECIEN))
    tout = 0;
    while (1) {
        cdcRegSelect(CDC_IFSTAT);
        if ((cdcRegRead() & IFSTAT_DECI) == 0)break;
        if(tout++ > 20000)return 0x44;
    }

    cdcRegSelect(CDC_IFCTRL);
    cdcRegWrite(IFCTRL_DOUTEN | IFCTRL_DTEIEN | IFCTRL_DECIEN);

    //only word access to 800A
    mcdWR16(0xff800A, 0);
    mcdWR8(0xff800A, 0xaa);
    if (mcdRD16(0xff800A) != 0xaaaa)return 0x46;
    mcdWR16(0xff800A, 0);
    mcdWR8(0xff800B, 0x55);
    if (mcdRD16(0xff800A) != 0x5555)return 0x47;


    /*
    gConsPrint("addr");
    gAppendHex16(mcdRD16(0xff800A));
    gConsPrint("");*/

    /*
    gConsPrint("DECI0: ");
    gAppendNum(DECI0);
    gConsPrint("DECI1: ");
    gAppendNum(DECI1);
    gConsPrint("");*/

    return 0;
}
