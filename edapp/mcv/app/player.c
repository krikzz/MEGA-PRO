
#include "sys.h"
#include "everdrive.h"

#define PLAYER_MODE     *((vu16 *)0x300000)
#define MODE_PAL        1
#define MODE_NTSC       0

#define VIEW_W 36
#define VIEW_H 24

#define ADDR_FMV_PIBUS  0x1F80000       //buffer address for internal perephirial bus
#define ADDR_FMV_M68K   0x0200000       //buffer address in motorola address space

#define FRAME_SIZE      46328           //frame size bitmap+pal+pcm

u8 playerOpen(u8 *path);
void playerInit();
void megacolor_play();

extern u16 tile_map_0_36x24[VIEW_W * VIEW_H];
extern u16 tile_map_1_36x24[VIEW_W * VIEW_H];

u64 vdata_size; //file size
vu32 pb_size; //playback counter (frame number / 2)
vu8 pb_joy; //joy val
vu8 pb_pause; //pause flag

u8 playerPlay(u8 *path) {

    u8 resp;

    //12800 pal
    //27648 bitbap
    //5880  audio

    resp = playerOpen(path);
    if (resp)return resp;

    while (1) {

        ed_cmd_file_set_ptr(0);

        playerInit();
        gVsync();
        megacolor_play();

        if (pb_size != 0)break; //exit request
    }

    resp = ed_cmd_file_close();
    if (resp)return resp;



    return 0;
}

u8 playerOpen(u8 *path) {

    u8 resp;

    resp = ed_cmd_file_open(path, FA_READ);
    if (resp)return resp;

    vdata_size = ed_cmd_file_available();

    return 0;
}

void playerInit() {

    u16 i;

    VDP_CTRL16 = 0x8004;
    VDP_CTRL16 = 0x8200; // Plan A in 0x0000
    VDP_CTRL16 = 0x8300; // Window out 0x000
    VDP_CTRL16 = 0x8400; // Plan B in 0x0000
    VDP_CTRL16 = 0x8500; // sprite table begins at 0x0000= 0 * 0x200
    VDP_CTRL16 = 0x8c81; // no shadow
    VDP_CTRL16 = 0x8d00; // hscroll table out
    VDP_CTRL16 = 0x9001; // plan size 64 x 32
    VDP_CTRL16 = 0x9100; // reg 17 - window hpos
    VDP_CTRL16 = 0x9200; // reg 18 - window vpos

    JOY_CTRL_1 = 0x40;
    JOY_DATA_1 = 0x40;

    pb_pause = 0;
    pb_joy = JOY_DATA_1;
    pb_size = vdata_size / FRAME_SIZE / 2;
    //pb_size = 80;

    VDP_CTRL32 = VDP_VRAM_WR(0);
    for (i = 0; i < 4096; i++) {
        VDP_DATA32 = 0;
        VDP_DATA32 = 0;
        VDP_DATA32 = 0;
        VDP_DATA32 = 0;
    }

    for (i = 0; i < VIEW_H; i++) {
        vdpVramWrite(&tile_map_0_36x24[i * VIEW_W], (2 + (2 + i) * 64) * 2 + 0x0000, VIEW_W * 2);
        vdpVramWrite(&tile_map_1_36x24[i * VIEW_W], (2 + (2 + i) * 64) * 2 + 0x8000, VIEW_W * 2);
    }


    gVsync();
    u16 time = ed_get_ticks();
    gVsync();
    time = ed_get_ticks() - time;
    if (time > 17) {
        PLAYER_MODE = MODE_PAL;
    } else {
        PLAYER_MODE = MODE_NTSC;
    }
}


