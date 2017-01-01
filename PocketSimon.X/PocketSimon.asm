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
; before each sequence play the number of notes that will be played is displayed
; in binary form on the 4 LEDs. If the sequence is longer than 15 then the high
; nibble is displayed first for 1 second then the low nibble for another second.
; After that display there a 1/2 second delay then the sequence is played
; which the user must repeat in exact order. At first error the game is over and
; a MCU wait for a new set.
; To wake up the MCU one must press a button. At wake up the MCU run a Power On Self
; Test, which consist of lighting the 4 LEDs sequencially while sounding the
; associated note. After POST the 4 LEDs chase in loop until the player press a
; button to start game.
;
; DESCRIPTION: the purpose of this project is to demonstrate the use of a single
; logic I/O to read many switches using a capacitor charging time.
; the game use 4 switches that are all tied to the GP3 input.
; Four LEDs of different colour are connected to GP0 and GP1
; The audio output is to GP2
; a PNP small switching transistor is used to drive an 8 ohm speaker
; Another NPN small signal transistor is also connected GP2. This one is used
; to discharge the switches timing capacitor. If GP3 could be configured
; as output this one would not be needded as the capacitor could be discharged through
; GP3 output low.
; The inconvience of this design is that when reading buttons a noise is heard in speaker.
; I consider this to be is a small inconvience.
; This design connect 2 LEDs in series from V+ to ground and consequently worls only
; with a 3 volt power supply. For a voltage over 3 volt a permanent current path is
; formed through diodes GREEN, RED and YELLOW, BLUE and the LEDs are always ligthed.
; But with a 3 volt power supply it works fine because the conduction voltage of LEDs
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
#define RED_GPIO         B'1001'
#define GREEN_GPIO       B'1011'
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
#define TC1 .15
#define TC2 2*TC1
#define TC3 3*TC1
#define TC4 4*TC1
#define TC_MAX 5*TC1

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

init_timer0 macro ; initialize TIMER0 for 1msec period
  movlw .7
  movwf TMR0
  movlw OPTION_MASK
  option
  endm

;;;;;    macros ;;;;;;;;;;;;;;;;;

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

incr16 macro r16  ; increment r16 variable
  incf r16,F
  skpnz
  incf r16+1,F
  endm

decr16 macro r16 ; decrement r16 variable
 decf r16,F
 comf r16,W
 skpnz
 decf r16+1,F
 endm

;;;;;;;;;;;;;;;; VARIABLES  ;;;;;;;;;;;;;;;;;;;;;
    udata
  btn_down res 1  ; which button is down
  led res 1 ; active led value
  delay res 2 ; delay counter
  half_period res 1 ; note half-period delay
  timeout res 2 ; inactivity timeout
  cap_cnt res 1 ; capacitor charge time
  notes_cnt res 1 ; count notes played
  temp res 4 ; temporary storage
  rand res 3 ; pseudo random number generator register
  tune_array res 8 ; note sequence array maximun 32 notes. 2 bits used per note.
 


  code 
;;;;;;;;;;;;;;;;;;; CODE SEGMENT ;;;;;;;;;;;;;;;;;;
    org 0
 goto init

;;;;;;;;;;    delay_ms  ;;;;;;;;;;;;;;;;;;
; delay in miliseconds
; delay = value in msec
delay_ms:
 movf delay,F
 brnz dly1
 movf delay+1, F
 skpnz
 return ; delay over
dly1
 decr16 delay
dly2
 init_timer0
dly3
 movfw TMR0
 skpz
 goto dly3
 goto delay_ms


pause_table: ; pause length in milliseconds
 addwf PCL, F
 dt low .2000   ;1
 dt high .2000
 dt low .1000    ;1/2
 dt high .1000
 dt low .500    ;1/4
 dt high .500
 dt low .250     ;1/8
 dt high .250
 dt low .125    ;1/16
 dt high .125
 dt low .64     ;1/32
 dt high .64

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




led_gpio_table: ; led GPIO value for each led
 addwf PCL,F
 dt GREEN_GPIO
 dt RED_GPIO
 dt YELLOW_GPIO
 dt BLUE_GPIO

led_tris_table: ; TRIS value for each led
 addwf PCL,F
 dt RED_GREEN_TRIS
 dt RED_GREEN_TRIS
 dt YELLOW_BLUE_TRIS
 dt YELLOW_BLUE_TRIS
 movwf timeout


;;;;;;;  ligth_led  ;;;;;;
;; input: led is LED id
light_led:
 movfw led
 call led_gpio_table
 movwf GPIO
 movfw led
 call led_tris_table
 tris GPIO
 return


;;;;;;;;;;;;;;;;;  read_buttons ;;;;;;;;;;;;;;;;;;;;
;; read GP3
;; when GP3 == 1
;; check  cap_cnt to identify button
read_buttons:
  clrf btn_down
  clrf cap_cnt
  clamp_off ; capacitor start charging.
