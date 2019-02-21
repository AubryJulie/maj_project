; *********************************************************** ;
;                           DELAY                             ;
;                     compute the delay                       ;
;                                                             ;
;                                                             ;
; *********************************************************** ;

;!!!protocole de test!!!
;!!!1 delay >x led allumée sinon éteinte!!!
;!!!2 timer2H = delayH timer2L = delayL éteindre/allumer qd overflow!!!
	processor	18F25K80
	#include	"config18.inc"
	
; Set the first variable address in the RAM to 0x00
	cblock	0x00
	endc

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

   ; Declare usefull variables begining at the first GPR  adress of bank0 in ram
	movlb	0x00
	cblock	00h
	time1aL
	time1aH
	time2aL
	time2aH
	time3aL
	time3aH
	time1bL
	time1bH
	time2bL
	time2bH
	time3bL
	time3bH
	delay12L
	delay12H
	delay23L
	delay23H
	delay31L
	delay31H
	controller_uses_b
	_1before2
	_2before3
	_3before1
	enable1a
	enable2a
	enable3a
	enable1b
	enable2b
	enable3b
	timexH
	timexL
	timeyH
	timeyL
	xbeforey
	delayxyL
	delayxyH
	endc
	
	;set all the variables to 0
	movlw	0x00
	movwf	time1aL
	movwf	time1aH
	movwf	time2aL
	movwf	time2aH
	movwf	time3aL
	movwf	time3aH
	movwf	time1bL
	movwf	time1bH
	movwf	time2bL
	movwf	time2bH
	movwf	time3bL
	movwf	time3bH
	movwf	controller_uses_b
	movwf	_1before2
	movwf	_2before3
	movwf	_3before1
	movwf	enable1a
	movwf	enable2a
	movwf	enable3a
	movwf	enable1b
	movwf	enable2b
	movwf	enable3b
	movwf	timexH
	movwf	timexL
	movwf	timeyH
	movwf	timeyL
	movwf	xbeforey
	

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

    ; Configuration of clock - 4MHz - 
	movlb	0x0F
	movlw	b'01011010'
	movwf	OSCCON		    ; configure oscillator (cf datasheet SFR OSCCON)
	
    ; Configuration of Timer1 - 1MHz -
	movlb	0x0F
	movlw	b'00000000'
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
	
	movlb	0x00
	btfss	controller_uses_b, 0
	goto	controller_uses_a1
	
	movlb	0x0F
	movlw	CCPR2L
	movlb	0x00
	movwf	time1aL
	movlb	0x0F
	movlw	CCPR2H
	movlb	0x00
	movwf	time1aH
	movlw   0x01
	movwf	enable1a
	
controller_uses_a1:
	movlb	0x0F
	movlw	CCPR2L
	movlb	0x00
	movwf	time1bL
	movlb	0x0F
	movlw	CCPR2H
	movlb	0x00
	movwf	time1bH
	movlw   0x01
	movwf	enable1b
	
end_if_CCP2:
	movlb	0x0F
	btfss	PIR4, CCP3IF	; Test CCP3 interrupt flag
	goto	end_if_CCP3
	
	bcf	PIR4, CCP3IF
	movlw   0x02
	xorwf   LATB, 1	; RB1 = !RB1
	
	movlb	0x00
	btfss	controller_uses_b, 0
	goto	controller_uses_a2
	
	movlb	0x0F
	movlw	CCPR3L
	movlb	0x00
	movwf	time2aL
	movlb	0x0F
	movlw	CCPR3H
	movlb	0x00
	movwf	time2aH
	movlw   0x01
	movwf	enable2a
	
controller_uses_a2:
	movlb	0x0F
	movlw	CCPR3L
	movlb	0x00
	movwf	time2bL
	movlb	0x0F
	movlw	CCPR3H
	movlb	0x00
	movwf	time2bH
	movlw   0x01
	movwf	enable2b
	
