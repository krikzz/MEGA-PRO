/*
 * main_32colors_ver1.c
 *
 *  Created on: 2015/11/29
 *  Continued on: 2020/07/14
 *      Author: ivan
 */

#include "sys.h"
#include "bios.h"
#include "player.h"

void printError(u8 err);
void initGfx();
u8 play();

int main() {

    u8 resp;

    initGfx();

    resp = play();
    if (resp) {
        printError(resp);
    }

    initGfx();
    bi_exit_game();

    return 0;
}

u8 play() {

    u8 resp;

    resp = bi_init();
    if (resp)return resp;

    resp = playerPlay((u8 *) 0x20000);
    if (resp)return resp;

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

    //vdpVramWriteDMA(bg_rgb, 8192, sizeof (bg_rgb));
    //gSetBitMap(BPLAN, 256, 40, 28);

    gSetColor(0x00, 0x000);
    gSetColor(0x0f, 0x0c2); //file font color

    gSetColor(0x10, 0x000);
    gSetColor(0x1f, 0x0cc); //dirs font color

    gSetColor(0x20, 0x000);
    gSetColor(0x2f, 0xfff); //sel font color
}


