; *********************************************************** ;
;                           DELAY                             ;
;                     compute the delay                       ;
;                   between 2 microphones                     ;
;                                                             ;
; *********************************************************** ;
;micro1 = pin 13
;micro2 = pin 17
;led N0 light if error in the compute delay(RB0)
;led N1 blinks if timer3 overflow(RB1) ok
;led N2 blinks if only 1 of the microphone capture(RB2) not ok
;led N3 blinks if micro1 capture (RB3) ok
;led N4 blinks if micro2 capture (RB4) ok
;led N5 blinks if enable micro1 is set(RC3) not ok
;led N6 blinks if enable micro1 and 2 set(RC4) not ok
;led N7 lights if micro1 recieve before micro2 else switches off.(RC5)
; trick: devide the delay by 2 to have a step of 8µs instead of 4µs
	processor	18F25K80
	#include	"config18.inc"

; define constant
_1BEFORE2 EQU 0
_2BEFORE3 EQU 1
_3BEFORE1 EQU 2
ENABLE1 EQU 3
ENABLE2 EQU 4
ENABLE3 EQU 5
xBEFOREy EQU 6
W EQU 0
F EQU 1
TIMER3L EQU 0x6F
TIMER3H EQU 0xFF
ELAPSEL EQU 0x94
ELAPSEH EQU 0x00
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
	cblock	00h
	time1L
	time1H
	time2L
	time2H
	delay12L
	delay12H
	config_delay ;bit0 = _1before2, bit1 = _2before3, bit2 = _3before1,
				 ;bit3 = enable1, bit4 = enable2, bit5 = enable3, bit6
				 ; = xbeforey
	timexL
	timexH
	timeyL
	timeyH
	delayxyL
	delayxyH
	errorL
	errorH
	endc
	
	;set all the variables to 0
	movlw	0x00
	movwf	time1L
	movwf	time1H
	movwf	time2L
	movwf	time2H
	movwf	delay12L
	movwf	delay12H
	movwf	config_delay
	movwf	timexL
	movwf	timexH
	movwf	timeyL
	movwf	timeyH
	movwf	delayxyL
	movwf	delayxyH
	movwf	errorL
	movwf	errorH
	

	; Configure Pin
	
	; Configure Port C 
	;configure CCP pin
	;RC2/CCP2, RC6/CCP3 and RC7/CCP4 (pin 13, 17, 18)
	;!!!TRISC initiate to 11111111 at the start
	movlb	0x0F
	movlw	b'11000100' 
	movwf	TRISC		    ; All pins of PORTC are outputs except RC2,RC6,RC7
	movlw   b'00000000'
	movwf   LATB                ;while RB0..7 = 0
	
	; Configure Port B
	movlb   0x0F
	clrf    TRISB               ; All pins of PORTB are output
	movlw   b'00000000'
	movwf   LATB                ;while RB0..7 = 0

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
	bsf 	PIE2,TMR3IE	;Timer3 overflow interrupt enable
	bsf 	PIE3,2	;CCP2 interrupt enable  
	bsf 	PIE4,0	;CCP3 interrupt enable
	bsf 	PIE4,1	;CCP4 interrupt enable
	bsf 	INTCON,	GIE	; enable global interrupts
	bsf 	INTCON,	6	; enable peripheral interrupts
	
    ; Start Timer 1 
	movlb	0x0F
	movlw	0x00
	movwf	TMR1H
	movwf	TMR1L
	bsf	T1CON, TMR1ON
	
	return
;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!	
; The value of delay(µs)= delayxy*8
compute_delay:	;delayxy,xbeforey compute_delay(timex,timey)

	;compute the delay
	; delay = timex-timey
	movlb	0x01
	MOVF	timexL, W
	MOVWF	delayxyL
	MOVF	timeyL, W
	SUBWF	delayxyL, F
	MOVF	timexH, W
	MOVWF	delayxyH
	MOVF	timeyH, W
	SUBWFB	delayxyH, F
	
	; If negative
	BTFSS 	delayxyH, 7 ;skip if set
	goto 	delay_pos
	bcf 	config_delay, xBEFOREy ;xbeforey = 0
	;if delay < -148
	;		!!!error
	;error = delay+149	(don't use CPFSLT because it's unsigned operation)
	MOVF	delayxyL, W
	MOVWF	errorL
	MOVLW	ELAPSEL
	ADDWF	errorL, F
	MOVF	delayxyH, W
	MOVWF	errorH
	MOVLW	ELAPSEH
	ADDWFC	errorH, F
	; If error < 0 -> error
	BTFSS 	errorH, 7 ;skip if set
	goto 	end_compute_delay
    
	;TODEBUG
	movlb	0x0F
	bsf	LATB, 0	;Rb0 led blink ->N0
	movlb	0x01
	
	goto	end_compute_delay
	
delay_pos:

	bsf 	config_delay, xBEFOREy ;xbeforey = 0
	; to debug
	;if delay > 148
	;		!!!error
	MOVLW	ELAPSEL
	CPFSLT	delayxyL	; Skip if f < W
	goto	_error
	MOVLW	ELAPSEH
	CPFSLT	delayxyH	; Skip if f < W
	goto	_error
	goto 	end_compute_delay
_error:
    
	;TODEBUG
	movlb	0x0F
	bsf	LATB, 0	;Rb0 led blink ->N0
	movlb	0x01
	
	
end_compute_delay:
	; trick: devide the delay by 2 to have a step of 8µs instead of 4µs
	; /2
	bcf 	STATUS, C
	btfsc   delayxyH, 7
	bsf 	STATUS, C
	rrcf 	delayxyH
	rrcf 	delayxyL
	return
