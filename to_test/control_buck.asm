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
DUTYFLAGMIN EQU 0
DUTYFLAGMAX EQU 1
VALUECOUNTER EQU 1

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
	sumerror1
	sumerror2
	sumerror3
	sumerror4
	total1
	total2
	total3
	total4
	dutyflags
	dutyl
	tmp1
	tmp2
	tmp3
	tmp4
	counter_DC
	endc
	
	;set all the variables to 0
	movlw	0x00
	movwf	adch
	movwf	adcl
	movwf	errorh
	movwf	errorl
	movwf	sumerror1
	movwf	sumerror2
	movwf	sumerror3
	movwf	sumerror4
	movwf	total1
	movwf	total2
	movwf	total3
	movwf	total4
	movwf	dutyflags
	movwf	dutyl
	movwf	tmp1
	movwf	tmp2
	movwf	tmp3
	movwf	tmp4
	movlw	VALUECOUNTER
	movwf	counter_DC
	
	; Configure Pin
	
	; Configure Port B
	movlb   0x0F
	clrf    TRISB               ; All pins of PORTB are output
	movlb   0x0F
	movlw   b'00000000'
	movwf   LATB                ; RB0..7 = 0 (pin 21)
	
	; Configure AN0 (Pin 2)
	bsf	ANCON0,0	; configured as an analog channel

    ; Configuration of clock - 8MHz - 
	movlb	0x0F
	movlw	b'01101010'
	movwf	OSCCON		    ; configure oscillator (cf datasheet SFR OSCCON)
	
	; Configure ADC
	; 3.5V nominal value with vref+=4.1V -> 0x0DA7
	; 1 conversion = 15 TAD = 15µs
	; conversion f=30khz -> every 33µs
	movlb	0x0F
	movlw	b'00000000'
	movwf	ADCON0		; Channel 00 (AN0, RA0, pin 2)
	movlw	b'00110000'
	movwf	ADCON1		; Selects the special trigger from the ECCP1 | Internal VREF+ (4.1V) | Analog Negative Channel Select bits  Channel 00 (AVSS)
	movlw	b'10001001'
	movwf	ADCON2		; A/D Acquisition Time = 2 TAD | A/D Conversion Clock = FOSC/8 = 1Mhz (minimal for 8Mhz clock) 
	bsf	ADCON0,0	; ADC on
	
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
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; high_interrupt routine
high_interrupt_routine:
	movlb	0x0F
	btfss	PIR4, 7	; Test timer4 overflow interrupt flag
	goto	end_if_timer4
	
	DECFSZ	counter_DC	;decrement skip if 0
	goto 	end_if_timer4
	
	movlb	0x0F
	movlw	0x08
	xorwf	LATB,1	;RB3 = !RB3
	movlb	0x01
	movlw	VALUECOUNTER
	movwf	counter_DC
	movlb	0x0F
	bcf	PIR4, 7
	bsf	ADCON0,1	; ADC go

end_if_timer4:
	movlb	0x0F
	btfss	PIR1, 6		; Test the AD interrupt flag
	goto	end_if_ADC
	
	bcf	PIR1, 6

pi:
	
	movf	ADRESH, W
	movlb	0x01
	movwf	adch
	movlb	0x0F
	movf	ADRESL, W
	movlb	0x01
	movwf	adcl
	
	; ref - adc => error
	movlb	0x01
	MOVLW	REFL
	MOVWF	errorl
	MOVF	adcl, W
	SUBWF	errorl, F
	MOVLW	REFH
	MOVWF	errorh
	MOVF	adch, W
	SUBWFB	errorh, F
	
	; Anti windup
	BTFSC   errorh, 7 ;skip if clear
	GOTO    antiwindupneg
	; Positive error, check if duty == max
	BTFSC   dutyflags, DUTYFLAGMAX
	GOTO    end_sumerror_ki
	GOTO    sum_error
antiwindupneg:
	; Negative error, check if duty == min
	BTFSC   dutyflags, DUTYFLAGMIN
	GOTO    end_sumerror_ki

sum_error:
	; sumerror + error => sumerror
	MOVF 	errorl, W
	ADDWF 	sumerror1, F
	MOVF 	errorh, W
	ADDWFC 	sumerror2, F
	movlw	0x0
	BTFSC   errorh, 7
	movlw   0xFF
	ADDWFC 	sumerror3, F
	ADDWFC 	sumerror4, F
	