rbtn1
  btfsc GPIO, GP3
  goto rbtn3
  incf cap_cnt,F
  movlw TC_MAX
  subwf cap_cnt, W
  skpc
  goto rbtn1
  movlw BTN_NONE
  movwf btn_down
  clamp_on
  return
rbtn3 ; check cap_cnt to identify button
  clamp_on ; discharge capacitor
  movlw TC1
  subwf cap_cnt, W
  skpc
  return  ; BTN_BLUE
  incf btn_down,F
  movlw TC2
  subwf cap_cnt, W
  skpc
  return ; BTN_YELLOW
  incf btn_down,F
  movlw TC3
  subwf cap_cnt, W
  skpc
  return ; BTN_RED
  incf btn_down,F ; BTN_GREEN
  movlw TC4
  subwf cap_cnt,W
  skpnc
  incf btn_down,f ; BTN_NONE
  return 

;;;;;; store_note  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; store note in tune_array
;;; inputs:
;;;	temp= array index where to store note {0-31}
;;;	temp+1=note  {0-3} stored as 2 bits value.
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
;;; slot is remainder(6,4)=2
;;;  AND mask is 0b11001111
;;                   ^^ slot 2 will be set to 0 after AND operation     
;;;  OR mask is 0b00010000 
;;;                 ^^  slot 2 will be set to 1 after OR operation
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
store_note:
;initialize array pointer    
 movlw tune_array
 movwf FSR
; extract the byte order and put in temp+2 
 movlw 0xFC
 andwf temp,W  ; mask out 2 least significant bits 
 movwf temp+2 ; and put the value in temp+2
; divide by 4
 bcf STATUS, C  
 rrf temp+2,F
 rrf temp+2,F
 movfw temp+2
 addwf FSR, F ; ajust pointer to correct byte in tune_array
 movlw 3
 andwf temp+1,F ; all bits to 0 except bits 0,1
 movwf temp+2   ; 3->temp+2
 andwf temp,W   ; get slot number
 subwf temp+2,F  ; shift left counter.
;create the AND mask
 movlw 0xFC
 movwf temp
store_note1
; first shift left AND mask and note value
; while shift counter not zero. 
 brnz shift_left_slot
 movfw temp  ; mask shifted in right slot
 andwf INDF,F ; reset that slot to 0
 movfw temp+1 ; note to W
 iorwf INDF,F ; insert note in slot
 return
shift_left_slot
;; shift left mask 1 slot 
 bcf STATUS, C
 rlf temp+1,F
 rlf temp+1,F
;; shift left note 1 slot 
 bsf STATUS,C 
 rlf temp,F
 rlf temp,F
 decf temp+2,F
 goto store_note1

;;;;;;  load_note  ;;;;;;;;
;;; get note from tune_array and put it in W 
;;; input: W is array index  {0-31}
;;; output: temp+1 note {0-3}
;;; byte_order is index/4
;;; slot is remainder(index,4)
;;; AND mask is inverse of that store_note 
load_note:
 movwf temp ; save index
; set array pointer
 movlw tune_array
 movwf FSR
 movlw 0xFC
 andwf temp,W
 movwf temp+1
 bcf STATUS,C
 rrf temp+1,F
 rrf temp+1,W
 addwf FSR,F  ; FSR point to byte in tune_array
 movfw INDF   ; get the byte containing the note slot
 movwf temp+1 ; save it in temp+1
 movlw 3
 movwf temp+2 ; the AND mask 
 andwf temp,W ; get slot number
 subwf temp+2,F ; save it in temp+2
load_note1
; first shift right until the slot is in bits 1:0
 brnz rotate_right_twice
 movlw 3
 andwf temp+1,F  ; W=note
 return
rotate_right_twice
 rrf temp+1,F
 rrf temp+1,F
 decf temp+2,F
 goto load_note1


;;;;;;;;;  random  ;;;;;;;;;;;;;;;;
;; pseudo random number generator
;; 24 bits linear feedback shift register 
;; rand+2 is loaded with cap_cnt at each button pressed
;; to improve randomness.
;; REF: http://en.wikipedia.org/wiki/Linear_feedback_shift_register
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

;;;;;;;;;;;;;;;;;;;   wait_btn_release  ;;;;;;;;;;;;;;;;;;;
wait_btn_release:
 call read_buttons
 skpeq btn_down, BTN_NONE
 goto wait_btn_release
 return


;;;;;;;;;;;;; note  ;;;;;;;;;;;;;
; play a tone from tempered scale. 
; input:
;  w = note : encoding  bits 0-4 notes, note 0x1F=pause , bits 5-7 lapse
; period based on Tcy=1uSec
; each half-cycle has 6Tcy including 'goto note1'
; each path in half-cycle loop is 10Tcy;.
; values are based on this 10Tcy.
note:
 movwf temp
 movlw 0x1F
 andwf temp,W
 xorlw 0x1F
 brz pause
 loadr16 delay, 0x0D40
 movlw 3
 movwf timeout
 movlw 0xE0
 andwf temp,W
 movwf temp+1
 swapf temp+1,F
 rrf temp+1,F
 movf temp+1,F
 brz note02
