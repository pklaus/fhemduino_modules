/// @dir FHEMduino (2013-11-07)
/// FHEMduino communicator
//
// authors: mdorenka + jowiemann + sidex, mick6300
// see http://forum.fhem.de/index.php/topic,17196.0.html
//
// History of changes:
// 2013-11-07 - started working on PCA 301
// 2013-12-06 - second version
// 2013-12-15 - KW9010ISR
// 2013-12-15 - fixed a bug where readings did not get submitted due to wrong error
// 2013-12-18 - major upgrade to new receiver system (might be extendable to other protocols
// 2013-12-18 - fixed typo that prevented compilation of code
// 2014-02-27 - remove magic numbers for IO Pins, #define constants instead / Make the code Leonardo compatible / This has not been tested on a atmega328 (all my devices are atmega32u4 based)
// 2014-04-09 - add support for pearl NC7159 Code from http://forum.fhem.de/index.php/topic,17196.msg147168.html#msg147168 Sensor from: http://www.pearl.de/a-NC7159-3041.shtml
// 2014-06-04 - add support for EUROCHRON modified Code from http://forum.arduino.cc/index.php/topic,136836.0.html / Prevent receive the same message continius
// 2014-06-11 - add support for LogiLink NC_WS
// 2014-06-13 - EUROCHRON bugfix for neg temp 
// 2014-06-16 - Added TX70DTH (Aldi)
// 2014-06-16 - Added DCF77 ( http://www.arduinoclub.de/2013/11/15/dcf77-dcf1-arduino-pollin/)
// 2014-06-18 - Two loops for different duration timings
// 2014-06-21 - Added basic Support to dectect the follwoing codecs: Oregon Scientific v2, Oregon Scientific v3,Cresta,Kaku,XRF,Home Easy
//            - Implemented Decoding for OSV2 Protocol
//            - Added some compiler switches for DCF-77, but they are currently not working
//            - Optimized duration calculation and saved variable 'time'.
// 2014-06-22 - Added Compiler Switch for __AVR_ATmega32U4__ DCF Pin#4
// 2014-06-24 - Capsulatet all decoder with #defines
// 2014-06-24 - Added receive support for smoke detectors FA20RF / RM150RF (KD101 not verified)
// 2014-06-24 - Added send / activate support for smoke detectors FA20RF / RM150RF (KD101 not verified) -- not yet inetgrated in FHEM-Modul
// 2014-06-24 - Integrated mick6300 developments (not tested yet, global Variables have to be sorted into #ifdefs, Modul have to sorted to 1-WIRE

// --- Configuration ---------------------------------------------------------
#define PROGNAME               "FHEMduino"
#define PROGVERS               "2.1a"

#if defined(__AVR_ATmega32U4__)          //on the leonardo and other ATmega32U4 devices interrupt 0 is on dpin 3
#define PIN_RECEIVE            3
#else
#define PIN_RECEIVE            2
#endif

#define PIN_LED                13
#define PIN_SEND               11
#define DHT11_PIN              1         // ADC0  Define the ANALOG Pin connected to DHT11 Sensor

#include "Time.h"        // Unterstuetzung für Datum/Zeit-Funktionen

//#define DEBUG           // Compile sketch witdh Debug informations
#ifdef DEBUG
#define BAUDRATE               115200
#else
#define BAUDRATE               9600
#endif

//#define WIRE-SUP        // Compile sketch with 1-WIRE-Support

#define COMP_DCF77      // Compile sketch witdh DCF-77 Support (currently disableling this is not working, has still to be done)
#define COMP_PT2262     // Compile sketch with PT2262 (IT / ELRO switches)
#define COMP_FA20RF     // Compile sketch with smoke detector Flamingo FA20RF / ELRO RM150RF
#define COMP_KW9010     // Compile sketch with KW9010 support
#define COMP_NC_WS      // Compile sketch with PEARL NC7159, LogiLink WS0002 support
#define COMP_EUROCHRON  // Compile sketch with EUROCHRON / Tchibo support
#define COMP_LIFETEC    // Compile sketch with LIFETEC support
#define COMP_TX70DTH    // Compile sketch with TX70DTH (Aldi) support

ifdef WIRE-SUP
#include "Wire.h"        // Unterstuetzung für 1-WIRE-Sensoren

// Hallo Michael, ab hier kann ich für nichts garantieren
#define COMP_DS3231     // Compile sketch with RTC Modul support
#define COMP_BMP085     // compile sketch with BMP085 is a high-precision, ultra-low power barometric pressure sensor support
#define COMP_DHT11      // compile sketch with DHT11 sensor support
#define COMP_GAS        //
#define COMP_MQ2        //

// Ab bitte prüfen, ob die Variablen wirklich global definiert sein müssen und bitte auch den Modulen zuordnen.
// Am Besten schon in die #ifdef ... #endif Bereich der Module verlagern
// Ganz am Ende ist noch eine Funktion, die nirgendwo gebraucht wird...
byte tMSB, tLSB;
float temp3231,temp3231d;
float tempbmp085, tempbmp085d;

int temp1[3];                //Temp1, temp2, hum1 & hum2 are the final integer values that you are going to use in your program. 
int temp2[3];                // They update every 2 seconds.
int hum1[3];
int hum2[3];

int sensor_mq2 = A2;    
int sensor_gas = A3;
char tmp[11];

//bmp085
const unsigned char OSS = 0;  // Oversampling Setting

// Calibration values
int ac1;
int ac2;
int ac3;
unsigned int ac4;
unsigned int ac5;
unsigned int ac6;
int b1;
int b2;
int mb;
int mc;
int md;
// b5 is calculated in bmp085GetTemperature(...), this variable is also used in bmp085GetPressure(...)
// so ...Temperature(...) must be called before ...Pressure(...).
long b5; 
int fehler = 0;
// Michel ende
#endif

//#define COMP_OSV2       // Compile sketch with OSV2 Support
//#define COMP_Cresta     // Compile sketch with Cresta Support (currently not implemented, just for future use)

// Future enhancement
//#define COMP_TX2_4    // Compile sketch for LaCroose TX2/4 support

//#define COMP_OSV3     // Compile sketch with OSV3 Support (currently not implemented, just for future use)

//#define COMP_Kaku     // Compile sketch with Kaku  Support (currently not implemented, just for future use)
//#define COMP_HEZ      // Compile sketch with Homeeasy Support (currently not implemented, just for future use)
//#define COMP_XRF      // Compile sketch with XTF Support (currently not implemented, just for future use)

/*
 * Modified code to fit info fhemduino - Sidey
 * Oregon V2 decoder modfied - Olivier Lebrun
 * Oregon V2 decoder added - Dominique Pierre
 * New code to decode OOK signals from weather sensors, etc.
 * 2010-04-11 <jcw@equi4.com> http://opensource.org/licenses/mit-license.php
 *
*/

/* Currently not working, this is for future Mode
#include "decoders.h";
#ifdef COMP_OSV2     // Compile sketch with OSV3 Support (currently not implemented, just for future use)
OregonDecoderV2 orscV2;
#endif

#ifdef COMP_Cresta     // Compile sketch with Cresta Support (currently not implemented, just for future use)
CrestaDecoder cres;
#endif

#ifdef COMP_Kaku     // Compile sketch with Kaku  Support (currently not implemented, just for future use)
KakuDecoder kaku;
#endif

#ifdef COMP_HEZ     // Compile sketch with Homeeasy Support (currently not implemented, just for future use)
HezDecoder hez;
#endif

#ifdef COMP_XRF
XrfDecoder xrf;
#endif
*/

class DecodeOOK {
  protected:
    byte total_bits, bits, flip, state, pos, data[25];

    virtual char decode (word width) = 0;

  public:

    enum { UNKNOWN, T0, T1, T2, T3, OK, DONE };

    DecodeOOK () {
      resetDecoder();
    }

    bool nextPulse (word width) {
      if (state != DONE)

        switch (decode(width)) {
          case -1: resetDecoder(); break;
          case 1:  done(); break;
        }
      return isDone();
    }

    bool isDone () const {
      return state == DONE;
    }

    const byte* getData (byte& count) const {
      count = pos;
      return data;
    }

    void resetDecoder () {
      total_bits = bits = pos = flip = 0;
      state = UNKNOWN;
    }

    // add one bit to the packet data buffer

