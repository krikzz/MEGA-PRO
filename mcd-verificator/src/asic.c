
#include "main.h"


extern u16 font_base[];
extern u16 pal[];
extern u16 img[];

#define ASIC_STAMP_SIZE 0xFF8058 //tilemap size
#define ASIC_STAMP_ADDR 0xFF805A //tilemap addr. word access
#define ASIC_BUFF_H     0xFF805C
#define ASIC_BUFF_ADDR  0xFF805E
#define ASIC_BUFF_OFFS  0xFF8060
#define ASIC_BUFF_PW    0xFF8062
#define ASIC_BUFF_PH    0xFF8064 //direct counter. 0 when finished
#define ASIC_VBASE      0xFF8066 //direct counter. (vbase + ASIC_BUFF_PH)/4 in the end

#define STABP_BITMAP            512
#define RENDER_BUFF             0x30000     
#define STAMP_TILEMAP           0x20000
#define VECTOR_ADDR             0x18000

void asicSetupImage(u16 w, u16 h, u16 vector_speed) {

    u16 *ptr;
    u16 i;

    mcdWR16(ASIC_BUFF_H, (h - 1));
    mcdWR16(ASIC_BUFF_PW, w * 8); //0 = 0
    mcdWR16(ASIC_BUFF_PH, h * 8); //0 = 512 or 256?

    ptr = (u16 *) & mcd->word_ram[VECTOR_ADDR];
    for (i = 0; i < h * 8; i++) {
        *ptr++ = (256 << 3); //stamp x;
        *ptr++ = (i << 3); //stamp y
        *ptr++ = 0xF800;//vector_speed; //delta x
        *ptr++ = 0; //delta y
    }
}

void asicRepaint(u16 w, u16 h) {

    u16 idx = 0;
    u16 i, x, y;
    u16 buff[G_PLAN_W * 64];
    u16 *ptr;

    for (i = 0; i < sizeof (buff) / 2; i++)buff[i] = 0;



    for (x = 0; x < w; x++) {
        for (y = 0; y < h; y++) {

            buff[y * G_PLAN_W + x] = 256 + idx++;
        }
    }

    vdpVramWrite(buff, APLAN, sizeof (buff));


    ptr = (u16 *) & mcd->word_ram[RENDER_BUFF];
    //vdpVramWrite(ptr, 8192, w * h * 32);

    gVsync();
    vdpVramWriteDma(ptr + 1, 8192, w * h * 32);
}

void testAsic() {

    u32 ctr = 0;
    u16 joy = 0;
    u16 i;
    u16 *ptr;
    u16 w = 32;
    u16 h = 16;
    u16 vs = (1 << 11); //1.0


    mcdWramSetMode(WRAM_MODE_2M);
    mcdWramToMain();
    mcdWramPriorMode(WRAM_PM_OFF);

    for (i = 0; i < 15; i++) {
        gSetColor(i, pal[i]);
    }
    ptr = (u16 *) & mcd->word_ram[STABP_BITMAP];
    for (i = 0; i < 2048; i++)*ptr++ = img[i];


    ptr = (u16 *) & mcd->word_ram[STAMP_TILEMAP];
    for (i = 0; i < 64 * 32; i++) {
        ptr[i] = 4; //1 + (i & 1);
    }

    for (i = 0; i < 8; i++) {
        ptr[i] = 8 | (i << 13);
    }
    /*
    ptr[2] = (4 + 2);
    ptr[4] = (4 + 4) | (1 << 15) | (2 << 13);
    ptr[16 * 7] = 4 + 2;

    ptr[5] = (4) | (1 << 15) | (2 << 13);
    ptr[6] = 0;*/

    //mcdWR16(ASIC_BUFF_PH, h * 8); //0 = 512 or 256?
    mcdWR16(ASIC_STAMP_SIZE, 0); //16x16 macrotile, screen 256x256 (16x16 macro tiles)
    mcdWR16(ASIC_STAMP_ADDR, (STAMP_TILEMAP >> 2)); //tilemap
    mcdWR16(ASIC_BUFF_ADDR, (RENDER_BUFF >> 2)); //render buffer
    mcdWR16(ASIC_BUFF_OFFS, 0 | (0 << 3));

    while (1) {

        ptr = (u16 *) & mcd->word_ram[RENDER_BUFF];
        for (i = 0; i < 32768; i++)*ptr++ = 0xffff;

        asicSetupImage(w, h, vs);

        mcdWramToSub();
        if (joy == JOY_A || joy == JOY_STA) {
            gCleanPlan();
            gConsPrint("pres key to start rendering");
            sysJoyWait();
        }



        if (joy == JOY_STA) {
            mcdRenderAndRead(0xA0000, VECTOR_ADDR >> 2);
        } else {

            mcdWR16(ASIC_VBASE, (VECTOR_ADDR >> 2)); //direct pointer. can be readed back relatime
        }



        //mcdWramToMain();
        //mcdWramToMain();
        //mcdWramToSub();

        ctr = 0;
        while ((mcdRD16(ASIC_STAMP_SIZE) & 0x8000) != 0) {
            ctr++;
        }



        mcdWramToMain();
        asicRepaint(w, h);

        gSetXY(0, 20);
        gConsPrint("screen size:  ");
        gAppendNum(w);
        gAppendString("x");
        gAppendNum(h);
        gConsPrint("vector speed: ");
        gAppendNum(vs >> 11);
        gAppendString(".");
        gAppendNum(vs & 2047);
        gConsPrint("ctr: ");
        gAppendNum(ctr);
        gConsPrint("********************************++++++++");



        joy = sysJoyWait();
        if (joy == JOY_L)w--;
        if (joy == JOY_R)w++;
        if (joy == JOY_U)h--;
        if (joy == JOY_D)h++;

        if (joy == JOY_B)vs += 256;
        if (joy == JOY_C)vs -= 256;

    }

}
