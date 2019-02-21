; *********************************************************** ;
;                           Skeleton                          ;
;       Make Timer 1 trigger an interrupt after 100ms	      ;
;                                                             ;
;       INFO0064 - Embedded Systems - Lab 3                   ;
;                                                             ;
; *********************************************************** ;

processor 16f1789
#include 	"config.inc"

; That is where the MCU will start executing the program (0x00)
	org 	0x00
	nop
	goto    start		    	; jump to the beginning of the code
	
; That is where the MCU will start executing the interrupt (0x04)
	org 	0x04
	nop
	goto    interrupt_routine   ; jump to the interrupt routine

;BEGINNING OF THE PROGRAM
start:
	call	initialisation      ; initialisation routine configuring the MCU
	goto	main_loop           ; main loop

;INITIALISATION
initialisation:

    ; Configuration of clock - 4MHz - internal 
	movlb	0x01
	movlw	b'01101110'
	movwf	OSCCON		    	; configure oscillator (cf datasheet SFR OSCCON)
	movlw	b'00000000'	    
	movwf	OSCTUNE		    	; configure oscillator (cf datasheet SFR OSCTUNE)
    
    ; Timer1 ON - ?x prescaling - ? clock source
	movlb	0x00
	movlw	b'00110000'
	movwf	T1CON               ; configure Timer1 (cf. datasheet SFR T1CON)
	
	; Pin configuration
	movlb   0x01
	movlw	b'00000010'	
	movwf   TRISD               ; All pins of PORTD are output exept RD1
	movlb   0x02
	movlw   b'00000000'
	movwf   LATD                ; RD0..7 = 0;
	movlb   0x03
	bsf 	ANSELD,1	    ; RD1 is an analog input
	
    ; ADC configuration
	movlb   0x01
	movlw	b'01000000'
	movwf	ADCON1				; Sign-magnitude format, FOSC/4, VREF+=VDD, VREF-=VSS
	movlw	b'00001111'
	movwf	ADCON2				; Auto-conversion Disabled, ADC Negative reference=VSS
	movlw	b'11010101'
	movwf	ADCON0				; 10-bits, channel 21, ADC enabled
	
    ; Interrupt configuration
    movlb 	0x00
	bcf	PIR1, 0					; clear TMR1IF before interrupts enabling
	clrf	TMR1L				; clear TMR1F before interrupts enabling
	clrf	TMR1H				; clear TMR1H before interrupts enabling
	movlb	0x01
	bsf	PIE1,	TMR1IE			; enable timer 1 interrupts
	movlb	0x00
	bsf	INTCON,	GIE				; enable global interrupts
	bsf	INTCON,	6				; enable peripheral interrupts
	movlb	0x01
	bsf	PIE1, 6					; enable ADC interrupt
	
    ; Start Timer 1 for 100ms period (12500 ticks)
	movlb	0x00
	movlw	0xCF
	movwf	TMR1H
	movlw	0x2B
	movwf	TMR1L
	bsf	T1CON, TMR1ON
	
	return
	
; Interrupt routine
interrupt_routine:
    movlb 	0x00    
    btfss	PIR1, TMR1IF 		; Test Timer 1 interrupt flag
	goto 	end_if_timer1
	
	bcf	PIR1, TMR1IF
	movlb	0x02
	movlb   0x01
	bsf		ADCON0, 0 			; Turn ADC on		
	bsf		ADCON0, 1			; Start conversion
	btfsc	ADCON0,ADGO
	goto $-1
	bcf		ADCON0, 0 			; Turn ADC off
	
	; Reset timer 1 for 12500 ticks
	movlb 	0x00 
	bcf	T1CON, TMR1ON
	movlw	0xCF
	movwf	TMR1H
	movlw	0x2B
	movwf	TMR1L
	bsf	T1CON, TMR1ON

    end_if_timer1:
    
	movlb	0x00
	btfss	PIR1, 6 			; Test ADC interrupt flag
	goto 	end_if_ADC
	
	bcf	PIR1, 6
	
	movlb 	0x01
	BTFSC 	ADRESH, 7			; ADRESH > 127
	goto 	high_value
	movlb   0x02
	bcf	LATD, 0				;RD0 = 0
	goto end_if_ADC
	
	high_value:
	movlb   0x02
	bsf	LATD, 0				;RD0 = 1
	
	end_if_ADC:
    retfie		

;MAIN LOOP
main_loop:
    nop
    goto    main_loop
    END