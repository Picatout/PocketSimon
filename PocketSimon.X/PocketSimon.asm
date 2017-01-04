; NAME: PocketSimon
; DESC:  simon game implemented on a PIC10F202
; COPYRIGHT: jacques Deschenes, 2012,2016  
; LICENCE: GPLv3    
; DATE: 2012-03-05
; REVISION: 2016-12-31    
; VERSION: 1.1
; 
; GAME:  4 LEDs associated with 4 notes. A sequence of notes must be repeated by
; the player. At success a new note is appended at the end of sequence.
; After 6, 12, 18, 24 and 32 notes success a tune is played. The maximun length of
; sequence is 32 notes. A player that succeed to replay the full 32 notes sequence
; hear the complete victory tune after what the game start over.
; At end of each game the length of sequence is displayed.
; The display work like this:
;  BLUE LED is 25
;  YELLOW LED is 10
;  RED LED is 5
;  GREEN LED is 1
; length=NB*25+NY*10+NR*5+NG
;  where Nx is the number of blink for each color.    
; At first error the game is over and a MCU wait for a new set.
; At power on the MCU run a Power On Self Test, which consist of lighting 
; the 4 LEDs sequencially while sounding the associated note. 
; After POST the 4 LEDs light in loop until the player press a
; button to start game. 
;
; DESCRIPTION: the purpose of this project is to demonstrate the use of a single
; logic I/O to read many switches using a capacitor charging time.
; The game use 4 switches that are all connected  to a resistors ladder. The bottom
; of this ladder is connected to a capacitor and to the GP3 input. The time it take
; for this capacitor to charge to a logic 1 level depend on which button is pressed.    
; Four LEDs of different colour are connected to GP0 and GP1
; The audio output is to GP2
; a PNP small switching transistor is used to drive an 150 ohm speaker
; Another NPN small signal transistor is also connected GP2. This one is used
; to discharge the switches timing capacitor. As the 2 transistors are controlled by
; the same I/O as an inconvinience.    
; The inconvience of this design is that when reading buttons a noise is heard in speaker.
; I consider this to be a small inconvience.
; This design connect 2 LEDs in series from V+ to ground and consequently works only
; with a 3 volt power supply. For a voltage over 3 volt a permanent current path is
; formed through diodes GREEN, RED and YELLOW, BLUE and the LEDs are always ligthed.
; But with a 3 volt power supply it works fine because the conduction voltage of 2 LEDs
; in series in over 3 volts.
; see schematic for detail.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;This program is free software: you can redistribute it and/or modify
;    it under the terms of the GNU General Public License as published by
;    the Free Software Foundation, either version 3 of the License, or
;    (at your option) any later version.
;
;    This program is distributed in the hope that it will be useful,
;    but WITHOUT ANY WARRANTY; without even the implied warranty of
;    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;    GNU General Public License for more details.
;
;    You should have received a copy of the GNU General Public License
;    along with this program.  If not, see <http://www.gnu.org/licenses/>.    
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    
    include P10F202.INC
    radix dec
    
    __config _MCLRE_OFF & _CP_OFF & _WDTE_OFF  ; Watchdog disabled
                                               ;'master clear' disabled
                                               ; no code protection

    errorlevel 2 ; warning disabled

;;;;;;    MCU option mask ;;;;;;;;;;;;;;;;;;;;
#define OPTION_MASK B'01000001';bit7=0, wakeup on I/O change
                               ;bit6=1, pullup disabled
                               ;bit5=0, timer0 clock -> Fosc/4.
                               ;bit4=0, 
                               ;bti3=0, prescale on TIMER0
                               ;bit2-0=001, prescale 1:4
                               ;  TIMR0 increment every 4usec.



#define RED_GREEN_TRIS   B'1001'
#define YELLOW_BLUE_TRIS B'1010'
#define RED_GPIO         B'1011'
#define GREEN_GPIO       B'1001'
#define YELLOW_GPIO      B'1010'
#define BLUE_GPIO        B'1001'

#define GREEN  0
#define RED    1
#define YELLOW 2
#define BLUE   3

#define BTN_GREEN  0
#define BTN_RED    1
#define BTN_YELLOW 2
#define BTN_BLUE   3
#define BTN_NONE   4

