
#include "main.h"

#define ADJ_FRACTION    0x80000

#define STATE_OFF       0
#define STATE_SYNC      1
#define STATE_TX        2

#define TX_MODE_OFF     0
#define TX_MODE_ON      1
#define TX_MODE_TST     2

typedef struct {
    u8 call[6];
    u8 locator[4];
    u8 tx_pow;
    u8 band;
    u8 tx_mode;
    u32 freq_adj;
    u32 crc;
} WsprCfg;

typedef struct {
    u32 freq;
    u32 msg_ctr;
    u8 state;
    s16 channel;
    u8 msg[256];
} WsprState;

typedef enum {
    MENU_CALL,
    MENU_LOC,
    MENU_BAND,
    MENU_FADJ,
    MENU_TXPOW,
    MENU_TRANS,
    MENU_SIZE
} MENU;

typedef enum {
    STAT_FREQ,
    STAT_MSG_SENT,
    STAT_TIME,
    STAT_STATE,
    STAT_SIZE
} STAT;

void wsprInit();
void wsprResetCfg();
void wsprSaveCfg();
u32 wsprCfgCrc();
void menuDrawFreq(u32 freq);
void menuDrawCfg(u8 selector);
void menuUpdateCfg(u8 selector, u16 joy);
void menuDrawState();
void menuEditCall();
void menuEditLocator();
u8 menuSeq(u8 val, u8 *seq, u8 dec);
void wsprUpdateState();
void wsprNextChan();
void wsprSetCfg();
void wsprDecodeMsg();


WsprCfg *cfg;
WsprState ws;

u8 tx_pow[] = {
    TX_PWR_1,
    TX_PWR_2,
    TX_PWR_3,
    TX_PWR_4,
    TX_PWR_5,
};

#define BAND_NUM        9
u32 band_freq[BAND_NUM] = {
    1836600,
    3568600,
    7038600,
    10138700,
    14095600,
    18104600,
    21094600,
    24924600,
    28124600
};

RtcTime rtc;

void wsprMenu() {


    u8 selector = 0;
    u16 joy = 0;
    u16 old_joy = 0;
    //static WsprCfg s;
    cfg = (WsprCfg *) 0x200000; //bram

    wsprInit();

    gCleanPlan();

    while (1) {

        gVsync();
        gSetXY(0, 1);
        menuDrawCfg(selector);

        wsprUpdateState();
        menuDrawState();

        joy = sysJoyRead();
        if (joy == old_joy) {
            continue;
        }
        old_joy = joy;

        if (joy == JOY_U) {
            selector = selector == 0 ? MENU_SIZE - 1 : selector - 1;
        }

        if (joy == JOY_D) {
            selector = (selector + 1) % MENU_SIZE;
        }

        menuUpdateCfg(selector, joy);

    }

    while (1);

}

void menuDrawFreq(u32 freq) {

    u32 frac;
    gAppendNum(freq / 1000000);
    gAppendString(".");

    frac = freq % 1000000;
    for (int i = 100000; i > frac; i /= 10) {
        gAppendString("0");
    }
    if (frac != 0) {
        gAppendNum(frac);
    }
    gAppendString(" Mhz");
}

void menuDrawCfg(u8 selector) {

    u8 * item[MENU_SIZE];

    item[MENU_CALL] = "CALL       : ";
    item[MENU_LOC] = "LOCATOR    : ";
    item[MENU_BAND] = "BAND       : ";
    item[MENU_FADJ] = "FREQ ADJ   : ";
    item[MENU_TXPOW] = "TX POWER   : ";
    item[MENU_TRANS] = "TRANSMITTER: ";

    gConsPrint("--------------WSPR SETTINGS-------------");
    for (int i = 0; i < MENU_SIZE; i++) {

        gConsPrint("");

        if (selector == i) {
            gConsPrint(" >");
        } else {
            gConsPrint("  ");
        }

        gAppendString(item[i]);

        switch (i) {
            case MENU_CALL:
                for (int u = 0; u < sizeof (cfg->call); u++) {
                    gAppendChar(cfg->call[u]);
                }
                break;
            case MENU_LOC:
                for (int u = 0; u < sizeof (cfg->locator); u++) {
                    gAppendChar(cfg->locator[u]);
                }
                break;
            case MENU_FADJ:

                if (cfg->freq_adj == ADJ_FRACTION) {
                    gAppendString("0 ");

                } else if (cfg->freq_adj > ADJ_FRACTION) {
                    gAppendString("+");
                    gAppendNum(cfg->freq_adj - ADJ_FRACTION);
                } else {
                    gAppendString("-");
                    gAppendNum(ADJ_FRACTION - cfg->freq_adj);
                }
                break;
            case MENU_TXPOW:
                gAppendNum(cfg->tx_pow);
                if (tx_pow[cfg->tx_pow] == TX_PWR_MAX) {
                    gAppendString(" (MAX)");
                } else if (tx_pow[cfg->tx_pow] == TX_PWR_MIN) {
                    gAppendString(" (MIN)");
                }
                break;
            case MENU_BAND:
                menuDrawFreq(band_freq[cfg->band]);
                break;
            case MENU_TRANS:
                if (cfg->tx_mode == TX_MODE_OFF) {
                    gAppendString("OFF");
                } else if (cfg->tx_mode == TX_MODE_ON) {
                    gAppendString("ON");
                } else if (cfg->tx_mode == TX_MODE_TST) {
                    gAppendString("TEST MODE");
                } else {
                    gAppendString("???");
                }
                break;
        }

        gAppendString("         ");
    }

    gConsPrint("");
}

