
#include "main.h"

void PSG_init();

void PSG_write(u8 data);

void PSG_setEnvelope(u8 channel, u8 value);
void PSG_setTone(u8 channel, u16 value);
void PSG_setFrequency(u8 channel, u16 value);
void pcmLimmiterTest();

void tonePCM(u16 speed) {

    u16 i;
    PcmChan pcm = {0};
    u8 buff[64];

    // buff[0] = 127;
    buff[0 + 16] = 0xff;
    for (i = 0; i < 8; i++) {
        buff[i + 0 + 0] = 127;
        buff[i + 0 + 8] = 254;
        buff[i + 0 + 16] = 0xff;
    }


    /*
        memSet(buff, 127, sizeof (buff));
        memSet(buff, 254, sizeof (buff) / 2);
        buff[sizeof (buff) - 1] = 0xff;*/



    pcm.env = 0xff;
    pcm.pan = 0xff;
    pcm.fd = speed;
    pcm.ls = 0;
    pcm.st = 0;

    pcmMemWrite(buff, 0, sizeof (buff));
    for (i = 0; i < 8; i++) {
        pcmChanSet(i, &pcm);
    }
    pcmWrite(PCM_OFF_SW, 0xff);
    pcmWrite(PCM_CTRL, CTRL_ON);
    pcmWrite(PCM_OFF_SW, 0xfe);

    //sysJoyWait();
}

void toneTest() {

    u16 speed = 2048;
    u16 joy = 0;

    while (1) {

        tonePCM(speed);
        gCleanPlan();
        gConsPrint("freq: ");
        gAppendNum(32623 * speed / 2048 / 16);

        joy = sysJoyWait();
        if (joy == JOY_U) {
            speed *= 2;
        }

        if (joy == JOY_D) {
            speed /= 2;
        }


    }

}

void audioTune() {


    u16 joy = 0;
    u16 old_joy = 0;
    u16 i;
    u8 buff[1024];
    PcmChan pcm = {0};

    gCleanPlan();
    gConsPrint("audio tuning app init...");

    toneTest();
    //pcmLimmiterTest();

    mcdWR16(0xff8034, 0x4000);
    PSG_init();
    cddInit(0);

    //memSet(&buff[0], 0 + 5, 32);
    //memSet(&buff[32], 0 + 13, 32);
    memSet(&buff[0], 0 + 12, 64);
    memSet(&buff[64], 128 + 12, 64);
    buff[128] = 0xff;

    pcm.env = 0xff;
    pcm.pan = 0xff;
    pcm.fd = 2048;
    pcm.ls = 0;
    pcm.st = 0;

    pcmMemWrite(buff, 0, 257);
    for (i = 0; i < 8; i++) {
        pcmChanSet(i, &pcm);
    }
    pcmWrite(PCM_OFF_SW, 0xff);
    pcmWrite(PCM_CTRL, CTRL_ON);
    //pcmWrite(PCM_OFF_SW, ~0x01);

    gAppendString("ok");

    while (1) {

        joy = sysJoyWait();
        if (joy == old_joy)continue;

        pcmWrite(PCM_OFF_SW, 0xff);
        PSG_init();
        gVsync();
        cddCmd_pause();
        cddUpdate();


        if (joy == JOY_A) {
            PSG_setEnvelope(0, 4);
            PSG_setTone(0, 0);
            PSG_setFrequency(0, 250);
        }

        if (joy == JOY_B) {
            pcmWrite(PCM_OFF_SW, ~0x01);
        }


        if (joy == JOY_C) {
            cddCmd_play(0x33000);
            cddUpdate();
        }




        if (joy == JOY_U) {
            /*
                        pcmWrite(PCM_OFF_SW, 0xff);
                        pcmWrite(PCM_CTRL, CTRL_OFF);

                        memSet(&buff[0], 34, 64);
                        memSet(&buff[64], 164, 64);
                        buff[128] = 0xff;

                        pcmMemWrite(buff, 0, 257);
                        for (i = 0; i < 8; i++) {
                            pcmChanSet(i, &pcm);
                        }

                        pcmWrite(PCM_OFF_SW, 0xff);
                        pcmWrite(PCM_CTRL, CTRL_ON);*/


            cddCmd_play(0x30000);
            cddUpdate();

            //pcmWrite(PCM_OFF_SW, 0x00);

        }


        if (joy == JOY_D) {
            cddCmd_play(0x40000);
            cddUpdate();
        }

        if (joy == JOY_L) {
            cddCmd_play(0x43000);
            cddUpdate();
        }
        if (joy == JOY_R) {
            cddCmd_play(0x50000);
            cddUpdate();
        }
        /*
        if (joy == JOY_B) {
            pcmWrite(PCM_OFF_SW, ~0x03);
        }
        if (joy == JOY_C) {
            pcmWrite(PCM_OFF_SW, ~0x7f);
        }*/

    }

}

