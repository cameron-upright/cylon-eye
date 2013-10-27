cylon-eye
=========

A PIC microcontroller program used to simulate a Cylon eye.



Hardware
========

Overview
--------

This program uses the PIC12F615, a mid-range 8 bit PIC microcontroller.  This was chosen because it has 8 pins and an ECCP module, which allows measurement of the pulse width of the PWM signal.


Pin Assignment
--------------

Pin 5 (GP2) is used to interpret the PWM signal coming from the RC receiver.  Since the PWM signal can have a lower maximum voltage than the receivers supply voltage, the PWM signal is passed through an inverter, to make sure it matches the 5 volt supply voltage.

Pins 2,3,6,7 (GP0, GP1, GP4, GP5) are used to control the LED array.  Using charlieplexing, this allows control of up to 12 LEDs.


Schematic
---------

TODO



