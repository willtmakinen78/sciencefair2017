const int bedDetector = 10;                                 //pin assignments
const int shutDownPin = 6;
const int lf = 10;                                          //used for sending the signals

long startMillis;

void setup() {                                              //initialization
  Serial.begin(9600);
  pinMode(bedDetector, OUTPUT);
  pinMode(shutDownPin, OUTPUT);

  digitalWrite(shutDownPin, HIGH);

  startMillis = millis();
}
void loop() {
  if (millis() - startMillis > 100) {
    if (digitalRead(bedDetector) == HIGH) {                   //if the bed is in the camera position:
      Serial.print("pic");                                        //send the appropriate signal
      Serial.write(lf);
    }
    else {
      Serial.print("print");                                        //otherwise send the other signal
      Serial.write(lf);
    }
    startMillis = millis();
  }
  if (Serial.available()) {
    char temp = Serial.read();
    if (temp == 's') {                                      //shut down and restart the printer when instructed by proecssing
      digitalWrite(shutDownPin, LOW);
    }
    else if (temp == 'g') {
      digitalWrite(shutDownPin, HIGH);
    }
  }
}
