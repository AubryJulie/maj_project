; PIC18F45K80 Configuration Bit Settings

; Assembly source line config statements

#include "p18f25k80.inc"

; CONFIG1L
  CONFIG  RETEN = OFF           ; VREG Sleep Enable bit (Ultra low-power regulator is Disabled (Controlled by REGSLP bit))
  CONFIG  INTOSCSEL = HIGH      ; LF-INTOSC Low-power Enable bit (LF-INTOSC in High-power mode during Sleep)
  CONFIG  SOSCSEL = DIG        ; SOSC Power Selection and mode Configuration bits (High Power SOSC circuit selected)
  CONFIG  XINST = ON            ; Extended Instruction Set (Enabled)

; CONFIG1H
  CONFIG  FOSC = INTIO2         ; Oscillator (Internal RC oscillator)
  CONFIG  PLLCFG = OFF          ; PLL x4 Enable bit (Disabled)
  CONFIG  FCMEN = ON            ; Fail-Safe Clock Monitor (Enabled)
  CONFIG  IESO = OFF            ; Internal External Oscillator Switch Over Mode (Disabled)

; CONFIG2L
  CONFIG  PWRTEN = OFF          ; Power Up Timer (Disabled)
  CONFIG  BOREN = SBORDIS       ; Brown Out Detect (Enabled in hardware, SBOREN disabled)
  CONFIG  BORV = 3              ; Brown-out Reset Voltage bits (1.8V)
  CONFIG  BORPWR = ZPBORMV      ; BORMV Power level (ZPBORMV instead of BORMV is selected)

; CONFIG2H
  CONFIG  WDTEN = OFF           ; Watchdog Timer (WDT disabled in hardware; SWDTEN bit disabled)
  CONFIG  WDTPS = 1048576       ; Watchdog Postscaler (1:1048576)

; CONFIG3H
  CONFIG  CANMX = PORTB         ; ECAN Mux bit (ECAN TX and RX pins are located on RB2 and RB3, respectively)
  CONFIG  MSSPMSK = MSK7        ; MSSP address masking (7 Bit address masking mode)
  CONFIG  MCLRE = OFF           ; Master Clear Enable (MCLR Disabled, RE3 Enabled)

; CONFIG4L
  CONFIG  STVREN = ON           ; Stack Overflow Reset (Enabled)
  CONFIG  BBSIZ = BB2K          ; Boot Block Size (2K word Boot Block size)

; CONFIG5L
  CONFIG  CP0 = OFF             ; Code Protect 00800-01FFF (Disabled)
  CONFIG  CP1 = OFF             ; Code Protect 02000-03FFF (Disabled)
  CONFIG  CP2 = OFF             ; Code Protect 04000-05FFF (Disabled)
  CONFIG  CP3 = OFF             ; Code Protect 06000-07FFF (Disabled)

; CONFIG5H
  CONFIG  CPB = OFF             ; Code Protect Boot (Disabled)
  CONFIG  CPD = OFF             ; Data EE Read Protect (Disabled)

; CONFIG6L
  CONFIG  WRT0 = OFF            ; Table Write Protect 00800-01FFF (Disabled)
  CONFIG  WRT1 = OFF            ; Table Write Protect 02000-03FFF (Disabled)
  CONFIG  WRT2 = OFF            ; Table Write Protect 04000-05FFF (Disabled)
  CONFIG  WRT3 = OFF            ; Table Write Protect 06000-07FFF (Disabled)

; CONFIG6H
  CONFIG  WRTC = OFF            ; Config. Write Protect (Disabled)
  CONFIG  WRTB = OFF            ; Table Write Protect Boot (Disabled)
  CONFIG  WRTD = OFF            ; Data EE Write Protect (Disabled)

; CONFIG7L
  CONFIG  EBTR0 = OFF           ; Table Read Protect 00800-01FFF (Disabled)
  CONFIG  EBTR1 = OFF           ; Table Read Protect 02000-03FFF (Disabled)
  CONFIG  EBTR2 = OFF           ; Table Read Protect 04000-05FFF (Disabled)
  CONFIG  EBTR3 = OFF           ; Table Read Protect 06000-07FFF (Disabled)

; CONFIG7H
  CONFIG  EBTRB = OFF           ; Table Read Protect Boot (Disabled)
