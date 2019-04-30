; *********************************************************** ;
;                         CONTROL DC                          ;
;                      using ADC and PWM                      ;
;             regulation at 500Hz using the Timer2            ;
;                                                             ;
; *********************************************************** ;
;led N0 : blinks when enter low interrupt routine(RB0)
;led N1 : blinks when pi end (RB1)
;led N2 : set when duty is too low or too high, else clear (RB2)
;led N3 : blinks when timer2 overflow (RB3)
;led N4 : blinks when enter high interrupt routine(RB4)
;led N5 :(RC4)
;led N6 :(RA6)
;led N7 :(RA3)
processor	18F25K80
#include	"config18.inc"

; DEFINE CONSTANTS
W EQU 0
F EQU 1

; for the DC_convertor
;KP	= 0.04 -> 1/32 = 0.031
;Ki = 0.005 -> 1/128 = 0.0078
DC_REFH EQU	0x0D ;0x0DA7 = 3.5 V
DC_REFL EQU	0xA7 ;
DC_DUTYFLAGMIN EQU 0
DC_DUTYFLAGMAX EQU 1

; for PWM servo-motor
PWM_SERVO_IS_SET EQU 0
PWM_SERVO_VALUE_COUNTER EQU 0x0A ;50hz
PWM_MOTOR_FREQUENCY EQU 0xF8 

; That is where the MCU will start executing the program (0x00)
	org 	0x00
	nop
	goto    start		    ; jump to the beginning of the code
	
; That is where the MCU will start executing the high interrupt (0x08)
	org 	0x08
	nop
	goto    high_interrupt_routine   ; jump to the high interrupt routine
	
; That is where the MCU will start executing the low interrupt (0x18)
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
	DC_adch
	DC_adcl
	DC_errorh
	DC_errorl
	DC_sumerror1
	DC_sumerror2
	DC_sumerror3
	DC_sumerror4
	DC_total1
	DC_total2
	DC_total3
	DC_total4
	DC_dutyflags
	DC_dutyl
	DC_tmp1
	DC_tmp2
	DC_tmp3
	DC_tmp4
	endc
	
	;set all the variables to 0
	movlw	0x00
	movwf	DC_adch
	movwf	DC_adcl
	movwf	DC_errorh
	movwf	DC_errorl
	movwf	DC_sumerror1
	movwf	DC_sumerror2
	movwf	DC_sumerror3
	movwf	DC_sumerror4
	movwf	DC_total1
	movwf	DC_total2
	movwf	DC_total3
	movwf	DC_total4
	movwf	DC_dutyflags
	movwf	DC_dutyl
	movwf	DC_tmp1
	movwf	DC_tmp2
	movwf	DC_tmp3
	movwf	DC_tmp4
	
; CONFIGURE PIN
	
	; Configure Port B
	movlb   0x0F
	clrf    TRISB               ; All pins of PORTB are output
	movlb   0x0F
	movlw   b'00000000'
	movwf   LATB                ; RB0..7 = 0 (pin 21)

; CONFIGURE CLOCK AND TIMERS
	
	; Configure AN0 (Pin 2)
	bsf 	ANCON0,0	; configured as an analog channel

    ; Configuration of clock - 8MHz - 
	movlb	0x0F
	movlw	b'01101010'
	movwf	OSCCON		    ; configure oscillator (cf datasheet SFR OSCCON)

    ; Configuration of Timer2 - 125kHz - overflow at 500Hz
	movlb	0x0F
	movlw	b'00000010' ; prescale: 16
	movwf	T2CON		; configure Timer2 (cf. datasheet SFR T2CON)
	movlw   PWM_MOTOR_FREQUENCY
	movwf   PR2
	
	; Configuration Timer4 for use with PWM
	movlb	0x0F
	movlw	0x41
	movwf	PR4		    ; PR4 = 0x41 = 65
	movlw	b'00000000'
	movwf	T4CON
	
; CONFIGURE ADC

	; configure ADC
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
	bsf 	ADCON0,0	; ADC on

; CONFIGURE PWM
	
	; configure PWM
	movlb	0x0F
	movlw	b'00111100'	; 000011xx (PWM mode, no prescale and no postscale)
	movwf	CCP5CON

	movlw	b'01001111'		; MSB of duty cycle 30%
	movwf	CCPR5L
	bsf 	CCPTMRS,4  ; CCP5 en PWM
	
