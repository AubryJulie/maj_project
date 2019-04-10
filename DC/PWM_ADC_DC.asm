; *********************************************************** ;
;                     ADC and PWM at 30khz                    ;
;                                                             ;
; *********************************************************** ;
    processor	18F25K80
	#include	"config18.inc"

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
	movlw	b'11011110'
	movwf   TRISB               ; All pins of PORTB are input except RB0 and RB5
	 
	; Configure AN0 (Pin 2)
	bsf	ANCON0,0	; configured as an analog channel

    ; Configuration of clock - 8MHz - prescaler 1
	movlb	0x0F
	movlw	b'01101010'
	movwf	OSCCON		    ; configure oscillator (cf datasheet SFR OSCCON)
	
	; Configure ADC
	; 2,33V nominal value with vref+=4.1V -> 0x91B
	; 1 conversion = 15 TAD = 15µs
	; conversion f=20khz -> every 50µs
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
	movlw	41
	movwf	PR4		    ; PR4 = 41
    movlw	b'00000000'
	movwf	T4CON
	
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
	bsf	PIE4, TMR4IE	; enable timer 4 overflow interrupts
	;bsf    IPR4, TMR4IP    ;high priority 
	;bsf    RCON,IPEN       ; enable priority
	bsf	INTCON,	GIE	; enable global interrupts
	bsf	INTCON,	6	; enable peripheral interrupts
	
   return
	
; Interrupt routine
high_interrupt_routine:
	movlb	0x0F
	btfss	PIR4, 7	; Test timer4 overflow interrupt flag
	goto	end_if_timer4
	
	bcf	PIR4, 7
	
	bsf	ADCON0,1	; ADC go

end_if_timer4:
	btfss	PIR1, 6		; Test the AD interrupt flag
	goto	end_if_ADC
	
	bcf	PIR1, 6

	movlw	0x09
	CPFSGT 	ADRESH		; skip if ADRESH > 0x09
	goto	low_or_eq_value
	bsf	LATB, 0			;RB0 = 1
	goto end_if_ADC
	
low_or_eq_value:
	movlw	0x09
	CPFSEQ	ADRESH		; skip if ADRESH = 0x09
	goto	low_value
	movlw	0x1B
	CPFSGT 	ADRESL		; skip if ADRESL > 1B
	goto	low_value
	bsf	LATB, 0			;RB0 = 1
	goto end_if_ADC
	
low_value:
	bcf	LATB, 0			;RB0 = 0
	
end_if_ADC:
		retfie
;MAIN LOOP
main_loop:
    nop
    goto    main_loop
    END
