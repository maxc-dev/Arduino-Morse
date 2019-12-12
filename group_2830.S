	
	CPU_FREQ = 16000000 ;set cpu frequency
	TICKS_PER_SEC = CPU_FREQ / (256 * 1024) ;set amount of times timer will increase by one in a second

	DECISION_LIMIT = 2 * TICKS_PER_SEC / 10 ; set time between a dot and a dash to be 200ms

#define __SFR_OFFSET 0
#include <avr/io.h> ;make sure avr is used
#include "mappings.S" ;add access to mappings

;Set input button to 1st pin on port b
	BUTTON = 0

;Set LEDs to be 2nd to 7th pin on port d
	LEDA = 7	
	LEDB = 1
	LEDC = 2
	LEDD = 3
	LEDE = 4
	LEDF = 5
	LEDG = 6

;Set timer to be 256*256*3*170 clock ticks (about 2 seconds)
	TIME = 33

;Make sure all important registers are cleared
	clr 22 ;register 22 holds the current button press (dash/dot)
	clr 23 ;register 23 holds the conbined button presses of up to 4 presses
	clr 24 ;register 24 holds the amount of times the current button press needs to be left shifted in order to be correctly conbined with the other button presses
	clr 25 ;register 25 holds the displayed letter
	clr 26 ;register 26 holds the index of the letter in SegmentBits to be displayed
	clr 29 ;resister 29 holds the amount of times the button has been pressed
	clr 30 ;resgister 30 holds the current index of the table
	clr 31 ;register 31 holds the end of the table

	.section .text
	.global main
main:
	
	ldi r16, _BV(LEDA) | _BV(LEDB) | _BV(LEDC) | _BV(LEDD) | _BV(LEDE) | _BV(LEDF) | _BV(LEDG) ;load each pin for the display
	out DDRD, r16 ;make each pin an output
	mov r20, r16 ;move r16 to r20 to make r20 a mask of the pins to be used in exclusive or functions
	
	mov r25, r20 ;make r25 all LEDs on by default
	out PORTD, r25 ;display r25

	sbi PORTB, BUTTON ;Set button to be an input


	clr r16
	sts TCCR1A, r16 ;set timer mode

	ldi r16, _BV(ICIE1) | _BV(TOIE1)
	sts TIMSK1, r16 ;Set input events

	ldi r16,  _BV(ICNC1) | _BV(CS12) | _BV(CS10) ;Set scaler, increment and noise canceller

	sts TCCR1B, r16 ;Make interrupt

	clr r19			

	sei ;start interrupt		

fourE4:	
	clr r1
	clr r2
	ldi r21, TIME ;clear all registers used for timer
	rjmp inner_timer ;run timer constantly
	;; end of setup

	
	.global timer1_ovr_isr  


timer1_ovr_isr:			

	push r16	
	in r16, SREG		
	push r16

	lds r16, TCCR1B
	sbrs r16, ICES1 	
	rjmp awaiting_press

awaiting_release:

	ser r19 		
	rjmp 1f

awaiting_press:
	out PORTD, r25		
	
1:	pop r16
	out SREG, r16 	
	pop r16
	
	reti

	
	.global timer1_cpt_isr

