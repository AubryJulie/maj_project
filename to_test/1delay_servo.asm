; *********************************************************** ;
;                           DELAY                             ;
;                     compute the delay                       ;
;                   between 2 microphones                     ;
;                                                             ;
; *********************************************************** ;
; *********************************************************** ;
;                          PWM_servo                          ;
;        Send a PWM signal at 50hz to the servo motor.        ;
;                                                             ;
; *********************************************************** ;
;micro1 = pin 13
;micro2 = pin 17
;led N0 : blinks when timer1 overflow (RB0) ok
;led N1 : blinks when timer2 overflow (RB1) ok
;led N2 : blinks when computation of delay(RB2) ok
;led N3 : PWM (RB3) ok
;led N4 : blinks when computation of delay_enable.(RB4)ok
;led N5 :
;led N6 :
;led N7 :

;IN COMMENT FOR THE MOMENT
;!!!;led N0 : bit0 of delay(RB0)
;!!!;led N1 : bit1 of delay(RB1)
;!!!;led N2 : bit2 of delay(RB2)
;!!!;led N3 : bit3 of delay(RB3)
;!!!;led N4 : bit4 of delay(RB4)
;!!!;led N5 : bit5 of delay(RC4)
;!!!;led N6 : bit6 of delay(RA6)
;!!!;led N7 : bit7 of delay(RA3) !!!!!!! bruitée
; trick: devide the delay by 2 to have a step of 8Âµs instead of 4Âµs
	processor	18F25K80
	#include	"config18.inc"

; DEFINE CONSTANTS
W EQU 0
F EQU 1

; for delay computation
DELAY_1BEFORE2 EQU 0
DELAY_2BEFORE3 EQU 1
DELAY_3BEFORE1 EQU 2
DELAY_ENABLE1 EQU 3
DELAY_ENABLE2 EQU 4
DELAY_ENABLE3 EQU 5
DELAY_xBEFOREy EQU 6
DELAY_ENABLE_COMPUTATION EQU 7
DELAY_ELAPSEL EQU 0x94
DELAY_ELAPSEH EQU 0x00
DELAY_VALUE_COUNTER EQU 0x0A

; timer3 set up
TIMER3L EQU 0x6F
TIMER3H EQU 0xFF

; for PWM servo-motor
PWM_SERVO_IS_SET EQU 0
PWM_SERVO_VALUE_COUNTER EQU 0x0A ;50hz
PWM_MOTOR_FREQUENCY EQU 0xF8 

; Set the first variable address in the RAM to 0x00
	cblock	0x00
	endc

; That is where the MCU will start executing the program (0x00)
	org 	0x00
	nop
	goto    start		    ; jump to the beginning of the code
	
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

   ; Declare usefull variables begining at the first GPR adress of bank1 in ram
	movlb	0x01
	cblock	00h
	DELAY_time1L
	DELAY_time1H
	DELAY_time2L
	DELAY_time2H
	DELAY_delay12L
	DELAY_delay12H
	DELAY_config ;bit0 = _1before2, bit1 = _2before3, bit2 = _3before1,
				 ;bit3 = enable1, bit4 = enable2, bit5 = enable3, bit6
				 ; = xbeforey, bit7 = enable_computation_delay
	DELAY_timexL
	DELAY_timexH
	DELAY_timeyL
	DELAY_timeyH
	DELAY_delayxyL
	DELAY_delayxyH
	DELAY_check_enable
	DELAY_errorL
	DELAY_errorH
	DELAY_counter
	PWM_servo_duty_timer
	PWM_servo_duty_counter
	PWM_servo_dif_timer
	PWM_servo_dif_counter
	PWM_servo_counter
	PWM_servo_config	;bit0 = is_set
	endc
	
	;set all the variables to 0
	movlw	0x00
	movwf	DELAY_time1L
	movwf	DELAY_time1H
	movwf	DELAY_time2L
	movwf	DELAY_time2H
	movwf	DELAY_delay12L
	movwf	DELAY_delay12H
	movwf	DELAY_config
	movwf	DELAY_timexL
	movwf	DELAY_timexH
	movwf	DELAY_timeyL
	movwf	DELAY_timeyH
	movwf	DELAY_delayxyL
	movwf	DELAY_delayxyH
	movwf	DELAY_errorL
	movwf	DELAY_errorH
	movwf	DELAY_check_enable
	movwf	DELAY_counter
	movwf   PWM_servo_duty_timer
	movwf   PWM_servo_duty_counter
	movwf	PWM_servo_dif_timer
	movwf	PWM_servo_dif_counter
	movwf	PWM_servo_counter
	movwf	PWM_servo_config
	
