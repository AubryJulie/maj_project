; *********************************************************** ;
;                       LOOKUP Table                          ;
;                                                             ;
;                          TEST                               ;
;                                                             ;
;                                                             ;
; *********************************************************** ;
; b1 blink.
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

; Look_up Table 	
	org 	0200h
TABLE:
	ADDWF PCL
	RETLW 0x01
	RETLW 0x02	;if this value led b1 blink
	RETLW 0x04	;if this value led b2 blink

;BEGINNING OF THE PROGRAM
start:
	call	initialisation      ; initialisation routine configuring the MCU
	goto	main_loop           ; main loop

;INITIALISATION
initialisation:

   ; Declare usefull variables begining at the first GPR  adress of bank1 in ram
	movlb	0x01
	_offset
	result
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

;look_up_routine:
		
;MAIN LOOP
main_loop:

	movlw 0x00
	movwf TBLPTRU
	movlw 0x10
	movwf TBLPTRH
	movlw 0x02
	movwf TBLPTRL

	TBLRD*+
	MOVF TABLAT, W
	MOVWF WORD_EVEN
	TBLRD*+
	MOVF TABLAT, W
	MOVF WORD_ODD

	xorwf	LATB, F 	; b1 = !b1
	
    ; goto    main_loop
    
    END 

org 0x1000
    
    da 0x02, 0x04, 0x08

END