; *********************************************************** ;
;                          PWM_servo                          ;
;        Send a PWM signal at 50hz to the servo motor.        ;
;                 increment the PWM of the servo              ;
;                                                             ;
; *********************************************************** ;
;led N0 : PWM (RB0) 
;led N1 : blinks when timer2 overflow (RB1)
;led N2 : sets when duty > counter(RB2)
;led N3 : sets when value_counter > counter(RB3)
;led N4 : (RB4)
;led N5 : (RC4)
;led N6 : (RA6)
;led N7 : (RA3) !!!!!!! bruitÃ©e
;!!!!!TMR2 overflow 26khz!!!!! trop rapide pour le pi
    processor	18F25K80
    #include	"config18.inc"
    
; define constant
W EQU 0
F EQU 1
PWM_SERVO_VALUE_COUNTER_L EQU 0xF4 ;500 steps
PWM_SERVO_VALUE_COUNTER_H EQU 0x01
PWM_MOTOR_FREQUENCY EQU 0xC0 ;50hz
MAX_VALUE_PWM_SERVO_OFFSET EQU 0x4E

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
	movlb   0x01
	cblock  0x00
	PWM_servo_counter_h
	PWM_servo_counter_l
	PWM_servo_duty
	PWM_servo_counter_dif_h
	PWM_servo_counter_dif_l
	PWM_servo_offset
	PWM_servo_result
	endc
	
	;set all the variables to 0
	movlw   0x00
	movwf   PWM_servo_counter_h
	movwf   PWM_servo_counter_l
	movwf	PWM_servo_duty
	movwf	PWM_servo_counter_dif_h
	movwf	PWM_servo_counter_dif_l
	movwf	PWM_servo_offset
	movwf	PWM_servo_result
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
    
    ; Configuration of Timer2 - 2MHz - overflow at 26khz
	movlb	0x0F
	movlw	b'00000000'
	movwf	T2CON		; configure Timer2 (cf. datasheet SFR T2CON)
	
	movlw   PWM_MOTOR_FREQUENCY
	movwf   TMR2
	
	; Interrupt configuration
	movlb	0x0F
	bsf	PIE1,1	; enable timer2 overflow interrupt
	bsf	INTCON,	GIE	; enable global interrupts
	bsf	INTCON,	6	; enable peripheral interrupts
	
	; Start Timer 1
	bsf	T2CON, 2 
	
	; Set duty cycle
	movlb   0x01
	movlw   0x26         ;45   max (sens trigo)  ;11   min (sens aiguille); 26 medium
	movwf   PWM_servo_duty
	
	
	return
;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
; Low_interrupt routine
low_interrupt_routine:
	movlb	0x0F
	btfss	PIR1, 1	; Test timer2 overflow interrupt flag
	goto	end_if_timer2
	
	bcf 	PIR1, 1  ;Clear timer2 overflow interrupt flag
	movlw   PWM_MOTOR_FREQUENCY
	movwf   TMR2
	movlb   0x01
	
	;TODEBUG
	movlb   0x0F
	movlw	0x02
	xorwf	LATB, F 	; N1
	movlb   0x01
	
	; servo_counter += 1
	MOVLW	0x01
	ADDWF	PWM_servo_counter_l, F
	MOVLW	0x00
	ADDWFC	PWM_servo_counter_h, F
	
end_if_timer2:

	retfie
;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!		
;MAIN LOOP
main_loop:
PWM_servo_read_look_up_table:
	movlw	0x00
	movwf	TBLPTRU
	movlw	0x10
	movwf	TBLPTRH
	movlw	PWM_servo_offset
	movwf	TBLPTRL

	TBLRD*+
	MOVF	TABLAT, W
	MOVWF	PWM_servo_duty
	
	movlw	MAX_VALUE_PWM_SERVO_OFFSET
	CPFSEQ	PWM_servo_offset		 ;Skip if offset=max_value_offset
	goto	PWM_servo_offset_add_2
	movlw	0x00
	ADDWF	PWM_servo_offset, F
	goto	PWM_servo
	
PWM_servo_offset_add_2:
	; offset+2
	movlw	0x02
	ADDWF	PWM_servo_offset, F
	
PWM_servo:
	; check for duty
	; if counter-duty >= 0 -> clear the pin, check for periode
	movlb   0x01
	; counter_dif = counter-duty
	MOVF	PWM_servo_counter_l, W
	MOVWF	PWM_servo_counter_dif_l
	MOVF	PWM_servo_duty, W
	SUBWF	PWM_servo_counter_dif_l, F
	MOVF	PWM_servo_counter_h, W
	MOVWF	PWM_servo_counter_dif_h
	MOVLW	0x00
	SUBWFB	PWM_servo_counter_dif_h, F
	
	btfsc	PWM_servo_counter_dif_h,7 ; skip if clear
	goto 	PWM_servo_less_then_duty
	
	;TODEBUG
	movlb   0x0F
	bsf	LATB, 2 	; N2
	movlb   0x01
	
	; duty < counter
	movlb	0x0F
	bcf 	LATB, 0		; N0
	movlb   0x01
	
	movlb	0x0F
	bcf	LATC, 0		
	movlb	0x01
	
	; check for periode
	; if counter-value_counter >= 0 -> reset counter, set the pin(next periode)
	; counter_dif = counter-value_counter
	MOVF	PWM_servo_counter_l, W
	MOVWF	PWM_servo_counter_dif_l
	MOVLW	PWM_SERVO_VALUE_COUNTER_L
	SUBWF	PWM_servo_counter_dif_l, F
	MOVF	PWM_servo_counter_h, W
	MOVWF	PWM_servo_counter_dif_h
	MOVLW	PWM_SERVO_VALUE_COUNTER_H
	SUBWFB	PWM_servo_counter_dif_h, F
	
	btfsc	PWM_servo_counter_dif_h,7 ; skip if clear
	goto 	PWM_servo_less_then_periode

	;TODEBUG
	movlb   0x0F
	bsf	LATB, 3 	; N3
	movlb   0x01
	
	; value_counter < counter
	; reset counter, set the pin(next periode)
	movlw	0x00
	movwf	PWM_servo_counter_l	;next periode
	movwf	PWM_servo_counter_h

	movlb	0x0F
	bsf 	LATB, 0		;N0
	movlb	0x01
	
	movlb	0x0F
	bsf	LATC, 0		
	movlb	0x01
	goto    PWM_servo_end
PWM_servo_less_then_duty:
    
	;TODEBUG
	movlb   0x0F
	bcf	LATB, 2 	; N2
	movlb   0x01
	
PWM_servo_less_then_periode:
	;TODEBUG
	movlb   0x0F
	bcf	LATB, 3 	; N3
	movlb   0x01
	goto	PWM_servo_end
	
PWM_servo_end:
    goto    main_loop
;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!	
org 0x1000
    
;!!! je n'ai mis que 1 0x33 -> tout les delay > 0x27 vont à la dernière valeur
    da 0x28, 0x28, 0x29, 0x29, 0x29, 0x29, 0x2A, 0x2A, 0x2A, 0x2A, 0x2B, 0x2B, 0x2B, 0x2B, 0x2C, 0x2C, 0x2C, 0x2C, 0x2D, 0x2D, 0x2D, 0x2E, 0x2E, 0x2E, 0x2E, 0x2F, 0x2F, 0x2F, 0x2F, 0x30, 0x30, 0x30, 0x31, 0x31, 0x31, 0x31, 0x32, 0x32, 0x32, 0x33 
    END