    virtual void gotBit (char value) {
      total_bits++;
      byte *ptr = data + pos;
      *ptr = (*ptr >> 1) | (value << 7);

      if (++bits >= 8) {
        bits = 0;
        if (++pos >= sizeof data) {
          resetDecoder();
          return;
        }
      }
      state = OK;
    }

    // store a bit using Manchester encoding
    void manchester (char value) {
      flip ^= value; // manchester code, long pulse flips the bit
      gotBit(flip);
    }

    // move bits to the front so that all the bits are aligned to the end
    void alignTail (byte max = 0) {
      // align bits
      if (bits != 0) {
        data[pos] >>= 8 - bits;
        for (byte i = 0; i < pos; ++i)
          data[i] = (data[i] >> bits) | (data[i + 1] << (8 - bits));
        bits = 0;
      }
      // optionally shift bytes down if there are too many of 'em
      if (max > 0 && pos > max) {
        byte n = pos - max;
        pos = max;
        for (byte i = 0; i < pos; ++i)
          data[i] = data[i + n];
      }
    }

    void reverseBits () {
      for (byte i = 0; i < pos; ++i) {
        byte b = data[i];
        for (byte j = 0; j < 8; ++j) {
          data[i] = (data[i] << 1) | (b & 1);
          b >>= 1;
        }
      }
    }

    void reverseNibbles () {
      for (byte i = 0; i < pos; ++i)
        data[i] = (data[i] << 4) | (data[i] >> 4);
    }

    void done () {
      while (bits)
        gotBit(0); // padding
      state = DONE;
    }
};

#ifdef COMP_OSV2
class OregonDecoderV2 : public DecodeOOK {
  public:

    OregonDecoderV2() {}

    // add one bit to the packet data buffer
    virtual void gotBit (char value) {
      if (!(total_bits & 0x01))
      {
        data[pos] = (data[pos] >> 1) | (value ? 0x80 : 00);
      }
      total_bits++;
      pos = total_bits >> 4;
      if (pos >= sizeof data) {
        resetDecoder();
        return;
      }
      state = OK;
    }

    virtual char decode (word width) {
      if (200 <= width && width < 1200) {
        //Serial.print("Dauer="); Serial.println(width);
        //Serial.println(width);
        byte w = width >= 700;

        switch (state) {
          case UNKNOWN:
            if (w != 0) {
              // Long pulse
              ++flip;
            } else if (w == 0 && 24 <= flip) {
              // Short pulse, start bit
              flip = 0;
              state = T0;
            } else {
              // Reset decoder
              return -1;
            }
            break;
          case OK:
            if (w == 0) {
              // Short pulse
              state = T0;
            } else {
              // Long pulse
              manchester(1);
            }
            break;
          case T0:
            if (w == 0) {
              // Second short pulse
              manchester(0);
            } else {
              // Reset decoder
              return -1;
            }
            break;
        }
      } else if (width >= 2500  && pos >= 8) {
        return 1;
      } else {
        return -1;
      }
      return 0;
    }
};
OregonDecoderV2 orscV2;
#endif

#ifdef COMP_OSV3
class OregonDecoderV3 : public DecodeOOK {
  public:
    OregonDecoderV3() {}

    // add one bit to the packet data buffer
    virtual void gotBit (char value) {
      data[pos] = (data[pos] >> 1) | (value ? 0x80 : 00);
      total_bits++;
      pos = total_bits >> 3;
      if (pos >= sizeof data) {
        resetDecoder();
        return;
      }
      state = OK;
    }

    virtual char decode (word width) {
      if (200 <= width && width < 1200) {
        byte w = width >= 700;
        switch (state) {
          case UNKNOWN:
            if (w == 0)
              ++flip;
            else if (32 <= flip) {
              flip = 1;
              manchester(1);
            } else
              return -1;
            break;
          case OK:
            if (w == 0)
              state = T0;
            else
              manchester(1);
            break;
          case T0:
            if (w == 0)
              manchester(0);
            else
              return -1;
            break;
        }
      } else {
        return -1;
      }
      return  total_bits == 80 ? 1 : 0;
    }
};
OregonDecoderV3 orscV3;
#endif

#ifdef COMP_Cresta
class CrestaDecoder : public DecodeOOK {
  public:
    CrestaDecoder () {}

    const byte* getData (byte& count) const {

      count = pos;
      return data;
    }

    virtual char decode (word width) {
      if (200 <= width && width < 1300) {
        byte w = width >= 750;
        switch (state) {
          case UNKNOWN:
            if (w == 1)
              ++flip;
            else if (2 <= flip && flip <= 10)
              state = T0;
            else
              return -1;
            break;
          case OK:
            if (w == 0)
              state = T0;
            else
              gotBit(1);
            break;
          case T0:
            if (w == 0)
              gotBit(0);
            else
              return -1;
            break;
        }
      } else if (width >= 2500 && pos >= 7)
        return 1;
      else
        return -1;
      return 0;
    }

    virtual void gotBit (char value) {

      if (++bits <= 8) {

        total_bits++;
        byte *ptr = data + pos;
        *ptr = (*ptr >> 1) | (value << 7);
      }
      else {

        bits = 0;
        if (++pos >= sizeof data) {
          resetDecoder();
          return;
        }
      }
      state = OK;
    }


};
CrestaDecoder cres;
#endif

#ifdef COMP_KAKU
class KakuDecoder : public DecodeOOK {
  public:
    KakuDecoder () {}

    virtual char decode (word width) {
      if (180 <= width && width < 450 || 950 <= width && width < 1250) {
        byte w = width >= 700;
        switch (state) {
          case UNKNOWN:
          case OK:
            if (w == 0)
              state = T0;
            else
              return -1;
            break;
          case T0:
            if (w)
              state = T1;
            else
              return -1;
            break;
          case T1:
            state += w + 1;
            break;
          case T2:
            if (w)
              gotBit(0);
            else
              return -1;
            break;
          case T3:
            if (w == 0)
              gotBit(1);
            else
              return -1;
            break;
        }
      } else if (width >= 2500 && 8 * pos + bits == 12) {
        for (byte i = 0; i < 4; ++i)
          gotBit(0);
        alignTail(2);
        return 1;
      } else
        return -1;
      return 0;
    }
};
KakuDecoder kaku;
#endif

#ifdef COMP_XRF
class XrfDecoder : public DecodeOOK {
  public:
    XrfDecoder () {}

    // see also http://davehouston.net/rf.htm
    virtual char decode (word width) {
      if (width > 2000 && pos >= 4)
        return 1;
      if (width > 5000)
        return -1;
      if (width > 4000 && state == UNKNOWN)
        state = OK;
      else if (350 <= width && width < 1800) {
        byte w = width >= 720;
        switch (state) {
          case OK:
            if (w == 0)
              state = T0;
            else
              return -1;
            break;
          case T0:
            gotBit(w);
            break;
        }
      } else
        return -1;
      return 0;
    }
};
XrfDecoder xrf;
#endif

#ifdef COMP_HEZ
class HezDecoder : public DecodeOOK {
  public:
    HezDecoder () {}

    // see also http://homeeasyhacking.wikia.com/wiki/Home_Easy_Hacking_Wiki
    virtual char decode (word width) {
      if (200 <= width && width < 1200) {
        byte w = width >= 600;
        gotBit(w);
      } else if (width >= 5000 && pos >= 5 /*&& 8 * pos + bits == 50*/) {
        for (byte i = 0; i < 6; ++i)
          gotBit(0);
        alignTail(7); // keep last 56 bits
        return 1;
      } else
        return -1;
      return 0;
    }
};
HezDecoder hez;
#endif

/*
 * Weather sensors
 */
#define MAX_CHANGES            90
unsigned int timings5000[MAX_CHANGES];      //  Startbit_5000
unsigned int timings2500[MAX_CHANGES];      //  Startbit_2500

String cmdstring;
volatile bool available = false;
String message = "";

#ifdef COMP_DCF77
/*
 * DCF77_SerialTimeOutput
 * Ralf Bohnen, 2013
 * This example code is in the public domain.
 */
 
#include "DCF77.h"
 
char time_s[9];
char date_s[11];
 
#if defined(__AVR_ATmega32U4__)          //on the leonardo and other ATmega32U4 devices interrupt 1 is on dpin 2
  #define DCF_PIN 2            // Connection pin to DCF 77 device
#else
  #define DCF_PIN 3            // Connection pin to DCF 77 device
#endif

#define DCF_INTERRUPT 1      // Interrupt number associated with pin
 
