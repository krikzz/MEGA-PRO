
#include "everdrive.h"

#define CMD_STATUS      0x10
#define CMD_GET_MODE    0x11
#define CMD_IO_RST      0x12
#define CMD_GET_VDC     0x13
#define CMD_RTC_GET     0x14
#define CMD_RTC_SET     0x15
#define CMD_FLA_RD      0x16
#define CMD_FLA_WR      0x17
#define CMD_FLA_WR_SDC  0x18
#define CMD_MEM_RD      0x19
#define CMD_MEM_WR      0x1A
#define CMD_MEM_SET     0x1B
#define CMD_MEM_TST     0x1C
#define CMD_MEM_CRC     0x1D
#define CMD_FPG_USB     0x1E
#define CMD_FPG_SDC     0x1F
#define CMD_FPG_FLA     0x20
#define CMD_SET_DISK    0x21
#define CMD_USB_WR      0x22
#define CMD_FIFO_WR     0x23
#define CMD_UART_WR     0x24
#define CMD_REINIT      0x25
#define CMD_SYS_INF     0x26
#define CMD_GAME_CTR    0x27
#define CMD_UPD_EXEC    0x28
#define CMD_HOST_RST    0x29


#define CMD_DISK_INIT   0xC0
#define CMD_DISK_RD     0xC1
#define CMD_DISK_WR     0xC2
#define CMD_F_DIR_OPN   0xC3
#define CMD_F_DIR_RD    0xC4
#define CMD_F_DIR_LD    0xC5
#define CMD_F_DIR_SIZE  0xC6
#define CMD_F_DIR_PATH  0xC7
#define CMD_F_DIR_GET   0xC8
#define CMD_F_FOPN      0xC9
#define CMD_F_FRD       0xCA
#define CMD_F_FRD_MEM   0xCB
#define CMD_F_FWR       0xCC
#define CMD_F_FWR_MEM   0xCD
#define CMD_F_FCLOSE    0xCE
#define CMD_F_FPTR      0xCF
#define CMD_F_FINFO     0xD0
#define CMD_F_FCRC      0xD1
#define CMD_F_DIR_MK    0xD2
#define CMD_F_DEL       0xD3
#define CMD_F_SEEK_IDX  0xD4
#define CMD_F_AVB       0xD5

#define CMD_GET_SIGNA   0xF3

#define ACK_BLOCK_SIZE  1024

u8 ed_init_rapp();
void ed_reboot(u8 status);
void ed_halt(u8 status);
void ed_cmd_tx(u8 cmd);
void ed_fifo_flush();
void ed_run_dma();
void(*halt_app_ptr)(u8 status);
void ed_halt_app(u8 status);
void ed_halt_app_end();

u8 halt_app_ram[512];

void ed_init() {

    ed_init_rapp();
    ed_fifo_flush();
}

u8 ed_init_rapp() {

    u32 app_len = (u32) ed_halt_app_end - (u32) ed_halt_app;

    if (app_len > sizeof (halt_app_ram)) {
        return 1; //ERR_OUT_OF_MEMORY;
    }
    mem_copy(ed_halt_app, halt_app_ram, app_len);
    halt_app_ptr = (void*) halt_app_ram;

    return 0;
}
//****************************************************************************** edio commands

void ed_cmd_tx(u8 cmd) {

    u8 buff[4];

    buff[0] = '+';
    buff[1] = '+' ^ 0xff;
    buff[2] = cmd;
    buff[3] = cmd ^ 0xff;

    ed_fifo_wr(buff, sizeof (buff));
}

void ed_cmd_status(u16 *status) {

    ed_cmd_tx(CMD_STATUS);
    ed_fifo_rd(status, 2);
}

u8 ed_cmd_file_open(u8 *path, u8 mode) {

    if (*path == 0)return ERR_NULL_PATH;
    ed_cmd_tx(CMD_F_FOPN);
    ed_fifo_wr(&mode, 1);
    ed_tx_string(path);
    return ed_check_status();
}

u8 ed_cmd_file_close() {

    ed_cmd_tx(CMD_F_FCLOSE);
    return ed_check_status();
}

