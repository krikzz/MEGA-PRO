/* 
 * File:   bios.h
 * Author: igor
 *
 * Created on January 23, 2020, 6:31 PM
 */

#include "sys.h"

#ifndef BIOS_H
#define	BIOS_H

/*----------------------------------------------------------------
 * cpu memory map:
 * 0x000000 256K OS code
 * 0x040000 256K OS ram
 * 0x080000 256K Save state buffer
 * 0xA130D0 16B control registers
 * ---------------------------------------------------------------- SST structure
 * 0x00000 64K  cpu ram
 * 0x10000 64K  vdp ram
 * 0x20000 128B sniffer
 * 0x20080 128B mapper regs
 * 0x20100 64B  cpu regs
 * 0x20140 128B vdp pal
 * 0x201C0 80B  vdp scroll
 * 0x20210 2B   halt st
 * 0x20212 ??   unused
 * 0x24000 64K  bram
 */

#define DEVID_MEGA_M20          0x18   

#define ERR_UNXP_STAT           0x40
#define ERR_NULL_PATH           0x41
//****************************************************************************** mappers

typedef enum {
    MAP_OS = 0,
    MAP_SMD, //1
    MAP_32X, //2
    MAP_10M, //3
    MAP_CDB, //4

    MAP_SSF, //5
    MAP_SMS, //6
    MAP_SVP, //7
    MAP_MCD, //8
    MAP_PIE, //9
    MAP_PIE_CD, //10
    MAP_SMD_CD, //11
    MAP_NES, //12
    MAP_GKO, //13
    MAP_END
} MAP_DEF;


//****************************************************************************** edio
#define REG_FIFO_DATA   *((vu16 *)0xA130D0) //fifo data register
#define REG_FIFO_STAT   *((vu16 *)0xA130D2) //fifo status register. shows if fifo can be readed.
#define REG_SYS_STAT    *((vu16 *)0xA130D4)
#define REG_TIMER       *((vu16 *)0xA130D6)

#define FIFO_CPU_RXF    0x8000 //fifo flags. system cpu can read
#define FIFO_ARM_RXF    0x4000 //fifo flags. mcu can read
#define FIFO_RXF_MSK    0x7FF

#define STATUS_CFG_OK   0x01 //mcu completed system configuration and. System ready for cpu execution
#define STATUS_CMD_OK   0x02 //mcu finished command execution
#define STATUS_FPG_OK   0x04 //fpga reboot complete
#define STATUS_STROBE   0x08 //toggled after each read
#define STATUS_REBOOT   0x10 //isn't real status. just an request to reboot at the end of halt

#define HOST_RST_SOFT   0x01
#define HOST_RST_HARD   0x02
//******************************************************************************
//PI bus addresses
#define ADDR_ROM        0x0000000       //ROM MEMORY    (2x8MB PSRAM)
#define ADDR_SRAM       0x1000000       //SRAM          (fast 10ns mem)
#define ADDR_BRAM       0x1080000       //Batery RAM 
#define ADDR_CFG        0x1800000       //various system configs
#define ADDR_SSR        0x1800100       //save state. sniffer data and mapper registers if any. !used by sms core!
#define ADDR_FIFO       0x1810000       //fifo buffer
#define ADDR_MAP        0x1830000       //mapper registers


#define ADDR_BRM_STD    (ADDR_BRAM + 0x00000)
#define ADDR_BRM_CDCART (ADDR_BRAM + 0x00000)
#define ADDR_BRM_CDBRAM (ADDR_BRAM + 0x40000)
#define ADDR_BRM_SST    (ADDR_ROM  + SIZE_ROM - 0x100000)
#define ADDR_CDBIOS     (ADDR_BRAM + 0x60000)
#define ADDR_MSBIOS     (ADDR_ROM  + 0x400000)
#define ADDR_OS_PRG     (ADDR_ROM  + SIZE_ROM - 0x80000)
#define ADDR_CSTART     (ADDR_OS_PRG + ADDR_MD_CSTART) //cold start marker
#define ADDR_MAP_MOD    (ADDR_MAP  + 0xffff)  //mapper mode.0xA5 if not supported


#define ADDR_FLA_MENU   0x00000         //boot fails cpu code
#define ADDR_FLA_FPGA   0x40000         //boot fails fpga code
#define ADDR_FLA_ICOR   0x80000         //mcu firmware update

#define SIZE_ROM        0x1000000       //ROM chip size 
#define SIZE_BRAM       0x80000         //battery ram size
#define SIZE_SRAM       0x80000         //SRAM chip size
#define SIZE_OS_CODE    0x40000         //OS CODE SIZE 
#define SIZE_OS_RAM     0x40000         //OS RAM SIZE
#define SIZE_FIFO       2048            //fifo buffer size between cpu and mcu
#define SIZE_IOCORE     0x20008         //IO core update size


#define GG_SLOTS        16
#define SS_COMBO_OFF    0xFFF   //turn off ss combo val
#define MAP_MOD_NSP     0xA5    //mapper not supported
#define MAP_MOD_MCD     0x01    //mcd mode
#define MAP_MOD_MDP     0x02    //md+ mode
//****************************************************************************** file mode
#define	FA_READ			0x01
#define	FA_WRITE		0x02
#define	FA_OPEN_EXISTING	0x00
#define	FA_CREATE_NEW		0x04
#define	FA_CREATE_ALWAYS	0x08
#define	FA_OPEN_ALWAYS		0x10
#define	FA_OPEN_APPEND		0x30

#define	AT_RDO	0x01	/* Read only */
#define	AT_HID	0x02	/* Hidden */
#define	AT_SYS	0x04	/* System */
#define AT_DIR	0x10	/* Directory */
#define AT_ARC	0x20	/* Archive */

#define DIR_OPT_SORTED  1
#define DIR_OPT_HIDCUE  2
#define DIR_OPT_SEEKCUE 4
//****************************************************************************** system control
#define SYS_CTRL_RSTOFF 0x01    //with this option quick reset wil reset the game but will not return to menu
#define SYS_CTRL_SS_ON  0x02    //vblank hook for in-game menu
#define SYS_CTRL_GG_ON  0x04    //cheats engine
#define SYS_CTRL_SS_BTN 0x08    //use external button for save state
#define SYS_CTRL_MKY_ON 0x10    //megakey
#define SYS_CTRL_GMODE  0x80    //mcu sets this bit when fpga configuration complete.
//****************************************************************************** game mapper control
#define BRAM_OFF        0x00
#define BRAM_SRM        0x01
#define BRAM_SRM3M      0x02
#define BRAM_24X01      0x03
#define BRAM_24C01      0x04
#define BRAM_24C02      0x05
#define BRAM_24C08      0x06
#define BRAM_24C16      0x07
#define BRAM_24C64      0x08
#define BRAM_M95320     0x09
#define BRAM_RCART      0x0A

#define BRAM_BUS_ACLM   0x00 //D=200001(0), C=200000(0)
#define BRAM_BUS_EART   0x10 //D=200000(7), C=200000(6)
#define BRAM_BUS_SEGA   0x20 //D=200001(0), C=200001(1)
#define BRAM_BUS_CODM   0x30 //D=300000(0), C=300000(1), RD=380001(7)

#define BRAM_MSK_TYPE   0x0F
#define BRAM_MSK_EBUS   0xF0

#define MCFG_MS_BIOS    0x01
#define MCFG_MS_FM      0x02
#define MCFG_MS_EXT     0x04
//****************************************************************************** 

typedef struct {
    u32 size;
    u16 date;
    u16 time;
    u8 is_dir;
    u8 *file_name;
} FileInfo;

typedef struct {
    u32 addr;
    u16 val;
    u16 unused;
} CheatSlot;

typedef struct {
    CheatSlot slot[GG_SLOTS];
} CheatList;

typedef struct {//lo/hi pass filter config
    u8 alpha; //filter alpha
    u8 gbase; //gain vol base
    u8 gfilt; //gain vol filt
    u8 gtotl; //gain total
} DspCfg;

typedef struct {
    CheatList gg;
    DspCfg lpf;
    DspCfg hpf;
    u16 mcd_irq_phase;
    u8 reserved[110];
    u8 map_idx;
    u8 mask;
    u8 map_cfg;
    u8 bram_cfg;
    u8 ss_key_save;
    u8 ss_key_load;
    u8 ss_key_menu;
    u8 sys_ctrl;
} MapConfig;

typedef struct {
    u16 v50;
    u16 v25;
    u16 v12;
    u16 vbt;
} Vdc;

typedef struct {
    u8 yar;
    u8 mon;
    u8 dom;
    u8 hur;
    u8 min;
    u8 sec;
} RtcTime;

typedef struct {
    u8 fla_id[8];
    u8 cpu_id[12];
    u32 serial_g;
    u32 serial_l;
    u32 boot_ctr;
    u32 game_ctr;
    u16 asm_date;
    u16 asm_time;
    u16 sw_date;
    u16 sw_time;
    u16 sw_ver;
    u16 hv_ver;
    u16 boot_ver;
    u8 device_id;
    u8 manufac_id;
    u8 rst_src;
    u8 boot_status;
    u8 bat_dry;
    u8 disk_status;
    u8 pwr_sys;
    u8 pwr_usb;
    u8 eep_id[6];
} SysInfoIO;

typedef struct {
    u16 vdp_regs[32];
    u8 reserved[63];
    u8 joy_keys;
    u8 map_regs[128];
} MapSSR_SMD;

typedef struct {
    u8 cpu_ram[0x10000];
    u8 vdp_ram[0x10000];
    MapSSR_SMD map_ssr;
    u32 cpu_reg[16];
    u16 vdp_crm[64];
    u16 vdp_vsr[40];
    u16 halt_st;
    u16 moto_sr;
    u8 unused[0x3DEC];
    u8 cpu_brm[0x10000];
} SaveState;



u8 bi_init();
void bi_cmd_status(u16 *status);
u8 bi_check_status();

//disk operations
u8 bi_cmd_disk_init();
u8 bi_cmd_dir_load(u8 *path, u8 args);
void bi_cmd_dir_get_size(u16 *size);
void bi_cmd_dir_seek_idx(u16 *idx);
void bi_cmd_dir_get_recs(u16 start_idx, u16 amount, u16 max_name_len);
u8 bi_cmd_file_open(u8 *path, u8 mode);
u8 bi_cmd_file_close();
u8 bi_cmd_file_read_mem(u32 addr, u32 len); //read to cartridge ram
u8 bi_cmd_file_read(void *dst, u32 len); //reat to system ram
u8 bi_cmd_file_write(void *src, u32 len); //write from system ram
u8 bi_cmd_file_write_mem(u32 addr, u32 len); //write from cartrifgr ram
u8 bi_cmd_file_info(u8 *path, FileInfo *inf);
u8 bi_cmd_file_set_ptr(u32 addr);
u8 bi_file_get_size(u8 *path, u32 *size);
u8 bi_cmd_file_del(u8 *path);


void bi_cmd_uart_wr(void *data, u16 len);
void bi_cmd_usb_wr(void *data, u16 len);
void bi_cmd_fifo_wr(void *data, u16 len);
u8 bi_cmd_file_crc(u32 len, u32 *crc_base);
void bi_cmd_mem_set(u8 val, u32 addr, u32 len);
u8 bi_cmd_mem_test(u8 val, u32 addr, u32 len);
void bi_cmd_mem_rd(u32 addr, void *dst, u32 len);
void bi_cmd_mem_wr(u32 addr, void *src, u32 len);
void bi_cmd_mem_crc(u32 addr, u32 len, u32 *crc_base);
void bi_cmd_upd_exec(u32 addr, u32 crc);
void bi_cmd_get_vdc(Vdc *vdc);
void bi_cmd_rtc_get(RtcTime *time);
void bi_cmd_rtc_set(RtcTime *time);
void bi_cmd_sys_inf(SysInfoIO *inf);
void bi_cmd_reboot();
void bi_cmd_game_ctr();
void bi_cmd_fla_rd(void *dst, u32 addr, u32 len);
u8 bi_cmd_fla_wr_sdc(u32 addr, u32 len);
void bi_cmd_set_disk(u8 *path);
u8 bi_cmd_fpga_init(u8 *path);
void bi_cmd_get_cur_path(u8 *path);

void bi_tx_string(u8 *string);
void bi_rx_string(u8 *string);
u8 bi_rx_next_rec(FileInfo *inf);
void bi_fifo_wr(void *data, u16 len);
void bi_fifo_rd(void *data, u16 len);
u8 bi_fifo_busy();

void bi_sleep(u16 ms);
u16 bi_get_ticks();


#endif	/* BIOS_H */