void pcmLimmiterTest() {

    u16 i;
    u16 joy = 0;
    u8 pcm_vol_a = 34;
    u8 pcm_vol_b = 164;
    PcmChan pcm = {0};
    u8 buff[1024];

    pcm.env = 0xff;
    pcm.pan = 0xff;
    pcm.fd = 2048;
    pcm.ls = 0;
    pcm.st = 0;


    gCleanPlan();
    while (1) {

        gSetXY(0, 0);
        gConsPrint("pcm vol a: ");
        gAppendNum(pcm_vol_a);
        gAppendString("   ");

        gConsPrint("pcm vol b: ");
        gAppendNum(pcm_vol_b);
        gAppendString("   ");

        pcmWrite(PCM_OFF_SW, 0xff);
        pcmWrite(PCM_CTRL, CTRL_OFF);

        memSet(&buff[0], pcm_vol_a, 64);
        memSet(&buff[64], pcm_vol_b, 64);
        buff[128] = 0xff;


        pcmMemWrite(buff, 0, 257);
        for (i = 0; i < 8; i++) {
            pcmChanSet(i, &pcm);
        }

        pcmWrite(PCM_OFF_SW, 0xff);
        pcmWrite(PCM_CTRL, CTRL_ON);
        pcmWrite(PCM_OFF_SW, 0x00);


        joy = sysJoyWait();

        if (joy == JOY_L)pcm_vol_a -= 1;
        if (joy == JOY_R)pcm_vol_a += 1;
        if (joy == JOY_U)pcm_vol_b += 1;
        if (joy == JOY_D)pcm_vol_b -= 1;
        if (joy == JOY_C)pcm_vol_b = 34;
        if (joy == JOY_C)pcm_vol_a = 164;
        if (joy == JOY_STA)pcm_vol_b = 0;

    }
}
//******************************************************************************

void PSG_init() {

    u16 i;

    for (i = 0; i < 4; i++) {
        PSG_setEnvelope(i, PSG_ENVELOPE_MIN);
        PSG_setFrequency(i, 0);
        PSG_setTone(i, 0);
    }

}

void PSG_write(u8 data) {

    *((volatile u8*) PSG_PORT) = data;
}

void PSG_setEnvelope(u8 channel, u8 value) {

    *((volatile u8*) PSG_PORT) = 0x90 | ((channel & 3) << 5) | (value & 0xF);
}

void PSG_setTone(u8 channel, u16 value) {

    *((volatile u8*) PSG_PORT) = 0x80 | ((channel & 3) << 5) | (value & 0xF);
    *((volatile u8*) PSG_PORT) = (value >> 4) & 0x3F;
}

void PSG_setFrequency(u8 channel, u16 value) {

    u16 data;
    if (value) {

        data = 3546893 / (value * 32);
    } else {
        data = 0;
    }

    *((volatile u8*) PSG_PORT) = 0x80 | ((channel & 3) << 5) | (data & 0xF);
    *((volatile u8*) PSG_PORT) = (data >> 4) & 0x3F;
}
