   ; Declare usefull variables begining at the first GPR  adress of bank0 in ram
	movlb	0x00
	cblock	00h
	timexL
	timexH
	timeyL
	timeyH
	delayxy
	xbeforey
	;set all the variables to 0
	movlw	0x00
	movwf	timexL
	movwf	timexH
	movwf	timeyL
	movwf	timeyH
	movwf	delayxy
	movwf	xbeforey

compute_delay:	;delayxy,xbeforey compute_delay(timex,timey)

	;compute the delay
	movlb	0x00
	movlw	timeyH		; w = timeyH
	CPFSGT	timexH		;if timexH > timeyH, skip
	goto	timexH<=timeyH	
	
	SUBWF	timexH,0	;w = timexH - timeyH
	CPFSLT	0x01		;if 0x01 < timexH-timeyH, skip
	goto	no_overflow_xy
	
	; an overflow occur => micx capture before micy
	movlw	timexH
	SUBLW	0xFF	;w = FF-timexH
	ADDLW	0x01	;w = FF-timexH+1
	ADDWF	timeyH,0;w = FF-timexH+1+timeyH
	CPFSLT	0x01		;if 0x01 < FF-timexH + 1 + timeyH, skip
	goto	no_error1
	
	;#error1 ; maybe light a led when it occure
	goto end_compute_delay
	
no_error1:
	movlw	timexL
	SUBLW	0xFF	;w = FF-timexL
	ADDLW	0x01	;w = FF-timexL+1
	ADDWF	timeyL,0;w = FF-timexL+1+timeyL
	CPFSLT	0x59		;if 0x59 < FF-timexL + 1 + timeyL, skip
	goto	no_error2
	
	;#error2 ; maybe light a led when it occure
	goto end_compute_delay
	
no_error2:
	;if change w in error2
	;movlw	timexL
	;SUBLW	0xFF	;w = FF-timexL
	;ADDLW	0x01	;w = FF-timexL+1
	;ADDWF	timeyL,0;w = FF-timexL+1+timeyL	
	movwf	delayxy	;delayxy = FF-timexL+1+timeyL
	bsf		xbeforey;xbeforey = 1
	goto end_compute_delay
	
no_overflow_xy:
	movlw	timeyL
	SUBLW	0xFF	;w = FF-timeyL
	ADDLW	0x01	;w = FF-timeyL+1
	ADDWF	timexL,0;w = FF-timeyL+1+timexL
	CPFSLT	0x59		;if 0x59 < FF-timeyL + 1 + timexL, skip
	goto	no_error3
	
	;#error3 ; maybe light a led when it occure
	goto end_compute_delay
	
no_error3:
	;if change w in error3
	; movlw	timeyL
	; SUBLW	0xFF	;w = FF-timeyL
	; ADDLW	0x01	;w = FF-timeyL+1
	; ADDWF	timexL,0;w = FF-timeyL+1+timexL
	movwf	delayxy	;delayxy = FF-timeyL+1+timexL
	bcf		xbeforey;xbeforey = 0
	goto end_compute_delay

timexH<=timeyH:
	movlw	timexH		;w = timexH
	CPFSGT	timeyH		;if timeyH > timexH, skip
	goto	timexH==timeyH
	
	SUBWF	timeyH,0	;w = timeyH - timexH
	CPFSLT	0x01		;if 0x01 < timeyH-timexH, skip
	goto	no_overflow_yx
	
	; an overflow occur => micy capture before micx
	movlw	timeyH
	SUBLW	0xFF	;w = FF-timeyH
	ADDLW	0x01	;w = FF-timeyH+1
	ADDWF	timexH,0;w = FF-timeyH+1+timexH
	CPFSLT	0x01	;if 0x01 < FF-timexH + 1 + timeyH, skip
	goto	no_error4
		
	;#error4 ; maybe light a led when it occure
	goto end_compute_delay
	
no_error4:
	movlw	timeyL
	SUBLW	0xFF	;w = FF-timeyL
	ADDLW	0x01	;w = FF-timeyL+1
	ADDWF	timexL,0;w = FF-timeyL+1+timexL
	CPFSLT	0x59		;if 0x59 < FF-timeyL + 1 + timexL, skip
	goto	no_error5
	
	;#error5 ; maybe light a led when it occure
	goto end_compute_delay
	
no_error5:
	;if change w in error5
	;movlw	timeyL
	;SUBLW	0xFF	;w = FF-timeyL
	;ADDLW	0x01	;w = FF-timeyL+1
	;ADDWF	timexL,0;w = FF-timeyL+1+timexL	
	movwf	delayxy	;delayxy = FF-timeyL+1+timexL
	bcf		xbeforey;xbeforey = 0
	goto end_compute_delay
	
no_overflow_yx:
	movlw	timexL
	SUBLW	0xFF	;w = FF-timexL
	ADDLW	0x01	;w = FF-timexL+1
	ADDWF	timeyL,0;w = FF-timexL+1+timeyL
	CPFSLT	0x59		;if 0x59 < FF-timexL + 1 + timeyL, skip
	goto	no_error6
	
	;#error6 ; maybe light a led when it occure
	goto end_compute_delay
	
no_error6:
	;if change w in error6
	; movlw	timexL
	; SUBLW	0xFF	;w = FF-timexL
	; ADDLW	0x01	;w = FF-timexL+1
	; ADDWF	timeyL,0;w = FF-timexL+1+timexL
	movwf	delayxy	;delayxy = FF-timexL+1+timeyL
	bsf		xbeforey;xbeforey = 1
	goto end_compute_delay
	
timexH==timeyH:
	movlw	timexL		;w = timexL
	CPFSGT	timeyL		;if timeyL > timexL, skip
	goto	timeyL<=timexL
	
	SUBWF	timeyL,0	;w = timeyL - timexL
	CPFSLT	0x59		;if 0x59 < timeyL-timexL, skip
	goto	no_error7
	
	;#error7 ; maybe light a led when it occure
	goto end_compute_delay
	
no_error7:
	;if change w in error7
	;movlw	timexL		;w = timexL
	;SUBWF	timeyL,0	;w = timeyL - timexL
	movwf	delayxy		;delayxy = timeyL - timexL
	bsf		xbeforey	;xbeforey = 1
	goto end_compute_delay
	
timeyL<=timexL:
	movlw	timeyL		;w = timeyL
	SUBWF	timexL,0	;w = timexL - timeyL
	CPFSLT	0x59		;if 0x59 < timexL-timeyL, skip
	goto	no_error8
	
	;#error8 ; maybe light a led when it occure
	goto end_compute_delay
	
no_error8:
	;if change w in error8
	;movlw	timeyL		;w = timeyL
	;SUBWF	timexL,0	;w = timexL - timeyL
	movwf	delayxy		;delayxy = timexL - timeyL
	bcf		xbeforey	;xbeforey = 0
end_compute_delay:
	return