time_t time;
DCF77 DCF = DCF77(DCF_PIN, DCF_INTERRUPT);

char* sprintTime() {
    snprintf(time_s,sizeof(time_s),"%02d%02d%02d" , hour(), minute(), second());
    time_s[strlen(time_s)] = '\0';
    return time_s;
}
 
char* sprintDate() {
    snprintf(date_s,sizeof(date_s),"%02d%02d%04d" , day(), month(), year());
    date_s[strlen(date_s)] = '\0';
    return date_s;
}
#endif

void setup() {
  // put your setup code here, to run once:
  
  Serial.begin(BAUDRATE);
  enableReceive();
  pinMode(PIN_RECEIVE,INPUT);
  pinMode(PIN_SEND,OUTPUT);

  Wire.begin();
  DDRC |= _BV(DHT11_PIN);
  PORTC |= _BV(DHT11_PIN);

#ifdef COMP_3231
  get3231Temp_start();
#endif

#ifdef COMP_BMP085
  bmp085Calibration(); //nur wenn bmp085 angeschlossen
#endif

#ifdef DEBUG
    Serial.println(" -------------------------------------- ");
    Serial.print("    ");
    Serial.print(PROGNAME);
    Serial.print(" ");
    Serial.println(PROGVERS);
    Serial.println(" -------------------------------------- ");
#endif

#ifdef COMP_DCF77
    DCF.Start();

#ifdef DEBUG
    Serial.println("Warte auf Zeitsignal ... ");
    Serial.println("Dies kann 2 oder mehr Minuten dauern.");
#endif

#endif

}

void loop() {
  static uint32_t timer;
  int geraete_zahl = 1;
  int geraete = 2; 

  // put your main code here, to run repeatedly: 

  if (millis() > timer) {
    timer = millis() + 100000;
#ifdef COMP_GAS
    gas_sendData();
#endif
/*     switch(geraete_zahl){
        case 1:  mq2_sendData();
                 break;
        case 2:  gas_sendData();
                 break;
        case 3:  getdht11();
                 break;
        case 4:  getbmp085();
                 break;
     }
     if (geraete_zahl == geraete) {geraete_zahl = 0;}
     geraete_zahl++;
//     Serial.println(fehler);*/
  }

  if (messageAvailable()) {
    Serial.println(message);
    resetAvailable();
  }

#ifdef COMP_DCF77
    time_t DCFtime = DCF.getTime(); // Nachschauen ob eine neue DCF77 Zeit vorhanden ist
    if (DCFtime!=0)
    {
      setTime(DCFtime); //Neue Systemzeit setzen
      // Serial.print("Neue Zeit erhalten : "); //Ausgabe an seriell
      Serial.print("D"); 
      Serial.print(sprintTime()); 
      Serial.print("-"); 
      Serial.println(sprintDate());   
    }
#endif

//serialEvent does not work on ATmega32U4 devices like the Leonardo, so we do the handling ourselves
#if defined(__AVR_ATmega32U4__)
  if (Serial.available()) {
    serialEvent();
  }
#endif
}

/*
 * Interrupt System
 */

void enableReceive() {
  attachInterrupt(0,handleInterrupt,CHANGE);
}

void disableReceive() {
  detachInterrupt(0);
}

void handleInterrupt() {
  static unsigned int duration;
  static unsigned long lastTime;

  duration = micros() - lastTime;
  
#ifdef COMP_FA20RF
  FA20RF(duration);
#endif
  Startbit_5000(duration);
  Startbit_2500(duration);

#ifdef COMP_OSV2
  if (orscV2.nextPulse(duration) )
  {
    byte len;
    const byte* data = orscV2.getData(len);

    char tmp[36]="";
    int tmp_len = 0;
    strcat(tmp, "OSV2:");
    tmp_len = 5;
#ifdef DEBUG
    Serial.print("HEXStream");
#endif

    for (byte i = 0; i < len; ++i) {
#ifdef DEBUG
        Serial.print(data[i] >> 4, HEX);
        Serial.print(data[i] & 0x0F, HEX);
        Serial.print(",");
#endif
      tmp_len += snprintf(tmp + tmp_len, 36, "%X", data[i]);
    }

#ifdef DEBUG
    Serial.println(" ");
#endif

    message = tmp;
    available = true;
    orscV2.resetDecoder();
  }
#endif

#ifdef COMP_Cresta
  if (cres.nextPulse(duration))
  {
    byte len;
    const byte* data = orscV2.getData(len) + 5;
    char tmp[36]="";
    int tmp_len = 0;
    strcat(tmp, "CRESTA:");
    tmp_len = 7;

#ifdef DEBUG
      Serial.print("HEXStream");
#endif

    for (byte i = 0; i < len; ++i) {
#ifdef DEBUG
        Serial.print(data[i] >> 4, HEX);
        Serial.print(data[i] & 0x0F, HEX);
        Serial.print(",");
#endif
      tmp_len += snprintf(tmp + tmp_len, 36, "%X", data[i]);
    }
    
#ifdef DEBUG
      Serial.println(" ");
#endif

    message = tmp;
    available = true;
  }
  cres.resetDecoder();
#endif

  lastTime += duration;
}

#ifdef COMP_FA20RF
/*
 * FA20RF Receiver
 */
#define FA20_MAX_CHANGES 60
unsigned int timingsFA20[FA20_MAX_CHANGES];      //  FA20RF

void FA20RF(unsigned int duration) {
#define L_STARTBIT_TIME         8020
#define H_STARTBIT_TIME         8120
#define L_STOPBIT_TIME          10000
#define H_STOPBIT_TIME          14500

  static unsigned int changeCount;

  if (duration > L_STARTBIT_TIME && duration < H_STARTBIT_TIME) {
    changeCount = 0;
    timingsFA20[0] = duration;
  } 
  else if ((duration > L_STOPBIT_TIME && duration < H_STOPBIT_TIME) && ( timingsFA20[0] > L_STARTBIT_TIME && timingsFA20[0] < H_STARTBIT_TIME)) {
    timingsFA20[changeCount] = duration;
    receiveProtocolFA20RF(changeCount);
    changeCount = 0;
  }

  if (changeCount >= FA20_MAX_CHANGES) {
    changeCount = 0;
  }
  timingsFA20[changeCount++] = duration;
}

/*
 * FA20RF Decoder
 */
void receiveProtocolFA20RF(unsigned int changeCount) {
#define FA20RF_SYNC   8060
#define FA20RF_SYNC2  960
#define FA20RF_ONE    2740
#define FA20RF_ZERO   1450
#define FA20RF_GLITCH  70
#define FA20RF_MESSAGELENGTH 24

  if (changeCount < (FA20RF_MESSAGELENGTH * 2)) {
#ifdef DEBUG
    Serial.print("changeCount: ");
    Serial.println(changeCount);
#endif
    return;
  }
  
  if ((timingsFA20[0] < FA20RF_SYNC - FA20RF_GLITCH) || (timingsFA20[0] > FA20RF_SYNC + FA20RF_GLITCH)) {
#ifdef DEBUG
    Serial.print("timingsFA20[0]: ");
    Serial.println(timingsFA20[0]);
#endif
    return;
  }

  if ((timingsFA20[1] < FA20RF_SYNC2 - FA20RF_GLITCH) || (timingsFA20[1] > FA20RF_SYNC2 + FA20RF_GLITCH)) {
#ifdef DEBUG
    Serial.print("timingsFA20[1]: ");
    Serial.println(timingsFA20[1]);
#endif
    return;
  }

  byte i;
  unsigned long code = 0;

  for (i = 1; i < (FA20RF_MESSAGELENGTH * 2); i = i + 2)
  {
    if ((timingsFA20[i + 2] > FA20RF_ZERO - FA20RF_GLITCH) && (timingsFA20[i + 2] < FA20RF_ZERO + FA20RF_GLITCH))    {
      code <<= 1;
    }
    else if ((timingsFA20[i + 2] > FA20RF_ONE - FA20RF_GLITCH) && (timingsFA20[i + 2] < FA20RF_ONE + FA20RF_GLITCH)) {
      code <<= 1;
      code |= 1;
    }
    else {
#ifdef DEBUG
      Serial.print("timingsFA20[");
      Serial.print(i + 2);
      Serial.print("]: ");
      Serial.println(timingsFA20[i + 2]);
      Serial.print("timingsFA20[51]: ");
      Serial.println(timingsFA20[51]);
#endif
      return;
    }
  }

#ifdef DEBUG
  Serial.println(code,BIN);
#endif

  char tmp[5];
  message = "F";
  message += String(code,HEX);

  sprintf(tmp, "%05u", timingsFA20[i+2]);
  message += "-";
  message += tmp;

  available = true;
  return;
}