note01
 bcf STATUS,C
 rrf timeout
 rrf delay+1,F
 rrf delay,F
 decfsz temp+1
 goto note01
note02
 movlw 0x1F
 andwf temp,W
 call note_table
 movwf half_period
note1
 movlw B'0100'
 xorwf GPIO, F  ; toggle output pin
 movfw half_period
 movwf temp
note2
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
note3
 goto $+1
note4
 decfsz temp
 goto note2  ; half-cycle loop
 goto note1 ; half-cycle completed
note5
 clamp_on
 return
 
pause: ;musical pause
 swapf temp, F
 movlw 0xE
 andwf temp,F
 movfw temp
 call pause_table
 movwf delay
 incf temp,W
 call pause_table
 movwf delay+1
 call delay_ms
 return


;;;;;;;;;;;;;;;  INITIALIZATION CODE ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
init: ; hardware initialization
 movlw .12
 movwf OSCCAL
 movlw OPTION_MASK
 option
 led_off
 clrf notes_cnt
 movlw 0xA5
 movwf rand
 clamp_on

;;;;;;;;;;;;;;;;;;;;;;;;  MAIN PROCEDURE  ;;;;;;;;;;;;;;;;;;;;;

main:
 clrf led
post: ; power on self test
 call light_led
 movfw led
 call translate_table
 call note
 incf led,F
 btfss led, 2
 goto post
 led_off
 call wait_btn_release
 clrf led
; wait for a button down to start game 
led_chase:    ;round robin led chase
 call light_led    ;until a button is pressed down or timeout occur
 loadr16 delay, .250
 call delay_ms
 incf led,F
 movlw 3
 andwf led,F
 call read_buttons
 skpneq btn_down, BTN_NONE
 goto led_chase
 led_off
 movfw timeout
 movwf rand
 call wait_btn_release
 loadr16 delay, .500
 call delay_ms
; game loop.
play_rand:
 movfw notes_cnt
 movwf temp
 incf notes_cnt,F
;;;;;;  display sequence length in binary ;;;;;;;;;;;;;
hi_nibble ; show high nibble
 movlw 3
 movwf led
 movfw notes_cnt
 movwf temp+3
 btfsc temp+3, 4
 call light_led
 loadr16 delay, .1000
 call delay_ms ; 1 second pause
 led_off
 swapf temp+3,F
 clrf timeout
 clrf led
lo_nibble  ; show low nibble
 rlf temp+3,F
 skpnc
 call light_led
 incf led,F
 movlw 3
 andwf led,F
 skpz
 goto $+3
 swapf notes_cnt,W
 movwf temp+3
 loadr16 delay, .4
 call delay_ms
 decfsz timeout
 goto lo_nibble
display_exit
 led_off
 loadr16 delay, .500 
 call delay_ms ; half seconde pause
;;;; end display_count ;;;;;
; add a random value to play sequence 
 call random
 movfw rand+2
 xorwf rand+1,W
 xorwf rand,W
 andlw 3
 movwf temp+1
 call store_note
 clrf temp+3 ; notes counter
; play sequence loop 
play_rand02:
 movfw temp+3
 call load_note
 movfw temp+1
 movwf led
 call light_led
 movfw led
 call translate_table
 call note
 led_off
 loadr16 delay, .100
 call delay_ms ; 1/10 second pause
 incf temp+3,F
 movfw notes_cnt
 subwf temp+3,W
 skpz
 goto play_rand02
; wait player playing sequence back
wait_playback:
 clrf temp+3 ; notes counter
wait01:
 movlw .255   ; maximun delay between each button 255 msec.
 movwf timeout
wait02: ; wait button loop
 loadr16 delay, .20
 call delay_ms
 movfw timeout
 movwf rand
 decf timeout,F
 skpnz
 goto playback_error
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
 call light_led
 movfw led
 call translate_table
 call note
 led_off
 call wait_btn_release
 movfw temp+3
 call load_note
 movfw led
 subwf temp+1
 skpz
 goto playback_error
 incf temp+3,F
 movfw notes_cnt
 subwf temp+3,W
 skpz
 goto wait01 ; loop to wait for next button
playback_success
 switch notes_cnt
 case .6, victory
 case .12, victory
 case .18, victory
 case .24, victory
 case .32, victory_final
 loadr16 delay, .500
 call delay_ms
 goto play_rand
; play rocky_theme at 6,12,18,24 and 32 length success.
victory:
 movfw notes_cnt
 goto play_victory_theme
victory_final:
 clrf notes_cnt
 movlw .40
play_victory_theme
 movwf temp+2
 clrf temp+3
prt01:
 movfw temp+3
 call rocky_theme
 call note
 incf temp+3,F
 movfw temp+2
 subwf temp+3,W
 skpz
 goto prt01
 loadr16 delay, 0x400
 call delay_ms
 goto play_rand

; player failed to repeat sequence
; game over. Reset to beginning 
playback_error:
 movlw B'01011000'
 call note
 clrf notes_cnt
 clrf led
 goto led_chase
 
 end