end_sumerror_ki:
	
	;total2 = sumerror/4 -> shift of 2 bits
	movf	sumerror1, W
	movwf	total1
	movf	sumerror2, W
	movwf	total2
	movf	sumerror3, W
	movwf	total3
	movf	sumerror4, W
	movwf	total4
	; /2
	bcf 	STATUS, C
	btfsc   total4, 7
	bsf	STATUS, C
	rrcf 	total4
	rrcf 	total3
	rrcf 	total2
	rrcf 	total1
	; /4
	bcf 	STATUS, C
	btfsc   total4, 7
	bsf	STATUS, C
	rrcf 	total4
	rrcf 	total3
	rrcf 	total2
	rrcf 	total1
	; \8
	bcf 	STATUS, C
	btfsc   total4, 7
	bsf	STATUS, C
	rrcf 	total4
	rrcf 	total3
	rrcf 	total2
	rrcf 	total1
	
	; error + sumerror/4
	MOVF 	errorl, W
	ADDWF 	total1, F
	MOVF 	errorh, W
	ADDWFC 	total2, F
	movlw	0x0
	BTFSC   errorh, 7
	movlw   0xFF
	ADDWFC 	total3, F
	ADDWFC 	total4, F
	
	
	;total = kp*error+ki*sumerror -> shift of 5 bits
	; /2
	bcf 	STATUS, C
	btfsc   total4, 7
	bsf	STATUS, C
	rrcf 	total4
	rrcf 	total3
	rrcf 	total2
	rrcf 	total1
	; /4
	bcf 	STATUS, C
	btfsc   total4, 7
	bsf	STATUS, C
	rrcf 	total4
	rrcf 	total3
	rrcf 	total2
	rrcf 	total1
	; /8
	bcf 	STATUS, C
	btfsc   total4, 7
	bsf	STATUS, C
	rrcf 	total4
	rrcf 	total3
	rrcf 	total2
	rrcf 	total1
	; /16
	bcf 	STATUS, C
	btfsc   total4, 7
	bsf	STATUS, C
	rrcf 	total4
	rrcf 	total3
	rrcf 	total2
	rrcf 	total1
	; /32
	bcf 	STATUS, C
	btfsc   total4, 7
	bsf	STATUS, C
	rrcf 	total4
	rrcf 	total3
	rrcf 	total2
	rrcf 	total1
	; /64
	bcf 	STATUS, C
	btfsc   total4, 7
	bsf	STATUS, C
	rrcf 	total4
	rrcf 	total3
	rrcf 	total2
	rrcf 	total1
	
	movf	total1, W
	movwf	tmp1
	movf	total2, W
	movwf	tmp2
	movf	total3, W
	movwf	tmp3
	movf	total4, W
	movwf	tmp4
	
	; The final duty cycle is in tmp
	
	MOVLW 0
	MOVWF dutyflags
	; If negative, set to 0
	BTFSS tmp4, 7 ;skip if set
	GOTO dutypositive
	;MOVLW 0 already done above
	MOVWF  tmp1
	MOVWF  tmp2
	BSF dutyflags, DUTYFLAGMIN
	; To debug
	movlb	0x0F
	bsf	LATB, 2	; RB2 = !RB2
	movlb	0x01
	GOTO dutycontinue
	
dutypositive:
	; Check overflow
	MOVF tmp4, F
	BNZ dutyoverflow
	MOVF tmp3, F
	BNZ dutyoverflow
	MOVLW b'11111100' ; Duty cycle only in 10 LSB of tmp (2 LSB of tmp1) since duty high = 0x01.
	ANDWF tmp2, W ; Check overflow on 5 MSB of tmp1
	; To debug
	movlb	0x0F
	bcf	LATB, 2	; RB2 = !RB2
	movlb	0x01
	BZ dutycontinue

dutyoverflow:
	
	MOVLW  0xFF
	MOVWF  tmp1
	MOVWF  tmp2
	BSF dutyflags, DUTYFLAGMAX
	; To debug
	movlb	0x0F
	bsf	LATB, 2	; RB2 = !RB2
	movlb	0x01
	
dutycontinue:
	; PUT DUTY CYCLE IN SFR
	; Low significant bits
	
	movf	tmp1, W
	movwf	dutyl
	movlw 	b'00000011'
	andwf 	dutyl, F
	rlncf 	dutyl
	rlncf 	dutyl
	rlncf 	dutyl
	rlncf 	dutyl ; 00110000

	movlb 	0x0F
	movlw 	b'11001111'
	andwf 	CCP5CON, F

	movlb 	0x01
	movf 	dutyl, W

	movlb 	0x0F
	IORWF 	CCP5CON, F
	
	movlb 	0x01
	
 	; Most significant bits
	bcf 	STATUS, C
	rrcf 	tmp2, F
	rrcf 	tmp1, F
	bcf 	STATUS, C
	rrcf 	tmp2, F
	rrcf 	tmp1, F

	movf 	tmp1, W	
	movlb 	0x0F
	movwf 	CCPR5L
	movlb 	0x01
	
pi_end:
	
	; To debug
	 movlb	0x0F
	 movlw  0x02
	 xorwf  LATB, 1	; RB1 = !RB1
	 movlb	0x01
	
	goto	end_if_ADC
	
no_pi:
	
end_if_ADC:
		retfie
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
;MAIN LOOP
main_loop:
	nop
    goto    main_loop
    END