void sendFA20RF(char* triStateMessage) {
  unsigned int pos = 0;

  // sd010011010100111011111101#
  for (int i = 0; i < 14; i++) {
    delay(1);
    pos = 0;
    disableReceive();
    digitalWrite(PIN_SEND, HIGH);
    delayMicroseconds(8040);
    digitalWrite(PIN_SEND, LOW);
    delayMicroseconds(920);
    enableReceive();
    while (triStateMessage[pos] != '\0') {
      switch(triStateMessage[pos]) {
      case '0':
        disableReceive();
        digitalWrite(PIN_SEND, HIGH);
        delayMicroseconds(740);
        digitalWrite(PIN_SEND, LOW);
        delayMicroseconds(1440);
        enableReceive();
        break;
      case '1':
        disableReceive();
        digitalWrite(PIN_SEND, HIGH);
        delayMicroseconds(740);
        digitalWrite(PIN_SEND, LOW);
        delayMicroseconds(2740);
        enableReceive();
        break;
      }
      pos++;
    }
    disableReceive();
    digitalWrite(PIN_SEND, HIGH);
    delayMicroseconds(750);
    digitalWrite(PIN_SEND, LOW);
    delayMicroseconds(12000);
    digitalWrite(PIN_SEND, HIGH);
    delayMicroseconds(35);
    digitalWrite(PIN_SEND, LOW);
    enableReceive();
  }
  Serial.print("Ende Senden: ");
  Serial.println(pos);
}
#endif

/*
 * decoders with an startbit > 5000
 */
void Startbit_5000(unsigned int duration) {
#define STARTBIT_TIME   5000
#define STARTBIT_OFFSET 200

  static unsigned int changeCount;
  static unsigned int repeatCount;
  bool rc = false;

  if (duration > STARTBIT_TIME && duration > timings5000[0] - STARTBIT_OFFSET && duration < timings5000[0] + STARTBIT_OFFSET) {
    repeatCount++;
    changeCount--;
    if (repeatCount == 2) {
#ifdef DEBUG
      Serial.print("changeCount: ");
      Serial.println(changeCount);
      Serial.print("Timings: ");
      Serial.println(timings5000[0]);
#endif
#ifdef COMP_KW9010
      if (rc == false) {
        rc = receiveProtocolKW9010(changeCount);
      }
#endif
#ifdef COMP_NC_WS
      if (rc == false) {
        rc = receiveProtocolNC_WS(changeCount);
      }
#endif
#ifdef COMP_EUROCHRON
      if (rc == false) {
        rc = receiveProtocolEuroChron(changeCount);
      }
#endif
#ifdef COMP_PT2262
      if (rc == false) {
        rc = receiveProtocolPT2262(changeCount);
      }
#endif
#ifdef COMP_LIFETEC
      if (rc == false) {
        rc = receiveProtocolLIFETEC(changeCount);
      }
#endif
      if (rc == false) {
        // rc = next decoder;
      }
      repeatCount = 0;
    }
    changeCount = 0;
  } 
  else if (duration > STARTBIT_TIME) {
    changeCount = 0;
  }

  if (changeCount >= MAX_CHANGES) {
    changeCount = 0;
    repeatCount = 0;
  }
  timings5000[changeCount++] = duration;
}

/*
 * decoders with an startbit > 2500
 */
void Startbit_2500(unsigned int duration) {
#define STARTBIT_TIME2         2500
#define STARTBIT_OFFSET2       100

  static unsigned int changeCount;
  static unsigned int repeatCount;
  bool rc = false;

  if (duration > STARTBIT_TIME2 && duration > timings2500[0] - STARTBIT_OFFSET2 && duration < timings2500[0] + STARTBIT_OFFSET2) {
    repeatCount++;
    changeCount--;
    if (repeatCount == 2) {
#ifdef COMP_TX70DTH
      if (rc == false) {
        rc = receiveProtocolTX70DTH(changeCount);
      }
#endif
      if (rc == false) {
        // rc = next decoder;
      }
      repeatCount = 0;
    }
    changeCount = 0;
  } 
  else if (duration > STARTBIT_TIME2) {
    changeCount = 0;
  }

  if (changeCount >= MAX_CHANGES) {
    changeCount = 0;
    repeatCount = 0;
  }
  timings2500[changeCount++] = duration;
}

/*
 * Serial Command Handling
 */
void serialEvent()
{
  while (Serial.available())
  {
    char inChar = (char)Serial.read();
    switch(inChar)
    {
    case '\n':
    case '\r':
    case '\0':
      HandleCommand(cmdstring);
      break;
    default:
      cmdstring = cmdstring + inChar;
    }
  }
}

void HandleCommand(String cmd)
{
  // Version Information
  if (cmd.equals("V"))
  {
    Serial.println(F("V 1.0b1 FHEMduino - compiled at " __DATE__ " " __TIME__));
  }
  // Print free Memory
  else if (cmd.equals("R")) {
    Serial.print(F("R"));
    Serial.println(freeRam());
  }
#ifdef COMP_FA20RF
  // Switch FA20RF Devices
  else if (cmd.startsWith("sd"))
  {
  // sd010011010100111011111101#
    digitalWrite(PIN_LED,HIGH);
    char msg[30];
    cmd.substring(2).toCharArray(msg,30);
    sendFA20RF(msg);
    digitalWrite(PIN_LED,LOW);
    Serial.println(msg);
  }
#endif
#ifdef COMP_PT2262
  // Switch Intertechno Devices
  else if (cmd.startsWith("is"))
  {
    digitalWrite(PIN_LED,HIGH);
    char msg[13];
    cmd.substring(2).toCharArray(msg,13);
    sendPT2262(msg);
    digitalWrite(PIN_LED,LOW);
    Serial.println(cmd);
  }
#endif
  else if (cmd.equals("XQ")) {
    disableReceive();
    Serial.flush();
    Serial.end();
  }
  // Print Available Commands
  else if (cmd.equals("?"))
  {
    Serial.println(F("? Use one of V is R q"));
  }
  cmdstring = "";
}

// Get free RAM of UC
int freeRam () {
  extern int __heap_start, *__brkval; 
  int v; 
  return (int) &v - (__brkval == 0 ? (int) &__heap_start : (int) __brkval); 
}

/*
 * Message Handling
 */
bool messageAvailable() {
  return (available && (message.length() > 0));
}

void resetAvailable() {
  available = false;
  message = "";
}

#ifdef COMP_KW9010
/*
 * KW9010
 */
