; *********************************************************** ;
;                      BLINKY-INTERRUPT                       ;
;       make a LED blink at a given frequency using Timer1    ;
;                     overflow interrupt                      ;
;                                                             ;
;       INFO0064 - Embedded Systems - Lab 2                  ;
;                                                             ;
; *********************************************************** ;

    processor	18F25K80
    #include	"config18.inc"
    #DEFINE	value_counter_l	0xF4
    #DEFINE value_counter_h 0x01
    #DEFINE	frequency 0xC5
    

; Set the first variable address in the RAM to 0x00
	cblock	0x00
	endc

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
	movlb   0x01
	cblock  0x00
	counter_h	; use to have 50hz
	counter_l	; use to have 50hz
	duty
	endc
	movlw   0x00
	movwf   counter_h
	movwf   counter_l
	
    ;configuration of the GPIO
	movlb	0x0F
	bcf	TRISB,0             ; RB0 is output
	bcf	TRISB,1             ; RB1 is output
	bcf	LATB,0              ; RB0 = 0, RB0 -> PWM Hbridge(IN2)
	bsf	LATB,1              ; RB1 = 1, RB1 -> H (IN1)

    ; Configuration of clock - 8MHz - 
	movlb	0x0F
	movlw	b'01101010'
	movwf	OSCCON		    ; configure oscillator (cf datasheet SFR OSCCON)
    
    ; Configuration of Timer2 - 2MHz -
	movlb	0x0F
	movlw	b'00000000'
	movwf	T2CON		; configure Timer2 (cf. datasheet SFR T2CON)
	
	movlw   frequency
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
	movwf   duty
	
	
	return

; Low_interrupt routine
low_interrupt_routine:
	movlb	0x0F
	btfss	PIR1, 1	; Test timer2 overflow interrupt flag
	goto	end_if_timer2
	bcf	PIR1, 1  ;Clear timer2 overflow interrupt flag
	movlw   frequency
	movwf   TMR2
	movlb   0x01
	movlw   0xff
	cpfseq  counter_l  ;Skip if counter l = 0xff
	goto    not_max
	movlw   0x00
	movwf	counter_l   ;Restart counter_l to 0
	incf    counter_h,1  ; increment counter_h
	goto	end_increment
		
not_max: 
	incf    counter_l, 1
	
end_increment:
	
	retfie
		
;MAIN LOOP
main_loop:
PWM_Hbridge:
    movlb   0x01
    movlw   value_counter_h
    cpfseq  counter_h	;Skip if counter_h is equal to value_counter_h
    goto    not_equal_h
    movlw   value_counter_l
    CPFSLT  counter_l  ;Skip if counter_l is lower to value_counter_l
    goto    equal_greater_l
	goto	not_equal_l
equal_greater_l:
    movlw	0x00
    movwf	counter_l	;next periode
    movwf	counter_h

    movlb	0x0F
    bsf	LATB, 0			;RB0 is set to 1
	
not_equal_h:
	movlb	0x01
	movf	duty,0
	CPFSLT	counter_l	;Skip if duty is lower to counter_l
	goto	duty_equal
	goto	duty_not_equal
duty_equal:
	movlb	0x0F
	bcf	LATB, 0			;RB0 is set to 0

duty_not_equal: 
not_equal_l:
end_if_timer2:
    goto    main_loop
    END