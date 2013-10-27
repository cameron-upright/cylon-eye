#include "p12f615.inc"
	list p=12f615 		; Set the processor
; 	__config (_HS_OSC & _WDT_OFF & _PWRTE_ON & _MCLRE_OFF & _CP_OFF)
	__config (_INTRC_OSC_NOCLKOUT & _WDT_OFF & _PWRTE_ON & _MCLRE_OFF & _CP_OFF & _IOSCFS8)

CBLOCK 0x40
	;; CCP Stuff
	captureRising
	risingTimeH
	risingTimeL
	fallingTimeH
	fallingTimeL
	lowBorrow
	speedH
	speedL
	speed
	enableEye ; Seems to no longer be used...

	;; LED Stuff
	timerCount
	timerCount2
	timerDelay
	led
	currentLed
	direction

	;; Interrupt Stuff
	W_TEMP
	STATUS_TEMP
ENDC

CaptureRising	equ	b'00000101'
CaptureFalling	equ	b'00000100'

; Program load
	ORG 	0x000
	GOTO 	Init


; Interrupt
	ORG 	0x004

	MOVWF	W_TEMP			; Store W
	SWAPF	STATUS, W
	MOVWF	STATUS_TEMP		; Store status

	BCF	STATUS, RP0
	
	BCF	PIR1, CCP1IF		; Clear the interrupt for CCP1

	BTFSS	captureRising, 0 	;
	GOTO	FallingPulsePhase	; if (captureRising<0> == 0)
	GOTO	RisingPulsePhase	; else

FallingPulsePhase
	MOVF	CCPR1H, W		;
	MOVWF	fallingTimeH		;
	MOVF	CCPR1L, W		;
	MOVWF	fallingTimeL		; Capture the time of the fall

	BSF	captureRising, 0 	; Switch to rising pulse phase

	CLRF	CCP1CON			;
	MOVLW	CaptureRising		;
	MOVWF	CCP1CON			; Capture rising edges

	GOTO	EndInterrupt

RisingPulsePhase
	MOVF	CCPR1H, W		;
	MOVWF	risingTimeH		;
	MOVF	CCPR1L, W		;
	MOVWF	risingTimeL		; Capture the time of the raise

	;; Perform subtraction of [risingTimeH|risingTimeL] - [fallingTimeH|fallingTimeL]
	CLRF	lowBorrow		; Clear out the variable that tracks if the low resulted in a carry
	MOVF	fallingTimeL, W
	SUBWF	risingTimeL, F		; risingTimeL -= fallingTimeL
	BTFSS	STATUS, C		; !borrow
	INCF	lowBorrow, F		; if (borrowed), increment low borrow (set to 1)
	MOVF	fallingTimeH, W
	SUBWF	risingTimeH, F		; risingTimeH -= fallingTimeH
	MOVF	lowBorrow, W
	SUBWF	risingTimeH, F		; risingTimeH -= lowBorrow

	MOVF	risingTimeH, W
	MOVWF	speedH
	MOVF	risingTimeL, W
	MOVWF	speedL

	
	BCF	STATUS, C
	RRF	speedH, F
	RRF	speedL, F		; [speedH:speedL] /= 2



	MOVLW	d'20'
	SUBWF	speedL, W		; W = speedL - 20
	SUBLW	d'250'			; W = 250 - W
	
	MOVWF	speed			; speed = W
	BCF	STATUS, C
	RLF	speed, F		; speed = min(speed*2, 255)

	MOVLW	0xFF
	BTFSC	STATUS, C
	MOVWF	speed


	
	MOVLW	0x8C
	SUBWF	speedL, W		; W = risingTimeH - 0x0C
	BTFSS	STATUS, C		; !borrow (risingTime >= 0x0C)
	GOTO	SwitchOff		; risingTime < 0x0C
	BSF	enableEye, 0
	GOTO	SwitchEnd
SwitchOff
	BCF	enableEye, 0
