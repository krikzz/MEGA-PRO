
#include "sys.h"
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

#define CMD_GET_SIGNA   0xF3

#define ACK_BLOCK_SIZE  1024

void ed_reboot(u8 status);
void ed_halt(u8 status);
void ed_cmd_tx(u8 cmd);
void ed_rx_file_info(FileInfo *inf);
u8 ed_fifo_rd_skip(u16 len);

void ed_fifo_flush();
void ed_run_dma();

void(*halt_app_ptr)(u8 status);
void ed_halt_app(u8 status);
void ed_halt_app_end();

u8 halt_app_ram[512];

u8 ed_init() {

    u8 resp;
    u32 app_len = (u32) ed_halt_app_end - (u32) ed_halt_app;

    mem_copy(ed_halt_app, halt_app_ram, app_len);
    halt_app_ptr = (void*) halt_app_ram;

    ed_fifo_flush();

    //check if disk initialized.
    resp = ed_cmd_dir_load("/", 0);
    if (resp) {
        resp = ed_cmd_disk_init();
        if (resp)return resp;
    }

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

u8 ed_cmd_disk_init() {

    ed_cmd_tx(CMD_DISK_INIT);
    return ed_check_status();
}

u8 ed_cmd_dir_load(u8 *path, u8 args) {

    ed_cmd_tx(CMD_F_DIR_LD);
    ed_fifo_wr(&args, 1);
    ed_tx_string(path);

    return ed_check_status();
}

void ed_cmd_dir_get_size(u16 *size) {

    ed_cmd_tx(CMD_F_DIR_SIZE);
    ed_fifo_rd(size, 2);
}

void ed_cmd_dir_seek_idx(u16 *idx) {

    ed_cmd_tx(CMD_F_SEEK_IDX);
    ed_fifo_rd(idx, 2);
}

void ed_cmd_dir_get_recs(u16 start_idx, u16 amount, u16 max_name_len) {

    ed_cmd_tx(CMD_F_DIR_GET);
    ed_fifo_wr(&start_idx, 2);
    ed_fifo_wr(&amount, 2);
    ed_fifo_wr(&max_name_len, 2);
}

void ed_cmd_uart_wr(void *data, u16 len) {

    ed_cmd_tx(CMD_UART_WR);
    ed_fifo_wr(&len, 2);
    ed_fifo_wr(data, len);
}

void ed_cmd_usb_wr(void *data, u16 len) {

    ed_cmd_tx(CMD_USB_WR);
    ed_fifo_wr(&len, 2);
    ed_fifo_wr(data, len);
}

void ed_cmd_fifo_wr(void *data, u16 len) {//write to own fifo buffer

    ed_cmd_tx(CMD_FIFO_WR);
    ed_fifo_wr(&len, 2);
    ed_fifo_wr(data, len);
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

    //ed_dma_exec();
    ed_run_dma();

    return ed_check_status();
}

u8 ed_cmd_file_read(void *dst, u32 len) {

    u8 resp;
    u32 block;
    u8 *dst8 = (u8 *) dst;

    while (len) {

        block = min(512, len);

        ed_cmd_tx(CMD_F_FRD); //we can read up to 4096 in single block. but reccomended not more than 512 to avoid fifo overload
        ed_fifo_wr(&block, 4);

        ed_fifo_rd(&resp, 1);
        if (resp)return resp;

        ed_fifo_rd(dst8, block);

        len -= block;
        dst8 += block;
    }

    return 0;
}

u8 ed_cmd_file_write(void *src, u32 len) {

    u8 resp;
    u32 block;
    u8 *src8 = (u8 *) src;

    ed_cmd_tx(CMD_F_FWR);
    ed_fifo_wr(&len, 4);

    while (len) {

        block = min(ACK_BLOCK_SIZE, len);

        ed_fifo_rd(&resp, 1);
        if (resp)return resp;

        ed_fifo_wr(src8, block);

        len -= block;
        src8 += block;
    }

    return ed_check_status();
}

u8 ed_cmd_file_write_mem(u32 addr, u32 len) {

    if (len == 0)return 0;
    ed_cmd_tx(CMD_F_FWR_MEM);
    ed_fifo_wr(&addr, 4);
    ed_fifo_wr(&len, 4);

    //ed_dma_exec();
    ed_run_dma();

    return ed_check_status();
}

u8 ed_cmd_file_set_ptr(u32 addr) {

    ed_cmd_tx(CMD_F_FPTR);
    ed_fifo_wr(&addr, 4);
    return ed_check_status();
}

u8 ed_cmd_file_info(u8 *path, FileInfo *inf) {

    u8 resp;

    ed_cmd_tx(CMD_F_FINFO);
    ed_tx_string(path);

    ed_fifo_rd(&resp, 1);
    if (resp)return resp;

    ed_rx_file_info(inf);

    return 0;
}

u8 ed_cmd_file_del(u8 *path) {

    ed_cmd_tx(CMD_F_DEL);
    ed_tx_string(path);
    return ed_check_status();
}

u8 ed_cmd_fpga_init(u8 *path) {

    u8 resp;
    u32 len;

    resp = ed_file_get_size(path, &len);
    if (resp)return resp;
    resp = ed_cmd_file_open(path, FA_READ);
    if (resp)return resp;

    ed_cmd_tx(CMD_FPG_SDC);
    ed_fifo_wr(&len, 4);
    ed_halt(STATUS_FPG_OK); //fpg ok flag will be reset only after fpga reconfig

    ed_fifo_flush();

    return ed_check_status();

}

u8 ed_cmd_file_crc(u32 len, u32 *crc_base) {

    u8 resp;
    ed_cmd_tx(CMD_F_FCRC);
    ed_fifo_wr(&len, 4);
    ed_fifo_wr(crc_base, 4);

    ed_fifo_rd(&resp, 1);
    if (resp)return resp;
    ed_fifo_rd(crc_base, 4);

    return 0;
}

void ed_cmd_mem_set(u8 val, u32 addr, u32 len) {

    ed_cmd_tx(CMD_MEM_SET);
    ed_fifo_wr(&addr, 4);
    ed_fifo_wr(&len, 4);
    ed_fifo_wr(&val, 1);
    ed_run_dma();
}

u8 ed_cmd_mem_test(u8 val, u32 addr, u32 len) {

    u8 resp;

    ed_cmd_tx(CMD_MEM_TST);
    ed_fifo_wr(&addr, 4);
    ed_fifo_wr(&len, 4);
    ed_fifo_wr(&val, 1);
    ed_run_dma();
    ed_fifo_rd(&resp, 1);

    return resp;
}

void ed_cmd_mem_rd(u32 addr, void *dst, u32 len) {

    u8 ack = 0;

    ed_cmd_tx(CMD_MEM_RD);

    ed_fifo_wr(&addr, 4);
    ed_fifo_wr(&len, 4);

    if (addr < ADDR_CFG) {
        ed_run_dma();
    } else {
        ed_fifo_wr(&ack, 1); //move to ram app for access to memoey
    }

    ed_fifo_rd(dst, len);
}

void ed_cmd_mem_wr(u32 addr, void *src, u32 len) {

    u8 ack = 0;
    u32 block;

    while (len) {

        if (addr < ADDR_CFG)ack = 0xaa; //force to wait second ack byte befor dma
        block = min(len, ACK_BLOCK_SIZE);

        ed_cmd_tx(CMD_MEM_WR);
        ed_fifo_wr(&addr, 4);
        ed_fifo_wr(&block, 4);
        ed_fifo_wr(&ack, 1);
        ed_fifo_wr(src, block);

        if (ack == 0xaa) {
            ed_run_dma();
        }

        src += block;
        addr += block;
        len -= block;
    }
}

void ed_cmd_mem_crc(u32 addr, u32 len, u32 *crc_base) {

    ed_cmd_tx(CMD_MEM_CRC);
    ed_fifo_wr(&addr, 4);
    ed_fifo_wr(&len, 4);
    ed_fifo_wr(crc_base, 4);
    ed_run_dma();

    ed_fifo_rd(crc_base, 4);

}

void ed_cmd_upd_exec(u32 addr, u32 crc) {

    ed_cmd_tx(CMD_UPD_EXEC);
    ed_fifo_wr(&addr, 4);
    ed_fifo_wr(&crc, 4);
    ed_reboot(STATUS_CFG_OK | STATUS_FPG_OK);
}

void ed_cmd_get_vdc(Vdc *vdc) {

    ed_cmd_tx(CMD_GET_VDC);
    ed_fifo_rd(vdc, sizeof (Vdc));

}

void ed_cmd_rtc_get(RtcTime *time) {

    ed_cmd_tx(CMD_RTC_GET);
    ed_fifo_rd(time, sizeof (RtcTime));
}

void ed_cmd_rtc_set(RtcTime *time) {

    ed_cmd_tx(CMD_RTC_SET);
    ed_fifo_wr(time, sizeof (RtcTime));
}

void ed_cmd_sys_inf(SysInfoIO *inf) {
    ed_cmd_tx(CMD_SYS_INF);
    ed_fifo_rd(inf, sizeof (SysInfoIO));
}

void ed_cmd_reboot() {

    ed_cmd_tx(CMD_REINIT);
    ed_reboot(STATUS_CFG_OK | STATUS_FPG_OK);
}

void ed_cmd_game_ctr() {
    ed_cmd_tx(CMD_GAME_CTR);
}

void ed_cmd_fla_rd(void *dst, u32 addr, u32 len) {

    ed_cmd_tx(CMD_FLA_RD);
    ed_fifo_wr(&addr, 4);
    ed_fifo_wr(&len, 4);
    ed_fifo_rd(dst, len);
}

u8 ed_cmd_fla_wr_sdc(u32 addr, u32 len) {

    ed_cmd_tx(CMD_FLA_WR_SDC);
    ed_fifo_wr(&addr, 4);
    ed_fifo_wr(&len, 4);
    return ed_check_status();
}

void ed_cmd_set_disk(u8 *path) {

    ed_cmd_tx(CMD_SET_DISK);
    ed_tx_string(path);
}

void ed_cmd_get_cur_path(u8 *path) {
    ed_cmd_tx(CMD_F_DIR_PATH);
    ed_rx_string(path);
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

u8 ed_fifo_rd_skip(u16 len) {

    u8 tmp;

    while (len--) {

        while ((REG_FIFO_STAT & FIFO_CPU_RXF));
        tmp = REG_FIFO_DATA;
    }

    return 0;
}

u8 ed_fifo_busy() {

    return (REG_FIFO_STAT & FIFO_CPU_RXF) ? 1 : 0;
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

void ed_rx_string(u8 *string) {

    u16 str_len;

    ed_fifo_rd(&str_len, 2);

    if (string == 0) {
        ed_fifo_rd_skip(str_len);
        return;
    }

    string[str_len] = 0;

    ed_fifo_rd(string, str_len);
}

void ed_rx_file_info(FileInfo *inf) {

    ed_fifo_rd(inf, 9);
    ed_rx_string(inf->file_name);
    inf->is_dir &= AT_DIR;
}

u8 ed_rx_next_rec(FileInfo *inf) {

    u8 resp;

    ed_fifo_rd(&resp, 1);
    if (resp)return resp;

    ed_rx_file_info(inf);

    return 0;
}

void ed_run_dma() { //acknowledge mcu access to memory and wait until it ends in wram

    ed_halt(STATUS_CMD_OK);
}

u8 ed_file_get_size(u8 *path, u32 *size) {

    u8 resp;
    FileInfo inf = {0};

    resp = ed_cmd_file_info(path, &inf);
    if (resp)return resp;

    *size = inf.size;
    return 0;
}

void ed_sleep(u16 ms) {

    u16 time = REG_TIMER;
    while ((u16) (REG_TIMER - time) < ms);
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
        asm("move.l 4, %a0");
        asm("jmp (%a0)");
    }
}

void ed_halt_app_end() {
}


