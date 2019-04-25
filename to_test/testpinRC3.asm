; *********************************************************** ;
;                           DELAY                             ;
;                     compute the delay                       ;
;                   between 2 microphones                     ;
;                                                             ;
; *********************************************************** ;
;micro1 = pin 13
;micro2 = pin 17
;led N0 light if enable micro2 is set (in interrupt ccp2)(RB0)
;led N1 blinks if enable micro1 is set (in interrupt ccp2) not ok
;led N2 blinks if only 1 of the microphone capture (overflow timer3)(RB2) ok
;led N3 blinks if micro1 capture (RB3) ok
;led N4 blinks if micro2 capture (RB4) ok
;led N5 light if e(RC3)
;led N6 blinks if main_loop(RC4) not ok
;led N7 blinks if overflow timer3 occur(RC5)
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
	check_enable
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
	movwf	check_enable
	

	; Configure Pin
	
	; Configure Port C 
	;configure CCP pin
	;RC2/CCP2, RC6/CCP3 and RC7/CCP4 (pin 13, 17, 18)
	;!!!TRISC initiate to 11111111 at the start
	movlb	0x0F
	movlw	b'11000100' 
	movwf	TRISC		    ; All pins of PORTC are outputs except RC2,RC6,RC7
	clrf   LATC                ;while RB0..7 = 0
	
	; Configure Port B
	movlb   0x0F
	clrf    TRISB               ; All pins of PORTB are output
	clrf    LATB                ;while RB0..7 = 0
	
	; Configure Port A
	movlb   0x0F
	movlw	b'00000001'
	movwf   TRISA               ; All pins of PORTA are output except RA0
	clrf    LATA                ;while RB0..7 = 0

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
;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!	
; Low_interrupt routine
low_interrupt_routine:
	movlb	0x0F
	btfss	PIR3, CCP2IF	; Test CCP2 interrupt flag
	goto	end_if_CCP2
	
	bcf 	PIR3, CCP2IF
end_if_CCP2:

	movlb	0x0F
	btfss	PIR4, CCP3IF	; Test CCP3 interrupt flag
	goto	end_if_CCP3
	
	bcf 	PIR4, CCP3IF
    
end_if_CCP3:
    
	movlb	0x0F
	btfss	PIR4, CCP4IF	; Test CCP3 interrupt flag
	goto	end_if_CCP4
	
	bcf 	PIR4, CCP4IF
	
end_if_CCP4:
		retfie
		
;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
		
;MAIN LOOP
main_loop:

	;TODEBUG
	movlb	0x0F
	movlw	b'00001000'
	xorwf	LATA, F	;Ra3 led blink ->N7
	movlb	0x01
	
	nop
    goto    main_loop
    END 


