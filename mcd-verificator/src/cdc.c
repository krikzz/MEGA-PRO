

#include "main.h"

DiskReader dr;

void cdcInit() {

    cdcRegSelect(CDC_RST);
    cdcRegWrite(0x00);
    gVsync();

    cdcRegSelect(CDC_IFCTRL);
    cdcRegWrite(0x00);

    cdcRegSelect(CDC_CTRL0);
    cdcRegWrite(0x00); //DECEN=0
    cdcRegWrite(CDC_CTRL1_SYIEN | CDC_CTRL1_SYDEN | CDC_CTRL1_DESEN); //SYIEN, SYDEN, DSCREN
}

void cdcRegSelect(u8 reg) {
    mcdWR8(SUB_REG_CDC_RADR, reg);
}

void cdcRegWrite(u8 val) {
    mcdWR8(SUB_REG_CDC_RDAT, val);
}

u8 cdcRegRead() {

    return mcdRD8(SUB_REG_CDC_RDAT);
}

void cdcDma(u8 dst_mem, u32 dst_addr, u16 cdc_addr, u16 len) {

    len--;

    mcdWR8(SUB_REG_CDC_DST, dst_mem);
    mcdWR16(SUB_REG_CDC_DADR, dst_addr >> 3);

    cdcRegSelect(CDC_IFCTRL);
    cdcRegWrite(IFCTRL_DOUTEN | IFCTRL_DECIEN);
    cdcRegWrite(len & 0xff); //DBCL
    cdcRegWrite(len >> 8); //DBCH
    cdcRegWrite(cdc_addr & 0xff); //DACL
    cdcRegWrite(cdc_addr >> 8); //DACH
    cdcRegWrite(0); //DTTRG
}

void cdcDecoderON() {

    cdcRegSelect(CDC_IFCTRL);
    cdcRegWrite(IFCTRL_DECIEN);

    cdcRegSelect(CDC_WAL);
    cdcRegWrite(0x00); //WAL
    cdcRegWrite(0x00); //WAH

    cdcRegSelect(CDC_PTL);
    cdcRegWrite(0x00);
    cdcRegWrite(0x00);

    cdcRegSelect(CDC_CTRL0);
    cdcRegWrite(CDC_CTRL0_DECEN | CDC_CTRL0_WRRQ);
    cdcRegWrite(CDC_CTRL1_SYIEN | CDC_CTRL1_SYDEN | CDC_CTRL1_DESEN);

}

void cdcDecoderOFF() {

    cdcRegSelect(CDC_CTRL0);
    cdcRegWrite(0);
    /*
    cdcRegSelect(CDC_IFCTRL);
    cdcRegWrite(0);
    cdcRegSelect(CDC_WAL);
    cdcRegWrite(0x00); //WAL
    cdcRegWrite(0x00); //WAH
    cdcRegWrite(0);
    cdcRegWrite(0);*/
}

void cdcDmaSetup(u8 dst_mem, u16 len, u16 cdc_addr) {

    mcdWR8(0xff8004, dst_mem); //set dst
    mcdWR8(0xff8005, CDC_DBCL);
    mcdWR8(0xff8007, (len - 1)); //len
    mcdWR8(0xff8007, (len - 1) >> 8);
    mcdWR8(0xff8007, cdc_addr); //cdc buff addr
    mcdWR8(0xff8007, cdc_addr >> 8);
}

void cdcDTACK() {
    cdcRegSelect(CDC_DTACK);
    cdcRegWrite(0);
}

void cdcDTTRG() {
    cdcRegSelect(CDC_DTTRG);
    cdcRegWrite(0);
}