;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!	
; Low_interrupt routine
low_interrupt_routine:

	movlb	0x0F
	btfss	PIR2, 1	; Test timer3 overflow interrupt flag
	goto	end_if_timer3
	
	bcf	PIR2, 1
    
	;TODEBUG
	movlb	0x0F
	movlw	0x02
	xorwf	LATB, F	;Rb1 led blink ->N1
	movlb	0x01
	
	
	movlb	0x01
	btfsc	config_delay, ENABLE1	; Test enable1 (if enable1 == 0, skip)
	goto	reset_enables
	
	btfsc	config_delay, ENABLE2	; Test enable2 (if enable2 == 0, skip)
	goto	reset_enables
	goto	stop_timer3
; reset when only 1 of the 2 microphones has recieved a signal.
reset_enables:
    
	;TODEBUG
	movlb	0x0F
	movlw	0x04
	xorwf	LATB, F	;Rb2 led blink ->N2
	movlb	0x01
	

	bcf	config_delay, ENABLE1	; enable1 = 0
	bcf	config_delay, ENABLE2	; enable2 = 0
	
stop_timer3:
	; Stop Timer 3
	movlb	0x0F
	bcf	T3CON, TMR3ON
	
end_if_timer3:

	movlb	0x0F
	btfss	PIR3, CCP2IF	; Test CCP2 interrupt flag
	goto	end_if_CCP2
	
	bcf 	PIR3, CCP2IF
    
	;TODEBUG
	movlb	0x0F
	movlw	0x08
	xorwf	LATB, F	;Rb3 led blink ->N3
	movlb	0x01
	
	
	movlb	0x01
	btfsc	config_delay, ENABLE1	; Test enable1 (if enable1 == 0, skip)
	goto	end_if_CCP2
	
	btfsc	config_delay, ENABLE2	; Test enable2 (if enable2 == 0, skip)
	goto	no_timer3_1
	
	;if(!enable1 && !enable2)
	; !!!!begin timer3 #overflow after 590µs
	; Start Timer 3     
	movlb	0x0F
	bcf 	T3CON, TMR3ON
	movlw	TIMER3H
	movwf	TMR3H
	movlw	TIMER3L
	movwf	TMR3L
	bsf 	T3CON, TMR3ON
	
no_timer3_1:	
	movlb	0x0F
	movf	CCPR2L,W
	movlb	0x01
	movwf	time1L
	movlb	0x0F
	movf	CCPR2H,W
	movlb	0x01
	movwf	time1H
	bsf 	config_delay, ENABLE1	; enable1 = 1
	
end_if_CCP2:

	movlb	0x0F
	btfss	PIR4, CCP3IF	; Test CCP3 interrupt flag
	goto	end_if_CCP3
	
	bcf 	PIR4, CCP3IF
    
	;TODEBUG
	movlb	0x0F
	movlw	0x10
	xorwf	LATB, F	;Rb4 led blink ->N4
	movlb	0x01
	
	
	movlb	0x01
	btfsc	config_delay, ENABLE2	; Test enable2 (if enable2 == 0, skip)
	goto	end_if_CCP3
	
	btfsc	config_delay, ENABLE1	; Test enable1 (if enable1 == 0, skip)
	goto	no_timer3_2
	
	;if(!enable1 && !enable3)
	; !!!!begin timer3 #overflow après 590µs
	; Start Timer 3
	bcf	T3CON, TMR3ON
	movlb	0x0F
	movlw	TIMER3H
	movwf	TMR3H
	movlw	TIMER3L
	movwf	TMR3L
	bsf 	T3CON, TMR3ON
	
no_timer3_2:	
	movlb	0x0F
	movf	CCPR3L, W
	movlb	0x01
	movwf	time2L
	movlb	0x0F
	movf	CCPR3H, W
	movlb	0x01
	movwf	time2H
	bsf 	config_delay, ENABLE2	; enable2 = 1
	
end_if_CCP3:	

		retfie
		
;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
		
;MAIN LOOP
main_loop:
	movlb	0x01
	; if (enable1 && enable2)
	btfss	config_delay, ENABLE1	; Test enable1 (if enable1 == 1, skip)
	goto	end_delay
	
	;TODEBUG
	movlb	0x0F
	movlw	0x08
	xorwf	LATC, F	;Rc3 led blink ->N5
	movlb	0x01
	
	
	btfss	config_delay, ENABLE2	; Test enable2 (if enable2 == 1, skip)
	goto	end_delay
    
	;TODEBUG
	movlb	0x0F
	movlw	0x10
	xorwf	LATC, F	;Rc4 led blink ->N6
	movlb	0x01
	
	
	;delay12,1before2 = compute_delay(time1,time2)
	MOVF	time1L, W
	MOVWF	timexL
	MOVF	time1H, W
	MOVWF	timexH
	MOVF	time2L, W
	MOVWF	timeyL
	MOVF	time2H, W
	MOVWF	timeyH
	call	compute_delay
	MOVF	delayxyL, W
	MOVWF	delay12L
	MOVF	delayxyH, W
	MOVWF	delay12H
	bsf 	config_delay, _1BEFORE2
	btfss 	config_delay, xBEFOREy ;skip if set
	bcf 	config_delay, _1BEFORE2
	
	; to debug
	btfsc	config_delay, _1BEFORE2 ;skip if clear
	goto	led_set
	
	movlb	0x0F
	bcf 	LATC, 5 ;Rc5 led blink ->N7
	goto	end_led
	
led_set:
	movlb	0x0F
	bsf 	LATC, 5 ;Rc5 led blink ->N7
end_led:
	movlb	0x01
	
	;!!! use delay to compute angle and distance
	
	;enable1,enable2,enable3 = 0
	movlw	b'11000111'
	ANDWF	config_delay,F
end_delay:
    goto    main_loop
    END 


