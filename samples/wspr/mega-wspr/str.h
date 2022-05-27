/* 
 * File:   str.h
 * Author: igor
 *
 * Created on July 13, 2020, 3:25 PM
 */

#ifndef STR_H
#define	STR_H

u8 *str_append(u8 *dst, u8 *src);
u8 *str_append_hex8(u8 *dst, u8 num);
u8 *str_append_num(u8 *dst, u32 num);
u8* str_append_date(u8 *dst, u16 date); 
u8* str_append_time(u8 *dst, u16 time);
u16 str_lenght(u8 *str);

#endif	/* STR_H */

