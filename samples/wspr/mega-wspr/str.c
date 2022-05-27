
#include "main.h"


u8 decToBcd(u8 val);
u8 bcdToDec(u8 val);

u8 *str_append(u8 *dst, u8 *src) {

    while (*dst != 0)dst++;
    while (*src != 0)*dst++ = *src++;
    *dst = 0;
    return dst;
}

u8 *str_append_hex8(u8 *dst, u8 num) {

    u8 buff[3];
    buff[2] = 0;
    buff[0] = (num >> 4) + '0';
    buff[1] = (num & 15) + '0';

    if (buff[0] > '9')buff[0] += 7;
    if (buff[1] > '9')buff[1] += 7;

    return str_append(dst, buff);
}


u8 *str_append_num(u8 *dst, u32 num) {

    u16 i;
    u8 buff[11];
    u8 *str = (u8 *) & buff[10];

    *str = 0;
    if (num == 0)*--str = '0';
    for (i = 0; num != 0; i++) {
        *--str = num % 10 + '0';
        num /= 10;
    }

    return str_append(dst, str);
}

u8* str_append_date(u8 *dst, u16 date) {

    str_append_hex8(dst, decToBcd(date & 31));
    str_append(dst, ".");
    str_append_hex8(dst, decToBcd((date >> 5) & 15));
    str_append(dst, ".");
    return str_append_num(dst, (date >> 9) + 1980);
}

u8* str_append_time(u8 *dst, u16 time) {

    str_append_hex8(dst, decToBcd(time >> 11));
    str_append(dst, ":");
    str_append_hex8(dst, decToBcd((time >> 5) & 0x3F));
    str_append(dst, ":");
    return str_append_hex8(dst, decToBcd((time & 0x1F) * 2));
}




u16 str_lenght(u8 *str) {

    u16 len = 0;
    while (*str++ != 0)len++;
    return len;
}

u8 decToBcd(u8 val) {

    if (val > 99)val = 99;
    return (val / 10 << 4) | val % 10;
}

u8 bcdToDec(u8 val) {
    return (val >> 4) * 10 + (val & 15);
}

