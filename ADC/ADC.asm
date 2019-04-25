; *********************************************************** ;
;                           CAPTURE                           ;
;                  make a LED blink using ADC                 ;
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
	
	; Configure Port B
	movlb   0x0F
	clrf    TRISB               ; All pins of PORTB are output
	movlb   0x0F
	movlw   b'00000001'
	movwf   LATB                ; RB0 = 1 while RB2..7 = 0 (pin 21)
	
	; Configure AN0 (Pin 2)
	bsf		ANCON0,0	; configured as an analog channel

    ; Configuration of clock - 8MHz - 
	movlb	0x0F
	movlw	b'01101010'
	movwf	OSCCON		    ; configure oscillator (cf datasheet SFR OSCCON)
	
	; Configure ADC
	; 2,33V nominal value with vref+=4.1V -> 0x91B
	movlb	0x0F
	movlw	b'00000000'
	movwf	ADCON0		; Channel 00 (AN0, RA0, pin 2)
	movlw	b'00110000'
	movwf	ADCON1		; Special Trigger Select bits??? | Internal VREF+ (4.1V) | Analog Negative Channel Select bits  Channel 00 (AVSS)
	movlw	b'10001001'
	movwf	ADCON2		; A/D Acquisition Time = 2 TAD | A/D Conversion Clock = FOSC/8 (minimal for 8Mhz clock) 
	bsf		ADCON0,0	; ADC on
	
    ; Interrupt configuration
	movlb	0x0F
	bcf PIR1,6	;Clear the AD interrupt flag
	bsf PIE1,6	;AD interrupt enable
	bsf	INTCON,	GIE	; enable global interrupts
	bsf	INTCON,	6	; enable peripheral interrupts
	
	return
; Low_interrupt routine
low_interrupt_routine:
	movlb	0x0F
	btfss	PIR1, 6		; Test the AD interrupt flag
	goto	end_if_ADC
	
	bcf		PIR1, 6

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
	movlb	0x0F
	btfss	ADCON0,1 ;If conversion not start: start it
	bsf		ADCON0,1 ;Start conversion
    goto    main_loop
    END