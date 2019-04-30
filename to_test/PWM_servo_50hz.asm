; *********************************************************** ;
;                          PWM_servo                          ;
;        Send a PWM signal at 50hz to the servo motor.        ;
;                                                             ;
; *********************************************************** ;
;THERE ARE VERY STANGE BEHAVIOURS
;led N0 : PWM (RB0) 
;led N1 : blinks when timer2 overflow (RB1)
;led N2 : must blink at 25Hz(RB2)
;led N3 : (RB3)
;led N4 : (RB4)
;led N5 : (RC4)
;led N6 : (RA6)
;led N7 : (RA3) !!!!!!! bruitée
;!!!!!TMR2 overflow 500Hz!!!!!
    processor	18F25K80
    #include	"config18.inc"
    
; define constant
W EQU 0
F EQU 1
IS_SET EQU 0
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
	; Declare usefull variables begining at the first GPR  adress of bank1 in ram
	movlb   0x01
	cblock  0x00
	PWM_servo_duty_timer
	PWM_servo_duty_counter
	PWM_servo_dif_timer
	PWM_servo_dif_counter
	PWM_servo_counter
	PWM_servo_config	;bit0: is_set
	
	endc
	
	;set all the variables to 0
	movlw   0x00
	movwf   PWM_servo_duty_timer
	movwf   PWM_servo_duty_counter
	movwf	PWM_servo_dif_timer
	movwf	PWM_servo_dif_counter
	movwf	PWM_servo_counter
	movwf	PWM_servo_config
    ; Configure Pin
	
	; Configure Port C 
	;configure CCP pin as input
	;RC2/CCP2, RC6/CCP3 and RC7/CCP4 (pin 13, 17, 18)
	movlb	0x0F
	movlw	b'11000100' 
	movwf	TRISC		    ; All pins of PORTC are outputs except RC2,RC6,RC7
	clrf 	LATC                
	
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
    
    ; Configuration of Timer2 - 2MHz - overflow at 500Hz
	movlb	0x0F
	movlw	b'00000010' ; prescale: 16
	movwf	T2CON		; configure Timer2 (cf. datasheet SFR T2CON)
	
	movlw   PWM_MOTOR_FREQUENCY
	movwf   PR2
	
	; Interrupt configuration
	movlb	0x0F
	bsf	PIE1,1	; enable timer2 overflow interrupt
	bsf	INTCON,	GIE	; enable global interrupts
	bsf	INTCON,	6	; enable peripheral interrupts
	
	; Start Timer 2
	bsf	T2CON, 2 
	
	; Set duty cycle
	movlb   0x01
	movlw   0xC8         ;45   max (sens trigo)  ;11   min (sens aiguille); 26 medium
	movwf   PWM_servo_duty_timer
	movlw   0x00
	movwf	PWM_servo_duty_counter
	
	
	return
;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
; Low_interrupt routine
low_interrupt_routine:
	movlb	0x0F
	btfss	PIR1, 1	; Test timer2 overflow interrupt flag
	goto	end_if_timer2
	
	bcf 	PIR1, 1  ;Clear timer2 overflow interrupt flag

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
	movlb   0x0F
	movlw	0x04
	xorwf	LATB, F 	; N2
	movlb   0x01
	
	;TODEBUG
	movlb	0x0F
	bsf 	LATB, 3		; N3
	movlb   0x01
	
	bsf 	PWM_servo_config, IS_SET
	; set the PWM
	movlb	0x0F
	bsf	LATC, 0		
	movlb	0x01
	
end_if_timer2:

	retfie
;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!		
;MAIN LOOP
main_loop:

PWM_servo:
	; check for duty
	movlb   0x01
	; duty_counter > counter
	MOVF	PWM_servo_duty_counter, W
	CPFSGT	PWM_servo_counter ; skip if counter > duty_counter
	goto 	PWM_servo_counter_greather_or_equal_duty
	
PWM_servo_clear:
	btfss	PWM_servo_config, IS_SET	;skip if set
	goto	PWM_servo_end
	; clear the PWM
	movlb	0x0F
	bcf 	LATB, 3		; N3
	movlb   0x01

	movlb	0x0F
	bcf	LATC, 0		
	movlb	0x01
	
	bcf 	PWM_servo_config, IS_SET
	
	goto	PWM_servo_end

PWM_servo_counter_greather_or_equal_duty:
	MOVF	PWM_servo_counter, W
	CPFSEQ	PWM_servo_duty_counter	;skip if duty_counter = counter
	goto	PWM_servo_not_equal
	
	; duty_timer < timer
	movlb   0x0F
	bcf	T2CON, 2
	MOVF	TMR2, W
	bsf	T2CON, 2
	movlb   0x01
	CPFSGT	PWM_servo_duty_timer ; skip if duty_timer > timer
	goto 	PWM_servo_clear
	
PWM_servo_not_equal:
;!!!WHEN I retrieve the DEBUG it does very stange thinks
	
PWM_servo_end:
    goto    main_loop
    END