; CONFIGURE PIN
	
	; Configure Port C 
	;configure CCP pin as input
	;RC2/CCP2, RC6/CCP3 and RC7/CCP4 (pin 13, 17, 18)
	movlb	0x0F
	movlw	b'11000100' 
	movwf	TRISC		    ; All pins of PORTC are outputs except RC2,RC6,RC7
	clrf 	LATC                ;while RB0..7 = 0
	
	; Configure Port B
	movlb   0x0F
	clrf    TRISB               ; All pins of PORTB are output
	clrf    LATB                ;while RB0..7 = 0
	
	; Configure Port A
	movlb   0x0F
	movlw	b'00000001'
	movwf   TRISA               ; All pins of PORTA are output except RA0
	clrf    LATA                ;while RB0..7 = 0

; CONFIGURE CLOCK AND TIMERS

	; Configuration of clock - 8MHz - 
	movlb	0x0F
	movlw	b'01101010'
	movwf	OSCCON		    ; configure oscillator (cf datasheet SFR OSCCON)
	
    ; Configuration of Timer1 - 250kHz - 4Âµs
	movlb	0x0F
	movlw	b'00110000'
	movwf	T1CON		; configure Timer1 (cf. datasheet SFR T1CON)
		
    ; Configuration of Timer2 - 125kHz - overflow at 500Hz
	movlb	0x0F
	movlw	b'00000010' ; prescale: 16
	movwf	T2CON		; configure Timer2 (cf. datasheet SFR T2CON)
	movlw   PWM_MOTOR_FREQUENCY
	movwf   PR2
	
	; Configuration of Timer3 - 250khz - 4Âµs to create an overflow interrupt every - 590Âµs
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
;	movlw	b'00000101'
;	movwf	CCP4CON		;Capture mode: every rising edge
	movlw	b'00000000'
	movwf	CCPTMRS		;CCP 2, 3 and 4 is based off of TMR1
	
    ; Interrupt configuration
	movlb	0x0F
	bsf 	PIE1,TMR1IE	; enable timer1 overflow interrupt
	bsf 	PIE1,TMR2IE	; enable timer2 overflow interrupt
	bsf 	PIE2,TMR3IE	;Timer3 overflow interrupt enable
	bsf 	PIE3,2	;CCP2 interrupt enable  
	bsf 	PIE4,0	;CCP3 interrupt enable
	;bsf 	PIE4,1	;CCP4 interrupt enable
	bsf 	INTCON,	GIE	; enable global interrupts
	bsf 	INTCON,	6	; enable peripheral interrupts

	; Start Timer 2
	bsf	T2CON, TMR2ON 
	
	; Start Timer 1
	bsf	T1CON, TMR1ON
	
	; Set duty cycle
	movlb   0x01
	movlw   0xC8         ;45   max (sens trigo)  ;11   min (sens aiguille); 26 medium
	movwf   PWM_servo_duty_timer
	movlw   0x00
	movwf	PWM_servo_duty_counter
	
	return
;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!	
; The value of delay(Âµs)= delayxy*8
compute_delay:	;delayxy,xbeforey compute_delay(timex,timey)

	;compute the delay
	; delay = timex-timey
	movlb	0x01
	MOVF	DELAY_timexL, W
	MOVWF	DELAY_delayxyL
	MOVF	DELAY_timeyL, W
	SUBWF	DELAY_delayxyL, F
	MOVF	DELAY_timexH, W
	MOVWF	DELAY_delayxyH
	MOVF	DELAY_timeyH, W
	SUBWFB	DELAY_delayxyH, F
	
	; If negative
	BTFSS 	DELAY_delayxyH, 7 ;skip if set
	goto 	delay_pos
	bcf 	DELAY_config, DELAY_xBEFOREy ;xbeforey = 0
	;if delay < -148
	;		!!!error
	;error = delay+149	(don't use CPFSLT because it's unsigned operation)
	MOVF	DELAY_delayxyL, W
	MOVWF	DELAY_errorL
	MOVLW	DELAY_ELAPSEL
	ADDWF	DELAY_errorL, F
	MOVF	DELAY_delayxyH, W
	MOVWF	DELAY_errorH
	MOVLW	DELAY_ELAPSEH
	ADDWFC	DELAY_errorH, F
	; If error < 0 -> error
	BTFSS 	DELAY_errorH, 7 ;skip if set
	goto 	end_compute_delay
    
	; ;TODEBUG
	; movlb	0x0F
	; bsf	LATB, 0	;Rb0 led blink ->N0
	; movlb	0x01
	
	goto	end_compute_delay
	
