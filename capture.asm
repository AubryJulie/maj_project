; *********************************************************** ;
;                           CAPTURE                           ;
;             make a LED blink using capture event            ;
;                                                             ;
;                                                             ;
; *********************************************************** ;

	processor	18F25K80
	#include	"config18.inc"

; That is where the MCU will start executing the program (0x00)
	org 	0x00
	nop
	goto    start		    ; jump to the beginning of the code
	
; That is where the MCU will start executing the low interrupt (0x08)
	org 	0x18
	nop
	goto    low_interrupt_routine   ; jump to the low interrupt routine

;BEGINNING OF THE PROGRAM
start:
	call	initialisation      ; initialisation routine configuring the MCU
	goto	main_loop           ; main loop

;INITIALISATION
initialisation:

	; Configure Pin
	
	; Configure Port C 
	;configure CCP pin
	;RC2/CCP2, RC6/CCP3 and RC7/CCP4 (pin 13, 17, 18)
	;!!!TRISC initiate to 11111111 at the start
    ;movlb 0x0F
    ;movlw b'11111111' 
	;movwf TRISC		    ; All pins of PORTC are input
	
	; Configure Port D
	movlb   0x0F
	clrf    TRISB               ; All pins of PORTD are output
	movlb   0x0F
	movlw   b'00000111'
	movwf   LATB                ; RB0, RB1, RB2 = 1 while RB3..7 = 0 (pin 21, 22, 23)

    ; Configuration of clock - 8MHz - 
	movlb	0x0F
	movlw	b'01101010'
	movwf	OSCCON		    ; configure oscillator (cf datasheet SFR OSCCON)
	
    ; Configuration of Timer1 - 1MHz -
	movlb	0x0F
	movlw	b'00010000'
	movwf	T1CON		; configure Timer1 (cf. datasheet SFR T1CON)
	
	; Configure CCP 2, 3 and 4
	;!!when changing capture mode: CCPxIE and CCPxIF bits should be clear to avoid false interrupts
	movlb	0x0F
	movlw	b'00000101'
	movwf	CCP2CON		;Capture mode: every rising edge
	movlw	b'00000101'
	movwf	CCP3CON		;Capture mode: every rising edge
	movlw	b'00000101'
	movwf	CCP4CON		;Capture mode: every rising edge
	movlw	b'00000000'
	movwf	CCPTMRS		;CCP 2, 3 and 4 is based off of TMR1 !!!! look for the PWM to not disturbe
	
    ; Interrupt configuration
	movlb	0x0F
	bsf	PIE3,2	;CCP2 interrupt enable  
	bsf	PIE4,0	;CCP3 interrupt enable
	bsf	PIE4,1	;CCP4 interrupt enable
	bsf	INTCON,	GIE	; enable global interrupts
	bsf	INTCON,	6	; enable peripheral interrupts
	
    ; Start Timer 1 
	movlb	0x0F
	movlw	0x00
	movwf	TMR1H
	movlw	0x00
	movwf	TMR1L
	bsf	T1CON, TMR1ON
	
	return
; Low_interrupt routine
low_interrupt_routine:
	movlb	0x0F
	btfss	PIR3, CCP2IF	; Test CCP2 interrupt flag
	goto	end_if_CCP2
	
	bcf	PIR3, CCP2IF
	movlw   0x01
	xorwf   LATB, 1	; RB0 = !RB0
	
end_if_CCP2:
	movlb	0x0F
	btfss	PIR4, CCP3IF	; Test CCP3 interrupt flag
	goto	end_if_CCP3
	
	bcf	PIR4, CCP3IF
	movlw   0x02
	xorwf   LATB, 1	; RB1 = !RB1
end_if_CCP3:	
	movlb	0x0F
	btfss	PIR4, CCP4IF	; Test CCP4 interrupt flag
	goto	end_if_CCP4
	
	bcf	PIR4, CCP4IF
	movlw   0x04
	xorwf   LATB, 1	; RB2 = !RB2

end_if_CCP4:
		retfie
		
;MAIN LOOP
main_loop:
    nop
    goto    main_loop
    END