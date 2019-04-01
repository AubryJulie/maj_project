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
	totalh
	totall
	sumerrorh
	sumerrorl
	total2h
	total2l
	config_shift	; bit7: use in shift operation.
	endc
	
	;set all the variables to 0
	movlw	0x00
	movwf	adch
	movwf	adcl
	movwf	errorh
	movwf	errorl
	movwf	totalh
	movwf	totall
	movwf	sumerrorh
	movwf	sumerrorl
	movwf	total2h
	movwf	total2l
	movwf	config_shift
	
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
	
	; ref - adc => error
	movlb 	0x01
	MOVLW	REFL
	MOVWF	errorl
	MOVF	adcl, W
	SUBWF	errorl, F	; REFL-adcl
	;movlb 	0x0F
	btfsc	STATUS, N	; skip if clear
	goto	error_nega_l		
	;movlb 	0x01
	MOVLW	REFH		; adcl positive
	MOVWF	errorh
	MOVF	adch, W
	SUBWFB	errorh, F	; REFH-adch
	;movlb 	0x0F
	btfss	STATUS, N	; skip if set
	goto	end_error_kp		
	; adch negative/adcl positive
	;movlb 	0x01
	INCF	errorh, F	; errorh+1
	MOVLW	0x80
	ADDWF	errorl, F	;80+errorl
	goto	end_error_kp
	
error_nega_l:; adcl negative
	movlb 	0x01
	MOVLW	REFH
	MOVWF	errorh
	MOVF	adch, W
	SUBWFB	errorh, F	; REFH-adch
	movlb 	0x0F
	btfsc	STATUS, N	; skip if clear
	goto	end_error_kp
	; adch positive/adcl negative
	movlb 	0x0F
	btfsc	STATUS, Z	; skip if clear
	goto	end_error_kp; errorh = 0
	movlb 	0x01
	DECF	errorh, F	; errorh-1
	MOVLW	0x7F
	ADDWF	errorl, F	
	incf	errorl, F	; 7F+errorl+1
	goto	end_error_kp
	