; note for each color
#define GREEN_NOTE   B'01000000'
#define RED_NOTE B'01000101'
#define YELLOW_NOTE    B'01001001'
#define BLUE_NOTE  B'01001100'

; values for muical pauses
#define THIRTY2TH B'10111111'
#define SIXTEENTH B'10011111'
#define HEIGHT    B'01111111'
#define QUARTER   B'01011111'
#define HALF      B'00111111'
#define WHOLE     B'00011111'

#define AUDIO  GPIO, GP2
#define CLAMP GPIO, GP2

; charging time delay
; this is adjusted by testing
; It may vary due to components
; tolerance.
; When pressing RED button if
; GREEN LED turn on increase
; GRN_CNT value.
; On the contrary if YELLOW LED
; turn on decrease GRN_CNT value.			       
#define GRN_CNT 20
#define RED_CNT 2*GRN_CNT
#define YEL_CNT 3*GRN_CNT
#define BLUE_CNT 4*GRN_CNT
#define TC_MAX 5*GRN_CNT

;;;;;;;;;;;;    MACROS  ;;;;;;;;;;;;;;;;;;;;;;


led_off macro
 movlw B'1011'
 tris GPIO
 endm

note_off macro
 bsf AUDIO
 endm

note_on macro
 bcf AUDIO
 endm

clamp_on macro
 bsf CLAMP
 endm

clamp_off macro
 bcf CLAMP
 endm

brz macro address  ; branch on zero flag
 skpnz
 goto address
 endm

brnz macro address ; branch on not zero flag
 skpz
 goto address
 endm

brc macro address ; branch on carry flag
 skpnc
 goto address
 endm

brnc macro address ; branch on not carry flag
 skpc
 goto address
 endm

skpeq macro var, val ; skip next instruction if variable == val
  movlw val
  xorwf var, W
  skpz
  endm

skpneq macro var, val ; skip next instruction if variable!=val
 movlw val
 xorwf var, W
 skpnz
 endm


; switch marco
switch macro var ; put variable in W for use by following case
 movfw var
 endm

case macro  n, address  ; go to address if W==n
 xorlw n
 brz address
 xorlw n ; reset W for next case
 endm


loadr16 macro r16, n  ; load r16 with constant
 local h,l
 h=high n
 l=low n
 if l==0
   clrf r16
 else
   movlw low n
   movwf r16
 endif
 if h==0
   clrf r16+1
 else
   movlw h
   movwf r16+1
 endif
 endm

;;;;;;;;;;;;;;;; VARIABLES  ;;;;;;;;;;;;;;;;;;;;;
    udata
  btn_down res 1  ; which button is down
  led res 1 ; active led value
  delay res 2 ; delay counter used by delay_ms subroutine.
  half_period res 1 ; note half-period delay
  timeout res 2 ; inactivity timeout
  cap_cnt res 1 ; capacitor charge time
  notes_cnt res 1 ; sequence length
  rand res 3 ; pseudo random number generator register
  tune_array res 8 ; note sequence array maximun 32 notes. 2 bits used per note.
  t0 res 1 ; temporary storage
  t1 res 1 
  t2 res 1
  t3 res 1

  code 
;;;;;;;;;;;;;;;;;;; CODE SEGMENT ;;;;;;;;;;;;;;;;;;
    org 0
 goto init

;;;;;;;;;;    delay_ms  ;;;;;;;;;;;;;;;;;;
; delay in miliseconds
; delay = value in msec
#define delayH delay+1
delay_ms:
 movlw .7
 movwf TMR0
 movfw TMR0
 skpz
 goto $-2
 movlw 1
 subwf delay,F
 skpc
 subwf delayH,F
 skpnc
 goto delay_ms
 return
 

translate_table: ;translate button to corresponding note
 addwf PCL, F
 dt GREEN_NOTE
 dt RED_NOTE
 dt YELLOW_NOTE
 dt BLUE_NOTE