SwitchEnd

	BCF	captureRising, 0 	; Switch to falling pulse phase

	CLRF	CCP1CON			;
	MOVLW	CaptureFalling		;
	MOVWF	CCP1CON			; Capture falling edges


EndInterrupt

	SWAPF	STATUS_TEMP, W
	MOVWF	STATUS			; Restore status
	SWAPF	W_TEMP, F
	SWAPF	W_TEMP, W		; Restore W
	
	RETFIE





	
Init
	BSF	STATUS, RP0		; Bank 1
	CLRF 	ANSEL			; Digital I/O
	BCF	STATUS, RP0		; Bank 0
	MOVLW	d'01'
	MOVWF	currentLed
	MOVLW	h'FF'
	MOVWF	direction

	CALL	TurnOffEye


	MOVLW	d'01'
	MOVWF	timerCount
	MOVWF	timerCount2

	MOVLW	h'FF'
	MOVWF	timerDelay

	CLRF	enableEye


InitCCP
 	MOVLW	b'00110001'		; 1:1 prescalar, timer1 on
 	MOVWF	T1CON
	BSF	STATUS, RP0		; Bank 1
	MOVLW	b'11000000'		;
	MOVWF	INTCON			; Global and peripheral interrupts on
	MOVLW	b'00100000'		; 
	MOVWF	PIE1			; CCP1 interrupts enabled
	BCF	STATUS, RP0		; Bank 0
	CLRF	CCP1CON			;
	MOVLW	CaptureFalling		;
	MOVWF	CCP1CON			; Capture falling edges
	BCF	captureRising, 0 	; Switch to falling pulse phase

	
	
MainLoop

	DECFSZ	timerCount, F
	GOTO	MainLoop
	DECFSZ	timerCount2, F
	GOTO	MainLoop

	MOVF	speed, W
	MOVWF	timerCount2

;	BTFSC	enableEye, 0
;	GOTO	RunEye
;	CALL	TurnOffEye
; 	GOTO	MainLoop


RunEye
 	MOVF	currentLed, W		; Turn on the selected LED
	CALL	TurnOnLED

	MOVF	direction, F		; Check the direction
	BTFSS	STATUS, Z		;
	GOTO	IncreasingDir		; If dirfection != 0
	GOTO	DecreasingDir		; If direction == 0

IncreasingDir
	INCF	currentLed, F
	MOVF	currentLed, W
	SUBLW	d'12'
	BTFSC	STATUS, Z
	GOTO	SwitchDir
	GOTO	EndLEDLoop

DecreasingDir
	DECF	currentLed, F
	MOVF	currentLed, W
	SUBLW	d'01'
	BTFSC	STATUS, Z
	GOTO	SwitchDir
	GOTO	EndLEDLoop

SwitchDir
	COMF	direction, F

EndLEDLoop
	GOTO	MainLoop		; Start the next phase











	
;; TODO : I should use some sort of lookup table
TurnOnLED
	MOVWF	led			; Save the led index in LED
				
	MOVF	led, W
	SUBLW	d'01'
	BTFSC	STATUS, Z		; if led == 1
	GOTO	TurnOnLED0

	MOVF	led, W
	SUBLW	d'02'
	BTFSC	STATUS, Z		; if led == 2
	GOTO	TurnOnLED1

	MOVF	led, W
	SUBLW	d'03'
	BTFSC	STATUS, Z		; if led == 3
	GOTO	TurnOnLED2

	MOVF	led, W
	SUBLW	d'04'
	BTFSC	STATUS, Z		; if led == 4
	GOTO	TurnOnLED3

	MOVF	led, W
	SUBLW	d'05'
	BTFSC	STATUS, Z		; if led == 5
	GOTO	TurnOnLED4

	MOVF	led, W
	SUBLW	d'06'
	BTFSC	STATUS, Z		; if led == 6
	GOTO	TurnOnLED5

	MOVF	led, W
	SUBLW	d'07'
	BTFSC	STATUS, Z		; if led == 7
	GOTO	TurnOnLED6

	MOVF	led, W
	SUBLW	d'08'
	BTFSC	STATUS, Z		; if led == 8
	GOTO	TurnOnLED7

	MOVF	led, W
	SUBLW	d'09'
	BTFSC	STATUS, Z		; if led == 9
	GOTO	TurnOnLED8

	MOVF	led, W
	SUBLW	d'10'
	BTFSC	STATUS, Z		; if led == 10
	GOTO	TurnOnLED9

	MOVF	led, W
	SUBLW	d'11'
	BTFSC	STATUS, Z		; if led == 11
	GOTO	TurnOnLED10

	MOVF	led, W
	SUBLW	d'12'
	BTFSC	STATUS, Z		; if led == 12
	GOTO	TurnOnLED11

	RETURN