; CONFIGURE INTERRUPTS   
	
	; Interrupts configuration
	movlb	0x0F
	bcf 	PIR1,6	;Clear the AD interrupt flag
	bsf 	PIE1,6	;AD interrupt enable
	bsf 	PIE1,TMR2IE	; enable timer2 overflow interrupt
	;bsf	IPR4, TMR4IP	; high priority 
	bsf	RCON,IPEN       ; enable priority
	bsf 	INTCON,	GIE	; enable global interrupts
	bsf 	INTCON,	6	; enable peripheral interrupts
	
	; Start Timer 2
	bsf	T2CON, TMR2ON 
	
	; Start Timer 4
	bsf	T2CON, TMR4ON	
	
	return
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; low interrupt routine
low_interrupt_routine:
    
	;TODEBUG
	movlb	0x0F
	movlw	0x01
	xorwf	LATB,1	;N0
	movlb	0x01

	movlb	0x0F
	btfss	PIR1, 1	; Test timer2 overflow interrupt flag
	goto	end_if_timer2
	
	bcf 	PIR1, 1  ;Clear timer2 overflow interrupt flag

	movlb   0x01
	
	;TODEBUG
	movlb	0x0F
	movlw	0x08
	xorwf	LATB,1	;N3
	movlb	0x01

	bsf 	ADCON0,1	; ADC go

end_if_timer2:
	retfie
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; high_interrupt routine
high_interrupt_routine:
    
	;TODEBUG
	movlb	0x0F
	movlw	0x10
	xorwf	LATB,1	;N4
	movlb	0x01


	movlb	0x0F
	btfss	PIR1, 6		; Test the AD interrupt flag
	goto	end_if_ADC
	
	bcf 	PIR1, 6

pi:
	
	movf	ADRESH, W
	movlb	0x01
	movwf	DC_adch
	movlb	0x0F
	movf	ADRESL, W
	movlb	0x01
	movwf	DC_adcl
	
	; ref - adc => error
	movlb	0x01
	MOVLW	DC_REFL
	MOVWF	DC_errorl
	MOVF	DC_adcl, W
	SUBWF	DC_errorl, F
	MOVLW	DC_REFH
	MOVWF	DC_errorh
	MOVF	DC_adch, W
	SUBWFB	DC_errorh, F
	
	; Anti windup
	BTFSC   DC_errorh, 7 ;skip if clear
	GOTO    antiwindupneg
	; Positive error, check if duty == max
	BTFSC   DC_dutyflags, DC_DUTYFLAGMAX
	GOTO    end_sumerror_ki
	GOTO    sum_error
antiwindupneg:
	; Negative error, check if duty == min
	BTFSC   DC_dutyflags, DC_DUTYFLAGMIN
	GOTO    end_sumerror_ki

sum_error:
	; sumerror + error => sumerror
	MOVF 	DC_errorl, W
	ADDWF 	DC_sumerror1, F
	MOVF 	DC_errorh, W
	ADDWFC 	DC_sumerror2, F
	movlw	0x0
	BTFSC   DC_errorh, 7
	movlw   0xFF
	ADDWFC 	DC_sumerror3, F
	ADDWFC 	DC_sumerror4, F
	