note_table: ; tempered scale
 addwf PCL, F
 dt .254  ; G3     blue note (0)
 dt .240  ; G#3
 dt .226  ; A3
 dt .214  ; A#3
 dt .201  ; B3
 dt .190  ; C4     yellow note (5)
 dt .179  ; C#4
 dt .169  ; D4
 dt .160  ; D#4
 dt .151  ; E4     red note (9)
 dt .142  ; F4
 dt .134  ; F#4
 dt .127  ; G4     green note (12)
 dt .119  ; G#4
 dt .113  ; A4
 dt .106  ; A#4
 dt .100  ; B4
 dt .95   ; C5
 dt .89   ; C#5
 dt .84   ; D5
 dt .79   ; D#5
 dt .75   ; E5
 dt .71   ; F5
 dt .67   ; F#5
 dt .63   ; G5

; rocky 1 movie theme 
rocky_theme:
 addwf PCL,F
 dt B'10001001' ; 16e
 dt B'01101011' ; 8g
 dt B'10011111' ; 16p
 dt B'00101110' ; 2a
 dt B'01111111' ; 8p
 dt B'10001110' ; 16a
 dt B'01110000' ; 8b
 dt B'10011111' ; 16p
 dt B'00101001' ; 2e
 dt B'10011111' ; 16p
 dt B'10111111' ; 32p
 dt B'10001001' ; 16e
 dt B'01101011' ; 8g
 dt B'10011111' ; 16p
 dt B'00101110' ; 2a
 dt B'10011111' ; 16p
 dt B'10111111' ; 32p
 dt B'10001110' ; 16a
 dt B'01110000' ; 8b
 dt B'10011111' ; 16p
 dt B'00001001' ; 1e
 dt B'01111111' ; 8p
 dt B'10011111' ; 16p
 dt B'10000111' ; 16d4
 dt B'10000101' ; 16c4
 dt B'01100111' ; 8d4
 dt B'10011111' ; 16p
 dt B'10010001' ; 16c5
 dt B'10010011' ; 16d5
 dt B'01010101' ; 4e5
 dt B'01011111' ; 4p
 dt B'10010001' ; 16c5
 dt B'10010001' ; 16c5
 dt B'01110000' ; 8b
 dt B'10010000' ; 16b
 dt B'01101110' ; 8a
 dt B'10001110' ; 16a
 dt B'01001011' ; 4g
 dt B'01110110' ; 8f5
 dt B'00010101' ; 1e5



 ; led GPIO value for each led
led_gpio_table:
 addwf PCL,F
 dt GREEN_GPIO
 dt RED_GPIO
 dt YELLOW_GPIO
 dt BLUE_GPIO
 
; TRIS value for each led
led_tris_table: 
 addwf PCL,F
 dt RED_GREEN_TRIS
 dt RED_GREEN_TRIS
 dt YELLOW_BLUE_TRIS
 dt YELLOW_BLUE_TRIS

;;;;;;;  led_on  ;;;;;;;
;; light LED  
;; input: 
;;   variable 'led' 
;;   is LED identifier
;;;;;;;;;;;;;;;;;;;;;;;; 
led_on:
 movfw led
 call led_gpio_table
 movwf GPIO
 movfw led
 call led_tris_table
 tris GPIO
 return


;;;;;;;;;;;;;;;;;  read_buttons ;;;;;;;;;;;
;; read GP3 
;; when GP3 == 1
;; check  cap_cnt to identify button
;; WORKING:
;;   first the clamp is released on 'C3'
;;   charging capacitor.
;;   then variable 'cap_cnt' is incremented
;;   until GP3 read as '1'.
;;   The final value of 'cap_cnt' determine
;;   if a button is down and which one. 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
read_buttons:
  clrf btn_down
  clrf cap_cnt
  clamp_off ; capacitor start charging.
rbtn1: ; charging counter loop
  btfsc GPIO, GP3
  goto rbtn3
  incf cap_cnt,F
  movlw TC_MAX  ; charging timout
  subwf cap_cnt, W
  skpc
  goto rbtn1
  movlw BTN_NONE ; charging time too long,
  movwf btn_down ; assume no button down.
  clamp_on
  return
