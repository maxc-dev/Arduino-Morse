;;;  delay_cs.S 02/12/12 (A.Gruning)J.Y.Clark, C. Cheong
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
;;;  
;;;  [ATmega328p]: Specific ATmega328p document (quite large!)
;;;  downloadable from
;;;  www.atmel.com/Images/doc7810.pdf
;;;  [AVR]: Instruction Set Manual
;;;  downloadable from
;;;  www.atmel.com/Images/doc0856.pdf
;;;

;;; The subroutine in delay_cs.S is similar to delay.S from previous
;;; labs. While delay.S delays for a number of seconds (in r24),
;;; delay_cs.S delays for a number of 1/100 seconds (or centiseconds
;;; [cs]) stored in r24.

;;; In order for the c compiler to be able to call this assembler
;;; subroutine, we have to follow the c compilers calling convenction
;;; which is that is always places the first argument of a function
;;; call in c into the r24 register.
;;;
;;; We want to delay in chunks of 1/100ms, so -- with 16MHz CPU
;;; frequency -- we need to burn 160000 clock ticks times the value of r24.
	
	;.section .text
	;.global delay_cs
delay_cs:

	push r0
	push r17
	push r24
	
	clr r0
2:	ldi r17, 156
	
1:	dec r0			; 1 tick
	nop			; 1 tick
	brne 1b			; 2 ticks

	dec r17			; 1 tick + 255*4 + 3 = 256*4 ticks = 1024 ticks
	brne 1b			

	dec r24			; 1024*156 = 159744 ticks approx 10ms
	brne 2b			; and now jump back for the number of
				; ms in r24.
	pop r24
	pop r17
	pop r0
	ret