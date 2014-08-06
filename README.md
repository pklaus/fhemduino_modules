fhemduino_modules
=================

/-----\                             HEX-Wert (Empfang)                                         /------------> Log-File
| [ ] |<------------>FHEMduino.ino ------------>00_FHEMduino.pm<------------>14_FHEMduino_Env.pm------------->FHEM-Web
|     | Bitstream                  ^------------|            ^\        \                       \
\-----/                             BitStream (Senden)         \        |                       | Message         Sensor
Sensor /                                                        \       |                       | W01...          KW901
Aktor                                                            |      |                       | W02...          EuroChron / Tchibo
                                                                 |      |                       | W03...          PEARL NC7159, LogiLink WS0002
                                                                 |      |                       | W04...          Lifetec
                                                                 |      |                       | W05...          TX70DTH (Aldi)
                                                                 |      |                       | W05...          AURIOL (Lidl Version: 09/2013)
                                                                 |      |
                                                                 |      |--->14_FHEMduino_Oregon.pm
                                                                 |      |
                                                                 |      |--->10_CUL_TX.pm -> commandref.html
                                                                 |      |--->41_OREGON.pm -> commandref.html
                                                                 |
                                                                 |
                                                                 |--------->14_FHEMduino_PT2262.pm  -> PT2262 chip based transmitters / receivers ( Funksteckdosen,...)
                                                                 |--------->14_FHEMduino_DCF77.pm   -> DCF77-Signal der PTB Braunschweig (Datum, Zeit)
                                                                 |--------->14_FHEMduino_FA20RF.pm  -> smoke detectors FA20RF / RM150RF / Brennenstuhl BR 102-F / KD101
                                                                 |--------->14_FHEMduino_HX.pm      -> Heidemann HX series door bells
                                                                 |--------->14_FHEMduino_TCM.pm     -> Tchibo TCM234759 door bell