u8 ed_cmd_file_read_mem(u32 addr, u32 len) {

    if (len == 0)return 0;
    ed_cmd_tx(CMD_F_FRD_MEM);
    ed_fifo_wr(&addr, 4);
    ed_fifo_wr(&len, 4);

    ed_run_dma();

    return ed_check_status();
}

void ed_cmd_file_read_nb(u32 addr, u32 len) {

    ed_cmd_tx(CMD_F_FRD_MEM);
    ed_fifo_wr(&addr, 4);
    ed_fifo_wr(&len, 4);
    REG_FIFO_DATA = 0;
    REG_SYS_STAT = STATUS_CMD_OK;
}

u8 ed_cmd_file_set_ptr(u32 addr) {

    ed_cmd_tx(CMD_F_FPTR);
    ed_fifo_wr(&addr, 4);
    return ed_check_status();
}

u64 ed_cmd_file_available() {

    u64 len;
    ed_cmd_tx(CMD_F_AVB);
    ed_fifo_rd(&len, 8);

    return len;
}
//****************************************************************************** 
//****************************************************************************** 
//****************************************************************************** 

void ed_fifo_flush() {

    vu8 tmp;
    REG_FIFO_DATA = 0;
    REG_FIFO_DATA = 0;
    while ((REG_FIFO_STAT & FIFO_RXF_MSK)) {
        tmp = REG_FIFO_DATA;
    }
}

void ed_fifo_wr(void *data, u16 len) {

    u8 *data8 = data;

    while (len--) {
        REG_FIFO_DATA = *data8++;
    }

}

void ed_fifo_rd(void *data, u16 len) {

    u8 *data8 = data;
    u16 block = 0;


    while (len) {

        block = REG_FIFO_STAT & FIFO_RXF_MSK;
        if (block > len)block = len;
        len -= block;

        while (block >= 4) {
            *data8++ = REG_FIFO_DATA;
            *data8++ = REG_FIFO_DATA;
            *data8++ = REG_FIFO_DATA;
            *data8++ = REG_FIFO_DATA;
            block -= 4;
        }

        while (block--) *data8++ = REG_FIFO_DATA;
    }

}

u8 ed_check_status() {

    u16 status;

    ed_cmd_status(&status);

    if ((status & 0xff00) != 0xA500) {
        return ERR_UNXP_STAT;
    }

    return status & 0xff;
}

void ed_tx_string(u8 *string) {

    u16 str_len = 0;
    u8 *ptr = string;

    while (*ptr++ != 0)str_len++;

    ed_fifo_wr(&str_len, 2);
    ed_fifo_wr(string, str_len);
}

void ed_run_dma() { //acknowledge mcu access to memory and wait until it ends in wram

    ed_halt(STATUS_CMD_OK);
}

u16 ed_get_ticks() {

    return REG_TIMER;
}

void ed_reboot(u8 status) {

    ed_halt(status | STATUS_REBOOT);
}

void ed_halt(u8 status) {
    halt_app_ptr(status);
}

void ed_halt_app(u8 stat_req) {//must be executed from ram area

    vu16 stat;

    REG_SYS_STAT = stat_req;
    REG_FIFO_DATA = 0; //exec

    while (1) {
        stat = REG_SYS_STAT;
        if ((stat & (0xFFF0 | STATUS_STROBE)) != (0x55A0 | STATUS_STROBE))continue;
        stat = REG_SYS_STAT;
        if ((stat & (0xFFF0 | STATUS_STROBE)) != 0x55A0)continue;
        if ((stat & stat_req) != 0)continue;
        break;
    }


    if ((stat_req & STATUS_REBOOT)) {
        __asm__("move.l 4, %a0");
        __asm__("jmp (%a0)");
    }
}

void ed_halt_app_end() {
}

void ed_exit_game() {

    u32 addr = ADDR_CFG;
    u32 len = sizeof (MapConfig);
    u8 val = 0;

    ed_cmd_tx(CMD_MEM_SET);
    ed_fifo_wr(&addr, 4);
    ed_fifo_wr(&len, 4);
    ed_fifo_wr(&val, 1);

    ed_reboot(STATUS_CMD_OK);
}
