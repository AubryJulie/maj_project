; *********************************************************** ;
;                  Write to flash memory                      ;
;                                                             ;
;                          TEST                               ;
;                                                             ;
;                                                             ;
; *********************************************************** ;
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

;INITIALISATION
initialisation:

   ; Declare usefull variables begining at the first GPR  adress of bank1 in ram
	movlb	0x01
	endc
	
	;set all the variables to 0
	movlw	0x00
	

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

	MOVLW SIZE_OF_BLOCK ; number of bytes in erase block
	MOVWF COUNTER
; !!! attention je ne sais pas à quoi sert ce buffer !!!
	MOVLW BUFFER_ADDR_HIGH ; point to buffer
	MOVWF FSR0H
	MOVLW BUFFER_ADDR_LOW
	MOVWF FSR0L
	MOVLW CODE_ADDR_UPPER ; Load TBLPTR with the base
	MOVWF TBLPTRU ; address of the memory block
	MOVLW CODE_ADDR_HIGH
	MOVWF TBLPTRH
	MOVLW CODE_ADDR_LOW
	MOVWF TBLPTRL
READ_BLOCK
	TBLRD*+ ; read into TABLAT, and inc
	MOVF TABLAT, W ; get data
	MOVWF POSTINC0 ; store data
	DECFSZ COUNTER ; done?
	BRA READ_BLOCK ; repeat
MODIFY_WORD
; !!! attention je ne sais pas à quoi sert ce buffer !!!
; pas compris ce qu'est FSR0H
	MOVLW DATA_ADDR_HIGH ; point to buffer
	MOVWF FSR0H
	MOVLW DATA_ADDR_LOW
	MOVWF FSR0L
	MOVLW NEW_DATA_LOW ; update buffer word
	MOVWF POSTINC0
	MOVLW NEW_DATA_HIGH
	MOVWF INDF0
; je vois pas à quoi sert le code précédent.
ERASE_BLOCK
	MOVLW CODE_ADDR_UPPER ; load TBLPTR with the base
	MOVWF TBLPTRU ; address of the memory block
	MOVLW CODE_ADDR_HIGH
	MOVWF TBLPTRH
	MOVLW CODE_ADDR_LOW
	MOVWF TBLPTRL
	BSF EECON1, EEPGD ; point to Flash program memory
	BCF EECON1, CFGS ; access Flash program memory
	BSF EECON1, WREN ; enable write to memory
	BSF EECON1, FREE ; enable Row Erase operation
	BCF INTCON, GIE ; disable interrupts
	MOVLW 55h
	MOVWF EECON2 ; write 55h
	MOVLW 0AAh
	MOVWF EECON2 ; write 0AAh
	BSF EECON1, WR ; start erase (CPU stall)
	BSF INTCON, GIE ; re-enable interrupts
	TBLRD*- ; dummy read decrement
	MOVLW BUFFER_ADDR_HIGH ; point to buffer
	MOVWF FSR0H
	MOVLW BUFFER_ADDR_LOW
	MOVWF FSR0L
WRITE_BUFFER_BACK
	MOVLW SIZE_OF_BLOCK ; number of bytes in holding register
	MOVWF COUNTER
WRITE_BYTE_TO_HREGS
	MOVFF POSTINC0, WREG ; get low byte of buffer data
	MOVWF TABLAT ; present data to table latch
	TBLWT+* ; write data, perform a short write
	; to internal TBLWT holding register.
	DECFSZ COUNTER ; loop until buffers are full
	BRA WRITE_BYTE_TO_HREGS
PROGRAM_MEMORY
	BSF EECON1, EEPGD ; point to Flash program memory
	BCF EECON1, CFGS ; access Flash program memory
	BSF EECON1, WREN ; enable write to memory
	BCF INTCON, GIE ; disable interrupts
	MOVLW 55h
	Required MOVWF EECON2 ; write 55h
	Sequence MOVLW 0AAh
	MOVWF EECON2 ; write 0AAh
	BSF EECON1, WR ; start program (CPU stall)
	BSF INTCON, GIE ; re-enable interrupts
	BCF EECON1, WREN ; disable write to memory
	
	return
; Low_interrupt routine
low_interrupt_routine:

	retfie
		
;MAIN LOOP
main_loop:
	nop
    goto    main_loop
    END 

	