delay_pos:

	bsf 	DELAY_config, DELAY_xBEFOREy ;xbeforey = 0
	; to debug
	;if delay > 148
	;		!!!error
	MOVLW	DELAY_ELAPSEL
	CPFSLT	DELAY_delayxyL	; Skip if f < W
	goto	_error
	MOVLW	DELAY_ELAPSEH
	CPFSLT	DELAY_delayxyH	; Skip if f < W
	goto	_error
	goto 	end_compute_delay
_error:
    
	; ;TODEBUG
	; movlb	0x0F
	; bsf	LATB, 0	;Rb0 led blink ->N0
	; movlb	0x01
	
	
end_compute_delay:
	; trick: devide the delay by 2 to have a step of 8Âµs instead of 4Âµs
	; /2
	bcf 	STATUS, C
	btfsc   DELAY_delayxyH, 7
	bsf 	STATUS, C
	rrcf 	DELAY_delayxyH
	rrcf 	DELAY_delayxyL
	return
	
;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!	
; Low_interrupt routine
low_interrupt_routine:

	movlb	0x0F
	btfss	PIR1, TMR1IF	; Test timer1 overflow interrupt flag
	goto	end_if_timer1
	
	bcf 	PIR1, TMR1IF  ;Clear timer1 overflow interrupt flag
	
	;TODEBUG
	movlb   0x0F
	movlw	0x01
	xorwf	LATB, F 	; N0
	movlb   0x01
	
end_if_timer1:

	movlb	0x0F
	btfss	PIR1, TMR2IF	; Test timer2 overflow interrupt flag
	goto	end_if_timer2
	
	bcf 	PIR1, TMR2IF  ;Clear timer2 overflow interrupt flag

	movlb   0x01
	
	;TODEBUG
	movlb   0x0F
	movlw	0x02
	xorwf	LATB, F 	; N1
	movlb   0x01
	
	; servo_counter += 1
	INCF	PWM_servo_counter, F
	MOVLW	PWM_SERVO_VALUE_COUNTER
	CPFSEQ	PWM_servo_counter	;skip if equal
	goto	end_if_timer2
	CLRF	PWM_servo_counter
	
	;TODEBUG
	movlb	0x0F
	bsf 	LATB, 3		; N3
	movlb   0x01
	
	bsf 	PWM_servo_config, PWM_SERVO_IS_SET
	; set the PWM
	movlb	0x0F
	bsf 	LATC, 0		
	movlb	0x01
	
	; DELAY_counter += 1
	INCF	DELAY_counter, F
	MOVLW	DELAY_VALUE_COUNTER
	CPFSEQ	DELAY_counter	;skip if equal
	goto	end_if_timer2
	CLRF	DELAY_counter
	
	;TODEBUG
	movlb   0x0F
	movlw	0x10
	xorwf	LATB, F 	; N4
	movlb   0x01
	
	bsf 	DELAY_config, DELAY_ENABLE_COMPUTATION
	
end_if_timer2:

	movlb	0x0F
	btfss	PIR2, TMR3IF	; Test timer3 overflow interrupt flag
	goto	end_if_timer3
	
	bcf 	PIR2, TMR3IF

	movlb	0x01
	; enable1 & enable2 both = 0 ou 1 ->stop timer, else reset.
	btfsc	DELAY_config, DELAY_ENABLE1	; Test enable1 (if enable1 == 0, skip)
	goto	enable1_set
	movlw	0x00
	goto	DELAY_check_enable2
	
enable1_set:
	movlw	0x10	;enable2 = 4bits of DELAY_config
	
DELAY_check_enable2:
	xorwf	DELAY_config, W	; Test enable2 (if enable2 == 0, skip)
	movwf	DELAY_check_enable
	btfsc	DELAY_check_enable, 4	; if enable1 == enable2 skip
	goto	reset_enables
	goto	stop_timer3
; reset when only 1 of the 2 microphones has recieved a signal.
reset_enables:
    
	bcf	DELAY_config, DELAY_ENABLE1	; enable1 = 0
	bcf	DELAY_config, DELAY_ENABLE2	; enable2 = 0
	
stop_timer3:
	; Stop Timer 3
	movlb	0x0F
	bcf	T3CON, TMR3ON
	