rbtn3 ; check cap_cnt value to identify button
  clamp_on ; keep 'C3' discharge when not reading.
  movlw GRN_CNT
  subwf cap_cnt, W
  skpc
  return  ; BTN_GREEN
  incf btn_down,F
  movlw RED_CNT
  subwf cap_cnt, W
  skpc
  return ; BTN_RED
  incf btn_down,F
  movlw YEL_CNT
  subwf cap_cnt, W
  skpc
  return ; BTN_YELLOW
  incf btn_down,F ; BTN_BLUE
  movlw BLUE_CNT
  subwf cap_cnt,W
  skpnc
  incf btn_down,f ; BTN_NONE
  return 

;;;;;; store_note  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; store note in tune_array
;;; inputs:
;;;	t0= array index where to store note {0-31}
;;;	t1=note  {0-3} stored as 2 bits value.
;;; This one is a little tricky because each byte is split in 4 slots of
;;; 2 bits. The position in tune_array is index/4 and the slot is the remainder.  
;;; So there is 4 notes per byte. The note must be stored in the good slot without
;;; altering the contain of others slots.
;;;  bits:  76|54|32|10  
;;;  slots: s3|s2|s1|s0  
;;; To get that result a AND mask is create to reset the slot to 0 and the OR
;;; operation is used to insert the note in the slot.  
;;; exemple: say the index is 6 and the note is 1. then
;;; byte order is 6/4=1
;;; slot is 6 % 4 = 2
;;;  AND mask is 0b11001111
;;                   ^^ slot 2 will be set to 0 after AND operation     
;;;  OR mask is 0b00010000 
;;;                 ^^  slot 2 will be set to 1 after OR operation
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
store_note:
;initialize array pointer    
 movlw tune_array
 movwf FSR
; extract the byte order and put in t2 
 movlw 0xFC
 andwf t0,W  ; mask out 2 least significant bits 
 movwf t2 ; and put the value in t2
; divide by 4
 bcf STATUS, C  
 rrf t2,F
 rrf t2,F
 movfw t2
 addwf FSR, F ; FSR=tune_array+index/4
; create AND mask and shift note is right slot
 movlw 3
 andwf t1,F ; all bits to 0 except bits 0,1
 movwf t2   ; 3->t2
 andwf t0,W   ; get slot number
 subwf t2,F   ; how many times to shift left.
;create the AND mask
 movlw 0xFC
 movwf t0
store_note1:
; shift left AND mask and note value
; while shift counter not zero. 
 brnz shift_left_slot
; the shifting is done, store note in slot. 
 movfw t0  ; AND mask
 andwf INDF,F ; reset that slot to 0
 movfw t1 ; note to W
 iorwf INDF,F ; insert note in slot
 return
shift_left_slot: 
;; shift left mask 1 slot 
 bcf STATUS, C
 rlf t1,F
 rlf t1,F
;; shift left note 1 slot 
 bsf STATUS,C 
 rlf t0,F
 rlf t0,F
 decf t2,F
 goto store_note1

;;;;;;  load_note  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; get note from tune_array and put it in W 
;;; input: W is array index  {0-31}
;;; output: t1 note {0-3}
;;; byte_order is index/4
;;; slot is index % 4
;;; AND mask is inverse of that store_note
;;; because to read a slot we want to keep the
;;; contain of the slot and zero all other bits.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
load_note:
 movwf t0 ; save index
; set array pointer
 movlw tune_array
 movwf FSR
 movlw 0xFC
 andwf t0,W
 movwf t1
; divide index by 4 
 bcf STATUS,C
 rrf t1,F
 rrf t1,W
 addwf FSR,F  ; FSR=tune_array+index/4
 movfw INDF   ; get the byte containing the note slot
 movwf t1 ; save it in t1
 movlw 3
 movwf t2 ; the AND mask 
 andwf t0,W ; slot number index % 4 same as 2 least significant bits.
 subwf t2,F ; how many times t1 mus be shifted right to put the slot in bits 1:0
load_note1:
; first shift right until the slot is in bits 1:0
 brnz rotate_right_twice
; shifting done keep bits 1:0
; and mask all other to zero.
 movlw 3
 andwf t1,F  ; W=note
 return
; slot shifted right 1 position 
rotate_right_twice:
 rrf t1,F
 rrf t1,F
 decf t2,F
 goto load_note1


