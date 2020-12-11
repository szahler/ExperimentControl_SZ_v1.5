#include <Adafruit_MCP4725.h>

// Pin definitions
#define TRIGGER_PIN 5
#define STIM_MODE_PIN 8
#define DEBUG_LED_PIN 13
// PIN 2: Reserved for Adafruit_MCP4725 i2c SDA 
// PIN 3: Reserved for Adafruit_MCP4725 i2c SCL

Adafruit_MCP4725 dac;

// ====== STATE VARIABLES ======
bool NEW_COMMAND = false;
int TRIGGER_STATE = LOW;
int STIM_MODE = LOW;

// Timing variables
unsigned long cycleStartTime = 0;
unsigned long pulseStartTime = 0;
unsigned long currentTime = micros();

// Stimulus parameters
String current_line;

int opto_INTENSITY = 1000;
int opto_CYCLELENGTH = 1000;
int opto_PULSELENGTH = 500;

long opto_CYCLELENGTH_MICROS = long(opto_CYCLELENGTH)*1000;
long opto_PULSELENGTH_MICROS = long(opto_PULSELENGTH)*1000;

void setup()
{

  // Connect to Adafruit_MCP4725
  dac.begin(0x62);
  
  pinMode(TRIGGER_PIN, INPUT);
  pinMode(STIM_MODE_PIN, INPUT);
  Serial.begin(9600);           // start serial for output
}

void loop() {

  if (Serial.available() > 0) {

    // PARSE COMMAND STRING FROM BEHAVIOR COMPUTER
    current_line = Serial.readStringUntil(',');
    opto_INTENSITY = current_line.toInt();
    current_line = Serial.readStringUntil(',');
    opto_CYCLELENGTH = current_line.toInt();
    opto_CYCLELENGTH_MICROS = long(opto_CYCLELENGTH)*1000;
    current_line = Serial.readStringUntil('\n');
    opto_PULSELENGTH = current_line.toInt();
    opto_PULSELENGTH_MICROS = long(opto_PULSELENGTH)*1000;

    NEW_COMMAND = 1;
  }

  STIM_MODE = digitalRead(STIM_MODE_PIN);
  if (STIM_MODE == LOW) {
    TRIGGER_STATE = digitalRead(TRIGGER_PIN);
  }
  else {
    TRIGGER_STATE = HIGH;
  }

  if (TRIGGER_STATE == HIGH) {
    // Constant stimulus
    if (opto_CYCLELENGTH_MICROS == 0 | opto_PULSELENGTH_MICROS == 0) {
      dac.setVoltage(opto_INTENSITY, false);
    }
    // Pulsed stimulus
    else {
      unsigned long currentTime = micros();
      if ((currentTime-cycleStartTime) >= opto_CYCLELENGTH_MICROS) {
        cycleStartTime = currentTime;
        pulseStartTime = cycleStartTime;
        dac.setVoltage(opto_INTENSITY, false);
        digitalWrite(DEBUG_LED_PIN, HIGH);
      }
      if ((currentTime-pulseStartTime) >= opto_PULSELENGTH_MICROS) {
        dac.setVoltage(0, false);
        digitalWrite(DEBUG_LED_PIN, LOW);
      }
    }
  }

  // Stimulus off
  else {
    dac.setVoltage(0, false);
    digitalWrite(DEBUG_LED_PIN, LOW);
  }
}