bool receiveProtocolKW9010(unsigned int changeCount) {
#define KW9010_SYNC 9000
#define KW9010_ONE 4000
#define KW9010_ZERO 2000
#define KW9010_GLITCH 200
#define KW9010_MESSAGELENGTH 36

  bool bitmessage[KW9010_MESSAGELENGTH + 1];
  int bitcount = 0;
  int i = 0;

  if (changeCount < KW9010_MESSAGELENGTH * 2) return false;

  if ((timings5000[0] < KW9010_SYNC - KW9010_GLITCH) || (timings5000[0] > KW9010_SYNC + KW9010_GLITCH)) {
    return false;
  }

  //Serial.println(changeCount);
  for (int i = 2; i < changeCount; i=i+2) {
    if ((timings5000[i] > KW9010_ZERO - KW9010_GLITCH) && (timings5000[i] < KW9010_ZERO + KW9010_GLITCH)) {
      // its a zero
      bitmessage[bitcount] = false;
      bitcount++;
    }
    else if ((timings5000[i] > KW9010_ONE - KW9010_GLITCH) && (timings5000[i] < KW9010_ONE + KW9010_GLITCH)) {
      // its a one
      bitmessage[bitcount] = true;
      bitcount++;
    }
    else {
      return false;
    }
  }

#ifdef DEBUG
    Serial.print("Bit-Stream: ");
    for (i = 0; i < KW9010_MESSAGELENGTH; i++) {
      Serial.print(TX2_4_bitmessage[i]);
    }
    Serial.println();
#endif

  // Sensor ID & Channel
  byte id = bitmessage[7] | bitmessage[6] << 1 | bitmessage[5] << 2 | bitmessage[4] << 3 | bitmessage[3] << 4 | bitmessage[2] << 5 | bitmessage[1] << 6 | bitmessage[0] << 7;

  // (Propably) Battery State
  bool battery = bitmessage[8];

  // Trend
  byte trend = bitmessage[9] << 1 | bitmessage[10];

  // Trigger
  bool forcedSend = bitmessage[11];

  // Temperature & Humidity
  int temperature = ((bitmessage[23] << 11 | bitmessage[22] << 10 | bitmessage[21] << 9 | bitmessage[20] << 8 | bitmessage[19] << 7 | bitmessage[18] << 6 | bitmessage[17] << 5 | bitmessage[16] << 4 | bitmessage[15] << 3 | bitmessage[14] << 2 | bitmessage[13] << 1 | bitmessage[12]) << 4 ) >> 4;
  byte humidity = (bitmessage[31] << 7 | bitmessage[30] << 6 | bitmessage[29] << 5 | bitmessage[28] << 4 | bitmessage[27] << 3 | bitmessage[26] << 2 | bitmessage[25] << 1 | bitmessage[24]) - 156;

  // check Data integrity
  byte checksum = (bitmessage[35] << 3 | bitmessage[34] << 2 | bitmessage[33] << 1 | bitmessage[32]);
  byte calculatedChecksum = 0;

  for ( i = 0 ; i <= 7 ; i++) {
    calculatedChecksum += (byte)(bitmessage[i*4 + 3] <<3 | bitmessage[i*4 + 2] << 2 | bitmessage[i*4 + 1] << 1 | bitmessage[i*4]);
  }
  calculatedChecksum &= 0xF;

  if (calculatedChecksum == checksum) {
    if (temperature > -500 && temperature < 700) {
      if (humidity > 0 && humidity < 100) {
        char tmp[11];
        sprintf(tmp,"K%02X%01d%01d%01d%+04d%02d", id, battery, trend, forcedSend, temperature, humidity);
        message = tmp;
        available = true;
        return true;
      }
    }
  }
  return false;
}
#endif

#ifdef COMP_PT2262
/*
 * PT2262 Stuff
 */
#define RECEIVETOLERANCE       60

bool receiveProtocolPT2262(unsigned int changeCount) {

  message = "IR";
  if (changeCount != 49) {
    return false;
  }
  unsigned long code = 0;
  unsigned long delay = timings5000[0] / 31;
  unsigned long delayTolerance = delay * RECEIVETOLERANCE * 0.01; 

  // 1 3 5 7 9 11 13 15 17 19 21 23 25 27 29 31 33 35 37 39 41 43 45 47
  for (int i = 1; i < changeCount; i=i+2) {
    if (timings5000[i] > delay-delayTolerance && timings5000[i] < delay+delayTolerance && timings5000[i+1] > delay*3-delayTolerance && timings5000[i+1] < delay*3+delayTolerance) {
      code = code << 1;
    }
    else if (timings5000[i] > delay*3-delayTolerance && timings5000[i] < delay*3+delayTolerance && timings5000[i+1] > delay-delayTolerance && timings5000[i+1] < delay+delayTolerance)  { 
      code += 1;
      code = code << 1;
    }
    else {
      code = 0;
      i = changeCount;
      return false;
    }
  }
  code = code >> 1;
  message += code;
  available = true;
  return true;
}
void sendPT2262(char* triStateMessage) {
  for (int i = 0; i < 3; i++) {
    unsigned int pos = 0;
    while (triStateMessage[pos] != '\0') {
      switch(triStateMessage[pos]) {
      case '0':
        PT2262_sendT0();
        break;
      case 'F':
        PT2262_sendTF();
        break;
      case '1':
        PT2262_sendT1();
        break;
      }
      pos++;
    }
    PT2262_sendSync();    
  }
}

void PT2262_sendT0() {
  PT2262_transmit(1,3);
  PT2262_transmit(1,3);
}

void PT2262_sendT1() {
  PT2262_transmit(3,1);
  PT2262_transmit(3,1);
}

void PT2262_sendTF() {
  PT2262_transmit(1,3);
  PT2262_transmit(3,1);
}

void PT2262_sendSync() {
  PT2262_transmit(1,31);
}

void PT2262_transmit(int nHighPulses, int nLowPulses) {
  disableReceive();
  digitalWrite(PIN_SEND, HIGH);
  delayMicroseconds(350 * nHighPulses);
  digitalWrite(PIN_SEND, LOW);
  delayMicroseconds(350 * nLowPulses);
  enableReceive();
}
#endif

#ifdef COMP_NC_WS
/*
 * NC_WS / PEARL NC7159, LogiLink W0002
 */
bool receiveProtocolNC_WS(unsigned int changeCount) {
#define NC_WS_SYNC   9250
#define NC_WS_ONE    3900
#define NC_WS_ZERO   1950
#define NC_WS_GLITCH 100
#define NC_WS_MESSAGELENGTH 36

  if (changeCount < NC_WS_MESSAGELENGTH * 2) {
    return false;
  }
  
  if ((timings5000[0] < NC_WS_SYNC - NC_WS_GLITCH) || (timings5000[0] > NC_WS_SYNC + NC_WS_GLITCH)) {
    return false;
  }

  int i = 0;
  bool bitmessage[NC_WS_MESSAGELENGTH];

  for (i = 0; i < (NC_WS_MESSAGELENGTH * 2); i = i + 2)
  {
    if ((timings5000[i + 2] > NC_WS_ZERO - NC_WS_GLITCH) && (timings5000[i + 2] < NC_WS_ZERO + NC_WS_GLITCH))    {
      bitmessage[i >> 1] = false;
    }
    else if ((timings5000[i + 2] > NC_WS_ONE - NC_WS_GLITCH) && (timings5000[i + 2] < NC_WS_ONE + NC_WS_GLITCH)) {
      bitmessage[i >> 1] = true;
    }
    else {
      return false;
    }
  }

#ifdef DEBUG
/*  Serial.print("NC_WS: ");
  for (i = 0; i < NC_WS_MESSAGELENGTH; i++) {
    if(i==4) Serial.print(" ");
    if(i==12) Serial.print(" ");
    if(i==13) Serial.print(" ");
    if(i==14) Serial.print(" ");
    if(i==16) Serial.print(" ");
    if(i==17) Serial.print(" ");
    if(i==28) Serial.print(" ");
    if(i==29) Serial.print(" ");
    Serial.print(bitmessage[i]);
  }
  Serial.println(); */

  //                 /--------------------------------- Sensdortype      
  //                /    / ---------------------------- ID, changes after every battery change      
  //               /    /        /--------------------- Battery state 0 == Ok
  //              /    /        /  / ------------------ forced send      
  //             /    /        /  /  / ---------------- Channel (0..2)      
  //            /    /        /  /  /  / -------------- neg Temp: if 1 then temp = temp - 2048
  //           /    /        /  /  /  /   / ----------- Temp
  //          /    /        /  /  /  /   /          /-- unknown
  //         /    /        /  /  /  /   /          /  / Humidity
  //         0101 00101001 0  0  00 0  01000110000 1  1011101
  // Bit     0    4        12 13 14 16 17          28 29    36
#endif

  // Sensor type (Type 5)
  byte unsigned id = 0;
  for (i = 0; i < 4; i++) if (bitmessage[i]) id +=  1 << (3 - i);
  if (id != 5) {
    return false;
  }

  // Sensor ID, will change after ever battery replacement
  id = 0; 
  for (i = 4; i < 12; i++)  if (bitmessage[i]) id +=  1 << (11 - i);

  // Bit 12 : Battery State
  bool battery = !bitmessage[12];

  // Bit 13 : Trigger
  bool forcedSend = bitmessage[13];

  // Bit 14 + 15 = Sensor channel, depends on channel switch: 0 - 2
  byte unsigned channel = bitmessage[15] | bitmessage[14]  << 1;

  // Bit 16 : Temperatur sign (+/-)

  // Temperatur
  int temperature = 0;
  for (i = 17; i < 28; i++) if (bitmessage[i]) temperature +=  1 << (27 - i);
  if (bitmessage[16]) temperature -= 2048; // negative Temp

  // Don't know ?
  byte trend = 0;
  for (i = 28; i < 29; i++)  if (bitmessage[i]) trend +=  1 << (29 - i);

  // die restlichen 6 Bits fuer Luftfeuchte
  int humidity = 0;
  for (i = 29; i < 36; i++) if (bitmessage[i]) humidity +=  1 << (35 - i);

  char tmp[13];
  sprintf(tmp, "L%01d%02x%01d%01d%01d%+04d%02d", channel, id, battery, trend, forcedSend, temperature, humidity);
  message = tmp;
  available = true;
  return true;
}
#endif

