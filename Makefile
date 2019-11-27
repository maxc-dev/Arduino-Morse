# Version: $Id: Makefile 971 2011-11-22 23:34:05Z ag0015 $

PRG = morse
OBJ = $(PRG).o init.o

MCU_TARGET = atmega328p
#MCU_TARGET = atmega329
#OPTIMIZE = -Os
OPTIMIZE = -O0

DEFS =
LIBS =

CC = avr-gcc
AS = avr-gcc

# Override is only needed by avr-lib build system.
#override CFLAGS = -g -Wall $(OPTIMIZE) -mmcu=$(MCU_TARGET) $(DEFS)
#override LDFLAGS = = -g -Wall $(OPTIMIZE) -mmcu=$(MCU_TARGET) $(DEFS)

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

# Rules for building the .eeprom rom images
ehex: $(PRG)_eeprom.hex

%_eeprom.hex: %.elf
	$(OBJCOPY) -j .eeprom --change-section-lma .eeprom=0 -O ihex $< $@ || { echo empty $@ not generated; exit 0; }

# Rules for Uploading to the Arduino board:
upload: all
	avrdude -p m328p -c arduino -P /dev/ttyACM0 -Uflash:w:$(PRG).hex