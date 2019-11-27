;;;  timing.s 21/11/12 (A.Gruning)J.Y.Clark. C. Cheong
;;;  This lab material and corresponding solutions are 
;;;  released under the Creative Commons Share-Alike 
;;;  Non-Commercial Licence at 
;;;  http://creativecommons.org/licenses/by-nc-sa/3.0/
;;;  (C) Andre Gruning, 2011. Developed for COM1031 in 2011.
;;;  (C) Jonathan Clark. 2012. Adapted for COM1031 in 2012.
;;;  (C) Clive Cheong. 2013. Adapted for COM1031 in 2013.
;;;	REFERENCES:
;;;	[ATmega]: General 8-bit Atmel Microcontroller document 
;;;  
;;;  [ATmega328p]: Specific ATmega328p document (quite large!)
;;;  downloadable from
;;;  www.atmel.com/Images/doc7810.pdf
;;;  [AVR]: Instruction Set Manual
;;;  downloadable from
;;;  www.atmel.com/Images/doc0856.pdf
;;;


;;; To understand the code read the ATmega328p technical documentation
;;; [328] in conjunction with the instruction manual [AVR]
;;;
;;; Basis of timing:
;;; First of all the timer prescaler is set to 1024, ie one timer tick
;;; is 1024 CPU clock ticks. Then we only look at the high byte of the
;;; 16 bit timer1, which is the basis for all timing. One tick at the
;;; high byte is 1024*256 CPU clock ticks. With a CPU clock of 16MHz,
;;; ie 16,000,000 CPU clock ticks per second, this means one tick in
;;; the high byte of timer1 corresponds to 256*1024 / 16.000.000 Hz =
;;; 16ms. So 16ms is the basis of all our timings, about 61 ticks per second:

	CPU_FREQ = 16000000
	TICKS_PER_SEC = CPU_FREQ / (256 * 1024)

	DECISION_LIMIT = 3 * TICKS_PER_SEC / 10 ; 300ms
	
;;; Timer1 capture interrupt is used to record the length of button
;;; presses and button releases. 
;;;
;;; Global register use:
;;; r19: used as a flag that indicates whether the timer has overrun its
;;; max value while a button has been held pressed.
	
;;; include all port definitions
#define __SFR_OFFSET 0
#include <avr/io.h> 				

;;; Button is connected to PIN 8, PORTB, Bit 0, because that doubles as the ICP1 for timer1.
	BUTTON = 0
;;; LEDs on display connected to these bits of PORTD:
	LEDA = 7	
	LEDB = 1
	LEDC = 2
	LEDD = 3
	LEDE = 4
	LEDF = 5
	LEDG = 6

;;; this is the entry point to the user code, called from init.S. We
;;; do the setup of ports, timer and interrupts, then we go to an
;;; eternal loop because all the work is done in the interrupt service
;;; routines. 

	.section .text
	.global main
main:	
	;; make these pins output:
	ldi r16, _BV(LEDA) | _BV(LEDB) | _BV(LEDC) | _BV(LEDD) | _BV(LEDE) | _BV(LEDF) | _BV(LEDG)
	out DDRD, r16
	mov r20, r16		; store mask for later use
	out PORTD, r20 		; turn LEDs off as 1 = off
	
	;; setup for the button, DDRB0 is automatically an input.
	sbi PORTB, BUTTON 	; switch on the pull-up. Released
				; button is 1, depressed button read as 0.

	;; set up the timer ([ATmega328p], Section 15.11.1 (p126))

	clr r16
	sts TCCR1A, r16 	; setting timer output mode: no output
				; pin used, normal counting up. 

	;; enable input capture interrupt (to time button presses) and
	;; timer overflow interrupt (the time-out to switch on the
	;; yellow LED:
	ldi r16, _BV(ICIE1) | _BV(TOIE1)
	sts TIMSK1, r16

	;; enable noise canceller, set prescaler to 1024, and start
	;; timer in normal mode, [ATmega328p] section 12.11.2 (p128).
	ldi r16,  _BV(ICNC1) | _BV(CS12) | _BV(CS10)
	sts TCCR1B, r16

	clr r19			; reset overflow flag to defined state

	sei			; enable interrupts globally.

fourE4:	rjmp fourE4 		; do nothing :-) just wait for the
				; interrupts to occur -- forever.
	;; end of setup

;;; This interrupt service routine is currently called whenever timer1 has
;;; an overflow, ie when more than 4s have elapses since the last button release. 
	
	.global timer1_ovr_isr  ; export symbol to overwrite weak
				; definition in init.S

;;; This is the start of the interrupt service routine:
timer1_ovr_isr:			

	push r16	
	in r16, SREG		; save the status register.
	push r16

	;; check whether we are waiting for a button press or release:
	lds r16, TCCR1B
	sbrs r16, ICES1 	; skip if waiting for positive edge (ie for button release)
	rjmp awaiting_press

awaiting_release:
	;;  make sure also an overly long press is always recognised
	;;  as a long press, irrespective of a timer overrun:

	ser r19 		; using r19 as a flag to indicate a
				; timer overflow has occured.
	rjmp 1f

awaiting_press:	
	;; if we are waiting for a button press, then more time than
	;; 4s has elasped since the last release -- in this case
	;; we switch the yellow led on and the others off.
		 
	out PORTD, r20		
	
1:	pop r16
	out SREG, r16 		; restore status register
	pop r16
	
	reti


;;; This interrupt service routine times the duration of button
;;; presses. It is also involved in timing button releases as it
;;; always resets timer1 when called.
;;; It is called whenever the signal at ICP1 (PORTB0) changes in a
;;; certain direction. If we are called for a negative edge (button
;;; has just been depressed), we go on waiting for a positive edge
;;; (button will be released) and vice-versa.
	
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
	ldi r16, _BV(LEDG) | _BV(LEDF) ; bit pattern for red LED and
	eor r16, r20				; pull-up for button on.
	rjmp 1f

short_press:

	ldi r16, _BV(LEDA) | _BV(LEDB) ; bit pattern for green an
	eor r16, r20
	
1:	out PORTD, r16		; transfer bitpattern into PORTD (ie
				; do switch the LEDs).
	
	pop r16
	clr r19			; clear overflow flag in case it was set
	ret