void menuUpdateCfg(u8 selector, u16 joy) {

    u32 crc_old = wsprCfgCrc();

    switch (selector) {

        case MENU_CALL:
            if (joy == JOY_A) {
                menuEditCall();
                wsprDecodeMsg();
            }
            break;

        case MENU_LOC:
            if (joy == JOY_A) {
                menuEditLocator();
                wsprDecodeMsg();
            }
            break;

        case MENU_BAND:
            if (joy == JOY_R && cfg->band < BAND_NUM - 1) {
                cfg->band++;
            }

            if (joy == JOY_L && cfg->band != 0) {
                cfg->band--;
            }
            cfg->band %= BAND_NUM;
            break;

        case MENU_FADJ:
            if (joy == JOY_R) {
                cfg->freq_adj++;
            }
            if (joy == JOY_L) {
                cfg->freq_adj--;
            }
            if (joy == JOY_A) {
                cfg->freq_adj = ADJ_FRACTION;
            }
            break;

        case MENU_TXPOW:
            if (joy == JOY_R && cfg->tx_pow < sizeof (tx_pow) - 1) {
                cfg->tx_pow++;
            }

            if (joy == JOY_L && cfg->tx_pow != 0) {
                cfg->tx_pow--;
            }
            cfg->tx_pow %= sizeof (tx_pow);
            break;

        case MENU_TRANS:
            if (joy == JOY_R) {
                cfg->tx_mode = cfg->tx_mode >= 2 ? 2 : cfg->tx_mode + 1;
            }
            if (joy == JOY_L && cfg->tx_mode != 0) {
                cfg->tx_mode--;
            }
            break;
    }


    if (crc_old != wsprCfgCrc()) {

        wsprSaveCfg();
        if (cfg->tx_mode == TX_MODE_TST) {
            ws.state = STATE_SYNC;
        }
    }
}

void menuDrawState() {

    u8 * item[STAT_SIZE];

    item[STAT_FREQ] = "TX FREQ    : ";
    item[STAT_MSG_SENT] = "MSG SENT   : ";
    item[STAT_TIME] = "TIME       : ";
    item[STAT_STATE] = "STATE      : ";

    gConsPrint("---------------WSPR STATE---------------");
    gConsPrint("");

    for (int i = 0; i < STAT_SIZE; i++) {

        gConsPrint("  ");
        gAppendString(item[i]);

        switch (i) {
            case STAT_FREQ:
                menuDrawFreq(ws.freq);
                break;
            case STAT_MSG_SENT:
                gAppendNum(ws.msg_ctr);
                break;
            case STAT_TIME:
                gAppendHex8(rtc.hur);
                gAppendChar(':');
                gAppendHex8(rtc.min);
                gAppendChar(':');
                gAppendHex8(rtc.sec);
                break;
            case STAT_STATE:
                if (ws.state == STATE_OFF) {
                    gAppendString("OFF");
                }
                if (ws.state == STATE_SYNC) {
                    gAppendString("WAIT SYNC");
                }
                if (ws.state == STATE_TX) {
                    gAppendString("TX MSG");
                }
                break;
        }

        gAppendString("          ");
        gConsPrint("");
    }

}

void menuEditCall() {

    u16 joy;
    u8 selector = 0;
    u8 x = (G_SCREEN_W - 6) / 2;
    u8 y = G_SCREEN_H / 2;
    gCleanPlan();


    while (1) {

        gSetXY(x, y);

        for (int i = 0; i < 6; i++) {
            gAppendChar(cfg->call[i]);
        }
        gSetXY(x, y + 1);
        gAppendString("      ");
        gSetXY(x + selector, y + 1);
        gAppendChar('^');

        joy = sysJoyWait();
        if (joy == JOY_A) {
            break;
        }

        if (joy == JOY_R) {
            selector = (selector + 1) % 6;
        }

        if (joy == JOY_L) {
            selector = selector == 0 ? 5 : selector - 1;
        }


        if (joy == JOY_U || joy == JOY_D) {

            u8 *seq = 0;

            if (selector == 0) {
                seq = " 09AZ ";
            } else if (selector == 1) {
                seq = "9AZ0";
            } else if (selector == 2) {
                seq = "90";
            } else {
                seq = "ZA";
            }

            cfg->call[selector] = menuSeq(cfg->call[selector], seq, joy == JOY_D);
        }
    }

    gCleanPlan();
}

