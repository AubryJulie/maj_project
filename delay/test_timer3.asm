; *********************************************************** ;
;                     overflow interrupt                      ;
;                  using timer3 every 590탎                   ;
;                                                             ;
;                                                             ;
; *********************************************************** ;
	processor	18F25K80
	#include	"config18.inc"
	
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
	clrf    TRISB               ; All pins of PORTB are output
	movlb   0x0F
	movlw   b'00000001'
	movwf   LATB                ; RB0 = 1 while RB2..7 = 0 (pin 21, 22, 23)

    ; Configuration of clock - 8MHz - 
	movlb	0x0F
	movlw	b'01101010'
	movwf	OSCCON		    ; configure oscillator (cf datasheet SFR OSCCON)
	
	; !!!!!!!!!!!configurer timer 3!!!!!!!
	; Configuration of Timer3 - 250khz (4탎) - to create an overflow interrupt every - 590탎
	movlb	0x0F
	movlw	b'00110000'
	movwf	T3CON		; configure Timer3 (cf. datasheet SFR T3CON)
	
    ; Interrupt configuration
	movlb	0x0F
	bsf	PIE2,1		;Timer3 overflow interrupt enable
	bsf	INTCON,	GIE	; enable global interrupts
	bsf	INTCON,	6	; enable peripheral interrupts
	
    ; Start Timer 3 
	movlb	0x0F
	movlw	0xFF
	movwf	TMR3H
	movlw	0x6F
	movwf	TMR3L
	bsf	T3CON, TMR3ON
	
	return
	
; Low_interrupt routine
low_interrupt_routine:
	movlb	0x0F
	btfss	PIR2, 1	; Test timer3 overflow interrupt flag
	goto	end_if_timer3
	
	bcf	PIR2, 1
	movlw   0x01
	xorwf   LATB, 1	; RB0 = !RB0
	
	; Start Timer 3
	bcf	T3CON, TMR3ON
	movlb	0x0F
	movlw	0xFF
	movwf	TMR3H	; set to create an overflow interrupt every - 590탎
	movlw	0x6F
	movwf	TMR3L
	bsf	T3CON, TMR3ON

end_if_timer3:
	retfie
		
;MAIN LOOP
main_loop:
    nop
    ; movlb   0x0F
    ; movlw   0x01
    ; xorwf   LATB, 1	; RB0 = !RB0
    goto    main_loop
    END