timer1_cpt_isr:

	push r8

	in r8, SREG 		; save the status register.
	push r8

	lds r8, ICR1L		; get the timer count when the capture event happened.
	lds r8, ICR1H           ; we discard the low part, only
				; interested in the high part, but
				; reading low byte is necessary to get
				; a correct high byte in ICR1H, see
				; documentation [ATmega328p] Section 15.11.7 p131 
	push r17				

	;; debounce button:

	mov r17,r19		;  If there is no timer-overflow (ie a
				;  very long button press and
	or r17,r8		;  ICR1H is still zero, then 
				;  less than 16ms have elapsed since
				;  last release or press
	breq debounce		;  and we do nothing

	clr r17
	sts TCNT1H, r17 	; reset timer, first writing the high byte to the latch
	sts TCNT1L, r17		; then the low byte -- Section 16.3 of [328] again.

	;; check whether we were looking for a positive or a negative edge:
	lds r17, TCCR1B
	sbrs  r17, ICES1	; skip next instruction if positive edge dedection.
	
	rjmp pressed		; we have a negative edge ie button
				; has been pressed

	;; positive edge, button has been released
	rcall released

	andi r17, ~(_BV(ICES1)) ; we have had positive edge, so next
				; time looking for negative edge
	rjmp end_isr

	
pressed:
	;clr r1
	;clr, r2
	;ldi r21, TIME
	;; call depressed ; more code to execute, perhaps for the coursework?
	ori r17, _BV(ICES1)	; next time detect positive edge, ie a
				; button release.

end_isr:
	sts TCCR1B, r17 	; write r17 to TCCR1B to activate the
				; change in edge detection.
	
debounce:
	pop r17
	pop r8
	out SREG, r8		; restore status register
	pop r8

	reti

;;; This subroutine handles the detection of a button release (ie the
;;; end of a button press)
;;; It expects the durations of button presses in 16ms ticks in r8

released:

	push r16

	tst r19 		; Did we have a timer overflow
				; (ie more than TIMEOUT time since the
				; last released of the button?
	brne long_press		; if yes, then signal is a long
				; press in any case

	;; is the signal longer than DECISION_LIMIT?
	ldi r16, DECISION_LIMIT
	cp r8,r16
	brcs short_press		; if it is shorter jump to label short
	
long_press:
	ldi r22, 0b00000011 ;If dash is done, load 3 into r22

	rjmp 1f

short_press:
	ldi r22, 0b00000001 ;If dot is done, load 1 into r22
	
1:	
	clr r1
	clr r2
	ldi r21, TIME ;reset r1, r2 and r21 to make the timer reset 

	add r24, r29
	add r24, r29 ;multiply r29 by 2 and load it into r24

	tst r29	    ;check to see if r29 is 0
	brne leftshift ;if r29 is not 0 then branch to leftshift the bits in r22

	inc r29 ; increase r29 to show the amount of times the button has been pressed

	or r23, r22 ;combine r22 with r23 to make r23 hold the content of upto the first 4 clicks

	pop r16 ;restore r16
	clr r19 ; clear r19
	ret ;return from interrupt

leftshift:
	lsl r22 ;do a logical left shift on r22

	dec r24 ;decrease r24 by one

	tst r24 ; check if r24 is 0
	brne leftshift ;if r24 is not 0 then keep looping leftshift until it is

	inc r29	; increase r29 to show the amount of button presses

	or r23, r22 ; combine r22 and r23

	pop r16 ;restore r16
	clr r19 ;clear r19
	ret ;return from interrupt

end_timer:
	cpi r29, 4
	brsh error_display ;if more than 4 presses have been done then go to 
			   ;error_display as there is no morse code that is larger than 4 presses
	push r30 
	push r31 ;push the pointers of the last table used

	ldi r30, lo8(ButtonBits)
	ldi r31, hi8(ButtonBits) ;load  the pointers of ButtonsBits table
	rjmp loop_bytes ;jump to loop_bytes

loop_bytes:
	cpi r23, 0
	breq actual_end ;if r23 holds no presses then dont update the display
	lpm r28, Z+ ;get the content of ButtonBits at index Z into r28 and then add 1 to Z 

	cp r28, r23 ;compare r28 to the button presses
	breq display_letter ;if the content of the table index is equal to the button presses then branch to display_letter

	inc r26 ;increase r26 to show the current index that is being looked at

	cpi r26, 26 ;check if we are at the end of the list 

	brne loop_bytes ;if not then keep looping along the list
	rjmp error_display ;jump to error code since no letters matched

display_letter:
	ldi r30, lo8(SegmentBits) 
	ldi r31, hi8(SegmentBits) ;load pointers of SegmentBits table
	add r30, r26 ;change current index to index held in r26
	lpm r25, Z ;load current index into r25
	eor r25, r20 ;do an exlusive or to reverse the bits so they show properly on the display
	pop r30 
	pop r31 ;restore old table pointers
	rjmp actual_end

error_display:
	ldi r25, 0b10111110 ;binary value to dislay error symbol

actual_end:
	;clr r28 
	clr r23 ;clear register holding button presses
	clr r26 ;clear register holding current bale index
	clr r24 ;clear register that holds amount of times the button press needs to be shifted left
	clr r29 ;clear amount of times the button has been pressed
	;clr r22 
	out PORTD, r25
	ldi r21, TIME ;reset timer

outer_timer:
	clr r1
middle_timer:
	clr r2
inner_timer:
	dec r2
	brne inner_timer ;keep decreasing r2 until 0

	dec r1 ;keep decreasing r1 until 0
	brne middle_timer

	dec r21 ;keep decreasing r21 until xero
	brne outer_timer

	rjmp end_timer ;jump to end_timer





	
	