end_sumerror_ki:
	
	;DC_total2 = sumerror/4 -> shift of 2 bits
	movf	DC_sumerror1, W
	movwf	DC_total1
	movf	DC_sumerror2, W
	movwf	DC_total2
	movf	DC_sumerror3, W
	movwf	DC_total3
	movf	DC_sumerror4, W
	movwf	DC_total4
	; /2
	bcf 	STATUS, C
	btfsc   DC_total4, 7
	bsf 	STATUS, C
	rrcf 	DC_total4
	rrcf 	DC_total3
	rrcf 	DC_total2
	rrcf 	DC_total1
	; /4
	bcf 	STATUS, C
	btfsc   DC_total4, 7
	bsf 	STATUS, C
	rrcf 	DC_total4
	rrcf 	DC_total3
	rrcf 	DC_total2
	rrcf 	DC_total1
	; \8
	bcf 	STATUS, C
	btfsc   DC_total4, 7
	bsf 	STATUS, C
	rrcf 	DC_total4
	rrcf 	DC_total3
	rrcf 	DC_total2
	rrcf 	DC_total1
	
	; error + sumerror/4
	MOVF 	DC_errorl, W
	ADDWF 	DC_total1, F
	MOVF 	DC_errorh, W
	ADDWFC 	DC_total2, F
	movlw	0x0
	BTFSC   DC_errorh, 7
	movlw   0xFF
	ADDWFC 	DC_total3, F
	ADDWFC 	DC_total4, F
	
	
	;total = kp*error+ki*sumerror -> shift of 5 bits
	; /2
	bcf 	STATUS, C
	btfsc   DC_total4, 7
	bsf 	STATUS, C
	rrcf 	DC_total4
	rrcf 	DC_total3
	rrcf 	DC_total2
	rrcf 	DC_total1
	; /4
	bcf 	STATUS, C
	btfsc   DC_total4, 7
	bsf 	STATUS, C
	rrcf 	DC_total4
	rrcf 	DC_total3
	rrcf 	DC_total2
	rrcf 	DC_total1
	; /8
	bcf 	STATUS, C
	btfsc   DC_total4, 7
	bsf 	STATUS, C
	rrcf 	DC_total4
	rrcf 	DC_total3
	rrcf 	DC_total2
	rrcf 	DC_total1
	; /16
	bcf 	STATUS, C
	btfsc   DC_total4, 7
	bsf 	STATUS, C
	rrcf 	DC_total4
	rrcf 	DC_total3
	rrcf 	DC_total2
	rrcf 	DC_total1
	; /32
	bcf 	STATUS, C
	btfsc   DC_total4, 7
	bsf 	STATUS, C
	rrcf 	DC_total4
	rrcf 	DC_total3
	rrcf 	DC_total2
	rrcf 	DC_total1
	; /64
	bcf 	STATUS, C
	btfsc   DC_total4, 7
	bsf 	STATUS, C
	rrcf 	DC_total4
	rrcf 	DC_total3
	rrcf 	DC_total2
	rrcf 	DC_total1
	
	movf	DC_total1, W
	movwf	DC_tmp1
	movf	DC_total2, W
	movwf	DC_tmp2
	movf	DC_total3, W
	movwf	DC_tmp3
	movf	DC_total4, W
	movwf	DC_tmp4
	
	; The final duty cycle is in tmp
	
	MOVLW	0x00
	MOVWF	DC_dutyflags
	; If negative, set to 0
	BTFSS	DC_tmp4, 7 ;skip if set
	GOTO	dutypositive
	;MOVLW 0 already done above
	MOVWF	DC_tmp1
	MOVWF	DC_tmp2
	BSF 	DC_dutyflags, DC_DUTYFLAGMIN
	
	; TODEBUG
	movlb	0x0F
	bsf 	LATB, 2	; N2
	movlb	0x01
	
	GOTO	dutycontinue
	
dutypositive:
	; Check overflow
	MOVF	DC_tmp4, F
	BNZ 	dutyoverflow
	MOVF	DC_tmp3, F
	BNZ 	dutyoverflow
	MOVLW	b'11111100' ; Duty cycle only in 10 LSB of tmp (2 LSB of DC_tmp1) since duty high = 0x01.
	ANDWF	DC_tmp2, W ; Check overflow on 5 MSB of DC_tmp1
	; TODEBUG
	movlb	0x0F
	bcf 	LATB, 2	; N2
	movlb	0x01
	BZ  	dutycontinue

dutyoverflow:
	
	MOVLW	0xFF
	MOVWF	DC_tmp1
	MOVWF	DC_tmp2
	BSF 	DC_dutyflags, DC_DUTYFLAGMAX
	; TODEBUG
	movlb	0x0F
	bsf 	LATB, 2	; N2
	movlb	0x01
	
dutycontinue:
	; PUT DUTY CYCLE IN SFR
	; Low significant bits
	
	movf	DC_tmp1, W
	movwf	DC_dutyl
	movlw 	b'00000011'
	andwf 	DC_dutyl, F
	rlncf 	DC_dutyl
	rlncf 	DC_dutyl
	rlncf 	DC_dutyl
	rlncf 	DC_dutyl ; 00110000

	movlb 	0x0F
	movlw 	b'11001111'
	andwf 	CCP5CON, F

	movlb 	0x01
	movf 	DC_dutyl, W

	movlb 	0x0F
	IORWF 	CCP5CON, F
	
	movlb 	0x01
	
 	; Most significant bits
	bcf 	STATUS, C
	rrcf 	DC_tmp2, F
	rrcf 	DC_tmp1, F
	bcf 	STATUS, C
	rrcf 	DC_tmp2, F
	rrcf 	DC_tmp1, F

	movf 	DC_tmp1, W	
	movlb 	0x0F
	movwf 	CCPR5L
	movlb 	0x01
	
pi_end:
	
	; TODEBUG
	 movlb	0x0F
	 movlw  0x02
	 xorwf  LATB, 1	; N1
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