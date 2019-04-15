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

   ; Declare usefull variables begining at the first GPR  adress of bank1 in ram
	movlb	0x01
	cblock	00h
	time1L
	time1H
	time2L
	time2H
	time3L
	time3H
	delay12
	delay23
	delay31
	config_delay ;bit0 = _1before2, bit1 = _2before3, bit2 = _3before1,
				 ;bit3 = enable1, bit4 = enable2, bit5 = enable3, bit6
				 ; = xbeforey
	timexH
	timexL
	timeyL
	timeyH
	delayxy
	endc
	
	;set all the variables to 0
	movlw	0x00
	movwf	time1L
	movwf	time1H
	movwf	time2L
	movwf	time2H
	movwf	time3L
	movwf	time3H
	movwf	delay12
	movwf	delay23
	movwf	delay31
	movwf	config_delay
	movwf	timexH
	movwf	timexL
	movwf	timexH
	movwf	timeyL
	movwf	timeyH
	movwf	delayxy
	

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
	movlw   b'00000111'
	movwf   LATB                ; RB0, RB1, RB2 = 1 while RB3..7 = 0 (pin 21, 22, 23)

    ; Configuration of clock - 8MHz - 
	movlb	0x0F
	movlw	b'01101010'
	movwf	OSCCON		    ; configure oscillator (cf datasheet SFR OSCCON)
	
    ; Configuration of Timer1 - 250kHz - 4µs
	movlb	0x0F
	movlw	b'00110000'
	movwf	T1CON		; configure Timer1 (cf. datasheet SFR T1CON)
	
	; Configuration of Timer3 - 250khz - 4µs to create an overflow interrupt every - 590µs
	movlb	0x0F
	movlw	b'00110000'
	movwf	T3CON		; configure Timer3 (cf. datasheet SFR T3CON)
	
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
	movwf	CCPTMRS		;CCP 2, 3 and 4 is based off of TMR1
	
    ; Interrupt configuration
	movlb	0x0F
	bsf	PIE2,1	;Timer3 overflow interrupt enable
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
	btfss	PIR2, 1	; Test timer3 overflow interrupt flag
	goto	end_if_timer3
	
	bcf	PIR2, 1
	
	movlb	0x01
	btfsc	config_delay, 3	; Test enable1 (if enable2 == 0, skip)
	goto	stop_timer3
	
	btfsc	config_delay, 4	; Test enable2 (if enable1 == 0, skip)
	goto	stop_timer3

	btfsc	config_delay, 5	; Test enable3 (if enable3 == 0, skip)
	goto	stop_timer3
	
	bcf	config_delay, 3	; enable1 = 0
	bcf	config_delay, 4	; enable2 = 0
	bcf	config_delay, 5	; enable3 = 0
	
stop_timer3:
	; Stop Timer 3
	bcf	T3CON, TMR3ON

end_if_timer3:
	movlb	0x0F
	btfss	PIR3, CCP2IF	; Test CCP2 interrupt flag
	goto	end_if_CCP2
	
	bcf	PIR3, CCP2IF
	
	movlb	0x01
	btfsc	config_delay, 3	; Test enable1 (if enable1 == 0, skip)
	goto	end_if_CCP2
	
	btfsc	config_delay, 4	; Test enable2 (if enable2 == 0, skip)
	goto	no_timer3_1

	btfsc	config_delay, 5	; Test enable3 (if enable3 == 0, skip)
	goto	no_timer3_1	
	
	;if(!enable2 && !enable3)
	; !!!!begin timer3 #overflow après 590µs
	; Start Timer 3 
	movlb	0x0F
	movlw	0xFF
	movwf	TMR3H
	movlw	0x6F
	movwf	TMR3L
	bsf	T3CON, TMR3ON
	
no_timer3_1:	
	movlb	0x0F
	movlw	CCPR2L
	movlb	0x01
	movwf	time1L
	movlb	0x0F
	movlw	CCPR2H
	movlb	0x01
	movwf	time1H
	bsf	config_delay, 3	; enable1 = 1
	
