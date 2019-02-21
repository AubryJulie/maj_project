; *********************************************************** ;
;                           BLINKY                            ;
;       make a LED blink at a given frequency using Timer1    ;
;                                                             ;
;       INFO0064 - Embedded Systems - Lab 1                   ;
;                                                             ;
; *********************************************************** ;

    processor	18F25K80
    #include	"config18.inc"
    #DEFINE	value_counter	0x04

; Set the first variable address in the RAM to 0x00
	cblock	0x00
	endc

; That is where the MCU will start executing the program (0x00)
	org 	0x00
	nop
	goto    start		    ; jump to the beginning of the code

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
	movlw	b'00000001'
	movwf	T1CON		; configure Timer1 (cf. datasheet SFR T1CON)
	
    ; Declare counter variable at the first GPR  adress of bank0 in ram
	movlb	0x00
	cblock	00h
	counter
	endc
	
	;set the counter
	movlw	value_counter
	movwf	counter
	
	return

;MAIN LOOP
main_loop:
    
    movlb   0x0F		
    btfss   TMR1H, 7	
    goto    main_loop

    bcf	    T1CON, 0
    clrf    TMR1H
    clrf    TMR1L
    bsf	    T1CON, 0
    
    movlb   0x00		; select bank 2
    decfsz  counter, 1	
    goto    main_loop

    movlw   value_counter
    movwf   counter		; reset the value of the counter
    
    movlb   0x0F
    movlw   0x01
    xorwf   LATB, 1		; RB0 = !RB0

    goto    main_loop
    END