;;;;;;;;;  random  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; pseudo random number generator
;; 24 bits linear feedback shift register 
;; REF: http://en.wikipedia.org/wiki/Linear_feedback_shift_register
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
random:  
  bcf STATUS, C
  rrf rand+2,F
  rrf rand+1,F
  rrf rand,F
  skpc
  return
  movlw 0xE1
  xorwf rand+2, F
  return

;;;;;;;;;;   wait_btn_release  ;;;;;
;; repeatedly read buttons until 
;; until it return BTN_NONE
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;  
wait_btn_release:
 call read_buttons
 skpeq btn_down, BTN_NONE
 goto wait_btn_release
 return


;;;;;;;;;;;;; note  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; play a musical note from tempered scale. 
; input:
;  w = note : encoding  bits 0-4 notes, note 0x1F=pause , bits 5-7 timelapse
; WORKING:
;  This subroutine is cycle counted.
;  Tones period are based on Tcy=1uSec
;  Each path in half-cycle loop is 10 Tcy.
;  Frequencies values are computed based on this 10 Tcy.
;  Any change on this code will alter the frequencies. 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
note:
 movwf t0
 movlw 0x1F
 andwf t0,W
 xorlw 0x1F
 brz pause
 loadr16 delay, 0x0D40
 movlw 3
 movwf timeout
 movlw 0xE0
 andwf t0,W
 movwf t1
 swapf t1,F
 rrf t1,F
 movf t1,F
 brz note02
note01:
 bcf STATUS,C
 rrf timeout
 rrf delay+1,F
 rrf delay,F
 decfsz t1
 goto note01
note02:
 movlw 0x1F
 andwf t0,W
 call note_table
 movwf half_period
note1:
 movlw B'0100'
 xorwf GPIO, F  ; toggle output pin
 movfw half_period
 movwf t0
note2:
 decf delay,F
 comf delay,W
 skpz
 goto note3
 decf delay+1,F
 comf delay+1,W
 skpz
 goto note4  ; to get 10 Tcy in this path must goto note4
 decf timeout,F
 comf timeout,W
 skpnz
 goto note5
note3:
 goto $+1
note4:
 decfsz t0
 goto note2  ; half-cycle loop
 goto note1 ; half-cycle completed
note5:
 clamp_on
 return

;;;;; musical pause ;;;;;;;;;;;;;;
;; when note value is 0x1F
;; tone subroutine branch here.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
pause: ;musical pause
 loadr16 delay, 2000
 swapf t0,F
 rrf t0,F
 movlw 0x7
 andwf t0,F
 skpnz
 goto pause01
pause00: 
 clrc
 rrf delay+1,F
 rrf delay,F
 decfsz t0,F
 goto pause00
pause01: 
 call delay_ms
 return


    
;;;;;;;;;;;;;;;  INITIALIZATION CODE ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
 ; hardware initialization
init:
 movlw OPTION_MASK
 option 
 led_off
 clrf notes_cnt
 movlw 0xA5
 movwf rand
 clamp_on

;;;;;;;;;;;;;;;;;;;;;;;;  MAIN PROCEDURE  ;;;;;;;;;;;;;;;;;;;;;
; the biggest share of the code is here
; because subroutine calls are limited to 2 levels
; It use a lot of goto instead of call.
; I like to factor code in many subroutines that neast each others
; but this is not possible with this MCU.
; Here is spaghetti code for your degustation (or disgustation), MCU obliged. 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
main:
;;;;;;;;;;;;;;;;;;;;;;;;
;; power on self test
;; light each LED in sequence
;; with associated tone.
;;;;;;;;;;;;;;;;;;;;;;;; 
 clrf led
post:
 call led_on
 movfw led
 call translate_table
 call note
 incf led,F
 btfss led, 2
 goto post
 led_off
 call wait_btn_release
next_set:
 clrf led
 movlw .134
 movwf timeout
; wait for a button down to start game
; light LEDs in sequence
;until a button is pressed down or timeout occur 
led_sweep:
 decfsz timeout,F
 goto keep_going
 goto init  ; after about 35 seconds of idle time, reset.
keep_going: 
 call led_on
 loadr16 delay, .250
 call delay_ms
 incf led,F
 movlw 3
 andwf led,F
 call read_buttons
 skpneq btn_down, BTN_NONE
 goto led_sweep
 led_off
 movfw timeout
 movwf rand
 call wait_btn_release
 loadr16 delay, .500
 call delay_ms
