; *********************************************************** ;
;                       LOOKUP Table                          ;
;                                                             ;
;                          TEST                               ;
;                                                             ;
;                                                             ;
; *********************************************************** ;
; b1 blink.
;led N0 blinks if enter Table(RB0)
;led N1 blinks if execute the first instruction after addwf PCL (RB1)
;led N2 blinks if don't get the table number in w, don't work!(RB2)
;led N3 blinks if all goes well, good job!(RB3)
	processor	18F25K80
	#include	"config18.inc"

; define constant
W EQU 0
F EQU 1
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
	; Look_up Table 	
	org 	0100h
	
;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
TABLE
    
	;TODEBUG
	movlb	0x0F
	movlw	0x01
	xorwf	LATB, F	;Rb0 led blink ->N0
	movlb	0x01
	
	movlb	0x0F
	ADDWF	PCL,F		;!!!! cette instruction ne marche pas je ne sais pas pourquoi.
    
	;TODEBUG
	movlb	0x0F
	movlw	0x02
	xorwf	LATB, F	;Rb1 led blink ->N1
	movlb	0x01
	RETLW	0x01  ;+2
	RETLW	0x09  ;+4
	RETLW	0x08  ;+6
;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

;INITIALISATION
initialisation:

   ; Declare usefull variables begining at the first GPR  adress of bank1 in ram
	movlb	0x01
	cblock	00h
	_offset
	result
	_error
	endc
	
	;set all the variables to 0
	movlw	0x00
	movwf	_offset
	movwf	result

	; Configure Pin
	
	; Configure Port B
	movlb   0x0F
	clrf    TRISB               ; All pins of PORTB are output
	movlw   b'00000000'
	movwf   LATB                ;while RB0..7 = 0

    ; Configuration of clock - 8MHz - 
	movlb	0x0F
	movlw	b'01101010'
	movwf	OSCCON		    ; configure oscillator (cf datasheet SFR OSCCON)
	
	return
; Low_interrupt routine
low_interrupt_routine:

	retfie
	
;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!		

;MAIN LOOP
main_loop:
	movlw	0x00
	CALL	TABLE
	movlb	0x01
	movwf	_error
	btfss	_error, 1	;skip if set (skip if don't get the table number in w) 
	goto	ledb2
	bsf 	LATB, 2 	;Rb2 led blink ->N2
	goto	main_loop
ledb2:
	bsf 	LATB, 3 	;Rb3 led blink ->N3
	
    goto    main_loop
    END 


	
