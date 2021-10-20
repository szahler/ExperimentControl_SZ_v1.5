// Name: BehaviorControl_v2
// Date: 7/8/2019
// Author: David Taylor
// Purpose: Whisker Puff Behavior

// Command string: "trigger_control,puff_OFFSET,leftpuff_DURATION,rightpuff_DURATION,opto_OFFSET,opto_DURATION,"

// leftpuff_DURATION and rightpuff_DURATION cannot both be greater than 0.
// Command strings violating these constraints will be ignored.

#include "TimerOne.h"

// ====== INPUT PINS ======
#define ENCODER_A_PIN 2
#define ENCODER_B_PIN 3

// ====== OUTPUT PINS ======
#define CAMERA_TRIGGER_PIN 11
#define SOLENOID_L_PIN 22 // left solenoid control
#define SOLENOID_R_PIN 24 // right solenoid control
#define OPTO_PIN 8 // opto trigger

#define DAQ_CAMERA_TRIGGER_PIN 30
#define DAQ_SOLENOID_L_PIN 5
#define DAQ_SOLENOID_R_PIN 6
#define DAQ_OPTO_PIN 7

#define INTAN_CAMERA_TRIGGER_PIN 9
#define INTAN_OPTO_PIN 12


// ====== COMMAND STRING VARIABLES ======
String current_line;

int trigger_control;
int puff_OFFSET;
int leftpuff_DURATION;
int rightpuff_DURATION;
int opto_OFFSET;
int opto_DURATION;

// ====== ENCODER VARIABLES ======
volatile int stateA = LOW;
volatile int stateB = LOW;
volatile int counter = 0;

// ====== STATE VARIABLES ======
bool NEW_COMMAND = false;
bool SESSION_RUNNING = false;
bool LEFT_SOLENOID_ON = false;
bool RIGHT_SOLENOID_ON = false;
bool OPTO_ON = false;
bool LEFT_PUFF_FINISHED = true;
bool RIGHT_PUFF_FINISHED = true;
bool OPTO_FINISHED = true;

unsigned long startTime;
unsigned long currentTime;

void setup() {
  pinMode (ENCODER_A_PIN, INPUT_PULLUP);
  pinMode (ENCODER_B_PIN, INPUT_PULLUP);

  pinMode (CAMERA_TRIGGER_PIN, OUTPUT);
  pinMode(SOLENOID_L_PIN, OUTPUT);
  pinMode(SOLENOID_R_PIN, OUTPUT);
  pinMode(OPTO_PIN, OUTPUT);
  
  pinMode (DAQ_CAMERA_TRIGGER_PIN, OUTPUT);
  pinMode(DAQ_SOLENOID_L_PIN, OUTPUT);
  pinMode(DAQ_SOLENOID_R_PIN, OUTPUT);
  pinMode(DAQ_OPTO_PIN, OUTPUT);

  pinMode(INTAN_CAMERA_TRIGGER_PIN, OUTPUT);
  pinMode(INTAN_OPTO_PIN, OUTPUT);  

  Timer1.initialize(5000);   // Initialize Timer1 (Set to 50% of desired frame length in us. E.g. 10000 for 20ms)
  Timer1.attachInterrupt(trigger_callback);  // attaches callback() as a timer overflow interrupt

  Serial.begin (9600);
}

