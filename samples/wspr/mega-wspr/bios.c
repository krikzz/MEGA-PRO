
#include "bios.h"


#define REG_FIFO_DATA   *((vu16 *)0xA130D0) //fifo data register
#define REG_FIFO_STAT   *((vu16 *)0xA130D2) //fifo status register. shows if fifo can be readed.

#define FIFO_RXF_MSK    0x7FF

#define CMD_RTC_GET     0x14

void bi_cmd_tx(u8 cmd);
void bi_fifo_rd(void *data, u16 len);
void bi_fifo_wr(void *data, u16 len);


void bi_cmd_rtc_get(RtcTime *time) {

    bi_cmd_tx(CMD_RTC_GET);
    bi_fifo_rd(time, sizeof (RtcTime));
}

void bi_fifo_flush() {

    vu8 tmp;
    REG_FIFO_DATA = 0;
    REG_FIFO_DATA = 0;
    while ((REG_FIFO_STAT & FIFO_RXF_MSK)) {
        tmp = REG_FIFO_DATA;
    }
}

void bi_cmd_tx(u8 cmd) {

    u8 buff[4];

    buff[0] = '+';
    buff[1] = '+' ^ 0xff;
    buff[2] = cmd;
    buff[3] = cmd ^ 0xff;

    bi_fifo_wr(buff, sizeof (buff));
}

void bi_fifo_rd(void *data, u16 len) {

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

void bi_fifo_wr(void *data, u16 len) {

    u8 *data8 = data;

    while (len--) {
        REG_FIFO_DATA = *data8++;
    }

}
