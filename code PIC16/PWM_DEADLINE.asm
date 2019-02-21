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
	goto    start		    ; jump to the beginning of the code
	
; That is where the MCU will start executing the program (0x00)
	org 	0x04
	nop
	goto    interrupt_routine   ; jump to the interrupt routine

;BEGINNING OF THE PROGRAM
start:
	call	initialisation      ; initialisation routine configuring the MCU
	goto	main_loop           ; main loop

;INITIALISATION
initialisation:

	; Configure Port C
    movlb 0x01
    movlw b'11111011' 
	movwf TRISC		    ; All pins of PORTC are input except RC2
    
    movlb 0x02
    movlw b'00000000'
    movwf LATC			    ; RC0..7 = 0;

    ; Configuration of clock - 4MHz - prescaler 1
	movlb	0x01
	movlw	b'01101110'
	movwf	OSCCON		    ; configure oscillator (cf datasheet SFR OSCCON)
	movlw	b'00000000'	    
	movwf	OSCTUNE		    ; configure oscillator (cf datasheet SFR OSCTUNE)
    
	; Configuration Timer2 for use with PWM
	movlb 0x00
	movlw 67
	movwf PR2		    ; PR2 = 67

	; Setup PWM
	movlb 0x05
	movlw b'00001100'	; 000011xx (PWM mode, no prescale and no postscale)
	movwf CCP1CON

	movlw 20		; MSB of duty cycle value 20
	movwf CCPR1L

	; Run timer2
	movlb 0x00
	movlw b'00000100'
	movwf T2CON

    ; Timer1 ON 
	movlb	0x00
	movlw	b'00110000'
	movwf	T1CON		; configure Timer1 (cf. datasheet SFR T1CON)
	
    ; Interrupt configuration
	movlb	0x01
	bsf	PIE1,	TMR1IE	; enable timer 1 interruts
	bsf	INTCON,	GIE	; enable global interrupts
	bsf	INTCON,	6	; enable peripheral interrupts
	
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
	movlb 0x00    
	btfss	PIR1, TMR1IF ; Test Timer 1 interrupt flag
	goto end_if_timer1
	
	bcf	PIR1, TMR1IF
	
	; Reset timer 1 for 12500 ticks
	bcf	T1CON, TMR1ON
	movlw	0xCF
	movwf	TMR1H
	movlw	0x2B
	movwf	TMR1L
	bsf	T1CON, TMR1ON

	movlb 0x05
	movlw 16
	subwf CCPR1L	    ; Duty cycle decremented by 16

    end_if_timer1:
    
    retfie

;MAIN LOOP
main_loop:
    nop
    goto    main_loop
    END