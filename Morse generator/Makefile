# Version: $Id: Makefile 1015 2011-12-07 22:57:05Z ag0015 $

PRG = morse_gen
OBJ = $(PRG).o init.o delay_cs.o 

MCU_TARGET = atmega328p
OPTIMIZE = -Os
#OPTIMIZE = -O2

DEFS =
LIBS =

CC = avr-gcc
AS = avr-gcc

CFLAGS = -g -Wall $(OPTIMIZE) -mmcu=$(MCU_TARGET) $(DEFS)
LDFLAGS = -g -Wall $(OPTIMIZE) -mmcu=$(MCU_TARGET) -nostdlib $(DEFS)
AFLAGS = -g -Wall -mmcu=$(MCU_TARGET) $(DEFS) -c

OBJCOPY = avr-objcopy
OBJDUMP = avr-objdump

all: hex ehex

# compiling is done by an implicit rule.

# assembling:

%.o: %.S
	$(AS) $(AFLAGS) -o $@ $< 

#linking:
$(PRG).elf: $(OBJ)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^ $(LIBS)

# dependency:
#test.o: test.c iocompat.h

clean:
	rm -rf *.o $(PRG).elf 
	rm -rf *.lst *.map $(EXTRA_CLEAN_FILES)

lst: $(PRG).lst

%.lst: %.elf
	$(OBJDUMP) -h -S $< > $@

# Rules for building the .text rom images
hex: $(PRG).hex

%.hex: %.elf
	$(OBJCOPY) -j .text -O ihex $< $@
#	$(OBJCOPY) -j .text -j .data -O ihex $< $@


bin: $(PRG).bin

%.bin: %.elf
	$(OBJCOPY) -j .text -O bin $< $@
#	$(OBJCOPY) -j .text -j .data -O ihex $< $@


# Rules for building the .eeprom rom images
ehex: $(PRG)_eeprom.hex

%_eeprom.hex: %.elf
	$(OBJCOPY) -j .eeprom --change-section-lma .eeprom=0 -O ihex $< $@ || { echo empty $@ not generated; exit 0; }

# Rules for Uploading to the Arduino board:
upload: all
	avrdude -p m328p -c arduino -P /dev/ttyACM0 -Uflash:w:$(PRG).hex