end_error_kp:
	movlb 	0x01
	;total = error*kp = error/32 -> shift of 5 bits
	MOVFF 	errorl, totall	; totall=errorl
	MOVFF 	errorh, totalh	; totalh=errorh
	; /2
	;movlb 	0x0F
	bcf 	STATUS, C
	;movlb 	0x01
	btfsc   totalh, 7	; skip if clear
	;movlb 	0x0F
	bsf		STATUS, C	; totalh is negative
	;movlb 	0x01
	rrcf 	totalh
	bcf		config_shift, 7
	;movlb 	0x0F
	btfsc	STATUS, C	; skip if clear
	;movlb 	0x01
	bsf		config_shift, 7
	;movlb 	0x0F
	bcf 	STATUS, C
	;movlb 	0x01
	btfsc   totall, 7	; skip if clear
	;movlb 	0x0F
	bsf		STATUS, C	; totall is negative
	;movlb 	0x01
	rrcf 	totall
	bcf		totall, 6
	btfsc	config_shift, 7	; skip if clear
	bsf		totall, 6
	; /4
	;movlb 	0x0F
	bcf 	STATUS, C
	;movlb 	0x01
	btfsc   totalh, 7	; skip if clear
	;movlb 	0x0F
	bsf		STATUS, C	; totalh is negative
	;movlb 	0x01
	rrcf 	totalh
	bcf		config_shift, 7
	;movlb 	0x0F
	btfsc	STATUS, C	; skip if clear
	;movlb 	0x01
	bsf		config_shift, 7
	;movlb 	0x0F
	bcf 	STATUS, C
	;movlb 	0x01
	btfsc   totall, 7	; skip if clear
	;movlb 	0x0F
	bsf		STATUS, C	; totall is negative
	;movlb 	0x01
	rrcf 	totall
	bcf		totall, 6
	btfsc	config_shift, 7	; skip if clear
	bsf		totall, 6
	; /8
	;movlb 	0x0F
	bcf 	STATUS, C
	;movlb 	0x01
	btfsc   totalh, 7	; skip if clear
	;movlb 	0x0F
	bsf		STATUS, C	; totalh is negative
	;movlb 	0x01
	rrcf 	totalh
	bcf		config_shift, 7
	;movlb 	0x0F
	btfsc	STATUS, C	; skip if clear
	;movlb 	0x01
	bsf		config_shift, 7
	;movlb 	0x0F
	bcf 	STATUS, C
	;movlb 	0x01
	btfsc   totall, 7	; skip if clear
	;movlb 	0x0F
	bsf		STATUS, C	; totall is negative
	;movlb 	0x01
	rrcf 	totall
	bcf		totall, 6
	btfsc	config_shift, 7	; skip if clear
	bsf		totall, 6
	; /16
	;movlb 	0x0F
	bcf 	STATUS, C
	;movlb 	0x01
	btfsc   totalh, 7	; skip if clear
	;movlb 	0x0F
	bsf		STATUS, C	; totalh is negative
	;movlb 	0x01
	rrcf 	totalh
	bcf		config_shift, 7
	;movlb 	0x0F
	btfsc	STATUS, C	; skip if clear
	;movlb 	0x01
	bsf		config_shift, 7
	;movlb 	0x0F
	bcf 	STATUS, C
	;movlb 	0x01
	btfsc   totall, 7	; skip if clear
	;movlb 	0x0F
	bsf		STATUS, C	; totall is negative
	;movlb 	0x01
	rrcf 	totall
	bcf		totall, 6
	btfsc	config_shift, 7	; skip if clear
	bsf		totall, 6
	; /32
	;movlb 	0x0F
	bcf 	STATUS, C
	;movlb 	0x01
	btfsc   totalh, 7	; skip if clear
	;movlb 	0x0F
	bsf		STATUS, C	; totalh is negative
	;movlb 	0x01
	rrcf 	totalh
	bcf		config_shift, 7
	;movlb 	0x0F
	btfsc	STATUS, C	; skip if clear
	;movlb 	0x01
	bsf		config_shift, 7
	;movlb 	0x0F
	bcf 	STATUS, C
	;movlb 	0x01
	btfsc   totall, 7	; skip if clear
	;movlb 	0x0F
	bsf		STATUS, C	; totall is negative
	;movlb 	0x01
	rrcf 	totall
	bcf		totall, 6
	btfsc	config_shift, 7	; skip if clear
	bsf		totall, 6
	
	; sumerror + error => sumerror
	;movlb 	0x01
	MOVF 	errorl, W
	ADDWF 	sumerrorl, F
	;movlb 	0x0F
	btfsc	STATUS, N	; skip if clear
	;movlb 	0x01
	goto	sumerror_nega_l	
	MOVF 	errorh, W	;sumerrorl positive
	ADDWF 	sumerrorh, F
	;movlb 	0x0F
	btfss	STATUS, N	; skip if set
	goto	end_sumerror_ki
	; sumerrorl positive/sumerrorh negative
	;movlb 	0x01
	INCF	sumerrorh, F	; sumerrorh+1
	MOVLW	0x80
	ADDWF	sumerrorl, F	;80+sumerrorl
	goto	end_sumerror_ki
	
sumerror_nega_l:;sumerrorl negative
	;movlb 	0x01
	MOVF 	errorh, W
	ADDWF 	sumerrorh, F
	;movlb 	0x0F
	btfsc	STATUS, N	; skip if clear
	;movlb 	0x01
	goto	end_sumerror_ki
	; sumerrorh positive/sumerrorl negative
	;movlb 	0x0F
	btfsc	STATUS, Z	; skip if clear
	;movlb 	0x01
	goto	end_sumerror_ki; sumerrorh = 0
	DECF	sumerrorh, F	; sumerrorh-1
	MOVLW	0x7F
	ADDWF	sumerrorl, F	
	incf	sumerrorl, F	; 7F+sumerrorl+1
	goto	end_sumerror_ki
	