; game loop.
play_rand:
 movfw notes_cnt
 movwf t0
 incf notes_cnt,F
; add a random value to sequence 
 call random
 movfw rand+2
 xorwf rand+1,W
 xorwf rand,W
 andlw 3
 movwf t1
 call store_note
 clrf t3 ; notes counter
; play sequence loop 
play_rand02:
 movfw t3
 call load_note
 movfw t1
 movwf led
 call led_on
 movfw led
 call translate_table
 call note
 led_off
 loadr16 delay, .100
 call delay_ms ; 1/10 second pause
 incf t3,F
 movfw notes_cnt
 subwf t3,W
 skpz
 goto play_rand02
; wait player playing sequence back
wait_playback:
 clrf t3 ; notes counter
wait01:
 movlw .250   ; maximun delay between each button 250 msec.
 movwf timeout
wait02: ; wait button loop
 loadr16 delay, .20
 call delay_ms
 movfw timeout
 movwf rand
 decf timeout,F
 skpnz
 goto game_over
 call read_buttons
 skpneq btn_down, BTN_NONE
 goto wait02
 loadr16 delay, .10  ; wait 10 msec before buttons
 call delay_ms       ; debouncing
 call read_buttons
 skpneq btn_down, BTN_NONE
 goto wait01 ; no button down
; light LED and play tone corresponding to that button
 movfw btn_down
 movwf led
 call led_on
 movfw led
 call translate_table
 call note
 led_off
 call wait_btn_release
 movfw t3
 call load_note
 movfw led
 subwf t1
 skpz
 goto game_over ; not the good one
 incf t3,F
 movfw notes_cnt
 subwf t3,W
 skpz
 goto wait01 ; loop to wait for next button
playback_success
; to understand this 'switch' and 'case'
; machanism see macros above. 
 switch notes_cnt
 case .6, victory
 case .12, victory
 case .18, victory
 case .24, victory
 case .32, victory_final
 loadr16 delay, .500
; this the default case 
 call delay_ms
 goto play_rand
; play rocky_theme at 6,12,18,24 and 32 length success.
; more notes of the theme are played at each milestone.
; If player get at maximum sequence length (i.e. 32)
; the theme is played to end. 
victory:
 movfw notes_cnt
 goto play_victory_theme
; play complete rocky theme.
victory_final:
 clrf notes_cnt
 movlw .40
play_victory_theme:
 movwf t2
 clrf t3
prt01:
 movfw t3
 call rocky_theme
 call note
 incf t3,F
 movfw t2
 subwf t3,W
 skpz
 goto prt01
 loadr16 delay, 0x400
 call delay_ms
 movlw 32
 xorwf notes_cnt,W
 skpz
 goto play_rand
 goto init
 
; player failed to repeat sequence
game_over:
 movlw B'00111000'
 call note ; audio alert game over
;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; display sequence length
;; BLUE is 25
;; YELLOW is 10
;; RED is 5
;; GREEN is 1
;; length=NB*25+NY*10+NR*5+NG
;; where Nx is number of blink of
;; each LED.
;;;;;;;;;;;;;;;;;;;;;;;;;;; 
#define len notes_cnt
 decf len,F
display_length:
 movf len,F
 skpnz
 goto wait1sec
 movlw 3
 movwf led
 movlw .25
 subwf len,W
 skpc
 goto lt25 ; <25
 movwf len
 goto blink_led
lt25:
 decf led,F
 movlw .10
 subwf len,W
 skpc
 goto lt10; <10
 movwf len
 goto blink_led
lt10:
 decf led,F
 movlw .5
 subwf len,W
 skpc
 goto lt5 ; <5
 movwf len
 goto blink_led
lt5:
 decf led,F
 decf len,F
blink_led:
 call led_on
 loadr16 delay, .500
 call delay_ms ; 500 msec pause
 led_off
 loadr16 delay, .500
 call delay_ms ; 500 msec pause
 goto display_length
;wait 1 second before resuming
;to next_set 
wait1sec:
 loadr16 delay, .1000
 call delay_ms
 goto next_set
 
 end
 