end_if_CCP2:
	movlb	0x0F
	btfss	PIR4, CCP3IF	; Test CCP3 interrupt flag
	goto	end_if_CCP3
	
	bcf	PIR4, CCP3IF
	
	movlb	0x01
	btfsc	config_delay, 4	; Test enable2 (if enable2 == 0, skip)
	goto	end_if_CCP3
	
	btfsc	config_delay, 3	; Test enable1 (if enable1 == 0, skip)
	goto	no_timer3_2

	btfsc	config_delay, 5	; Test enable3 (if enable3 == 0, skip)
	goto	no_timer3_2	
	
	;if(!enable1 && !enable3)
	; !!!!begin timer3 #overflow après 590µs
	; Start Timer 3 
	movlb	0x0F
	movlw	0xFF
	movwf	TMR3H
	movlw	0x6F
	movwf	TMR3L
	bsf	T3CON, TMR3ON
	
no_timer3_2:	
	movlb	0x0F
	movlw	CCPR3L
	movlb	0x01
	movwf	time2L
	movlb	0x0F
	movlw	CCPR3H
	movlb	0x01
	movwf	time2H
	bsf	config_delay, 4	; enable2 = 1
	
end_if_CCP3:	
	movlb	0x0F
	btfss	PIR4, CCP4IF	; Test CCP4 interrupt flag
	goto	end_if_CCP4
	
	bcf	PIR4, CCP4IF

	movlb	0x01
	btfsc	config_delay, 5	; Test enable3 (if enable3 == 0, skip)
	goto	end_if_CCP4
	
	btfsc	config_delay, 3	; Test enable1 (if enable1 == 0, skip)
	goto	no_timer3_3

	btfsc	config_delay, 4	; Test enable2 (if enable2 == 0, skip)
	goto	no_timer3_3	
	
	;if(!enable1 && !enable3)
	; !!!!begin timer3 #overflow après 590µs
	; Start Timer 3 
	movlb	0x0F
	movlw	0xFF
	movwf	TMR3H
	movlw	0x6F
	movwf	TMR3L
	bsf	T3CON, TMR3ON
	
no_timer3_3:	
	movlb	0x0F
	movlw	CCPR4L
	movlb	0x01
	movwf	time3L
	movlb	0x0F
	movlw	CCPR4H
	movlb	0x01
	movwf	time3H
	bsf	config_delay, 5	; enable3 = 1
	
end_if_CCP4:
		retfie
		
;MAIN LOOP
main_loop:
    nop
    goto    main_loop
    END 


compute_delay:	;delayxy,xbeforey compute_delay(timex,timey)

	;compute the delay
	movlb	0x01
	movlw	timeyH		; w = timeyH
	CPFSGT	timexH		;if timexH > timeyH, skip
	goto	timexH<=timeyH	
	
	SUBWF	timexH,0	;w = timexH - timeyH
	CPFSLT	0x01		;if 0x01 < timexH-timeyH, skip
	goto	no_overflow_xy
	
	; an overflow occur => micx capture before micy
	movlw	timexH
	SUBLW	0xFF	;w = FF-timexH
	ADDLW	0x01	;w = FF-timexH+1
	ADDWF	timeyH,0;w = FF-timexH+1+timeyH
	CPFSLT	0x01		;if 0x01 < FF-timexH + 1 + timeyH, skip
	goto	no_error1
	
	;#error1 ; maybe light a led when it occure
	goto end_compute_delay
	
no_error1:
	movlw	timexL
	SUBLW	0xFF	;w = FF-timexL
	ADDLW	0x01	;w = FF-timexL+1
	ADDWF	timeyL,0;w = FF-timexL+1+timeyL
	CPFSLT	0x94	;if 0x94 < FF-timexL + 1 + timeyL, skip
	goto	no_error2
	
	;#error2 ; maybe light a led when it occure
	goto end_compute_delay
	
no_error2:
	;if change w in error2
	;movlw	timexL
	;SUBLW	0xFF	;w = FF-timexL
	;ADDLW	0x01	;w = FF-timexL+1
	;ADDWF	timeyL,0;w = FF-timexL+1+timeyL	
	movwf	delayxy	;delayxy = FF-timexL+1+timeyL
	bsf		config_delay, 7;xbeforey = 1
	goto end_compute_delay
	
no_overflow_xy:
	movlw	timeyL
	SUBLW	0xFF	;w = FF-timeyL
	ADDLW	0x01	;w = FF-timeyL+1
	ADDWF	timexL,0;w = FF-timeyL+1+timexL
	CPFSLT	0x94	;if 0x94 < FF-timeyL + 1 + timexL, skip
	goto	no_error3
	
	;#error3 ; maybe light a led when it occure
	goto end_compute_delay
	
