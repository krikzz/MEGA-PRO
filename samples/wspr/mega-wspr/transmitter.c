
#include "main.h"

#define CLK_BASE        150000000//150mhz at clock generator
#define FSK_STEP        1.4648//1.4648Hz

#define REG_TX_FRAT     *((vu32 *)0xA130F0)//freq generator ratio
#define REG_TX_FINC     *((vu32 *)0xA130F4)//freq generator increment
#define REG_TX_FSKS     *((vu16 *)0xA130F8)//4-FSK tone separation (1.4648Hz)
#define REG_TX_TXPO     *((vu16 *)0xA130FA)//TX power (mask of GPIOs involved in rf emitting)
#define REG_TX_DATA     *((vu16 *)0xA130FC)
#define REG_TX_CTRL     *((vu16 *)0xA130FE)

#define CTRL_TX_ON      1
#define CTRL_TX_OFF     0

u32 calcRatio(u64 finc, u64 fbase, u64 ftarg);

void txInit(u32 freq, u8 tx_power, u8 *data) {

    u32 ratio;
    u32 clk_inc;
    u32 fsk_step;

    txStop();

    clk_inc = freq * 32;

    ratio = calcRatio(clk_inc, CLK_BASE, freq);
    fsk_step = ratio - calcRatio(clk_inc, CLK_BASE, freq + 100); //100hz delta val
    fsk_step = fsk_step * FSK_STEP / 100;

    
    if (data == 0) {
        for (u16 i = 0; i < 256; i++) {
            REG_TX_DATA = (i << 8);
        }
    } else {
        for (u16 i = 0; i < 256; i++) {
            REG_TX_DATA = (i << 8) | *data++;
        }
    }


    REG_TX_FRAT = ratio;
    REG_TX_FINC = clk_inc;
    REG_TX_FSKS = fsk_step;
    REG_TX_TXPO = tx_power;

}

void txStart() {
    REG_TX_CTRL = CTRL_TX_ON;
}

void txStop() {
    REG_TX_CTRL = CTRL_TX_OFF;
}

u32 calcRatio(u64 finc, u64 fbase, u64 ftarg) {

    return (u64) fbase * finc / ftarg / 2 - finc;
}