void loop() {


  if (Serial.available() > 0) {

    // PARSE COMMAND STRING FROM BEHAVIOR COMPUTER
    current_line = Serial.readStringUntil(',');
    trigger_control = current_line.toInt();
    current_line = Serial.readStringUntil(',');
    puff_OFFSET = current_line.toInt();
    current_line = Serial.readStringUntil(',');
    leftpuff_DURATION = current_line.toInt();
    current_line = Serial.readStringUntil(',');
    rightpuff_DURATION = current_line.toInt();
    current_line = Serial.readStringUntil(',');
    opto_OFFSET = current_line.toInt();
    current_line = Serial.readStringUntil('\n');
    opto_DURATION = current_line.toInt();

    NEW_COMMAND = 1;

//    // Ignore bad commands
//    if (leftpuff_DURATION > 0 && rightpuff_DURATION > 0) {
//      NEW_COMMAND = 0;
//    }
  }



  if (NEW_COMMAND == 1) {
    
    if (trigger_control == 1) {
      SESSION_RUNNING = 1;
    }
    else if (trigger_control == 0)  {
      SESSION_RUNNING = 0;
    }

    if (opto_DURATION > 0 || leftpuff_DURATION > 0 || rightpuff_DURATION > 0){
      
      OPTO_FINISHED = true;
      LEFT_PUFF_FINISHED = true;
      RIGHT_PUFF_FINISHED = true;
      if (opto_DURATION > 0) {
        OPTO_FINISHED = false;
      }
      if (leftpuff_DURATION > 0) {
        LEFT_PUFF_FINISHED = false;
      }
      if (rightpuff_DURATION > 0) {
        RIGHT_PUFF_FINISHED = false;
      }
      
      startTime = millis();
      while (OPTO_FINISHED == false || LEFT_PUFF_FINISHED == false || RIGHT_PUFF_FINISHED == false) {
        currentTime = millis();

        // =====================================================================
        // TOGGLE OPTO
        if (OPTO_FINISHED == false && opto_DURATION > 0){
          if (OPTO_ON == false) { // if element is off, check whether conditions are right to start
            if (currentTime - startTime >= opto_OFFSET) {
              digitalWrite(OPTO_PIN, HIGH);
              digitalWrite(DAQ_OPTO_PIN, HIGH);
              digitalWrite(INTAN_OPTO_PIN,HIGH);
              OPTO_ON = true;
            }
          }
          else if (OPTO_ON == true) { // if element is on, check whether conditions are right to stop
            if (currentTime - startTime >= opto_OFFSET + opto_DURATION) {
              digitalWrite(OPTO_PIN, LOW);
              digitalWrite(DAQ_OPTO_PIN, LOW);
              digitalWrite(INTAN_OPTO_PIN,LOW);
              OPTO_ON = false;
              OPTO_FINISHED = true;
            }
          }
        }

        // =====================================================================
        // TOGGLE LEFT PUFF
        if (LEFT_PUFF_FINISHED == false && leftpuff_DURATION > 0){
          if (LEFT_SOLENOID_ON == false) { // if element is off, check whether conditions are right to start
            if (currentTime - startTime >= puff_OFFSET) {
              digitalWrite(SOLENOID_L_PIN, HIGH);
              digitalWrite(DAQ_SOLENOID_L_PIN, HIGH);
              LEFT_SOLENOID_ON = true;
            }
          }
          else if (LEFT_SOLENOID_ON == true) { // if element is on, check whether conditions are right to stop
            if (currentTime - startTime >= puff_OFFSET + leftpuff_DURATION) {
              digitalWrite(SOLENOID_L_PIN, LOW);
              digitalWrite(DAQ_SOLENOID_L_PIN, LOW);
              LEFT_SOLENOID_ON = false;
              LEFT_PUFF_FINISHED = true;
            }
          }
        }

        // =====================================================================
        // TOGGLE RIGHT PUFF
        if (RIGHT_PUFF_FINISHED == false && rightpuff_DURATION > 0){
          if (RIGHT_SOLENOID_ON == false) { // if element is off, check whether conditions are right to start
            if (currentTime - startTime >= puff_OFFSET) {
              digitalWrite(SOLENOID_R_PIN, HIGH);
              digitalWrite(DAQ_SOLENOID_R_PIN, HIGH);
              RIGHT_SOLENOID_ON = true;
            }
          }
          else if (RIGHT_SOLENOID_ON == true) { // if element is on, check whether conditions are right to stop
            if (currentTime - startTime >= puff_OFFSET + rightpuff_DURATION) {
              digitalWrite(SOLENOID_R_PIN, LOW);
              digitalWrite(DAQ_SOLENOID_R_PIN, LOW);
              RIGHT_SOLENOID_ON = false;
              RIGHT_PUFF_FINISHED = true;
            }
          }
        }

        // =====================================================================
      }
    }
    NEW_COMMAND = 0;
  }
}


// ====== TRIGGER CALLBACK ======
void trigger_callback()
{
  if (SESSION_RUNNING == 1) {
    digitalWrite(CAMERA_TRIGGER_PIN, (digitalRead(CAMERA_TRIGGER_PIN) ^ 1));
    digitalWrite(DAQ_CAMERA_TRIGGER_PIN, (digitalRead(DAQ_CAMERA_TRIGGER_PIN) ^ 1));
    digitalWrite(INTAN_CAMERA_TRIGGER_PIN, (digitalRead(INTAN_CAMERA_TRIGGER_PIN) ^ 1));
  }
  else {
    if (digitalRead(CAMERA_TRIGGER_PIN) == HIGH || digitalRead(DAQ_CAMERA_TRIGGER_PIN) == HIGH) {
      digitalWrite(CAMERA_TRIGGER_PIN, LOW);
      digitalWrite(DAQ_CAMERA_TRIGGER_PIN, LOW);
      digitalWrite(INTAN_CAMERA_TRIGGER_PIN, LOW);
    }
  }
}
