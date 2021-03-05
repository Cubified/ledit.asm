all: ledit

ASM=nasm
STRIP=strip

NASMFLAGS=
DEBUG_NASMFLAGS=-g -F dwarf

ASM_INPUT=ledit.asm
ASM_OBJ=ledit.asm.o

RM=/bin/rm
CP=/bin/cp

.PHONY: ledit
ledit:
	$(ASM) -f elf64 $(ASM_INPUT) -o $(ASM_OBJ) $(NASMFLAGS)
	$(STRIP) -g --strip-unneeded -K ledit $(ASM_OBJ)

demo:
	$(MAKE)
	cc demo.c $(ASM_OBJ) -o demo -static

debug:
	$(ASM) -f elf64 $(ASM_INPUT) -o $(ASM_OBJ) $(DEBUG_NASMFLAGS)

clean:
	if [ -e "$(ASM_OBJ)" ] || [ -e "demo" ]; then $(RM) -f $(ASM_OBJ) demo; fi
