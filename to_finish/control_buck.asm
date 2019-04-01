; *********************************************************** ;
;                         CONTROL DC                          ;
;                      using ADC and PWM                      ;
;                                                             ;
;                                                             ;
; *********************************************************** ;

	processor	18F25K80
	#include	"config18.inc"

; -> on va utiliser des shifts!!!
;KP	= 0.04 -> 1/32 = 0.031
;Ki = 0.005 -> 1/128 = 0.0078
REFH EQU	0x0D ;0x0DA7 = 3.5 V
REFL EQU	0xA7 ;
MAXDUTY EQU 0x41 ;

; That is where the MCU will start executing the program (0x00)
	org 	0x00
	nop
	goto    start		    ; jump to the beginning of the code
	
; That is where the MCU will start executing the high interrupt (0x08)
	org 	0x08
	nop
	goto    high_interrupt_routine   ; jump to the high interrupt routine

;BEGINNING OF THE PROGRAM
start:
	call	initialisation      ; initialisation routine configuring the MCU
	goto	main_loop           ; main loop

;INITIALISATION
initialisation:

; Declare usefull variables begining at the first GPR  adress of bank1 in ram
	movlb	0x01
	cblock	00h
	adch
	adcl
	errorh
	errorl
	sumerrorh
	sumerrorl
	total2h
	total2l
	endc
	
	;set all the variables to 0
	movlw	0x00
	movwf	adch
	movwf	adcl
	movwf	errorh
	movwf	errorl
	movwf	sumerrorh
	movwf	sumerrorl
	movwf	total2h
	movwf	total2l
	
	; Configure Pin
	
	; Configure Port B
	movlb   0x0F
	clrf    TRISB               ; All pins of PORTB are output
	movlb   0x0F
	movlw   b'00000000'
	movwf   LATB                ; RB0..7 = 0 (pin 21)
	
	; Configure AN0 (Pin 2)
	bsf		ANCON0,0	; configured as an analog channel

    ; Configuration of clock - 8MHz - 
	movlb	0x0F
	movlw	b'01101010'
	movwf	OSCCON		    ; configure oscillator (cf datasheet SFR OSCCON)
	
	; Configure ADC
	; 2,33V nominal value with vref+=4.1V -> 0x91B
	; 1 conversion = 15 TAD = 15µs
	; conversion f=30khz -> every 33µs
	movlb	0x0F
	movlw	b'00000000'
	movwf	ADCON0		; Channel 00 (AN0, RA0, pin 2)
	movlw	b'00110000'
	movwf	ADCON1		; Selects the special trigger from the ECCP1 | Internal VREF+ (4.1V) | Analog Negative Channel Select bits  Channel 00 (AVSS)
	movlw	b'10001001'
	movwf	ADCON2		; A/D Acquisition Time = 2 TAD | A/D Conversion Clock = FOSC/8 = 1Mhz (minimal for 8Mhz clock) 
	bsf		ADCON0,0	; ADC on
	
	; Configuration Timer4 for use with PWM
	movlb	0x0F
	movlw	0x41
	movwf	PR4		    ; PR4 = 0x41 = 65
    movlw	b'00000000'
	movwf	T4CON
	
	; Setup PWM
	movlb 0x0F
	movlw b'00111100'	; 000011xx (PWM mode, no prescale and no postscale)
	movwf CCP5CON

	movlw b'01001111'		; MSB of duty cycle 30%
	movwf CCPR5L
	bsf CCPTMRS,4  ; CCP5 en PWM

	; Run timer4
	movlb 0x0F
	bsf T4CON,2
	
    ; Interrupt configuration
	movlb	0x0F
	bcf PIR1,6	;Clear the AD interrupt flag
	bsf PIE1,6	;AD interrupt enable
	bsf	PIE4, TMR4IE
	;bsf    IPR4, TMR4IP    ;high priority 
	;bsf    RCON,IPEN       ; enable priority
	bsf	INTCON,	GIE	; enable global interrupts
	bsf	INTCON,	6	; enable peripheral interrupts
	
	return
; high_interrupt routine
high_interrupt_routine:
	movlb	0x0F
	btfss	PIR4, 7	; Test timer4 overflow interrupt flag
	goto	end_if_timer4
	
	bcf	PIR4, 7
	
	bsf	ADCON0,1	; ADC go

end_if_timer4:
	movlb	0x0F
	btfss	PIR1, 6		; Test the AD interrupt flag
	goto	end_if_ADC
	
	bcf		PIR1, 6

pi:
	movff 	ADRESH, adch
	movff 	ADRESL, adcl
	
	; adc - ref => error
	MOVLW	REFL
	MOVWF	errorl
	MOVF	errorl, W
	SUBWF	adcl, W
	MOVWF	errorl
	MOVLW	REFH
	MOVWF	errorh
	MOVF	errorh, W
	SUBWFB	adch, W
	MOVWF	errorh
	
	; sumerror + error => sumerror
	MOVF 	errorl, W
	ADDWF 	sumerrorl, F
	MOVF 	errorh, W
	ADDWFC 	sumerrorh, F
	
end_sumerror_ki:
	
	;total2 = sumerror/4 -> shift of 2 bits
	MOVFF 	sumerrorl, total2l
	MOVFF 	sumerrorh, total2h
	; /2
	bcf 	STATUS, C
	btfsc   total2h, 7
	bsf		STATUS, C
	rrcf 	total2h
	rrcf 	total2l
	; /4
	bcf 	STATUS, C
	btfsc   total2h, 7
	bsf		STATUS, C
	rrcf 	total2h
	rrcf 	total2l
	
	; error + sumerror/4
	MOVF 	errorl, W
	ADDWF 	total2l, F
	MOVF 	errorh, W
	ADDWFC 	total2h, F
	
	;total = kp*error+ki*sumerror -> shift of 5 bits
	; /2
	bcf 	STATUS, C
	btfsc   total2h, 7
	bsf		STATUS, C
	rrcf 	total2h
	rrcf 	total2l
	; /4
	bcf 	STATUS, C
	btfsc   total2h, 7
	bsf		STATUS, C
	rrcf 	total2h
	rrcf 	total2l
	; /8
	bcf 	STATUS, C
	btfsc   total2h, 7
	bsf		STATUS, C
	rrcf 	total2h
	rrcf 	total2l
	; /16
	bcf 	STATUS, C
	btfsc   total2h, 7
	bsf		STATUS, C
	rrcf 	total2h
	rrcf 	total2l
	; /32
	bcf 	STATUS, C
	btfsc   total2h, 7
	bsf		STATUS, C
	rrcf 	total2h
	rrcf 	total2l

	movf	total2h
	btfss	STATUS, N	; Skip if Set
	goto	end_total
	movlw	0x00		; MSB of duty cycle 0%
	movwf	CCPR5L
	movlw   0x04
	xorwf   LATB, 1	; RB2 = !RB2
	goto	end_pi
	
end_total:
	btfss	STATUS, Z	; Skip if Set
	goto	end_total_max
	movf	total2l, W
	movwf	CCPR5L		; duty = totall
	goto	end_pi
	
end_total_max
	movlw	0x41	; MSB of duty cycle %
	movwf	CCPR5L
	movlw   0x04
	xorwf   LATB, 1	; RB2 = !RB2
	
end_pi:
	movlw   0x01
	xorwf   LATB, 1	; RB0 = !RB0
	
	
end_if_ADC:
		retfie
		
;MAIN LOOP
main_loop:
	nop
    goto    main_loop
    END