mega-wspr: genesis sources
fpga mapper: sources (transmitter core)
dist: application for Mega EverDrive

mega-wspr is a WSPR transmitter core for using on Genesis + Mega EverDrive PRO flashcart
you can read about WSPR here: https://physics.princeton.edu/pulsar/k1jt/wspr.html

------------------------------------how to use-------------------------------------
1. Copy mega-wspr.md and mapper.rbf at single folder on SD card

2. Joinn antenna to the cart gpio port. antenna-join.jpg shows how to join 
The simplest option could just an two wires directly joined to gpio
Wires length depends of band. Just google some dipole antenna calculator

3. Set actual time in the cart options menu. Time must be set to the nearest second

4. Launch mega-wspr.md

5. Enter you radio callsign in CALL field. It used for yours messages identifications

6. Enter your location in LOCATOR field. It used for the following distance calculations
   Use google to get some app for locator codes generation

7. Set TRANSMITTER field to the ON position

System will send messages every two minutes.
You can check if someone receive your signals at https://www.wsprnet.org/drupal/wsprnet/spotquery
Just enter your callsign in Call field and push "Update"
If nobody hear you, try to adjust FREQ ADJ option, usually it something in range of +/-10

-------------------------------------wspr settings-------------------------------------
CALL:
 Enter you radio callsign here

LOCATOR:
 Yours location code. I ganerated one in "WSPR Watch" ios application

BAND:
 Select one of WSPR channels

FREQ ADJ:
 Frequency correction
 Onboard clock source isn't accurate enough to hit precisely in 200hz wspr window
 Try to adjust this parameter if nobody hear your signals

TX POWER:
 Radio emission power. Max TX power around 0.02 Watts i guess

TRANSMITTER:
 transmitter modes
 OFF: disabled
 ON: time sync and transmit wspr messages
 TEST MODE: transmit constant tone. Useful for frequency correction, if you have some equipment to check the freq

-------------------------------------wspr state-------------------------------------
TX FREQ:
 shows actual transmit frequency

MSG SENT:
 How many WSPR messages were sent

TIME:
 Shows onboard clock time
 It very important to set actual time precisely befor than use
 WSPR packet exchange starts every two minutes and should be synchronized to the actual time

STATE:
 OFF: transmitter disabled
 TX MSG: message transmitting in process
 WAIT SYNC: waiting for the even minute begin to launch the transmission