end_sumerror_ki:
	
	;total2 = sumerror*ki = sumerror/128 -> shift of 7 bits
	;movlb 	0x01
	MOVFF 	sumerrorl, total2l
	MOVFF 	sumerrorh, total2h
	; /2
	;movlb 	0x0F
	bcf 	STATUS, C
	;movlb 	0x01
	btfsc   total2h, 7	; skip if clear
	;movlb 	0x0F
	bsf		STATUS, C	; totalh is negative
	;movlb 	0x01
	rrcf 	total2h
	bcf		config_shift, 7
	;movlb 	0x0F
	btfsc	STATUS, C	; skip if clear
	;movlb 	0x01
	bsf		config_shift, 7
	;movlb 	0x0F
	bcf 	STATUS, C
	;movlb 	0x01
	btfsc   total2l, 7	; skip if clear
	;movlb 	0x0F
	bsf		STATUS, C	; totall is negative
	;movlb 	0x01
	rrcf 	total2l
	bcf		total2l, 6
	btfsc	config_shift, 7	; skip if clear
	bsf		total2l, 6
	; /4
	;movlb 	0x0F
	bcf 	STATUS, C
	;movlb 	0x01
	btfsc   total2h, 7	; skip if clear
	;movlb 	0x0F
	bsf		STATUS, C	; totalh is negative
	;movlb 	0x01
	rrcf 	total2h
	bcf		config_shift, 7
	;movlb 	0x0F
	btfsc	STATUS, C	; skip if clear
	;movlb 	0x01
	bsf		config_shift, 7
	;movlb 	0x0F
	bcf 	STATUS, C
	;movlb 	0x01
	btfsc   total2l, 7	; skip if clear
	;movlb 	0x0F
	bsf		STATUS, C	; totall is negative
	;movlb 	0x01
	rrcf 	total2l
	bcf		total2l, 6
	btfsc	config_shift, 7	; skip if clear
	bsf		total2l, 6
	; /8
	;movlb 	0x0F
	bcf 	STATUS, C
	;movlb 	0x01
	btfsc   total2h, 7	; skip if clear
	;movlb 	0x0F
	bsf		STATUS, C	; totalh is negative
	;movlb 	0x01
	rrcf 	total2h
	bcf		config_shift, 7
	;movlb 	0x0F
	btfsc	STATUS, C	; skip if clear
	;movlb 	0x01
	bsf		config_shift, 7
	;movlb 	0x0F
	bcf 	STATUS, C
	;movlb 	0x01
	btfsc   total2l, 7	; skip if clear
	;movlb 	0x0F
	bsf		STATUS, C	; totall is negative
	;movlb 	0x01
	rrcf 	total2l
	bcf		total2l, 6
	btfsc	config_shift, 7	; skip if clear
	bsf		total2l, 6
	; /16
	;movlb 	0x0F
	bcf 	STATUS, C
	;movlb 	0x01
	btfsc   total2h, 7	; skip if clear
	;movlb 	0x0F
	bsf		STATUS, C	; totalh is negative
	;movlb 	0x01
	rrcf 	total2h
	bcf		config_shift, 7
	;movlb 	0x0F
	btfsc	STATUS, C	; skip if clear
	;movlb 	0x01
	bsf		config_shift, 7
	;movlb 	0x0F
	bcf 	STATUS, C
	;movlb 	0x01
	btfsc   total2l, 7	; skip if clear
	;movlb 	0x0F
	bsf		STATUS, C	; totall is negative
	;movlb 	0x01
	rrcf 	total2l
	bcf		total2l, 6
	btfsc	config_shift, 7	; skip if clear
	bsf		total2l, 6
	; /32
	;movlb 	0x0F
	bcf 	STATUS, C
	;movlb 	0x01
	btfsc   total2h, 7	; skip if clear
	;movlb 	0x0F
	bsf		STATUS, C	; totalh is negative
	;movlb 	0x01
	rrcf 	total2h
	bcf		config_shift, 7
	;movlb 	0x0F
	btfsc	STATUS, C	; skip if clear
	;movlb 	0x01
	bsf		config_shift, 7
	;movlb 	0x0F
	bcf 	STATUS, C
	;movlb 	0x01
	btfsc   total2l, 7	; skip if clear
	;movlb 	0x0F
	bsf		STATUS, C	; totall is negative
	;movlb 	0x01
	rrcf 	total2l
	bcf		total2l, 6
	btfsc	config_shift, 7	; skip if clear
	bsf		total2l, 6
	; /64
	;movlb 	0x0F
	bcf 	STATUS, C
	;movlb 	0x01
	btfsc   total2h, 7	; skip if clear
	;movlb 	0x0F
	bsf		STATUS, C	; totalh is negative
	;movlb 	0x01
	rrcf 	total2h
	bcf		config_shift, 7
	;movlb 	0x0F
	btfsc	STATUS, C	; skip if clear
	;movlb 	0x01
	bsf		config_shift, 7
	;movlb 	0x0F
	bcf 	STATUS, C
	;movlb 	0x01
	btfsc   total2l, 7	; skip if clear
	;movlb 	0x0F
	bsf		STATUS, C	; totall is negative
	;movlb 	0x01
	rrcf 	total2l
	bcf		total2l, 6
	btfsc	config_shift, 7	; skip if clear
	bsf		total2l, 6
	; /128
	;movlb 	0x0F
	bcf 	STATUS, C
	;movlb 	0x01
	btfsc   total2h, 7	; skip if clear
	;movlb 	0x0F
	bsf		STATUS, C	; totalh is negative
	;movlb 	0x01
	rrcf 	total2h
	bcf		config_shift, 7
	;movlb 	0x0F
	btfsc	STATUS, C	; skip if clear
	;movlb 	0x01
	bsf		config_shift, 7
	;movlb 	0x0F
	bcf 	STATUS, C
	;movlb 	0x01
	btfsc   total2l, 7	; skip if clear
	;movlb 	0x0F
	bsf		STATUS, C	; totall is negative
	;movlb 	0x01
	rrcf 	total2l
	bcf		total2l, 6
	btfsc	config_shift, 7	; skip if clear
	bsf		total2l, 6
	
	; total = total + total2
	;movlb 	0x01
	MOVF 	total2l, W
	ADDWF 	totall, F
	;movlb 	0x0F
	btfsc	STATUS, N	; skip if clear
	;movlb 	0x01
	goto	total_nega_l	
	MOVF 	total2h, W	;totall positive
	ADDWF 	totalh, F
	;movlb 	0x0F
	btfss	STATUS, N	; skip if set
	goto	end_total
	; totall positive/totalh negative
	INCF	totalh, F	; totalh+1
	MOVLW	0x80
	ADDWF	totall, F	; 80+totall
	goto	end_total_nega
	
