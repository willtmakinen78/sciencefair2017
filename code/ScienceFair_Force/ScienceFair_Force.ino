#include "HX711.h"                              //load cell library

const int  DOUT = 12;                               //pin assignments
const int CLK = 11;
const int perimeterPin = 9;                           
const int shutDownPin = 6;

HX711 scale(DOUT, CLK);                         //initialize library
float calibration_factor = 100;
        
float force;                                    //stores load cell readings
int lf = 10;                                    //used in serial communication

boolean acknowledgedP = false;                  //used to switch between force values and perimter/infill signals
boolean acknowledgedI = false;

void setup() {
  Serial.begin(9600);                           //initialization
  pinMode(perimeterPin, INPUT);
  pinMode(shutDownPin, OUTPUT);

  scale.set_scale(calibration_factor);          //Adjust to this calibration factor
  scale.tare();                                 //Reset the scale to 0

  digitalWrite(shutDownPin, HIGH);
}

void loop() {

  if (digitalRead(perimeterPin) == HIGH) {          //if the M-code command for a perimeter has been sent:
    acknowledgedI = false;                          //reset the infil acknowledgement
    if (acknowledgedP == false) {                   //until the perimter signal has been acknowledged by processing:
      Serial.print(666);                            //send the perimeter signal
      Serial.write(lf);
    }
    else {                                          //if the fact that a perimeter is being printed has been acknowledged:
      Serial.print(scale.get_units());              //send the force values
      Serial.write(lf);
    }
  }
  else {                                            //if the M-code command for infill has been sent:
    acknowledgedP = false;                          //reset the perimeter acknowledgement
    if (acknowledgedI == false) {                   //until the infill signal has been acknowledged by processing:
      Serial.print(555);                            //send the infill signal
      Serial.write(lf);
    }
    else {
      Serial.print(scale.get_units());              //after acknowledgement send the force data
      Serial.write(lf);
    }
  }
  while (Serial.available() > 0) {           
    char temp = Serial.read();
    if (temp == 'z') {                               //tare the scale when the signal is sent
      scale.tare();
    }
    else if (temp == 'p') {                          //read the port for acknowledgement signals
      acknowledgedP = true;
    }
    else if (temp == 'i') {
      acknowledgedI = true;
    }
    else if (temp == 's') {                          //shut down and restart the printer when instructed by proecssing
      digitalWrite(shutDownPin, LOW);
    }
    else if (temp == 'g') {
      digitalWrite(shutDownPin, HIGH);
    }
  }
}