end_if_CCP3:	
	movlb	0x0F
	btfss	PIR4, CCP4IF	; Test CCP4 interrupt flag
	goto	end_if_CCP4
	
	bcf	PIR4, CCP4IF
	movlw   0x04
	xorwf   LATB, 1	; RB2 = !RB2

	movlb	0x00
	btfss	controller_uses_b, 0
	goto	controller_uses_a3
	
	movlb	0x0F
	movlw	CCPR4L
	movlb	0x00
	movwf	time3aL
	movlb	0x0F
	movlw	CCPR4H
	movlb	0x00
	movwf	time3aH
	movlw   0x01
	movwf	enable3a
	
controller_uses_a3:
	movlb	0x0F
	movlw	CCPR4L
	movlb	0x00
	movwf	time3bL
	movlb	0x0F
	movlw	CCPR4H
	movlb	0x00
	movwf	time3bH
	movlw   0x01
	movwf	enable3b
	
end_if_CCP4:
		retfie
		
;MAIN LOOP
main_loop:
    nop
    goto    main_loop
    END

delay_compute:

	movlb	0x00
	movlw	timeyH		
	CPFSGT	timexH		;if timexH > timeyH skip
	goto	timexH<=timeyH	
	ADDLW	0x03		;w = timeyH + 768	
	CPFSLT	timexH		;if timexH < 768 + timeyH skip
	goto	overflow_in_delay
	movlw	timeyH
	SUBFW	timexH,0	;w = timexH - timeyH
	movwf	delayxyH	;delayxyH = timexH - timeyH
	movlw	timeyL		
	CPFSLT	timexL		;if timexL < timeyL skip
	goto	timexL>=timeyL
	DECF	delayxyH, 1	;delayxyH-1
	movlw	timeyL
	SUBLW	0xFF		;FF-timeyL
	ADDLW	0x01
	ADDWF	timexL,0	;w = FF - timeyL + 1 + timexL
	movwf	delayxyL	;delayxyL = w
	movlw	0x00
	movwf	xbeforey	;micy capture before micx
	goto	end_delay_compute

timexL>=timeyL:

	movlw	timeyL
	SUBWF	timexL, 0	;w = timexL - timeyL
	movwf	delayxyL	;delayxyL = timexL - timeyL
	movlw	0x00
	movwf	xbeforey	;micy capture before micx
	goto	end_delay_compute
	
overflow_in_delay:

	movlw	timexH
	SUBLW	0xFF		;FF-timeyL
	ADDLW	0x01
	ADDWF	timeyH, 0	;w = FF - timexH + 1 + timeyH
	movwf	delayxyH	;delayxyH = w
	movlw	timeyL		
	CPFSGT	timexL		;if timexL > timeyL skip
	goto	timeyL>=timexL
	DECF	delayxyH, 1	;delayxyH-1
	movlw	timexL
	SUBLW	0xFF		;FF-timeyL
	ADDLW	0x01
	ADDWF	timeyL, 0	;w = FF - timexL + 1 + timeyL
	movwf	delayxyL	;delayxyL = w
	movlw	0x01
	movwf	xbeforey	;micy capture before micx
	goto	end_delay_compute
	
timeyL>=timexL:

	movlw	timexL
	SUBWF	timeyL, 0	;w = timeyL - timexL
	movlw	0x01
	movwf	xbeforey	;micy capture before micx
	goto	end_delay_compute
	
timexH<=timeyH:

	movlw	timeyH		
	CPFSLT	timexH		;if timexH < timeyH skip
	goto	timexH=timeyH
	!!
	movlw	timexH
	ADDLW	0x03		;w = timexH + 768	
	CPFSLT	timeyH		;if timeyH < 768 + timexH skip
	goto	overflow_in_delay
	movlw	timexH
	SUBFW	timeyH,0	;w = timeyH - timexH
	movwf	delayxyH	;delayxyH = timeyH - timexH
	movlw	timeyL		
	CPFSLT	timexL		;if timexL < timeyL skip
	goto	timexL>=timeyL
	DECF	delayxyH, 1	;delayxyH-1
	movlw	timeyL
	SUBLW	0xFF		;FF-timeyL
	ADDLW	0x01
	ADDWF	timexL,0	;w = FF - timeyL + 1 + timexL
	movwf	delayxyL	;delayxyL = w
	movlw	0x00
	movwf	xbeforey	;micy capture before micx
	goto	end_delay_compute
end_delay_compute:
