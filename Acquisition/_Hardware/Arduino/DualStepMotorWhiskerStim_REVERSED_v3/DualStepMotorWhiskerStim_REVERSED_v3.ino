//Declare pin functions on Redboard
#define Left_EN  8
#define Left_stp 10
#define Left_dir 9
#define Left_TRIGGER 13

#define Right_EN  2
#define Right_stp 7
#define Right_dir 3
#define Right_TRIGGER 11


//Declare variables for functions
char user_input;
int x;
int stepDelay = 1500;
int numSteps = 12;
int LeftTriggerState;
int RightTriggerState;
bool stimulusFired;

void setup() {
  pinMode(Left_stp, OUTPUT);
  pinMode(Left_dir, OUTPUT);
  pinMode(Left_EN, OUTPUT);
  pinMode(Left_TRIGGER, INPUT);
  pinMode(Right_stp, OUTPUT);
  pinMode(Right_dir, OUTPUT);
  pinMode(Right_EN, OUTPUT);
  pinMode(Right_TRIGGER, INPUT);
  resetEDPins(); //Set step, direction, microstep and enable pins to default states
  Serial.begin(9600); //Open Serial connection for debugging
}

void loop() {
  // put your main code here, to run repeatedly:
  while(Serial.available()){
      user_input = Serial.read(); //Read user input and trigger appropriate function
      
      if (user_input =='l')
      {
         digitalWrite(Left_EN, LOW); //Pull enable pin low to allow motor control
         Left_Stimulus();
      }
      if (user_input =='r')
      {
         digitalWrite(Right_EN, LOW); //Pull enable pin low to allow motor control
         Right_Stimulus();
      }
      if (user_input =='b')
      {
         digitalWrite(Left_EN, LOW); //Pull enable pin low to allow motor control
         digitalWrite(Right_EN, LOW); //Pull enable pin low to allow motor control
         Both_Stimulus();
      }
      resetEDPins();
  }

  LeftTriggerState = digitalRead(Left_TRIGGER);
  RightTriggerState = digitalRead(Right_TRIGGER);

  if (LeftTriggerState==HIGH || RightTriggerState==HIGH) {
    delay(1); // give the other trigger a chance to occur

    LeftTriggerState = digitalRead(Left_TRIGGER);
    RightTriggerState = digitalRead(Right_TRIGGER);
  
    if (LeftTriggerState==HIGH & RightTriggerState==HIGH) {
      digitalWrite(Left_EN, LOW); //Pull enable pin low to allow motor control
      digitalWrite(Right_EN, LOW); //Pull enable pin low to allow motor control
        Serial.println("Both stimulus trigger detected");
        Both_Stimulus();
//        Both_Stimulus();
        while (LeftTriggerState == HIGH || RightTriggerState==HIGH) {
          LeftTriggerState = digitalRead(Left_TRIGGER);
          RightTriggerState = digitalRead(Right_TRIGGER);
          delay(1);
        }
        resetEDPins();
        return;
    }
    
    if (LeftTriggerState == HIGH & RightTriggerState == LOW) {
      digitalWrite(Left_EN, LOW); //Pull enable pin low to allow motor control
        Serial.println("Left stimulus trigger detected");
        Left_Stimulus();
//        Left_Stimulus();
        while (LeftTriggerState == HIGH) {
          LeftTriggerState = digitalRead(Left_TRIGGER);
          delay(1);
        }
        resetEDPins();
        return;
    }
  
    if (LeftTriggerState == LOW & RightTriggerState == HIGH) {
      digitalWrite(Right_EN, LOW); //Pull enable pin low to allow motor control
        Serial.println("Right stimulus trigger detected");
        Right_Stimulus();
//        Right_Stimulus();
        while (RightTriggerState == HIGH) {
          RightTriggerState = digitalRead(Right_TRIGGER);
          delay(1);
        }
        resetEDPins();
        return;
    }
    
  }


}

