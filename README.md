fhemduino_modules
=================

These are the perl files needed, to extend an existing fhem installation with support for the fhemduino.


Just copy all the .pm files from this repository into the fhem/FHEM directory.

If your fhem Installation resides in /opt/fhem, then these files must be copied into the /opt/fhem/FHEM directory.


How to set up the fhemduino in FHEM?
=================

Connect the fhemduino (Arduino with fhemduino sketch) via usb to your system (Fritzbox, Raspberrypi, ...).
Lets assume, it is available as  /dev/ttyACM0@9600 then add the fhemduino to your fhem.cfg like this:

define FHEMduino FHEMduino /dev/ttyACM0@9600


How to add Sensors
=================
Noting to do for you. Let autocreate add the sensors which are received.


Where to get help
=================
Open an issue, and ask.