#ifdef COMP_EUROCHRON
/*
 * EUROCHRON
 */
bool receiveProtocolEuroChron(unsigned int changeCount) {
#define EuroChron_SYNC   8050
#define EuroChron_ONE    2020
#define EuroChron_ZERO   1010
#define EuroChron_GLITCH  100
#define EuroChron_MESSAGELENGTH 36

  if (changeCount < EuroChron_MESSAGELENGTH * 2) {
    return false;
  }

  int i = 0;
  bool bitmessage[EuroChron_MESSAGELENGTH];

  if ((timings5000[0] < EuroChron_SYNC - EuroChron_GLITCH) && (timings5000[0] > EuroChron_SYNC + EuroChron_GLITCH)) {
    return false;
  }
  
  for (i = 0; i < (EuroChron_MESSAGELENGTH * 2); i = i + 2)
  {
    if ((timings5000[i + 2] > EuroChron_ZERO - EuroChron_GLITCH) && (timings5000[i + 2] < EuroChron_ZERO + EuroChron_GLITCH))    {
      bitmessage[i >> 1] = false;
    }
    else if ((timings5000[i + 2] > EuroChron_ONE - EuroChron_GLITCH) && (timings5000[i + 2] < EuroChron_ONE + EuroChron_GLITCH)) {
      bitmessage[i >> 1] = true;
    }
    else {
      return false;
    }
  }

#ifdef DEBUG
  //                /--------------------------- Channel, changes after every battery change      
  //               /        / ------------------ Battery state 0 == Ok      
  //              /        / /------------------ unknown      
  //             /        / /  / --------------- forced send      
  //            /        / /  /  / ------------- unknown      
  //           /        / /  /  /     / -------- Humidity      
  //          /        / /  /  /     /       / - neg Temp: if 1 then temp = temp - 2048
  //         /        / /  /  /     /       /  / Temp
  //         01100010 1 00 1  00000 0100011 0  00011011101
  // Bit     0        8 9  11 12    17      24 25        36

  Serial.print("Bit-Stream: ");
  for (i = 0; i < EuroChron_MESSAGELENGTH; i++) {
    if(i==8) Serial.print(" ");  
    if(i==9) Serial.print(" ");  
    if(i==11) Serial.print(" "); 
    if(i==12) Serial.print(" "); 
    if(i==17) Serial.print(" "); 
    if(i==24) Serial.print(" "); 
    if(i==25) Serial.print(" "); 
    Serial.print(bitmessage[i]);
  }
  Serial.println();
#endif

  // Sensor ID & Channel, will be changed after every battery change
  byte unsigned id = 0;
  for (i = 0; i < 8; i++)  if (bitmessage[i]) id +=  1 << (7 - i);

  // Battery State
  bool battery = bitmessage[8];
  
  // first unknown
  byte firstunknown = 0;
  for (i = 9; i < 11; i++)  if (bitmessage[i]) firstunknown +=  1 << (10 - i);

  // Trigger
  bool forcedSend = bitmessage[11];
  
  // second unknown
  byte secunknown = 0;
  for (i = 12; i < 17; i++)  if (bitmessage[i]) secunknown +=  1 << (16 - i);

  // Luftfeuchte
  int humidity = 0;
  for (i = 17; i < 24; i++) if (bitmessage[i]) humidity +=  1 << (23 - i);

  // Temperatur
  int temperature = 0;
  for (i = 25; i < 36; i++) if (bitmessage[i]) temperature +=  1 << (35 - i);
  if (bitmessage[24]) temperature -= 2048; // negative Temp

  char tmp[14];
  sprintf(tmp, "T%02x%01d%01d%01d%02d%+04d%02d", id, battery, firstunknown, forcedSend, secunknown, temperature, humidity);
  message = tmp;
  available = true;
  return true;
}
#endif

#ifdef COMP_LIFETEC
/*
 * LIFETEC
 */
bool receiveProtocolLIFETEC(unsigned int changeCount) {
#define LIFETEC_SYNC   8640
#define LIFETEC_ONE    4084
#define LIFETEC_ZERO   2016
#define LIFETEC_GLITCH  460
#define LIFETEC_MESSAGELENGTH 24

  bool bitmessage[24];
  int i = 0;

  if (changeCount < LIFETEC_MESSAGELENGTH * 2) {
    return false;
  }
  if ((timings5000[0] < LIFETEC_SYNC - LIFETEC_GLITCH) || (timings5000[0] > LIFETEC_SYNC + LIFETEC_GLITCH)) {
    return false;
  }

  for (i = 0; i < (LIFETEC_MESSAGELENGTH * 2); i = i + 2)
  {
    if ((timings5000[i + 2] > LIFETEC_ZERO - LIFETEC_GLITCH) && (timings5000[i + 2] < LIFETEC_ZERO + LIFETEC_GLITCH))    {
      bitmessage[i >> 1] = false;
    }
    else if ((timings5000[i + 2] > LIFETEC_ONE - LIFETEC_GLITCH) && (timings5000[i + 2] < LIFETEC_ONE + LIFETEC_GLITCH)) {
      bitmessage[i >> 1] = true;
    }
    else {
      return false;
    }
  }
  
  //                /------------------------------------- Channel, changes after every battery change      
  //               /        / ---------------------------- neg Temp: normal = 000 if 111 then temp = temp - 512      
  //              /        / /---------------------------- Temp      
  //             /        / /       / -------------------- Battery state 1 == Ok      
  //            /        / /       /  /------------------- forced send      
  //           /        / /       /  /  /----------------- filler ?
  //          /        / /       /  /  /  /--------------- TEMP Nachkommastelle
  //         /        / /       /  /  /  /  
  //         11010010 0 0011100 1  0  00 1001
  // Bit     0        8 9       16 17 18 20  24

#ifdef DEBUG
    Serial.print("Bit-Stream: ");
    for (i = 0; i < LIFETEC_MESSAGELENGTH; i++) {
      Serial.print(bitmessage[i]);
    }
    Serial.println();
  }
#endif

  // Sensor ID & Channel, will be changed after every battery change
  byte unsigned id = 0;
  for (i = 0; i < 8; i++)  if (bitmessage[i]) id +=  1 << (7 - i);

  // Battery State
  bool battery = bitmessage[16];
  if (battery = 1) {battery = 0;} else if (battery = 0) {battery = 1;}

  // (Propably) Trend
  byte trend = 0; //nicht unterstüzt

  // Trigger
  bool forcedSend = bitmessage[17];
  
  // Temperatur
  int temperature = 0;
  for (i = 9; i < 16; i++) if (bitmessage[i]) temperature +=  1 << (15 - i);
  temperature = temperature * 10;
  for (i = 20; i < 24; i++) if (bitmessage[i]) temperature +=  1 << (23 - i);
  if (bitmessage[8]) temperature = -temperature; // negative Temp

  // Luftfeuchte
  int humidity = 0; //nicht unterstüzt

  char tmp[12];
  sprintf(tmp, "K%02x%01d%01d%01d%+04d%02d", id, battery, trend, forcedSend, temperature, humidity);
  message = tmp;
  available = true;
  return true;
}
#endif

#ifdef COMP_TX70DTH
/*
 * TX70DTH
 */