void Left_Stimulus()
{
  
  Serial.println("Left Stimulus");
  digitalWrite(Left_dir, LOW); //Pull direction pin low to move "forward"
  for(x= 0; x<numSteps; x++)  //Loop the forward stepping enough times for motion to be visible
  {
    digitalWrite(Left_stp,HIGH); //Trigger one step forward
//    delay(1);
    delayMicroseconds(stepDelay);
    digitalWrite(Left_stp,LOW); //Pull step pin low so it can be triggered again
//    delay(1);
    delayMicroseconds(stepDelay);
  }
  digitalWrite(Left_dir, HIGH); //Pull direction pin low to move "forward"
  for(x= 0; x<numSteps; x++)  //Loop the forward stepping enough times for motion to be visible
  {
    digitalWrite(Left_stp,HIGH); //Trigger one step forward
//    delay(1);
    delayMicroseconds(stepDelay);
    digitalWrite(Left_stp,LOW); //Pull step pin low so it can be triggered again
//    delay(1);
    delayMicroseconds(stepDelay);
  }
//  Serial.println("Enter new option");
//  Serial.println();
}

void Right_Stimulus()
{
  
  Serial.println("Right Stimulus");
  digitalWrite(Right_dir, HIGH); //Pull direction pin low to move "forward"
  for(x= 0; x<numSteps; x++)  //Loop the forward stepping enough times for motion to be visible
  {
    digitalWrite(Right_stp,HIGH); //Trigger one step forward
//    delay(1);
    delayMicroseconds(stepDelay);
    digitalWrite(Right_stp,LOW); //Pull step pin low so it can be triggered again
//    delay(1);
    delayMicroseconds(stepDelay);
  }
  digitalWrite(Right_dir, LOW); //Pull direction pin low to move "forward"
  for(x= 0; x<numSteps; x++)  //Loop the forward stepping enough times for motion to be visible
  {
    digitalWrite(Right_stp,HIGH); //Trigger one step forward
//    delay(1);
    delayMicroseconds(stepDelay);
    digitalWrite(Right_stp,LOW); //Pull step pin low so it can be triggered again
//    delay(1);
    delayMicroseconds(stepDelay);
  }
//  Serial.println("Enter new option");
//  Serial.println();
}

void Both_Stimulus()
{
  
  Serial.println("Both Stimulus");
  digitalWrite(Left_dir, LOW); //Pull direction pin low to move "forward"
  digitalWrite(Right_dir, HIGH); //Pull direction pin low to move "forward"
  for(x= 0; x<numSteps; x++)  //Loop the forward stepping enough times for motion to be visible
  {
    digitalWrite(Left_stp,HIGH); //Trigger one step forward
    digitalWrite(Right_stp,HIGH); //Trigger one step forward
//    delay(1);
    delayMicroseconds(stepDelay);
    digitalWrite(Left_stp,LOW); //Pull step pin low so it can be triggered again
    digitalWrite(Right_stp,LOW); //Pull step pin low so it can be triggered again
//    delay(1);
    delayMicroseconds(stepDelay);
  }
  digitalWrite(Left_dir, HIGH); //Pull direction pin low to move "forward"
  digitalWrite(Right_dir, LOW); //Pull direction pin low to move "forward"
  for(x= 0; x<numSteps; x++)  //Loop the forward stepping enough times for motion to be visible
  {
    digitalWrite(Left_stp,HIGH); //Trigger one step forward
    digitalWrite(Right_stp,HIGH); //Trigger one step forward
//    delay(1);
    delayMicroseconds(stepDelay);
    digitalWrite(Left_stp,LOW); //Pull step pin low so it can be triggered again
    digitalWrite(Right_stp,LOW); //Pull step pin low so it can be triggered again
//    delay(1);
    delayMicroseconds(stepDelay);
  }
//  Serial.println("Enter new option");
//  Serial.println();
}

//Reset Easy Driver pins to default states
void resetEDPins()
{
  digitalWrite(Left_stp, LOW);
  digitalWrite(Left_dir, LOW);
//  digitalWrite(Left_MS1, LOW);
//  digitalWrite(Left_MS2, LOW);
  digitalWrite(Left_EN, HIGH);
  digitalWrite(Right_stp, LOW);
  digitalWrite(Right_dir, LOW);
  digitalWrite(Right_EN, HIGH);
}
