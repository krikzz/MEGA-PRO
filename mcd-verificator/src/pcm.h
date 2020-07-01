/* 
 * File:   pcm.h
 * Author: igor
 *
 * Created on February 27, 2020, 1:36 PM
 */

#ifndef PCM_H
#define	PCM_H

typedef struct {
    u8 env;
    u8 pan;
    u16 fd;
    u16 ls;
    u8 st;
} PcmChan;


#define PCM_BASE 0xFF0000

#define PCMC_ENV   0x00
#define PCMC_PAN   0x01
#define PCMC_FDL   0x02
#define PCMC_FDH   0x03
#define PCMC_LSL   0x04
#define PCMC_LSH   0x05
#define PCMC_ST    0x06
#define PCM_CTRL  0x07
#define PCM_OFF_SW 0x08

#define PCM_ADDR  0x10
#define PCM_RAM   0x1000

#define CTRL_ON         0x80
#define CTRL_OFF        0x00
#define CTRL_MOD_CHAN   0x40
#define CTRL_MOD_ADDR   0x00

u16 pcmAddrRead(u8 channel);
u8 pcmTestRam();
void pcmTmp();
u8 pcmRead(u16 reg);
void pcmWrite(u16 reg, u8 val);
u8 pcmTestVar();
u8 pcmTestClocking();
void pcmSampleWrite(u8 *src, u16 addr, u16 len, u8 state);
void pcmBeepTest();
void pcmSample();
void pcmDma();
void pcmMemRead(u8 *dst, u16 addr, u16 len);
void pcmMemWrite(u8 *src, u16 addr, u16 len);
void pcmSetBank(u8 bank);
void pcmChanSet(u8 chan, PcmChan *pcm);

#endif	/* PCM_H */