total_nega_l:; totall negative
	MOVF 	errorh, W
	ADDWF 	sumerrorh, F
	;movlb 	0x0F
	btfsc	STATUS, N	; skip if clear
	;movlb 	0x01
	goto	end_total_nega
	; totalh positive/totall negative
	;movlb 	0x0F
	btfsc	STATUS, Z	; skip if clear
	;movlb 	0x01
	goto	end_total_nega	; totalh = 0
	DECF	totalh, F	; totalh-1
	MOVLW	0x7F
	ADDWF	totall, F	
	incf	totall, F	; 7F+totall+1
	goto	end_total

end_total_nega:
	;movlb 	0x0F
	movlw	0x00			; MSB of duty cycle 0%
	movwf	CCPR5L
	movlw   0x04
	xorwf   LATB, 1	; RB2 = !RB2
	goto	end_pi
	
end_total:
	;movlb 	0x01
	movf	totall, W
	movf	totalh, F
	;movlb 	0x0F
	btfss	STATUS, Z	; skip if set
	goto	end_total_max
	movwf	CCPR5L		; duty = totall
	goto	end_pi
	
end_total_max
	;movlb 	0x0F
	movlw	0x41	; MSB of duty cycle %
	movwf	CCPR5L
	movlw   0x04
	xorwf   LATB, 1	; RB2 = !RB2
	
end_pi:
	;movlb 	0x0F
	movlw   0x01
	xorwf   LATB, 1	; RB0 = !RB0
	
	
end_if_ADC:
		retfie
		
;MAIN LOOP
main_loop:
	nop
    goto    main_loop
    END