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
REFH EQU	0x09 ;0x091B = 2.33 V
REFL EQU	0x1B ;

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
	
	; Configure Pin
	
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
	
	; Setup PWM
	movlb 0x0F
	movlw b'00011100'	; 000011xx (PWM mode, no prescale and no postscale)
	movwf CCP5CON

	movlw b'00101100'		; MSB of duty cycle 
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
	btfss	PIR1, 6		; Test the AD interrupt flag
	goto	end_if_ADC
	
	bcf		PIR1, 6

pi:
	movlb 	0x01
	movff 	ADRESH, adch
	movff 	ADRESL, adcl
	
	; ref - adc => error
	MOVLW	REFL
	MOVWF	errorl
	MOVF	adcl, W
	SUBWF	errorl, F
	MOVLW	REFH
	MOVWF	errorh
	MOVF	adch, W
	SUBWFB	errorh, F
	
	;total = error*kp = error/32 -> shift of 5 bits
	MOVFF 	errorl, totall
	MOVFF 	errorh, totalh
	; /2
	bcf 	STATUS, C
	btfsc   totalh, 7
	bsf		STATUS, C
	rrcf 	totalh
	rrcf 	totall
	; /4
	bcf 	STATUS, C
	btfsc   totalh, 7
	bsf		STATUS, C
	rrcf 	totalh
	rrcf 	totall
	; /8
	bcf 	STATUS, C
	btfsc   totalh, 7
	bsf		STATUS, C
	rrcf 	totalh
	rrcf 	totall
	; /16
	bcf 	STATUS, C
	btfsc   totalh, 7
	bsf		STATUS, C
	rrcf 	totalh
	rrcf 	totall
	; /32
	bcf 	STATUS, C
	btfsc   totalh, 7
	bsf		STATUS, C
	rrcf 	totalh
	rrcf 	totall
	
	; sumerror + error => sumerror
	MOVF 	errorl, W
	ADDWF 	sumerrorl, F
	MOVF 	errorh, W
	ADDWFC 	sumerrorh, F
	
	;total2 = sumerror*ki = sumerror/128 -> shift of 7 bits
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
	; /64
	bcf 	STATUS, C
	btfsc   total2h, 7
	bsf		STATUS, C
	rrcf 	total2h
	rrcf 	total2l
	; /128
	bcf 	STATUS, C
	btfsc   total2h, 7
	bsf		STATUS, C
	rrcf 	total2h
	rrcf 	total2l
	
	;total = total + total2
	MOVF 	total2l, W
	ADDWF 	totall, F
	MOVF 	total2h, W
	ADDWFC 	totalh, F
	
end_if_ADC:
		retfie
		
;MAIN LOOP
main_loop:
	nop
    goto    main_loop
    END