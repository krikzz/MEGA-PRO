

#include "main.h"

//wspr message decoder taken from:
//https://www.codeproject.com/Articles/1200310/Creating-WSPR-Message-in-Cplusplus

#define MSG_SIZE 162

u8 sync[] = {

    1, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 1, 1, 0, 0, 0,
    1, 0, 0, 1, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0,
    0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0, 1, 1,
    0, 1, 0, 0, 0, 1, 1, 0, 1, 0, 0, 0, 0, 1, 1, 0, 1, 0,
    1, 0, 1, 0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 1, 0, 0, 0, 1,
    1, 0, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 1,
    0, 0, 1, 1, 1, 0, 1, 1, 0, 0, 1, 1, 0, 1, 0, 0, 0, 1,
    1, 1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 1, 1, 0, 0, 0, 0,
    0, 0, 0, 1, 1, 0, 1, 0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0
};

u8 isdigit(u8 val);
u8 getCharValue(u8 val);
u8 reverseBits(u8 b);
u8 reverseAddress(u8 *reverseAddressIndex);
s32 calculateParity(u32 x);

void msgDecoder(u8 *call, u8 *locator, u8 power, u8 *msg) {

    /*
    N1 = [Ch 1] The first character can take on any of the 37 values including [sp],
    N2 = N1 * 36 + [Ch 2] but the second character cannot then be a space so can have 36 values
    N3 = N2 * 10 + [Ch 3] The third character must always be a number, so only 10 values are possible.
    N4 = 27 * N3 + [Ch 4] – 10]
    N5 = 27 * N4 + [Ch 5] – 10] Characters at the end cannot be numbers,
    N6 = 27 * N5 + [Ch 6] – 10] so only 27 values are possible.
     */

    u32 N = getCharValue(call[0]);
    N = N * 36 + getCharValue(call[1]);
    N = N * 10 + getCharValue(call[2]);
    N = N * 27 + (getCharValue(call[3]) - 10);
    N = N * 27 + (getCharValue(call[4]) - 10);
    N = N * 27 + (getCharValue(call[5]) - 10);


    u32 M1 = (179 - 10 * (locator[0] - 'A')
            - (locator[2] - '0')) * 180
            + (10 * (locator[1] - 'A'))
            + (locator[3] - '0');

    u32 M = M1 * 128 + power + 64;


    for (int i = 0; i < MSG_SIZE; i++) {

        msg[i] = sync[i];
    }

    u32 reg = 0;
    u8 reverseAddressIndex = 0;

    for (int i = 27; i >= 0; i--) {

        //make room for the next register bit
        reg <<= 1; // same as reg = reg << 1

        if (N & ((u32) 1 << i)) reg |= 1;

        msg[reverseAddress(&reverseAddressIndex)] += 2 * calculateParity(reg & 0xf2d05351L);
        msg[reverseAddress(&reverseAddressIndex)] += 2 * calculateParity(reg & 0xe4613c47L);
    }

    for (int i = 21; i >= 0; i--) {
        reg <<= 1;
        if (M & ((u32) 1 << i)) reg |= 1;
        msg[reverseAddress(&reverseAddressIndex)] += 2 * calculateParity(reg & 0xf2d05351L);
        msg[reverseAddress(&reverseAddressIndex)] += 2 * calculateParity(reg & 0xe4613c47L);
    }

    //pad with 31 zero bits
    for (int i = 30; i >= 0; i--) {

        reg <<= 1;
        msg[reverseAddress(&reverseAddressIndex)] += 2 * calculateParity(reg & 0xf2d05351L);
        msg[reverseAddress(&reverseAddressIndex)] += 2 * calculateParity(reg & 0xe4613c47L);
    }

}

u8 isdigit(u8 val) {

    if (val >= '0' && val <= '9') {
        return 1;
    } else {

        return 0;
    }
}

u8 getCharValue(u8 val) {

    if (isdigit(val)) {
        return val - '0';
    }

    if (val >= 'A' && val <= 'Z') {
        return 10 + val - 'A';
    }

    if (val == ' ') return 36;

    return 0;
}

u8 reverseBits(u8 b) {

    b = (b & 0xF0) >> 4 | (b & 0x0F) << 4;
    b = (b & 0xCC) >> 2 | (b & 0x33) << 2;
    b = (b & 0xAA) >> 1 | (b & 0x55) << 1;

    return b;
}

u8 reverseAddress(u8 *reverseAddressIndex) {

    u8 result = reverseBits(*reverseAddressIndex);
    *reverseAddressIndex = *reverseAddressIndex + 1;

    while (result > 161) {

        result = reverseBits(*reverseAddressIndex);
        *reverseAddressIndex = *reverseAddressIndex + 1;
    }
    return result;
}

s32 calculateParity(u32 x) {
    //generate XOR parity bit (returned as 0 or 1)
    int even = 0;
    while (x) {
        even = 1 - even;
        x = x & (x - 1);
    }
    return even;
}
