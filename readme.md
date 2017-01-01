# PocketSimon

Simon game implemented on a PIC10F202

## the PIC10F202 a minimalist MCU
*	program memory 768 bytes 
*   RAM 24 bytes
*   1 watchdog timer
*   1 8 bit timer
*   3 Input/Output pins
*   1 Input only pin.

## game description

  4 LEDs of different colours to each LED a tone and a button is associated. The object is to repeat the sequence of tones played by the 
  toy. At each success the length of the sequence is incremented by 1. The game end when the player can't reproduce the sequence without error.

## development tools
* MPLABX 
* mpasm  assembler
* pickit 2 or 3 for device programming
  
## Schematic  
![schematic](/KiCAD/schematic.png)

## BOM
*  1 mini spst power switch
*  1 CR2032 battery holder
*  1 CR2032 lithium battery
*  1 PIC10F202  MCU DIP-8 format
*  2 100nF ceramic capacitor
*  1 10µF/16v electrolytic capacitor
*  2 1N4148 diode
*  1 2N3904 NPN transistor
*  1 ztx749 PNP transistor
*  1 red 5mm LED T1-3/4
*  1 green 5mm LED T1-3/4
*  1 yellow 5mm LED T1-3/4
*  1 blue 5mm LED T1-3/4
*  4 push button
*  4 1K resistors
*  5 3K resistors
*  1 10K resistors
*  1 56 ohm resistor
*  1 8 ohm small speaker
*  1 prototyping board 7cmx9cm bakelyte, i.e. Adafruit p/n: 2670 pq of 10.
*  some length of 30 AWG  hookup wire

## licence
  software licence: GPLv3
  hardware licence: CC-BY-SA
  