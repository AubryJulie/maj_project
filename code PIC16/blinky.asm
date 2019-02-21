; *********************************************************** ;
;                           BLINKY                            ;
;       make a LED blink at a given frequency using Timer1    ;
;                                                             ;
;       INFO0064 - Embedded Systems - Lab 1                   ;
;                                                             ;
; *********************************************************** ;

    processor 16f1789
    #include 	"config.inc"
    #DEFINE		value_counter	0x04

; Set the first variable address in the RAM to 0x20
	cblock	0x20
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
    ; configure clock
    ;configuration of the GPIO
	movlb   0x01
	clrf    TRISD               ; All pins of PORTD are output
	movlb   0x02
	movlw   b'00000001'
	movwf   LATD                ; RD0 = 1 while RD1..7 = 0;

    ;configuration of clock - ? frequency - ? source
	movlb	0x01
	movlw	b'01101110'
	movwf	OSCCON		    ; configure oscillator (cf datasheet SFR OSCCON)
	movlw	b'00000000'	    
	movwf	OSCTUNE		    ; configure oscillator (cf datasheet SFR OSCTUNE)
    
    ; Timer1 ON - ?x prescaling - ? clock source
	movlb	0x00
	movlw	b'00110001'
	movwf	T1CON               ; configure Timer1 (cf. datasheet SFR T1CON)
	
    ; Declare counter variable at the first GPR  adress of bank2 in ram
	movlb	0x02
	cblock	20h
	counter
	endc
	
	;set the counter
	movlw	value_counter
	movwf	counter
	
	return

;MAIN LOOP
main_loop:
    
    movlb   0x00		; select bank 0
    btfss   TMR1H, 7		; explain what is performed here
	goto	main_loop

    bcf	    T1CON, 0
    clrf    TMR1H
    clrf    TMR1L
    bsf	    T1CON, 0
    
    movlb   0x02		; select bank 2
    decfsz  counter, 1		; explain what is performed here
	goto	main_loop

    movlw   value_counter
    movwf   counter		; reset the value of the counter
    
    movlw   0x01
    xorwf   LATD, 1		; RD0 = !RD0

    goto    main_loop
    END