bool receiveProtocolTX70DTH(unsigned int changeCount) {
#define TX70DTH_SYNC   4000
#define TX70DTH_ONE    2030
#define TX70DTH_ZERO   1020
#define TX70DTH_GLITCH  250
#define TX70DTH_MESSAGELENGTH 36

  bool bitmessage[TX70DTH_MESSAGELENGTH];
  byte i;
  if (changeCount < TX70DTH_MESSAGELENGTH * 2) {
    return false;
  }
  if ((timings2500[0] < TX70DTH_SYNC - TX70DTH_GLITCH) || (timings2500[0] > TX70DTH_SYNC + TX70DTH_GLITCH)) {
    return false;
  }
  for (i = 0; i < (TX70DTH_MESSAGELENGTH * 2); i = i + 2)
  {
    if ((timings2500[i + 2] > TX70DTH_ZERO - TX70DTH_GLITCH) && (timings2500[i + 2] < TX70DTH_ZERO + TX70DTH_GLITCH))    {
      bitmessage[i >> 1] = false;
    }
    else if ((timings2500[i + 2] > TX70DTH_ONE - TX70DTH_GLITCH) && (timings2500[i + 2] < TX70DTH_ONE + TX70DTH_GLITCH)) {
      bitmessage[i >> 1] = true;
    }
    else {
      return false;
    }
  }

#ifdef DEBUG
  //                /--------------------------------- Channel, changes after every battery change      
  //               /        / ------------------------ Battery state 1 == Ok      
  //              /        / /------------------------ Kanal 000 001 010 hier (Kanal 3)      
  //             /        / /   / -------------------- neg Temp: normal = 000 if 111 then temp = temp - 512      
  //            /        / /   /   / ----------------- Temp      
  //           /        / /   /   /         / -------- filler also 1111      
  //          /        / /   /   /         /     /---- Humidity
  //         /        / /   /   /         /     /  
  //         11111101 1 010 000 011111001 1111 00101111
  // Bit     0        8 9   12  15        24   28     35

  Serial.print("Bit-Stream: ");
  if(i==8) Serial.print(" ");  
  if(i==9) Serial.print(" ");  
  if(i==12) Serial.print(" "); 
  if(i==15) Serial.print(" "); 
  if(i==24) Serial.print(" "); 
  if(i==28) Serial.print(" "); 
  for (i = 0; i < TX70DTH_MESSAGELENGTH; i++) {
    Serial.print(bitmessage[i]);
  }
  Serial.println();
#endif

  // Sensor ID & Channel
  byte unsigned id = bitmessage[3] | bitmessage[2] << 1 | bitmessage[1] << 2 | bitmessage[0] << 3 ;
  id = 0; // unterdruecke Bit 4+5, jetzt erst einmal nur 6 Bit
  for (i = 6; i < 12; i++)  if (bitmessage) id +=  1 << (13 - i);

  // Bit 9 : immer 1 oder doch Battery State ?
  bool battery = bitmessage[8];

  // Bit 11 + 12 = Kanal  0 - 2 , id nun bis auf 8 Bit fuellen
  id = id | bitmessage[10] << 1 | bitmessage[11] ;

  // Trigger
  bool forcedSend = 0; // wird nicht unterstützt
  byte trend = 0; //trend wird nicht unterstützt

  int temperature = 0;
  for (i = 16; i < 24; i++) if (bitmessage) temperature +=  1 << (23 - i);
  if (bitmessage[14]) temperature -= 0x200; // negative Temp
  byte feuchte = 0;
  for (i = 29; i < 36; i++) if (bitmessage) feuchte +=  1 << (35 - i);

  // die restlichen 4 Bits sind z.Z unbekannt
  byte rest = 0;
  for (i = 24; i < 27; i++) if (bitmessage) rest +=  1 << (26 - i);

  char tmp[12];
  sprintf(tmp, "K%02x%01d%01d%01d%+04d%02d", id, battery, trend, forcedSend, temperature, feuchte);
  message = tmp;
  available = true;
  return true;
}
#endif

#ifdef COMP_MQ2
bool mq2_sendData() {
//  int sensor_mq2 = A4;    
//  int sensor_gas = A5;    
  // Sensor ID & Channel
  byte id = 16;
  // (Propably) Battery State
  bool battery = 1;
  // Trend
  byte trend = 1;
  // Trigger
  bool forcedSend = 1;

  // Temperature & Humidity
    int mq2_value = analogRead(sensor_mq2);    
    int gas_value = analogRead(sensor_gas);
    int temperature = mq2_value;
    byte humidity = 1;
    sprintf(tmp,"G%02X%01d%01d%01d%+04d%02d", id, battery, trend, forcedSend, temperature, humidity);
//    Serial.println(tmp);
  message = tmp;
  available = true;
  return true;
}
#endif

#ifdef COMP_GAS
bool gas_sendData() {
//  int sensor_mq2 = A4;    
//  int sensor_gas = A5;    
  // Sensor ID & Channel
  byte id = 11;
  // (Propably) Battery State
  bool stati = 0;

  // Temperature & Humidity
    int mq2_value = analogRead(sensor_mq2);    
    int gas_value = analogRead(sensor_gas);
    if (gas_value > 100 || mq2_value > 150) {stati = 1;}
    byte humidity = 1;
    sprintf(tmp,"G%02X%01d%+04d%+04d", id, stati, gas_value, mq2_value);
//    Serial.println(tmp);
  message = tmp;
  available = true;
  return true;
}
#endif

#ifdef COMP_DS3231
#define DS3231_I2C_ADDRESS 104
bool get3231Temp()
{
  //temp registers (11h-12h) get updated automatically every 64s
  Wire.beginTransmission(DS3231_I2C_ADDRESS);
  Wire.write(0x11);
  Wire.endTransmission();
  Wire.requestFrom(DS3231_I2C_ADDRESS, 2);
 
  if(Wire.available()) {
    tMSB = Wire.read(); //2's complement int portion
    tLSB = Wire.read(); //fraction portion
   
    temp3231 = (tMSB & B01111111); //do 2's math on Tmsb
    temp3231 += ( (tLSB >> 6) * 0.25 ); //only care about bits 7 & 8
  }
  else {
    //oh noes, no data!
  }
//  temp3231 = (int)((temp3231 * 10) + .5); 
//  return temp3231;

temp3231d = ((temp3231d * 10) + temp3231) / 11;
byte trend = 0;

if (temp3231d > temp3231) {
  trend = 2;
}
  
if (temp3231d < temp3231) {
  trend = 1;
}  

  // Sensor ID & Channel
  byte id = 15;
  // (Propably) Battery State
  bool battery = 0;
  // Trend
//  byte trend = 0;
  // Trigger
  bool forcedSend = 1;

  // Temperature & Humidity
    int temperature = (int)((temp3231 * 10) + .5);
    byte humidity = 1;
    sprintf(tmp,"K%02X%01d%01d%01d%+04d%02d", id, battery, trend, forcedSend, temperature, humidity);
//    Serial.println(tmp);
  message = tmp;
  available = true;
  return true;
}

int get3231Temp_start()
{ 
  //temp registers (11h-12h) get updated automatically every 64s
  Wire.beginTransmission(DS3231_I2C_ADDRESS);
  Wire.write(0x11);
  Wire.endTransmission();
  Wire.requestFrom(DS3231_I2C_ADDRESS, 2);
 
  if(Wire.available()) {
    tMSB = Wire.read(); //2's complement int portion
    tLSB = Wire.read(); //fraction portion
   
    temp3231 = (tMSB & B01111111); //do 2's math on Tmsb
    temp3231 += ( (tLSB >> 6) * 0.25 ); //only care about bits 7 & 8
  }
  else {
    //oh noes, no data!
  }
//  temp3231 = (int)((temp3231 * 10) + .5); 
//  return temp3231;
temp3231d = temp3231;
}
#endif

#ifdef COMP_BMP085
#define BMP085_ADDRESS 0x77  // I2C address of BMP085

bool getbmp085 () {
  byte trend = 0;

  tempbmp085d = ((tempbmp085d * 10) + tempbmp085) / 11;

  if (tempbmp085d > tempbmp085) {
    trend = 2;
  }
  
  if (tempbmp085d < tempbmp085) {
    trend = 1;
  }  

  // Sensor ID & Channel
  byte id = 20;
  
  // (Propably) Battery State
  bool battery = 0;
  
  // Trend
  // byte trend = 0;
  
  // Trigger
  bool forcedSend = 1;

  // Temperature & Humidity
  // int temperature = (int)((temp3231 * 10) + .5);
  int temperature = int ((bmp085GetTemperature(bmp085ReadUT()) * 10)+ .5); //MUST be called first
  float pressure = bmp085GetPressure(bmp085ReadUP());

  byte humidity = 1;
  sprintf(tmp,"K%02X%01d%01d%01d%+04d%02d", id, battery, trend, forcedSend, temperature, humidity);
  message = tmp;
  available = true;
  return true;
}