TurnOffEye
	BSF	STATUS, RP0
	MOVLW	b'11111111'
	MOVWF	TRISIO
	BCF	STATUS, RP0
	MOVLW	b'00000000'
	MOVWF	GPIO
	RETURN


TurnOnLED0
	BSF	STATUS, RP0
	MOVLW	b'11111100'
	MOVWF	TRISIO
	BCF	STATUS, RP0
	MOVLW	b'00000001'
	MOVWF	GPIO
	RETURN

	
TurnOnLED1
	BSF	STATUS, RP0
	MOVLW	b'11111100'
	MOVWF	TRISIO
	BCF	STATUS, RP0
	MOVLW	b'00000010'
	MOVWF	GPIO
	RETURN

TurnOnLED2
	BSF	STATUS, RP0
	MOVLW	b'11011110'
	MOVWF	TRISIO
	BCF	STATUS, RP0
	MOVLW	b'00000001'
	MOVWF	GPIO
	RETURN
	
TurnOnLED3
	BSF	STATUS, RP0
	MOVLW	b'11011110'
	MOVWF	TRISIO
	BCF	STATUS, RP0
	MOVLW	b'00100000'
	MOVWF	GPIO
	RETURN
	
TurnOnLED4
	BSF	STATUS, RP0
	MOVLW	b'11101110'
	MOVWF	TRISIO
	BCF	STATUS, RP0
	MOVLW	b'00000001'
	MOVWF	GPIO
	RETURN
	
TurnOnLED5
	BSF	STATUS, RP0
	MOVLW	b'11101110'
	MOVWF	TRISIO
	BCF	STATUS, RP0
	MOVLW	b'00010000'
	MOVWF	GPIO
	RETURN
	
TurnOnLED6
	BSF	STATUS, RP0
	MOVLW	b'11011101'
	MOVWF	TRISIO
	BCF	STATUS, RP0
	MOVLW	b'00000010'
	MOVWF	GPIO
	RETURN
	
TurnOnLED7
	BSF	STATUS, RP0
	MOVLW	b'11011101'
	MOVWF	TRISIO
	BCF	STATUS, RP0
	MOVLW	b'00100000'
	MOVWF	GPIO
	RETURN
	
TurnOnLED8
	BSF	STATUS, RP0
	MOVLW	b'11101101'
	MOVWF	TRISIO
	BCF	STATUS, RP0
	MOVLW	b'00000010'
	MOVWF	GPIO
	RETURN
	
TurnOnLED9
	BSF	STATUS, RP0
	MOVLW	b'11101101'
	MOVWF	TRISIO
 	BCF	STATUS, RP0
	MOVLW	b'00010000'
	MOVWF	GPIO
	RETURN

TurnOnLED10
	BSF	STATUS, RP0
	MOVLW	b'11001111'
	MOVWF	TRISIO
	BCF	STATUS, RP0
	MOVLW	b'00100000'
	MOVWF	GPIO
	RETURN
	
TurnOnLED11
	BSF	STATUS, RP0

	MOVLW	b'11001111'
	MOVWF	TRISIO
	BCF	STATUS, RP0
	MOVLW	b'00010000'
	MOVWF	GPIO
	RETURN



END
