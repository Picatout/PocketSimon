# PocketSimon

Simon game implemented on a PIC10F202

Copyright Jacques Deschenes, 2012,2016,2017

See licencing at end of this file.

## the PIC10F202 a minimalist MCU
*	program memory 768 bytes 
*   RAM 24 bytes
*   1 watchdog timer
*   1 8 bit timer
*   3 Input/Output pins
*   1 Input only pin.

 This is the simplest microcontroller available on market. the core is what Microchip call **baseline**. It as a 2 level hardware stack 
 which is quite limiting. This is why the main routine code is so linear instead of relying more on sub-routines calls.
 
 The code is written in assembly using **mpasmx**. This core as only 33 instructions which are coded on 12 bits so 768 bytes of program
 memory correspond to 512 instructions words. The program use 450 (after size optimization) of those and all the 24 bytes of RAM.
 
## game description

  4 LEDs of different colours. To each LED a tone and a button is associated. The object is to repeat the sequence of tones played by the 
  the PocketSimon. At each success the length of the sequence is incremented by 1. The game end when the player fail to repeat the sequence.

## development tools
* MPLABX 
* mpasmx  assembler
* pickit 2 or 3 for device programming
  
## Schematic  
![schematic](/documents/schematic.png)

## BOM
*  1 mini spst power switch
*  1 CR2025 battery holder
*  1 CR2025 lithium battery
*  1 PIC10F202  MCU DIP-8 format
*  2 100nF/50v ceramic capacitor
*  1 10µF/16v electrolytic capacitor
*  2 1N4148 diode
*  1 2N3904 NPN transistor
*  1 ztx749 PNP transistor
*  1 red 5mm LED T1-3/4
*  1 green 5mm LED T1-3/4
*  1 yellow 5mm LED T1-3/4
*  1 blue 5mm LED T1-3/4
*  4 push button
*  1 470 ohm resistor
*  4 1K resistors
*  5 3K resistors
*  1 10K resistors
*  1 150 ohm small speaker
*  1 prototyping board 7cmx9cm bakelyte, i.e. Adafruit p/n: 2670 pq of 10


## Hardware description

 The circuit is powered by a 3 volt button cell, CR2025 or CR2032 model  through **SW1** power switch. Capacitor **C1** should be 
soldered closest as possible to MCU power pins **Vdd** and **Vss**. Each LED as a 1K resistor in serie to reduce current drain on
the lithium cell. These are connected between the power rail by pair in serie with the midpoint connected to GPIO. **GP1** is at
midpoint between RED and GREEN LEDs and **GP0** is at midpoint between BLUE en YELLOW LEDs. This enable to control 2 LEDs with
a single I/O. When the outpout is high the lower LED turn on and when it is low the upper LED turn on. To turn off both LEDs the
I/O  is configured in high impedance input mode. When configured this way no current go trough the LEDs because the sum of their 
threshold voltage is higher than 3 volts. This would not works with a 5 volts power supply.

 The audio output is through **GP2** which control **Q1** base. Which drive a 150 ohm 1 inch voice coil speaker. I prefer voice coil
 speaker than piezo speaker for sound quality. **GP2** control also **Q2** which is used to discharge **C3**. This sharing of **GP2**
  as a  little inconvience in the form of noise when **GP2** is used to turn on and off **Q2**.
  
 the 4 push buttons  **SW2** to **SW5**  are connected between **Vdd** and a resistors ladder. The position of the switch in this 
ladder determine the charging time constant of **C3** and Rsw.  Hence the button can be identified by the time it take to voltage at **C3** 
to charge from 0 volt to logic level **1**. The reading sequence consist of discharging **C3** through **Q2** then counting the 
time it take for **GP3** to go from a **0** logic level to a **1** logic level. There maybe some variability from MCU to MCU and 
also due to **C3** capacitor tolerance variability. So the constant GRN_CNT defined is the software may have to be adjusted by testing.
See source code for more information. 

 The assembly is on single side perforated board with copper rings. I didn't design any layout before hand as the assembly is quite
 simple. I drawn this one after I completed the assembly.
 
![board layout](/documents/board_layout.png)

 This is the final assembly
 
![assembly board](/documents/prototype.png)
 
## game description

 At power up the MCU initialize the hardware then execute a power on selft test (**POST**). The POST consist in lighting LEDs in 
 sequence while sounding their correspondign tone. The POST execute in loop until the user press a button to start game.
 
 The game start with single note. Then at each repeat success a sequence length is increment by a new random
note. At length 6,12,18,24,32 a tune is played to mark your achievement. The maximum sequence length is 32 limited by RAM available. 
But if you got that far you are a real champion and you can listen to the complete Rocky 1 movie musical theme.
 
 At then of of game the length of last sequence succeeded is displayed in the following way.
 Each LED is assigned a value and blink for multiple of this value. Adding the blinks give the total count.

 LED    | value
 ------ | -----
 BLUE   | 25
 YELLOW | 10
 RED    | 5
 GREEN  | 1

  count = NB * 25 + NY * 10 + NR * 5 + NG 
  
  where Nx is number of blinks of the colour.
 
## software
 This source code is in totality in file  **PocketSimon.asm** and is well documented (I think). It use 100% of RAM and 88% of
 program space which is 768 bytes. At first I wrote a working version that used 100% of program memory. Then when that first 
 version was working properly I started **size optimization**. My notes describing the step I followed to reduce code size are
 in file [notes.txt](https://github.com/Picatout/PocketSimon/blob/master/PocketSimon.X/notes.txt). This process was concluded by a 12% size reduction, the final version using 450 instructions.
 Some tricks used in this process are what I would call **dirty tricks**. Like using **TMR0** special function register as a temporary
 storage because there was no more RAM available. The other **dirty trick** was to rely on the fact that special fonction register
**FSR** as only 5 bits implemented. In **store_note** and **load_note** subroutines FSR register is setup to point in tune_array. 
For that the array index must be divided by 4 which is done by 2 **rrf** (rotate right file) instructions. Normaly the **clr** instruction should be
used before each **rrf** to insure that carry roll in bit 7 as 0. But in this specific situtation we don't have to care about the value
of bits 7,6 W register after division because FSR has only 5 bits when the instruction **addwf FSR,F** the value of bits 7,6 of 
W registers won't affect the result.
 

## licence
*  software licence: GPLv3
*  hardware licence: CC-BY-SA
*  In short form: it is open source. You can copy hardware and software as long as you keep credits and licensing in files.
  