// Stores all of the bmp085's calibration values into global variables
// Calibration values are required to calculate temp and pressure
// This function should be called at the beginning of the program
void bmp085Calibration()
{
  ac1 = bmp085ReadInt(0xAA);
  ac2 = bmp085ReadInt(0xAC);
  ac3 = bmp085ReadInt(0xAE);
  ac4 = bmp085ReadInt(0xB0);
  ac5 = bmp085ReadInt(0xB2);
  ac6 = bmp085ReadInt(0xB4);
  b1 = bmp085ReadInt(0xB6);
  b2 = bmp085ReadInt(0xB8);
  mb = bmp085ReadInt(0xBA);
  mc = bmp085ReadInt(0xBC);
  md = bmp085ReadInt(0xBE);
}

// Calculate temperature in deg C
float bmp085GetTemperature(unsigned int ut){
  long x1, x2;

  x1 = (((long)ut - (long)ac6)*(long)ac5) >> 15;
  x2 = ((long)mc << 11)/(x1 + md);
  b5 = x1 + x2;

  float temp = ((b5 + 8)>>4);
  temp = temp /10;

  return temp;
}

// Calculate pressure given up
// calibration values must be known
// b5 is also required so bmp085GetTemperature(...) must be called first.
// Value returned will be pressure in units of Pa.
long bmp085GetPressure(unsigned long up){
  long x1, x2, x3, b3, b6, p;
  unsigned long b4, b7;

  b6 = b5 - 4000;
  // Calculate B3
  x1 = (b2 * (b6 * b6)>>12)>>11;
  x2 = (ac2 * b6)>>11;
  x3 = x1 + x2;
  b3 = (((((long)ac1)*4 + x3)<<OSS) + 2)>>2;

  // Calculate B4
  x1 = (ac3 * b6)>>13;
  x2 = (b1 * ((b6 * b6)>>12))>>16;
  x3 = ((x1 + x2) + 2)>>2;
  b4 = (ac4 * (unsigned long)(x3 + 32768))>>15;

  b7 = ((unsigned long)(up - b3) * (50000>>OSS));
  if (b7 < 0x80000000)
    p = (b7<<1)/b4;
  else
    p = (b7/b4)<<1;

  x1 = (p>>8) * (p>>8);
  x1 = (x1 * 3038)>>16;
  x2 = (-7357 * p)>>16;
  p += (x1 + x2 + 3791)>>4;

  long temp = p;
  return temp;
}

// Read 1 byte from the BMP085 at 'address'
char bmp085Read(unsigned char address)
{
  unsigned char data;

  Wire.beginTransmission(BMP085_ADDRESS);
  Wire.write(address);
  Wire.endTransmission();

  Wire.requestFrom(BMP085_ADDRESS, 1);
  while(!Wire.available())
    ;

  return Wire.read();
}

// Read 2 bytes from the BMP085
// First byte will be from 'address'
// Second byte will be from 'address'+1
int bmp085ReadInt(unsigned char address)
{
  unsigned char msb, lsb;

  Wire.beginTransmission(BMP085_ADDRESS);
  Wire.write(address);
  Wire.endTransmission();

  Wire.requestFrom(BMP085_ADDRESS, 2);
  while(Wire.available()<2)
    ;
  msb = Wire.read();
  lsb = Wire.read();

  return (int) msb<<8 | lsb;
}

// Read the uncompensated temperature value
unsigned int bmp085ReadUT(){
  unsigned int ut;

  // Write 0x2E into Register 0xF4
  // This requests a temperature reading
  Wire.beginTransmission(BMP085_ADDRESS);
  Wire.write(0xF4);
  Wire.write(0x2E);
  Wire.endTransmission();

  // Wait at least 4.5ms
  delay(5);

  // Read two bytes from registers 0xF6 and 0xF7
  ut = bmp085ReadInt(0xF6);
  return ut;
}

// Read the uncompensated pressure value
unsigned long bmp085ReadUP(){

  unsigned char msb, lsb, xlsb;
  unsigned long up = 0;

  // Write 0x34+(OSS<<6) into register 0xF4
  // Request a pressure reading w/ oversampling setting
  Wire.beginTransmission(BMP085_ADDRESS);
  Wire.write(0xF4);
  Wire.write(0x34 + (OSS<<6));
  Wire.endTransmission();

  // Wait for conversion, delay time dependent on OSS
  delay(2 + (3<<OSS));

  // Read register 0xF6 (MSB), 0xF7 (LSB), and 0xF8 (XLSB)
  msb = bmp085Read(0xF6);
  lsb = bmp085Read(0xF7);
  xlsb = bmp085Read(0xF8);

  up = (((unsigned long) msb << 16) | ((unsigned long) lsb << 8) | (unsigned long) xlsb) >> (8-OSS);

  return up;
}

void writeRegister(int deviceAddress, byte address, byte val) {
  Wire.beginTransmission(deviceAddress); // start transmission to device 
  Wire.write(address);       // send register address
  Wire.write(val);         // send value to write
  Wire.endTransmission();     // end transmission
}

int readRegister(int deviceAddress, byte address){

  int v;
  Wire.beginTransmission(deviceAddress);
  Wire.write(address); // register to read
  Wire.endTransmission();

  Wire.requestFrom(deviceAddress, 1); // read a byte

  while(!Wire.available()) {
    // waiting
  }

  v = Wire.read();
  return v;
}
#endif

#ifdef COMP_DHT11
bool getdht11()
{
    byte dht11_dat[5];
    byte dht11_in;
    byte i;
    // start condition
    // 1. pull-down i/o pin from 18ms
    PORTC &= ~_BV(DHT11_PIN);
    delay(18);
    PORTC |= _BV(DHT11_PIN);
    delayMicroseconds(40);

    DDRC &= ~_BV(DHT11_PIN);
    delayMicroseconds(40);

    dht11_in = PINC & _BV(DHT11_PIN);

    if(dht11_in){
      Serial.println("dht11 start condition 1 not met");
      fehler = fehler +1;
      return false;
    }
    delayMicroseconds(80);

    dht11_in = PINC & _BV(DHT11_PIN);

    if(!dht11_in){
      Serial.println("dht11 start condition 2 not met");
      fehler = fehler +1;
      return false;
    }
    delayMicroseconds(80);
    // now ready for data reception
    for (i=0; i<5; i++)
      dht11_dat[i] = read_dht11_dat();

    DDRC |= _BV(DHT11_PIN);
    PORTC |= _BV(DHT11_PIN);

    byte dht11_check_sum = dht11_dat[0]+dht11_dat[1]+dht11_dat[2]+dht11_dat[3];
    // check check_sum
    if(dht11_dat[4]!= dht11_check_sum)
    {
//      Serial.println("DHT11 checksum error");
      return false;
    }
    temp1[0]=dht11_dat[2];
    temp2[0]=dht11_dat[3];
    hum1[0]=dht11_dat[0];
    hum2[0]=dht11_dat[1];
/*    Serial.print("Temperature: ");
    Serial.print(temp1[0]);
    Serial.print(".");
    Serial.print(temp2[0]);
    Serial.print(" C");
    Serial.print("    ");
    Serial.print("Humidity: ");
    Serial.print(hum1[0]);
    Serial.print(".");
    Serial.print(hum2[0]);
    Serial.println("%");
*/
  // Sensor ID & Channel
  byte id = 14;
  // (Propably) Battery State
  bool battery = 0;
  // Trend
//  byte trend = 0;
  // Trigger
  bool forcedSend = 1;
byte trend = 0;

  // Temperature & Humidity
//    int temperature = (int)((temp3231 * 10) + .5);
    int temperature = (int) temp1[0]*10; 
    byte humidity = hum1[0];
    sprintf(tmp,"K%02X%01d%01d%01d%+04d%02d", id, battery, trend, forcedSend, temperature, humidity);
//    Serial.println(tmp);
  message = tmp;
  available = true;
  return true;
}

byte read_dht11_dat()
{
  byte i = 0;
  byte result=0;
  for(i=0; i< 8; i++){

    while(!(PINC & _BV(DHT11_PIN)));  // wait for 50us
    delayMicroseconds(30);

    if(PINC & _BV(DHT11_PIN)) 
      result |=(1<<(7-i));
    while((PINC & _BV(DHT11_PIN)));  // wait '1' finish

  }
  return result;
}
#endif

// Wofuer ist diese Funktion ????
// float calcAltitude(float pressure){

//   float A = pressure/101325;
//   float B = 1/5.25588;
//   float C = pow(A,B);
//   C = 1 - C;
//   C = C /0.0000225577;

//   return C;
// }


