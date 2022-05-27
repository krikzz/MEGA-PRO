

#include "main.h"



int main() {

    sysInit();
    gSetColor(0x00, 0x000);
    gSetColor(0x0f, 0xfff);

    bi_fifo_flush();
    wsprMenu();

    return 0;
}


