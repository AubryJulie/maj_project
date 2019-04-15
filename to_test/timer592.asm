; *********************************************************** ;
;                           Timer                             ;
;                  interrupt every 592 µs                     ;
;                                                             ;
;                                                             ;
; *********************************************************** ;
;utiliser b2: allumer/éteindre après un overflow 
	processor	18F25K80
	#include	"config18.inc"

; define constant
W EQU 0
F EQU 1
TIMER3L EQU 0x6F
TIMER3H EQU 0xFF
; Set the first variable address in the RAM to 0x00
	cblock	0x00
	endc

; That is where the MCU will start executing the program (0x00)
	org 	0x00
	nop
	goto    start		    ; jump to the beginning of the code
	
; That is where the MCU will start executing the low interrupt (0x08)
	org 	0x08
	nop
	goto    low_interrupt_routine   ; jump to the low interrupt routine

;BEGINNING OF THE PROGRAM
start:
	call	initialisation      ; initialisation routine configuring the MCU
	goto	main_loop           ; main loop

;INITIALISATION
initialisation:

   ; Declare usefull variables begining at the first GPR  adress of bank1 in ram
	movlb	0x01
	endc
	
	;set all the variables to 0
	movlw	0x00
	

	; Configure Pin
	
	; Configure Port C 
	;configure CCP pin
	;RC2/CCP2, RC6/CCP3 and RC7/CCP4 (pin 13, 17, 18)
	;!!!TRISC initiate to 11111111 at the start
    ;movlb 0x0F
    ;movlw b'11111111' 
	;movwf TRISC		    ; All pins of PORTC are input
	
	; Configure Port B
	movlb   0x0F
	clrf    TRISB               ; All pins of PORTB are output
	movlb   0x0F
	movlw   b'00000000'
	movwf   LATB                ;while RB0..7 = 0

    ; Configuration of clock - 8MHz - 
	movlb	0x0F
	movlw	b'01101010'
	movwf	OSCCON		    ; configure oscillator (cf datasheet SFR OSCCON)

	; Configuration of Timer3 - 250khz - 4µs to create an overflow interrupt every - 589~592µs
	movlb	0x0F
	movlw	b'00110000'
	movwf	T3CON		; configure Timer3 (cf. datasheet SFR T3CON)
		
    ; Interrupt configuration
	movlb	0x0F
	bsf	PIE2,1	;Timer3 overflow interrupt enable
	bsf	INTCON,	GIE	; enable global interrupts
	bsf	INTCON,	6	; enable peripheral interrupts
	
	; Start Timer 3 
	movlb	0x0F
	movlw	TIMER3H
	movwf	TMR3H
	movlw	TIMER3L
	movwf	TMR3L
	bsf	T3CON, TMR3ON
	
	return
; Low_interrupt routine
low_interrupt_routine:

	movlb	0x0F
	btfss	PIR2, 1	; Test timer3 overflow interrupt flag
	goto	end_if_timer3
	
	bcf	PIR2, 1
	
	; blink b2
	movlw	b'00000100'
	xorwf	LATB, F 	; b2 = !b2
	; Restart Timer 3 
	bcf 	T3CON, TMR3ON
	movlw	TIMER3H
	movwf	TMR3H
	movlw	TIMER3L
	movwf	TMR3L
	bsf 	T3CON, TMR3ON

end_if_timer3:	

	retfie
		
;MAIN LOOP
main_loop:
	nop
    goto    main_loop
    END 
