/* 
 * File:   wspr.h
 * Author: igor
 *
 * Created on May 25, 2022, 3:03 PM
 */

#ifndef WSPR_H
#define	WSPR_H

#define TX_PWR_MAX      TX_PWR_5
#define TX_PWR_MIN      TX_PWR_1

#define TX_PWR_5        0x00    //max tx power
#define TX_PWR_4        0x02
#define TX_PWR_3        0x06
#define TX_PWR_2        0x0E
#define TX_PWR_1        0x1E


void txInit(u32 freq, u8 tx_power, u8 *data);
void txStart();
void txStop();


#endif	/* WSPR_H */