end_if_timer3:

	movlb	0x0F
	btfss	PIR3, CCP2IF	; Test CCP2 interrupt flag
	goto	end_if_CCP2
	
	bcf 	PIR3, CCP2IF
	
	movlb	0x01
	btfsc	DELAY_config, DELAY_ENABLE1	; Test enable1 (if enable1 == 0, skip)
	goto	end_if_CCP2
	
	btfsc	DELAY_config, DELAY_ENABLE2	; Test enable2 (if enable2 == 0, skip)
	goto	no_timer3_1
	
	;if(!enable1 && !enable2)
	; !!!!begin timer3 #overflow after 590Âµs
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
	movwf	DELAY_time1L
	movlb	0x0F
	movf	CCPR2H,W
	movlb	0x01
	movwf	DELAY_time1H
	bsf 	DELAY_config, DELAY_ENABLE1	; enable1 = 1	
	
end_if_CCP2:

	movlb	0x0F
	btfss	PIR4, CCP3IF	; Test CCP3 interrupt flag
	goto	end_if_CCP3
	
	bcf 	PIR4, CCP3IF
	
	movlb	0x01
	btfsc	DELAY_config, DELAY_ENABLE2	; Test enable2 (if enable2 == 0, skip)
	goto	end_if_CCP3
	
	btfsc	DELAY_config, DELAY_ENABLE1	; Test enable1 (if enable1 == 0, skip)
	goto	no_timer3_2
	
	;if(!enable1 && !enable3)
	; !!!!begin timer3 #overflow aprÃ¨s 590Âµs
	; Start Timer 3
	movlb	0x0F
	bcf	T3CON, TMR3ON
	movlw	TIMER3H
	movwf	TMR3H
	movlw	TIMER3L
	movwf	TMR3L
	bsf 	T3CON, TMR3ON
	
no_timer3_2:	
	movlb	0x0F
	movf	CCPR3L, W
	movlb	0x01
	movwf	DELAY_time2L
	movlb	0x0F
	movf	CCPR3H, W
	movlb	0x01
	movwf	DELAY_time2H
	bsf 	DELAY_config, DELAY_ENABLE2	; enable2 = 1
	
end_if_CCP3:	
		retfie
		
;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
		
;MAIN LOOP
main_loop:

	btfss	DELAY_config, DELAY_ENABLE_COMPUTATION 	;skip if set
	goto	not_enable_delay
	
computation_delay:
	
	;TODEBUG
	movlb   0x0F
	movlw	0x04
	xorwf	LATB, F 	; N2
	movlb   0x01
	
	movlb	0x01
	; if (enable1 && enable2)
	btfss	DELAY_config, DELAY_ENABLE1	; Test enable1 (if enable1 == 1, skip)
	goto	end_delay
	
	btfss	DELAY_config, DELAY_ENABLE2	; Test enable2 (if enable2 == 1, skip)
	goto	end_delay
	
	;delay12,1before2 = compute_delay(time1,time2)
	MOVF	DELAY_time1L, W
	MOVWF	DELAY_timexL
	MOVF	DELAY_time1H, W
	MOVWF	DELAY_timexH
	MOVF	DELAY_time2L, W
	MOVWF	DELAY_timeyL
	MOVF	DELAY_time2H, W
	MOVWF	DELAY_timeyH
	call	compute_delay
	MOVF	DELAY_delayxyL, W
	MOVWF	DELAY_delay12L
	MOVF	DELAY_delayxyH, W
	MOVWF	DELAY_delay12H
	bsf 	DELAY_config, DELAY_1BEFORE2
	btfss 	DELAY_config, DELAY_xBEFOREy ;skip if set
	bcf 	DELAY_config, DELAY_1BEFORE2
	
;	; to debug
;	btfsc	DELAY_config, DELAY_1BEFORE2 ;skip if clear
;	goto	led_set
;	
;	movlb	0x0F
;	bcf 	LATC, 4 ;Rc4 led blink ->N5
;	goto	end_led
;	
;led_set:
;	movlb	0x0F
;	bsf 	LATC, 4 ;Rc4 led blink ->N5
;end_led:
;	movlb	0x01
	
	;!!! use delay to compute angle and distance
	
; The section below enable to see the delay compute (hight part of the delay)
;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!	
	; ;TODEBUG
	; btfsc	DELAY_delay12H, 0 ;skip if clear
	; goto	led_set0
	
	; movlb	0x0F
	; bcf 	LATB, 0 ;Rb0 led blink ->N0
	; goto	end_led0
	
; led_set0:
	; movlb	0x0F
	; bsf 	LATB, 0 ;Rb0 led blink ->N0