void menuEditLocator() {

    u16 joy;
    u8 selector = 0;
    u8 x = (G_SCREEN_W - 4) / 2;
    u8 y = G_SCREEN_H / 2;
    gCleanPlan();


    while (1) {

        gSetXY(x, y);

        for (int i = 0; i < 4; i++) {
            gAppendChar(cfg->locator[i]);
        }
        gSetXY(x, y + 1);
        gAppendString("    ");
        gSetXY(x + selector, y + 1);
        gAppendChar('^');

        joy = sysJoyWait();
        if (joy == JOY_A) {
            break;
        }

        if (joy == JOY_R) {
            selector = (selector + 1) % 4;
        }

        if (joy == JOY_L) {
            selector = selector == 0 ? 3 : selector - 1;
        }

        if (joy == JOY_U || joy == JOY_D) {

            u8 *seq = 0;

            if (selector < 2) {
                seq = "RA";
            } else {
                seq = "90";
            }

            cfg->locator[selector] = menuSeq(cfg->locator[selector], seq, joy == JOY_D);
        }
    }

    gCleanPlan();
}

u8 menuSeq(u8 val, u8 *seq, u8 dec) {

    u8 seq_len = 0;
    u8 new_seq[32];

    while (seq[seq_len] != 0) {
        seq_len++;
    }

    if (dec) {
        for (int i = 0; i < seq_len; i++) {
            new_seq[i] = seq[seq_len - 1 - i];
        }
    } else {

        for (int i = 0; i < seq_len; i++) {
            new_seq[i] = seq[i];
        }
    }

    for (int i = 0; i < seq_len; i += 2) {

        if (val == new_seq[i]) {
            val = i + 1 >= seq_len ? new_seq[0] : new_seq[i + 1];
            return val;
        }
    }

    return dec ? val - 1 : val + 1;
}

//******************************************************************************

void wsprInit() {

    ws.msg_ctr = 0;
    ws.channel = 0;

    if (cfg->crc != wsprCfgCrc()) {
        wsprResetCfg();
    }

    wsprDecodeMsg();
    wsprSetCfg();
}

void wsprResetCfg() {//G6AML

    cfg->call[0] = 'X';
    cfg->call[1] = '1';
    cfg->call[2] = '6';
    cfg->call[3] = 'B';
    cfg->call[4] = 'I';
    cfg->call[5] = 'T';

    cfg->locator[0] = 'K';
    cfg->locator[1] = 'O';
    cfg->locator[2] = '7';
    cfg->locator[3] = '0';

    cfg->tx_mode = TX_MODE_OFF;
    cfg->band = 4;
    cfg->tx_pow = sizeof (tx_pow) - 1;

    cfg->freq_adj = ADJ_FRACTION;
    cfg->tx_mode = TX_MODE_OFF;

    wsprSaveCfg();
}

void wsprSaveCfg() {

    cfg->crc = wsprCfgCrc();
}

u32 wsprCfgCrc() {
    return crc32(0, cfg, sizeof (WsprCfg) - 4);
}

void wsprUpdateState() {

    bi_cmd_rtc_get(&rtc);
    static u8 old_tx_mode;

    if (old_tx_mode != cfg->tx_mode) {
        ws.state = STATE_OFF;
    }

    if (cfg->tx_mode == TX_MODE_OFF) {
        ws.state = STATE_OFF;
    } else if (ws.state == STATE_OFF) {
        ws.state = STATE_SYNC;
    }

    if (cfg->tx_mode != TX_MODE_ON) {
        ws.channel = 0;
    }

    switch (ws.state) {

        case STATE_OFF:
            wsprSetCfg();
            break;

        case STATE_SYNC:
            wsprSetCfg();
            if ((rtc.min % 2 == 0 && rtc.sec == 0x01) || cfg->tx_mode == TX_MODE_TST) {
                ws.state = STATE_TX;
                txStart();
            }
            break;

        case STATE_TX:
            if ((rtc.min % 2 == 1 && rtc.sec == 0x57) && cfg->tx_mode != TX_MODE_TST) {
                ws.state = STATE_SYNC;
                ws.msg_ctr++;
                txStop();
                wsprNextChan();
            }
            break;
    }

    old_tx_mode = cfg->tx_mode;
}

void wsprNextChan() {

    static u16 rnd;
    rnd += (GFX_HV_CTR >> 8);
    //rnd ^= (GFX_HV_CTR >> 9);

    rnd %= 31;

    if (rnd < 15) {
        ws.channel = -rnd;
    }
    if (rnd == 15) {
        ws.channel = 0;
    } else {
        ws.channel = rnd - 15;
    }

    ws.channel = ws.channel * 6; //+-90hz
}

void wsprSetCfg() {

    ws.freq = band_freq[cfg->band];
    ws.freq += 1500; //1500Hz USB shift
    ws.freq += ws.channel; //random channel shift
    ws.freq = (u64) ws.freq * cfg->freq_adj / ADJ_FRACTION; //clk inaccuracy correction

    u8 *msg = cfg->tx_mode == TX_MODE_TST ? 0 : ws.msg;
    txInit(ws.freq, tx_pow[cfg->tx_pow], msg);
}

void wsprDecodeMsg() {
    for (int i = 0; i < 256; i++) {
        ws.msg[i] = 0;
    }
    msgDecoder(cfg->call, cfg->locator, 13, ws.msg);
}
