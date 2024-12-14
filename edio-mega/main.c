

#include "sys.h"
#include "everdrive.h"
#include "str.h"

u8 megaio();
u8 dirLoad();
u8 fileReadToRam();
u8 fileReadToRom();
u8 fileInfo();
void rtcPrint();
void usbRead();
void usbWrite();
u8 romPath();
void deviceID();

int main() {

    u8 resp;

    sysInit();
    gSetColor(0x00, 0x000);
    gSetColor(0x0f, 0xfff);

    resp = ed_init();

    if (resp) {
        gConsPrint("init error: ");
        gAppendHex8(resp);
    }


    while (1) {

        resp = megaio();
        if (resp) {
            gConsPrint("error: ");
            gAppendHex8(resp);
            sysJoyWait();
        }
    }

    return 0;
}

//******************************************************************************

u8 megaio() {

    typedef enum {
        MENU_LD_DIR = 0,
        MENU_RD_TO_RAM,
        MENU_RD_TO_ROM,
        MENU_FILE_INFO,
        MENU_USB_RD,
        MENU_USB_WR,
        MENU_RTC,
        MENU_ROM_PATH,
        MENU_DEVID,
        MENU_EXIT,
        MENU_SIZE
    } MENU;

    u8 * menu[MENU_SIZE + 1];
    u8 selector = 0;
    u8 resp;
    u16 i, joy;

    menu[MENU_LD_DIR] = "load dir";
    menu[MENU_RD_TO_RAM] = "read file to ram";
    menu[MENU_RD_TO_ROM] = "read file to rom";
    menu[MENU_FILE_INFO] = "file info";
    menu[MENU_USB_RD] = "usb read";
    menu[MENU_USB_WR] = "usb write";
    menu[MENU_RTC] = "rtc";
    menu[MENU_ROM_PATH] = "rom path";
    menu[MENU_DEVID] = "device id";
    menu[MENU_EXIT] = "back to menu";
    menu[MENU_SIZE] = 0;

    while (1) {
        gSetXY(12, 8);

        for (i = 0; menu[i] != 0; i++) {
            gConsPrint(selector == i ? ">" : " ");
            gAppendString(menu[i]);
        }

        joy = sysJoyWait();

        if (joy == JOY_U) {
            if (selector > 0)selector--;
        }

        if (joy == JOY_D) {
            if (menu[selector + 1] != 0)selector++;
        }

        if (joy != JOY_A)continue;

        resp = 0;

        switch (selector) {

            case MENU_LD_DIR:
                resp = dirLoad();
                break;

            case MENU_EXIT:
                gCleanPlan();
                ed_cmd_reboot();
                break;

            case MENU_RD_TO_RAM:
                fileReadToRam();
                break;

            case MENU_RD_TO_ROM:
                fileReadToRam();
                break;

            case MENU_FILE_INFO:
                fileInfo();
                break;

            case MENU_USB_RD:
                usbRead();
                break;

            case MENU_USB_WR:
                usbWrite();
                break;

            case MENU_RTC:
                rtcPrint();
                break;

            case MENU_ROM_PATH:
                resp = romPath();
                break;

            case MENU_DEVID:
                deviceID();
                break;

        }

        if (resp)return resp;
        gCleanPlan();
    }


    return 0;
}
//****************************************************************************** files and directories

u8 dirLoad() {

    u8 name_buff[G_SCREEN_W + 1];
    u8 resp;
    u16 i, dir_size;
    FileInfo inf = {0};
    inf.file_name = name_buff;

    gCleanPlan();

    resp = ed_cmd_dir_load("/MEGA", DIR_OPT_SORTED); //load system dir
    if (resp)return resp;

    ed_cmd_dir_get_size(&dir_size); //load dir

    if (dir_size > G_SCREEN_H)dir_size = G_SCREEN_H;

    ed_cmd_dir_get_recs(0, dir_size, G_SCREEN_W); //request dir reccords


    for (i = 0; i < dir_size; i++) {

        resp = ed_rx_next_rec(&inf); //read dir reccord
        if (resp)return resp;
        gConsPrint(inf.file_name);
    }

    sysJoyWait();

    return 0;
}

u8 fileReadToRam() {//read readme.txt to ram and print to the screen

    u8 *path = "MEGA/bios/readme.txt";
    u8 buff[G_SCREEN_W + 1];
    u8 resp;

    gCleanPlan();

    resp = ed_cmd_file_open(path, FA_READ);
    if (resp)return resp;

    resp = ed_cmd_file_read(buff, G_SCREEN_W);
    if (resp)return resp;

    resp = ed_cmd_file_close();
    if (resp)return resp;

    buff[G_SCREEN_W] = 0; //end of string
    gConsPrint(buff);

    sysJoyWait();

    return 0;
}

