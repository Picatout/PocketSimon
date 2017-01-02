# PocketSimon

Simon game implemented on a PIC10F202

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
 memory correspond to 512 instructions words. The program use 508 of those and all the 24 bytes of RAM.
 
## game description

  4 LEDs of different colours. To each LED a tone and a button is associated. The object is to repeat the sequence of tones played by the 
  the PocketSimon. At each success the length of the sequence is incremented by 1. The game end when the player make a mistake repeating the sequence.

## development tools
* MPLABX 
* mpasms  assembler
* pickit 2 or 3 for device programming
  
## Schematic  
![schematic](/KiCAD/schematic.png)

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

 The circuit is powered by a 3 volt button cell of CR2032 model  through **SW1** power switch. Capacitor **C1** should be 
soldered closest as possible to MCU power pins **Vdd** and **Vss**. Each LED as a 1K resistor in serie to reduce current drain on
the lithium cell. These are connected between the power rail by pair in serie with the midpoint connected to GPIO. **GP1** is at
midpoint between RED and GREEN LEDs and **GP0** is at midpoint between BLUE en YELLOW LEDs. This enable to control 2 LEDs with
a single I/O. When the outpout is high the lower LED turn on and when it is low the upper LED turn on. To turn off both LEDs the
I/O  is configure in high impedance input mode. When configured this way no current go trough the LEDs because the sum of their 
threshold voltage is higher than 3volt. This would not works with a 5volt power supply.

 The audio output is through **GP2** which control **Q1** base. Which drive a 150 ohm 1 inch voice coil speaker. I prefer voice coil
 speaker than piezo speaker for sound quality. **GP2** also control **Q2** which is used to discharge **C3**. This sharing of **GP2**
  as a  little inconvience in the form of noise when **GP2** is used to turn on and off **Q2**.
  
 the 4 push buttons  **SW2** to **SW5**  are connected between **Vdd** and a resistors ladder. The position of the switch in this 
ladder determine the charging time constant of **C3**.  Hence the button can be identified by the time it take to voltage at **C3** 
to charge from 0 volt to logic level **1**. The reading sequence consist of discharging **C3** through **Q2** then counting the 
time it take for **GP3** to go from a **0** logic level to a **1** logic level. There maybe some variability from MCU to MCU and 
also due to **C3** capacitor tolerance on vallue. So the constant GRN_CNT defined is the software may have to be adjusted by testing.
See source code for more information. 

![assembly board](/documents/prototype.png)
 
## game description

 At power up the MCU initialize the hardware then execute a power on selft test (**POST**). After the **POST** the 4 LEDs continue
 to light in sequence GREEN-RED-YELLOW-BLUE until the player press a button to start game or a timeout occur which happen about 35
 seconds of idle time. At timeout the MCU is resarted, the POST playing again. 

 At button pressed down start the game with a single note. Then at each repeat success a sequence length is increment by a new random
note. At length 6,12,18,24,32 a tune a played to mark your acheivement. The maximum sequence length is 32 limited by RAM available. But 
if you got that far you are a real champion and you can listen to the complete Rocky 1 movie musical theme.
 
 At then of of game the length of last sequence succeeded is displayed in the following way.
 Each LED is assigned a value and blink for multiple of this value. Adding the blinks the total count.

 LED    | value
 ------ | -----
 BLUE   | 25
 YELLOW | 10
 RED    | 5
 GREEN  | 1

  count = NB * 25 + NY * 10 + NR * 5 + NG 
  
  where Nx is number of blinks of the colour.
 
## software
 This source code is in totality in file  **PocketSimon.asm** and is well documented (I think). It use 100% of RAM and 100% of
 program space which is 768 bytes. 
 
 
## licence
*  software licence: GPLv3
*  hardware licence: CC-BY-SA
  