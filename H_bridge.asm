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
	bcf	TRISB,1             ; RB1 is output
	bcf	LATB,0              ; RB0 = 0, RB0 -> PWM Hbridge(IN2)
	bsf	LATB,1              ; RB1 = 1, RB1 -> H (IN1)

    ; Configuration of clock - 8MHz - 
	movlb	0x0F
	movlw	b'01101010'
	movwf	OSCCON		    ; configure oscillator (cf datasheet SFR OSCCON)
    return
    
;MAIN LOOP
main_loop:
	nop
    goto    main_loop
    END