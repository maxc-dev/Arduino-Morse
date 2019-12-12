#define __SFR_OFFSET 0
#include <avr/io.h>
#include "mappings.S"
#include "delay_cs.S"


;Timings in centiseconds
DOT = 10
DASH = 30
SIGNAL_GAP = 10
LETTER_GAP = 30

;Set output bit
OUTPUT = 5

;r16 = current morse byte, r17 = counter, r18 = bit pair to look at, r19 = AND mask, r20 = counter for table, r24 = delay in cs, to be passed to delay_cs
    .section .text
	.global main
main:
    ;Enable output
    ldi r16, _BV(OUTPUT)
    out DDRB, r16
    clr r16
    ;Load table pointers
    ldi r30, lo8(ButtonBits)
    ldi r31, hi8(ButtonBits)
    ;Set AND mask
    ldi r19, 0b00000011
    ;Make sure table counter is cleared (used to check when we have run out of letters)
    clr r20

;Start loop
loadbyte:
    lpm r16, Z+ ;Load value from table and increment pointer
    ldi r17, 0 ;initial counter value, 1-indexed so that r17=0 can be used to detect the end of a letter   

loop:
    mov r18, r16 ;load fresh byte for testing
    cpi r17, 0 ;skip shifting if on first bit pair
    breq skipshift
    push r17 ;save counter
    add r17, r17 ;double counter as we want to rightshift by counter * 2
rightshift:
	lsr r18 ;Shift r18 right
	dec r17 ;Decrement counter
	tst r17 ;Check if counter 0
	brne rightshift ;loop until shifting finished
    pop r17 ;restore counter

skipshift:
    and r18, r19 ;should now have 000000XX
    cpi r18, 0b00000001 ;check for dot
    breq dot
    cpi r18, 0b00000011 ;check for dash
    breq dash
    rjmp end ;skip output if pair is 00

dot:
    sbi PORTB, OUTPUT ;turn on output
    ldi r24, DOT ;delay for DOT centiseconds
    rcall delay_cs
    rjmp end

dash:
    sbi PORTB, OUTPUT ;turn on output
    ldi r24, DASH ;delay for DASH centiseconds
    rcall delay_cs
    rjmp end

end:
    cbi PORTB, OUTPUT ;turn output back off
    inc r17 ;increment counter
    cpi r17, 4 ;If counter 4, letter is over
    breq end_letter
    ldi r24, SIGNAL_GAP ;delay for SIGNAL_GAP centiseconds
    rcall delay_cs
    rjmp loop ;Go back to output next signal

end_letter:
    ldi r24, LETTER_GAP ;delay for LETTER_GAP centiseconds
    rcall delay_cs
    inc r20 ;increment table counter
    cpi r20, 26 ;Check if we have run out of letters
    breq end_table
    rjmp loadbyte ;Go back to load next letter for output

end_table:
    ldi r30, lo8(ButtonBits) ;Reset table pointers
    ldi r31, hi8(ButtonBits)
    clr r20 ;Clear table counter
    rjmp loadbyte ;Go back to load next letter for output