no_error3:
	;if change w in error3
	; movlw	timeyL
	; SUBLW	0xFF	;w = FF-timeyL
	; ADDLW	0x01	;w = FF-timeyL+1
	; ADDWF	timexL,0;w = FF-timeyL+1+timexL
	movwf	delayxy	;delayxy = FF-timeyL+1+timexL
	bcf		config_delay, 7;xbeforey = 0
	goto end_compute_delay

timexH<=timeyH:
	movlw	timexH		;w = timexH
	CPFSGT	timeyH		;if timeyH > timexH, skip
	goto	timexH==timeyH
	
	SUBWF	timeyH,0	;w = timeyH - timexH
	CPFSLT	0x01		;if 0x01 < timeyH-timexH, skip
	goto	no_overflow_yx
	
	; an overflow occur => micy capture before micx
	movlw	timeyH
	SUBLW	0xFF	;w = FF-timeyH
	ADDLW	0x01	;w = FF-timeyH+1
	ADDWF	timexH,0;w = FF-timeyH+1+timexH
	CPFSLT	0x01	;if 0x01 < FF-timexH + 1 + timeyH, skip
	goto	no_error4
		
	;#error4 ; maybe light a led when it occure
	goto end_compute_delay
	
no_error4:
	movlw	timeyL
	SUBLW	0xFF	;w = FF-timeyL
	ADDLW	0x01	;w = FF-timeyL+1
	ADDWF	timexL,0;w = FF-timeyL+1+timexL
	CPFSLT	0x94	;if 0x94 < FF-timeyL + 1 + timexL, skip
	goto	no_error5
	
	;#error5 ; maybe light a led when it occure
	goto end_compute_delay
	
no_error5:
	;if change w in error5
	;movlw	timeyL
	;SUBLW	0xFF	;w = FF-timeyL
	;ADDLW	0x01	;w = FF-timeyL+1
	;ADDWF	timexL,0;w = FF-timeyL+1+timexL	
	movwf	delayxy	;delayxy = FF-timeyL+1+timexL
	bcf		config_delay, 7;xbeforey = 0
	goto end_compute_delay
	
no_overflow_yx:
	movlw	timexL
	SUBLW	0xFF	;w = FF-timexL
	ADDLW	0x01	;w = FF-timexL+1
	ADDWF	timeyL,0;w = FF-timexL+1+timeyL
	CPFSLT	0x94	;if 0x94 < FF-timexL + 1 + timeyL, skip
	goto	no_error6
	
	;#error6 ; maybe light a led when it occure
	goto end_compute_delay
	
no_error6:
	;if change w in error6
	; movlw	timexL
	; SUBLW	0xFF	;w = FF-timexL
	; ADDLW	0x01	;w = FF-timexL+1
	; ADDWF	timeyL,0;w = FF-timexL+1+timexL
	movwf	delayxy	;delayxy = FF-timexL+1+timeyL
	bsf		config_delay, 7;xbeforey = 1
	goto end_compute_delay
	
timexH==timeyH:
	movlw	timexL		;w = timexL
	CPFSGT	timeyL		;if timeyL > timexL, skip
	goto	timeyL<=timexL
	
	SUBWF	timeyL,0	;w = timeyL - timexL
	CPFSLT	0x94		;if 0x94 < timeyL-timexL, skip
	goto	no_error7
	
	;#error7 ; maybe light a led when it occure
	goto end_compute_delay
	
no_error7:
	;if change w in error7
	;movlw	timexL		;w = timexL
	;SUBWF	timeyL,0	;w = timeyL - timexL
	movwf	delayxy		;delayxy = timeyL - timexL
	bsf		config_delay, 7	;xbeforey = 1
	goto end_compute_delay
	
timeyL<=timexL:
	movlw	timeyL		;w = timeyL
	SUBWF	timexL,0	;w = timexL - timeyL
	CPFSLT	0x94		;if 0x94 < timexL-timeyL, skip
	goto	no_error8
	
	;#error8 ; maybe light a led when it occure
	goto end_compute_delay
	
no_error8:
	;if change w in error8
	;movlw	timeyL		;w = timeyL
	;SUBWF	timexL,0	;w = timexL - timeyL
	movwf	delayxy		;delayxy = timexL - timeyL
	bcf		config_delay, 7	;xbeforey = 0
end_compute_delay:
	return
