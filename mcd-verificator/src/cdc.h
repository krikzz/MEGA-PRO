/* 
 * File:   cdc.h
 * Author: igor
 *
 * Created on November 12, 2019, 5:15 PM
 */

#ifndef CDC_H
#define	CDC_H

#define CDC_DST_MAIN    2
#define CDC_DST_SUB     3
#define CDC_DST_PCM     4
#define CDC_DST_PRG     5
#define CDC_DST_WRAM    7

typedef struct {
    u32 disk_addr;
    u32 dma_addr;
    u32 slen;
    u32 cdc_addr;
    u8 dst_mem;
    u8 *buff;
} DiskReader;

extern DiskReader dr;


void cdcInit();
void cdcTest();

void cdcTest2();

#define EDT     0x80
#define DSR     0x40


#define CDC_IFCTRL      1
#define CDC_WAL         8
#define CDC_CTRL0       10
#define CDC_CTRL1       11
#define CDC_PTL         12
#define CDC_RST         15
#define CDC_DTTRG       6
#define CDC_DTACK       7

#define CDC_IFSTAT      1
#define CDC_STAT0       12
#define CDC_STAT1       13
#define CDC_STAT2       14
#define CDC_STAT3       15

#define CDC_DBCL        2
#define CDC_HEAD0       4
#define CDC_STAT0       12

#define CDC_CTRL0_DECEN 0x80
#define CDC_CTRL0_EDCRQ 0x40
#define CDC_CTRL0_E01RQ 0x20
#define CDC_CTRL0_AUTRQ 0x10
#define CDC_CTRL0_ERARQ 0x08
#define CDC_CTRL0_WRRQ  0x04
#define CDC_CTRL0_QRQ   0x02
#define CDC_CTRL0_PRQ   0x01

#define CDC_CTRL1_SYIEN 0x80
#define CDC_CTRL1_SYDEN 0x40
#define CDC_CTRL1_DESEN 0x20
#define CDC_CTRL1_COWEN 0x10
#define CDC_CTRL1_MODRQ 0x08
#define CDC_CTRL1_FRMRQ 0x04
#define CDC_CTRL1_MBCRQ 0x02
#define CDC_CTRL1_SHDEN 0x01

#define IFCTRL_CMDIEN       0x80
#define IFCTRL_DTEIEN       0x40
#define IFCTRL_DECIEN       0x20
#define IFCTRL_CMDBK        0x10
#define IFCTRL_DTWAI        0x08
#define IFCTRL_STWAI        0x04
#define IFCTRL_DOUTEN       0x02
#define IFCTRL_SOUTEN       0x01


#define IFSTAT_CMDI     0x80
#define IFSTAT_DTEI     0x40
#define IFSTAT_DECI     0x20
#define IFSTAT_1111     0x10
#define IFSTAT_DTBSY    0x08
#define IFSTAT_STBSY    0x04
#define IFSTAT_DTEN     0x02
#define IFSTAT_STEN     0x01

u32 cdcWaitNext();
void cdcDma(u8 dst_mem, u32 dst_addr, u16 cdc_addr, u16 len);
void cdcRegSelect(u8 reg);
void cdcRegWrite(u8 val);
u8 cdcRegRead();
void cdcDecoderON();
void cdcDecoderOFF();
void cdcDmaSetup(u8 dst_mem, u16 len, u16 cdc_addr);
void cdcDTTRG();
void cdcDTACK();



u8 testCDC_new();

#endif	/* CDC_H */

