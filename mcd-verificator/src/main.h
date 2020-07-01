/* 
 * File:   main.h
 * Author: igor
 *
 * Created on October 28, 2019, 12:49 AM
 */

#ifndef MAIN_H
#define	MAIN_H

#include "sys.h"
#include "mcd.h"
#include "cdc.h"
#include "cdd.h"
#include "pcm.h"

void testSTD();
void testCDD();
void testCDD2();
void testAsic();
void testPCM();
void testPrintResp(u8 resp);
void testCDC_old();
void audioTune();

#endif	/* MAIN_H */

