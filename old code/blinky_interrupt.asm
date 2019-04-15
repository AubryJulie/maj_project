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
    #DEFINE	value_counter	0x04

; Set the first variable address in the RAM to 0x00
	cblock	0x20
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
    ;configuration of the GPIO
	movlb	0x0F
	bcf	TRISB,0             ; RB0 is output
	movlb	0x0F
	bsf	LATB,0              ; RB0 = 1 

    ; Configuration of clock - 4MHz - 
	movlb	0x0F
	movlw	b'01011010'
	movwf	OSCCON		    ; configure oscillator (cf datasheet SFR OSCCON)
    
    ; Configuration of Timer1 - 1MHz -
	movlb	0x0F
	movlw	b'00000000'
	movwf	T1CON		; configure Timer1 (cf. datasheet SFR T1CON)
	
	; Interrupt configuration
	movlb	0x0F
	bsf	PIE1,0	; enable timer1 overflow interrupt
	bsf	INTCON,	GIE	; enable global interrupts
	bsf	INTCON,	6	; enable peripheral interrupts
	
	; Start Timer 1
	bsf	T1CON, 0
	
	return

; Low_interrupt routine
low_interrupt_routine:
	movlb	0x0F
	btfss	PIR1, 0	; Test timer1 overflow interrupt flag
	goto	end_if_timer1
	
	bcf	PIR1, 0
	movlw   0x01
	xorwf   LATB, 1	; RB0 = !RB0

end_if_timer1:
		retfie
		
;MAIN LOOP
main_loop:
    nop
    goto    main_loop
    END