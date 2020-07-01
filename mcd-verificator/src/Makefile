GDK= e:/devtools/m68k-3.4.6/
CC= $(GDK)bin/gcc
OBJC= $(GDK)bin/objcopy
ASMZ80= $(GDK)bin/asmz80
BINTOC= $(GDK)bin/bintoc
NM= $(GDK)bin/nm
OUTPUT= mcd-verificator
RESOL=bin
LIB=$(GDK)lib
BIN= $(GDK)bin


#MAKEFLAGS= -j8

SRC_S = sega.s kos.s
SRC_C = $(wildcard *.c)

OBJ = $(SRC_S:.s=.o)
OBJ += $(SRC_C:.c=.o)

LINKOBJ= $(OBJ)

SRC_S_MCD = sub_app.s
OBJ_MCD = $(SRC_S_MCD:.s=.o)
LINKOBJ_MCD= $(OBJ_MCD)

SRC_S_BIOS = sub_bios.s
OBJ_BIOS = $(SRC_S_BIOS:.s=.o)
LINKOBJ_BIOS= $(OBJ_BIOS)

FLAGS= $(OPTION) -m68000 -Wall -O3 -fomit-frame-pointer $(INCS) -Wno-unused-variable
FLAGSZ80= -c -i -x1 -x2 -x3 -z -lnul

all: sub_bios sub_app main_app
	
main_app: $(OBJ)
	$(CC) -B$(BIN) -T rom.ld -nostdlib $(LINKOBJ) $(LIB)/libgcc.a -o $(OUTPUT).elf
	$(OBJC) --pad-to 0x20000 -O binary $(OUTPUT).elf $(OUTPUT).$(RESOL)
	
sub_app: $(OBJ_MCD)
	$(CC) -B$(BIN) -T sub_app.ld -nostdlib $(LINKOBJ_MCD) -o sub_app.elf
	$(OBJC) --pad-to 0x8000 -O binary sub_app.elf sub_app.bin

sub_bios: $(OBJ_BIOS)
	$(CC) -B$(BIN) -T sub_bios.ld -nostdlib $(LINKOBJ_BIOS) -o sub_bios.elf
	$(OBJC) --pad-to 0x8000 -O binary sub_bios.elf sub_bios.bin

%.o: %.c
	$(CC) $(FLAGS) -c $< -o $@

%.o: %.s
	$(CC) $(FLAGS) -c $< -o $@

clean:
	$(RM) *.o
	$(RM) *.elf