; end_led0:
	; movlb	0x01
	
	; ;TODEBUG
	; btfsc	DELAY_delay12H, 1 ;skip if clear
	; goto	led_set1
	
	; movlb	0x0F
	; bcf 	LATB, 1 ;Rb1 led blink ->N1
	; goto	end_led1
	
; led_set1:
	; movlb	0x0F
	; bsf 	LATB, 1 ;Rb1 led blink ->N1
; end_led1:
	; movlb	0x01
	
	; ;TODEBUG
	; btfsc	DELAY_delay12H, 2 ;skip if clear
	; goto	led_set2
	
	; movlb	0x0F
	; bcf 	LATB, 2 ;Rb2 led blink ->N2
	; goto	end_led2
	
; led_set2:
	; movlb	0x0F
	; bsf 	LATB, 2 ;Rb2 led blink ->N2
; end_led2:
	; movlb	0x01
	
	; ;TODEBUG
	; btfsc	DELAY_delay12H, 3 ;skip if clear
	; goto	led_set3
	
	; movlb	0x0F
	; bcf 	LATB, 3 ;Rb3 led blink ->N3
	; goto	end_led3
	
; led_set3:
	; movlb	0x0F
	; bsf 	LATB, 3 ;Rb3 led blink ->N3
; end_led3:
	; movlb	0x01
	
	; ;TODEBUG
	; btfsc	DELAY_delay12H, 4 ;skip if clear
	; goto	led_set4
	
	; movlb	0x0F
	; bcf 	LATB, 4 ;Rb4 led blink ->N4
	; goto	end_led4
	
; led_set4:
	; movlb	0x0F
	; bsf 	LATB, 4 ;Rb0 led blink ->N4
; end_led4:
	; movlb	0x01
	
	; ;TODEBUG
	; btfsc	DELAY_delay12H, 5 ;skip if clear
	; goto	led_set5
	
	; movlb	0x0F
	; bcf 	LATC, 4 ;Rc4 led blink ->N5
	; goto	end_led5
	
; led_set5:
	; movlb	0x0F
	; bsf 	LATC, 4 ;Rc4 led blink ->N5
; end_led5:
	; movlb	0x01
		
	; ;TODEBUG
	; btfsc	DELAY_delay12H, 6 ;skip if clear
	; goto	led_set6
	
	; movlb	0x0F
	; bcf 	LATA, 6 ;Ra6 led blink ->N6
	; goto	end_led6
	
; led_set6:
	; movlb	0x0F
	; bsf 	LATA, 6 ;Ra6 led blink ->N6
; end_led6:
	; movlb	0x01
		
	; ;TODEBUG
	; btfsc	DELAY_delay12H, 7 ;skip if clear
	; goto	led_set7
	
	; movlb	0x0F
	; bcf 	LATA, 3 ;Ra3 led blink ->N7
	; goto	end_led7
	
; led_set7:
	; movlb	0x0F
	; bsf 	LATA, 3 ;Ra3 led blink ->N7
; end_led7:
	; movlb	0x01
;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!	
	; Stop Timer3
	movlb	0x0F
	bcf	T3CON, TMR3ON
	
	;enable1,enable2,enable3 = 0
	movlw	b'11000111'
	ANDWF	DELAY_config,F
end_delay:
	bcf	DELAY_config, DELAY_ENABLE_COMPUTATION
	
not_enable_delay:

PWM_servo:
	; check for duty
	movlb   0x01
	; duty_counter > counter
	MOVF	PWM_servo_duty_counter, W
	CPFSGT	PWM_servo_counter ; skip if counter > duty_counter
	goto 	PWM_servo_counter_greather_or_equal_duty
	
PWM_servo_clear:
	btfss	PWM_servo_config, PWM_SERVO_IS_SET	;skip if set
	goto	PWM_servo_end
	; clear the PWM
	movlb	0x0F
	bcf 	LATB, 3		; N3
	movlb   0x01

	movlb	0x0F
	bcf	LATC, 0		
	movlb	0x01
	
	bcf 	PWM_servo_config, PWM_SERVO_IS_SET
	
	goto	PWM_servo_end

PWM_servo_counter_greather_or_equal_duty:
	MOVF	PWM_servo_counter, W
	CPFSEQ	PWM_servo_duty_counter	;skip if duty_counter = counter
	goto	PWM_servo_end
	
	; duty_timer < timer
	movlb   0x0F
	MOVF	TMR2, W
	CPFSGT	PWM_servo_duty_timer ; skip if duty_timer > timer
	goto 	PWM_servo_clear
	
PWM_servo_end:
    goto    main_loop
    END