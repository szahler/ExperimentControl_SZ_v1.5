#include <Q2HX711.h>
#include <Wire.h>
#include <Adafruit_MCP4725.h>

const byte hx711_data_pin = 7;
const byte hx711_clock_pin = 8;
int val = 0;
int x = 0;
int reset = 0;
Q2HX711 hx711(hx711_data_pin, hx711_clock_pin);

Adafruit_MCP4725 dac;
void setup() {
  Serial.begin(9600);
  dac.begin(0x62);
  val = hx711.read()/150;
}
void loop() {
  if (Serial.available() > 0) {
    reset = Serial.read();
    if (reset == '1') {
        x = val-2045;
        reset = 0;
    }
  }
  val = hx711.read()/150;
  dac.setVoltage(val - x, false);
}
