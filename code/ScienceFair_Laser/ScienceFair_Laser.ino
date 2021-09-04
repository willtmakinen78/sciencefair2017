const int lightPin = 0;                                 //pin assignments
const int detectPin = 8;
const int laserPin = 7;
const int shutDownPin = 6;
const int lf = 10;                                          //used for sending the signals

int pass = 0;
int acknowledged = 0;

void setup() {
  Serial.begin(9600);
  pinMode(detectPin, INPUT);
  pinMode(laserPin, OUTPUT);
  pinMode(shutDownPin, OUTPUT);

  digitalWrite(laserPin, LOW);
  digitalWrite(shutDownPin, HIGH);
}
void loop() {
  if (digitalRead(detectPin) == HIGH) {
    switch (pass) {
      case 0:
        pass = 1;
        break;
      case 11:
        pass = 2;
        break;
      case 22:
        pass = 3;
        break;
    }
  }
  else {
    switch (pass) {
      case 1:
        pass = 11;
        break;
      case 2:
        pass = 22;
        break;
      case 3:
        pass = 0;
        break;
    }
  }
  switch (pass) {
    case 0:
      Serial.println("NoScan");
      break;
    case 1:
      if (acknowledged == 1) {
        Serial.print(analogRead(lightPin));
        Serial.write(lf);
      }
      else {
        Serial.print("P1");
        Serial.write(lf);
      }
      break;
    case 2:
      if (acknowledged == 2) {
        Serial.print(analogRead(lightPin));
        Serial.write(lf);
      }
      else {
        Serial.print("P2");
        Serial.write(lf);
      }
      break;
    case 3:
      if (acknowledged == 3) {
        Serial.print(analogRead(lightPin));
        Serial.write(lf);
      }
      else {
        Serial.print("P3");
        Serial.write(lf);
      }
      break;
    case 11:
      Serial.println("trans");
      break;
    case 22:
      Serial.println("trans");
      break;
  }
  //  Serial.print(analogRead(lightPin));
  //  Serial.write(lf);
  //  Serial.print("scaNot");
  //  Serial.write(lf);
  if (Serial.available()) {
    char temp = Serial.read();
    switch (temp) {                                 //shut down and restart the printer when instructed by proecssing
      case 's':
        digitalWrite(shutDownPin, LOW);
        break;
      case 'g':
        digitalWrite(shutDownPin, HIGH);
        break;
      case 'e':
        acknowledged = 0;
        break;
      case 'o':
        acknowledged = 1;
        break;
      case 't':
        acknowledged = 2;
        break;
      case 'r':
        acknowledged = 3;
        break;
      case 'l':
        digitalWrite(laserPin, HIGH);
        break;
      case 'c':
        digitalWrite(laserPin, LOW);
        break;
    }
  }
}
