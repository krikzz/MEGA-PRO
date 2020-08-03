
#include "sys.h"
#include "bios.h"
#include "fmanager.h"
#include "player.h"

#define BORDER_Y        5
#define BORDER_X        1
#define MAX_ROWS        21
#define MAX_STR_LEN     38

#define JOY_DELAY1      20
#define JOY_DELAY2      3

typedef struct {
    u16 dir_size;
    u16 selector;
    u16 base_idx;
    u16 sel_stack[256];
    u8 sel_stack_idx;
    u8 path[1024 + 1];
} Fmanager;


void initGfx();
u8 getHomePath();
u8 dirOpen();
u8 dirDraw();
u8 openItem();
u8 dirExit();

Fmanager fm;

u8 selectFile() {

    u8 resp;
    u16 joy, joy_old, joy_ctr;

    fm.sel_stack_idx = 0;

    resp = getHomePath();
    if (resp)return resp;

    resp = dirOpen();
    if (resp)return resp;

    joy = joy_old = 0;
    joy_ctr = JOY_DELAY1;

    while (1) {

        resp = dirDraw();
        if (resp)return resp;


        while (joy == joy_old) {
            gVsync();
            joy = sysJoyRead();
            if ((joy & (JOY_U | JOY_D)))joy_ctr--;
            if (joy_ctr == 0) {
                joy_ctr = JOY_DELAY2;
                break;
            }
        }

        if (joy != joy_old) {
            joy_ctr = JOY_DELAY1;
        }
        joy_old = joy;


        if (joy == JOY_U) {
            if (fm.selector != 0)fm.selector--;
            if (fm.selector < fm.base_idx)fm.base_idx = fm.selector;
        }

        if (joy == JOY_D) {
            if (fm.selector + 1 < fm.dir_size)fm.selector++;
            if (fm.selector >= fm.base_idx + MAX_ROWS - 1)fm.base_idx = fm.selector - (MAX_ROWS - 1);
        }

        if (joy == JOY_A) {//open folder of file
            resp = openItem();
            if (resp)return resp;
            gCleanPlan();
        }

        if (joy == JOY_B && fm.sel_stack_idx != 0) {//exit folder
            resp = dirExit();
            if (resp)return resp;
            fm.selector = fm.sel_stack[--fm.sel_stack_idx];
            gCleanPlan();
        }
    }

    return 0;
}

u8 openItem() {

    u16 i;
    u8 resp;
    FileInfo inf = {0};

    for (i = 0; fm.path[i] != 0; i++);

    fm.path[i++] = '/';
    fm.path[i] = 0;

    inf.file_name = &fm.path[i]; //selected item name will be appended here

    bi_cmd_dir_get_recs(fm.selector, 1, sizeof (fm.path) - 1 - i);

    resp = bi_rx_next_rec(&inf);
    if (resp)return resp;


    if (inf.is_dir) {

        fm.sel_stack[fm.sel_stack_idx++] = fm.selector;
        resp = dirOpen();
        if (resp)return resp;
        return 0;

    } else {

        resp = playerPlay(fm.path);
        if (resp)return resp;

        u16 end = 0;
        for (i = 0; fm.path[i] != 0; i++) {
            if (fm.path[i] == '/')end = i;
        }
        fm.path[end] = 0;

        initGfx();
    }


    return 0;
}

u8 getHomePath() {

    u8 resp;
    u16 i;

    resp = bi_cmd_file_open("mega/registery.dat", FA_READ); //get last launched rom patch from os settings file
    if (resp)return resp;

    resp = bi_cmd_file_read(fm.path, sizeof (fm.path));
    if (resp)return resp;

    resp = bi_cmd_file_close();
    if (resp)return resp;

    //remove rom name from path string
    u8 *end = fm.path;
    for (i = 0; fm.path[i] != 0 && i < sizeof (fm.path); i++) {
        if (fm.path[i] == '/')end = &fm.path[i];
    }
    *end = 0;

    return 0;
}

u8 dirExit() {

    u16 i;
    u16 end = 0;

    for (i = 0; fm.path[i] != 0; i++) {
        if (fm.path[i] == '/')end = i;
    }

    fm.path[end] = 0;

    return dirOpen();
}

u8 dirOpen() {

    u8 resp;
    fm.selector = 0;
    fm.base_idx = 0;

    resp = bi_cmd_dir_load(fm.path, DIR_OPT_SORTED);
    if (resp)return resp;

    bi_cmd_dir_get_size(&fm.dir_size);

    return 0;
}

u8 dirDraw() {

    u16 i;
    u8 resp;
    FileInfo inf;
    u8 str_buff[MAX_STR_LEN + 1];
    u16 item_num = min(MAX_ROWS, fm.dir_size - fm.base_idx);

    inf.file_name = str_buff;

    //gCleanPlan();
    gSetXY(BORDER_X, BORDER_Y - 1);

    bi_cmd_dir_get_recs(fm.base_idx, item_num, MAX_STR_LEN); //request for catalog items

    for (i = 0; i < item_num; i++) {

        resp = bi_rx_next_rec(&inf);
        if (resp)return resp;

        if (fm.selector - fm.base_idx == i) {
            gSetPal(PAL_2);
        } else if (inf.is_dir) {
            gSetPal(PAL_1);
        } else {
            gSetPal(PAL_0);
        }

        gConsPrint(inf.file_name);
        gAppendString("                                    "); //cleaner
    }

    gSetPal(0);

    return 0;
}
