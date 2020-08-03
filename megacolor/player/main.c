/*
 * main_32colors_ver1.c
 *
 *  Created on: 2015/11/29
 *  Continued on: 2020/07/14
 *      Author: ivan
 */

#include "sys.h"
#include "bios.h"
#include "fmanager.h"

void printError(u8 err);
void initGfx();

extern u16 bg_rgb[17920];
extern u16 bg_pal[16];

int main() {

    u8 resp;


    initGfx();

    while (1) {

        resp = bi_init();
        if (resp) {
            printError(resp);
            continue;
        }

        resp = selectFile();
        if (resp) {
            printError(resp);
        }
    }

    return 0;
}

void printError(u8 err) {

    initGfx();

    gSetXY(G_SCREEN_W / 2 - 5, G_SCREEN_H / 2 - 2);
    gConsPrint("ERROR: ");
    gAppendHex8(err);
    sysJoyWait();
}

void initGfx() {

    sysInit(G_MODE_320x224, 64, 64);

    u16 i;
    for (i = 0; i < 16; i++) {
        gSetColor(i, bg_pal[i]);
    }

    vdpVramWriteDMA(bg_rgb, 8192, sizeof (bg_rgb));
    gSetBitMap(BPLAN, 256, 40, 28);

    gSetColor(0x00, 0x000);
    gSetColor(0x0f, 0x0c2); //file font color

    gSetColor(0x10, 0x000);
    gSetColor(0x1f, 0x0cc); //dirs font color

    gSetColor(0x20, 0x000);
    gSetColor(0x2f, 0xfff); //sel font color
}


