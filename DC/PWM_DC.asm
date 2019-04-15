; *********************************************************** ;
;    MOSFET                ;
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
	
	; Configure Port B
	movlb   0x0F
	clrf    TRISB               ; All pins of PORTB are output
	movlb   0x0F
	movlw   b'00000001'
	movwf   LATB                ; RB0 = 1 while RB2..7 = 0 (pin 21)
	; Configure Port C 
	;configure CCP pin
	;RC2/CCP2, RC6/CCP3 and RC7/CCP4 (pin 13, 17, 18)
	;!!!TRISC initiate to 11111111 at the start
    ;movlb 0x0F
    ;movlw b'11111111' 
	;movwf TRISC		    ; All pins of PORTC are input
	
	; Configure Port B
	movlb   0x0F
	movlw b'11011110'
	movwf    TRISB               ; All pins of PORTB are input except RB0 and RB5
	 

    ; Configuration of clock - 8MHz - prescaler 1
	movlb	0x0F
	movlw	b'01101010'
	movwf	OSCCON		    ; configure oscillator (cf datasheet SFR OSCCON)
	;movlw	b'00000000'	    
	;movwf	OSCTUNE		    ; configure oscillator (cf datasheet SFR OSCTUNE)
    
	; Configuration Timer4 for use with PWM
	movlb 0x0F
	movlw 41
	movwf PR4		    ; PR4 = 41 1001101
	movlw	b'00000000'
	movwf	T4CON
	
	; Setup PWM
	movlb 0x0F
	movlw b'00011100'	; 000011xx (PWM mode, no prescale and no postscale)
	movwf CCP5CON

	movlw b'0010011'		; MSB of duty cycle 
	movwf CCPR5L
	bsf CCPTMRS,4  ; CCP5 en PWM

	; Run timer4
	movlb 0x0F
	bsf T4CON,2

  
	
    ; Interrupt configuration
	movlb	0x0F
	bsf	PIE4,	TMR4IE	; enable timer 4 overflow interrupts  ,
	;bsf    IPR4, TMR4IP    ; high priority !!! on sait pas à quoi ça sert
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
	movlw   0x01
	xorwf   LATB, 1	; RB0 = !RB0

end_if_timer4:
		retfie
;MAIN LOOP
main_loop:
    nop
    goto    main_loop
    END