u8 fileReadToRom() {//read readme.txt to rom memory and print to the screen. m68k have no acces to rom memory during io DMA

    u8 *path = "MEGA/bios/readme.txt";
    u8 resp;
    u32 rom_dst = ADDR_ROM + 0x10000;

    gCleanPlan();


    resp = ed_cmd_file_open(path, FA_READ);
    if (resp)return resp;

    resp = ed_cmd_file_read_mem(rom_dst, G_SCREEN_W);
    if (resp)return resp;

    resp = ed_cmd_file_close();
    if (resp)return resp;

    ed_cmd_mem_set(0, rom_dst + G_SCREEN_W, 1); //end of string
    gConsPrint((u8 *) 0x10000);

    sysJoyWait();

    return 0;
}

u8 fileInfo() {

    u8 buff[32];
    u8 resp;
    u8 *path = "MEGA/megaos.dat";
    FileInfo inf = {0}; //file_name pointer should be set to 0 if not points to string buffer

    gCleanPlan();

    resp = ed_cmd_file_info(path, &inf);
    if (resp)return resp;

    gConsPrint("path: ");
    gAppendString(path);

    gConsPrint("size: ");
    gAppendNum(inf.size);

    buff[0] = 0;
    str_append_date(buff, inf.date);
    gConsPrint("date: ");
    gAppendString(buff);

    buff[0] = 0;
    str_append_time(buff, inf.time);
    gConsPrint("time: ");
    gAppendString(buff);


    sysJoyWait();

    return 0;
}
//****************************************************************************** rtc

void rtcPrint() {

    RtcTime rtc;


    gCleanPlan();
    while (sysJoyRead() != 0)gVsync();


    while (1) {

        ed_cmd_rtc_get(&rtc);
        gSetXY(0, 0);

        gConsPrint("date: ");
        gAppendHex8(rtc.dom);
        gAppendString(".");
        gAppendHex8(rtc.mon);
        gAppendString(".");
        gAppendHex8(rtc.yar);

        gConsPrint("time: ");
        gAppendHex8(rtc.hur);
        gAppendString(":");
        gAppendHex8(rtc.min);
        gAppendString(":");
        gAppendHex8(rtc.sec);

        gVsync();
        if (sysJoyRead())return;
    }

}
//****************************************************************************** usb io

void usbRead() {//receive strings from virtual-com and print to the screen. use string-read.bat for string sending

    u8 buff[2];

    gCleanPlan();
    while (sysJoyRead() != 0)gVsync();


    buff[1] = 0; //end of string

    gConsPrint("waiting for input string...");
    gConsPrint("");

    while (1) {

        while (ed_fifo_busy()) {
            gVsync();
            if (sysJoyRead())return;
        }

        //single byte communication is very slow. 
        //use larger blocks for real applications but not more than SIZE_FIFO
        ed_fifo_rd(buff, 1);

        if (buff[0] == '\n') {
            gConsPrint("");
            continue;
        }

        gAppendString(buff);
    }


}

void usbWrite() {//send strings to the virtual com-port. Use any serial terminal app to receive strings.

    u32 timer = 0;
    gCleanPlan();
    while (sysJoyRead() != 0)gVsync();

    gConsPrint("sending test string every second...");

    while (1) {

        if (timer++ % 60 == 0) {
            ed_cmd_usb_wr("test string\n", 12);
        }

        gSetXY(0, 2);
        gConsPrint("ctr: ");
        gAppendNum(timer / 60);

        gVsync();
        if (sysJoyRead())return;
    }

}

u8 romPath() {//read path to current rom file from system config

    u8 resp;
    u8 rom_path[512 + 1];

    gCleanPlan();

    //buffer size should be not less than 512B
    //CMD_ROM_PATH require firmware v24.xxxx or newer
    resp = ed_cmd_rom_path(rom_path, 0);
    if (resp)return resp;

    rom_path[28] = 0; //cut string len
    gConsPrint("rom path: ");
    gAppendString(rom_path);

    sysJoyWait();

    return 0;
}

void deviceID() {

    u8 resp[4];

    gCleanPlan();

    //0: STATUS_KEY
    //1: PROTOCOL_ID
    //2: DEVID
    //3: EDIO_STATUS

    //CMD_STATUS2 require firmware v24.xxxx or newer
    ed_cmd_status2(resp);


    gConsPrint("dev ID   : ");
    gAppendHex8(resp[2]);
    gConsPrint("dev name : ");

    switch (resp[2]) {
        case DEVID_MEGAPRO:
            gAppendString("Mega EverDrive PRO");
            break;
        case DEVID_MEGACORE:
            gAppendString("Mega EverDrive CORE");
            break;
        default:
            gAppendString("Unknown");
            break;
    }

    sysJoyWait();
}
