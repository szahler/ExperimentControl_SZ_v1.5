#include <Q2HX711.h>
#include <Wire.h>
#include <Adafruit_MCP4725.h>

const byte hx711_data_pin_L = 4;
const byte hx711_clock_pin_L = 5;
const byte hx711_data_pin_R = 7;
const byte hx711_clock_pin_R = 8;
int val_L = 0;
int val_R = 0;
int x = 0;
int reset = 0;
Q2HX711 hx711_L(hx711_data_pin_L, hx711_clock_pin_L);
Q2HX711 hx711_R(hx711_data_pin_R, hx711_clock_pin_R);

Adafruit_MCP4725 dac;
void setup() {
  Serial.begin(9600);
  dac.begin(0x62);
  val_L = hx711_L.read()/250;
  val_R = hx711_R.read()/250;
}
void loop() {
  if (Serial.available() > 0) {
    reset = Serial.read();
    if (reset == '1') {
        x = 2045 + val_L + val_R;
        reset = 0;
    }
  }
  val_L = hx711_L.read()/250;
  val_R = hx711_R.read()/250;
  //dac.setVoltage(-(val_L + val_R) + x, false);
  dac.setVoltage(val_L + val_R - x, false);
  
}
