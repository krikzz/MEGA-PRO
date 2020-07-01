/* 
 * File:   cdd.h
 * Author: igor
 *
 * Created on November 12, 2019, 5:15 PM
 */

#ifndef CDD_H
#define	CDD_H

typedef struct {
    u8 status;
    u8 u0;
    u8 arg[6];
    u8 u1;
    u8 crc;
} CddStatus;


void cddTest();
void cddUpdate();
void cddCmd_nop();
void cddCmd_stop();
void cddCmd_getToc(u8 toc_cmd, u16 arg);
void cddCmd_play(u32 msf);
void cddCmd_seek(u32 msf);
void cddCmd_pause();
void cddCmd_resume();
void cddTest2();
void cddCmdTX();
void cddStatusRX();
void cddCmd_playFastF();




void cddReadCD(u32 disk_addr, u32 mem_addr, u32 len, u8 dst_mem);
void cddInit(u8 skip_toc_loading);
void cdcDmaBusy();
void cddPrint();
u8 cddInitToc();

extern CddStatus cdd_stat;

#endif	/* CDD_H */

