; *********************************************************** ;
;                         CONTROL DC                          ;
;                      using ADC and PWM                      ;
;                                                             ;
;                                                             ;
; *********************************************************** ;
;led N0 blinks if (RB0)
;led N1 blinks if in the main(RB1)
;led N2 blinks if (RB2) 
;led N3 blinks if (RB3) 
;led N4 blinks if (RB4) 
;led N5 blinks if (RB?)
;led N6 blinks if (RA6)
;led N7 blinks if (RA7)
processor	18F25K80
#include	"config18.inc"

; -> on va utiliser des shifts!!!
;KP	= 0.04 -> 1/32 = 0.031
;Ki = 0.005 -> 1/128 = 0.0078
DUTYMAXH EQU 0x01
DUTYMAXL EQU 0x08
DUTYREFH EQU 0x00
DUTYREFL EQU 0x4D
REFH EQU	0x0D ;0x0DA7 = 3.5 V
REFL EQU	0xA7 ;
DUTYFLAGMIN EQU 0
DUTYFLAGMAX EQU 1
VALUECOUNTER EQU 1

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
	
	; Configure Pin
	
	; Configure Port B
	movlb   0x0F
	clrf    TRISB               ; All pins of PORTB are output
	movlb   0x0F
	movlw   b'00000000'
	movwf   LATB                ; RB0..7 = 0 (pin 21)

    ; Configuration of clock - 16MHz - 
	movlb	0x0F
	movlw	b'01111010'
	movwf	OSCCON		    ; configure oscillator (cf datasheet SFR OSCCON)
	;bsf 	OSCTUNE,6		; PLL enable ; 333kH (blink of the led)
	bcf 	OSCTUNE,6		; PLL enable ; 320kH
	
	return
	
main_loop:
	main_loop:
	
	; To debug
	 movlb	0x0F
	 movlw  0x02
	 xorwf  LATB, 1	; RB1 = !RB1
	 movlb	0x01
	 
    goto    main_loop
    END