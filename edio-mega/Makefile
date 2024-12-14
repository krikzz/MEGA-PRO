GCC= e:/devtools/m68k-3.4.6/
CC= $(GCC)bin/gcc
OBJC= $(GCC)bin/objcopy
ASMZ80= $(GCC)bin/asmz80
BINTOC= $(GCC)bin/bintoc
OUTPUT= edio-mega
LIB=$(GCC)lib
BIN= $(GCC)bin


MAKEFLAGS= -j8

BDIR		:=build
FLAGS		:= $(OPTION) -m68000 -Wall -O3 -fomit-frame-pointer $(INCS)
FLAGSZ80	:= -c -i -x1 -x2 -x3 -z -lnul

vpath %.o $(BDIR)/

SRC_S = sega.s
SRC_C = $(wildcard *.c)

OBJ = $(SRC_S:.s=.o)
OBJ += $(SRC_C:.c=.o)
OFILES = $(OBJ:%.o=$(BDIR)/%.o)


all: $(OBJ)
	$(CC) -B$(BIN) -T rom.ld -nostdlib $(OFILES) $(LIB)/libgcc.a -o $(BDIR)/$(OUTPUT).elf 
	$(OBJC) --pad-to 0x8000 -O binary $(BDIR)/$(OUTPUT).elf $(OUTPUT).md


%.o: %.c
	$(CC) $(FLAGS) -c $< -o $(basename $(BDIR)/$<).o

%.o: %.s
	$(CC) $(FLAGS) -c $< -o $(basename $(BDIR)/$<).o

clean:
	$(RM) $(BDIR)/*.o
	$(RM) $(BDIR)/*.elf


