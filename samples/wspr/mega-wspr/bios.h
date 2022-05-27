/* 
 * File:   bios.h
 * Author: igor
 *
 * Created on January 23, 2020, 6:31 PM
 */

#include "sys.h"

#ifndef BIOS_H
#define	BIOS_H

typedef struct {
    u8 yar;
    u8 mon;
    u8 dom;
    u8 hur;
    u8 min;
    u8 sec;
} RtcTime;

void bi_cmd_rtc_get(RtcTime *time);
void bi_fifo_flush();

//#define REG_TIMER       *((vu16 *)0xA130D6)

#endif	/* BIOS_H */

