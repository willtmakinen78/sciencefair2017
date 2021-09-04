import processing.serial.*;                                            //library imports
import http.requests.*;

PrintWriter output;                       
Notification notify;
SerialCommunication Arduino;
SerialCommunication Printer;

boolean started = false;                                            //used to start and stop picture taking

String configFilename = "Config.txt";                               //filename strings
String dataFilename = "";
String GCodeFilename = "";

String extruderTemp = "185";                                        //parameter strings
String bedTemp = "60";
String layerHeight = ".2";                                          //layer height of G-Code
String testFrequency = "10";

boolean printStarted = false;                                       //used for sending G-Code

int layerCount;
float printHeight;
float reflectHeight = 10.5;
boolean heightThreshPassed = false;

int pass = 0;
float data;
float avData = 0;
float avSum = 0;

String displayText = "";

int startTime;                                                        //will store the millis() value at which the program started
int currentTime;                                                      //store the elapsed time since startTime
int lineTime;
int lineCounter;
int lineInterval = 100;

int scanTime;
int avInterval = 2000;
int avCounter;

int failure = 0;
boolean incrementOnce = false;
int scanLayer = 0;
int failCounter;
boolean analyzed = false;
boolean zeroScan = true;

float[] datArray;
String[] timeArray;

boolean fileCreated = false;

void setup() {  
  size(1280, 720);

  Arduino = new SerialCommunication();                                       //initialize serial objects
  Printer = new SerialCommunication();

  notify = new Notification(configFilename);                                 //initialize notification library

  Arduino.openPort(this, 0, 9600, "Arduino");                                           //open ports
  Printer.openPort(this, 1, 250000, "Printer");

  datArray = new float[(width-130) / 10];
  timeArray = new String[13];
  for (int i = 0; i < timeArray.length; i++) {                            //clear the timestamp array
    timeArray[i] = "0";
  }

  rectMode(CENTER);
  textSize(12);
}
void draw() {
  if (printStarted == true) {
    int traval = Printer.transmit();
    if (traval < 0) {
      printStarted = false;
      println("Print Stopped");
    }
    if (Printer.layerChange == true) {                                           
      layerCount++;                                                           //increment layercount when the serial communication library reads one from the G-Code
      println("Layer: " + layerCount);

      Printer.layerChange = false;
    }
  }
  if (started == true) {

    if (fileCreated == false) {                                                                    //only create the file once per graphing session, not 60 times/sec
      output = createWriter(dataFilename + ".csv");
      output.println("Layer #,Pass #,Time(ms),Reading");
      fileCreated = true;
    }
    switch (Arduino.trimmedString) {
    case "NoScan":
      pass = 0;
      data = 0;
      Arduino.sendChar('e');
      Arduino.sendChar('c');
      break;
    case "trans":
      //data = 0;
      Arduino.sendChar('c');
      break;
    case "P1":
      pass = 1;
      Arduino.sendChar('o');
      Arduino.sendChar('c');

      failure = 0;
      incrementOnce = false;

      avData = 0;
      avSum = 0;
      avCounter = 0;
      scanTime = millis();
      break;
    case "P2":
      pass = 2;
      Arduino.sendChar('t');
      Arduino.sendChar('c');

      incrementOnce = false;

      avData = 0;
      avSum = 0;
      avCounter = 0;
      scanTime = millis();
      break;
    case "P3":
      pass = 3;
      Arduino.sendChar('r');
      Arduino.sendChar('c');

      incrementOnce = false;

      avData = 0;
      avSum = 0;
      avCounter = 0;
      scanTime = millis();
      break;
    default:
      data = float(Arduino.trimmedString);
      if (Float.isNaN(data)) {
        data = 0;
      }
      break;
    }
    currentTime = millis() - startTime;

    switch(pass) {
    case 0:
      if (scanLayer > 0) {
        if (scanLayer != layerCount) {
          if (analyzed == false) {
            if (failure >= 3) {
              failCounter++;

              if (failCounter > 2) {
                notify.sendNotification();
              }
            }
            failure = 0;
            analyzed = true;
          }
        }
      }
      displayText = "Printing";
      break;
    case 1:
      scanLayer = layerCount;
      analyzed = false;

      output.println(layerCount + "," + pass + "," + currentTime + "," + data);

      if (millis() < scanTime + avInterval) {
        avSum += data;
        avCounter++;

        displayText = "First Scan\nGetting Initial Value";
      } else {
        Arduino.sendChar('l');

        avData = avSum / avCounter;
        if (data < (avData * .87)) {
          if (incrementOnce == false) {
            failure++;
            incrementOnce = true;
          }
        }
        displayText = "First Scan";
      }
      break;
    case 2:
      output.println(layerCount + "," + pass + "," + currentTime + "," + data);

      if (millis() < scanTime + avInterval) {
        avSum += data;
        avCounter++;

        displayText = "Second Scan\nGetting Initial Value";
      } else {
        Arduino.sendChar('l');

        avData = avSum / avCounter;
        if (data < (avData * .87)) {
          if (incrementOnce == false) {
            failure++;
            incrementOnce = true;
          }
        } 
        displayText = "Second Scan";
      }
      break;
    case 3:
      output.println(layerCount + "," + pass + "," + currentTime + "," + data);

      if (millis() < scanTime + avInterval) {
        avSum += data;
        avCounter++;

        displayText = "Third Scan\nGetting Initial Value";
      } else {
        Arduino.sendChar('l');

        avData = avSum / avCounter;
        if (data < (avData * .87)) {
          if (incrementOnce == false) {
            failure++;
            incrementOnce = true;
          }
        } 
        displayText = "Third Scan";
      }
      break;
    }
    if (millis() - lineTime > lineInterval) {
      background(255);
      strokeWeight(3);
      stroke(0, 174, 252);

      float mappedData = map(data, 0, 1023, 15, 705);
      datArray[0] = mappedData;
      for (int i = datArray.length-1; i > 0; i--) {
        datArray[i] = datArray[i-1];
      }

      for (int i = 0; i < datArray.length-2; i++) {
        line((width-130)-(i*10), height-datArray[i], (width-130)-((i+1)*10), height-datArray[i+1]);
      }
      for (int i = 0; i < timeArray.length; i++) {
        text(timeArray[i], width-((i*100)+63), height-2);
      }
      lineCounter++;
      if (lineCounter >= (1000/lineInterval)) {
        timeArray[0] = str(currentTime/1000);

        for (int i = timeArray.length-1; i > 0; i--) {
          timeArray[i] = timeArray[i-1];
        }
        lineCounter = 0;
      }
      lineTime = millis();

      stroke(0);
      strokeWeight(1);

      displayText += "\nFail Counter: " + str(failCounter);
      displayText += "\nCurrent Reading: " + "\n" + str(data);
      if (failCounter > 2) {
        displayText += "\nPrint Failed";
      }
      text(displayText, 1173, 200);
    }
    dataMenu();
    printMenu();
  } else {
    mainMenu();
    printMenu();
  }
}
void serialEvent(Serial port) {                                             //triggers any time serial data is available
  if (port == Arduino.port) {
    String data = Arduino.port.readString();
    Arduino.readPort(data);
    //println("Arduino: " + Arduino.trimmedString);
  }
  if (port == Printer.port) {
    String data = Printer.port.readString();
    Printer.readPort(data);
    //println("Printer: " + Printer.trimmedString);
  }
}
void mousePressed() {
  if (started == false) {
    if ((mouseX > 540) && (mouseX < 740) && (mouseY > 385) && (mouseY < 435)) {          //start data collection
      started = true;
      fileCreated = false;

      startTime = millis();
      lineTime = millis();

      notify.getFirstTweet();
      failCounter = 0;
    }
  } else {
    if ((mouseX > 1157) && (mouseX < 1277) && (mouseY > 0) && (mouseY < 50)) {           //menu button
      output.flush();                                                                    //writes the remaining data to the file
      output.close();                                                                    //finishes the file
      started = false;
    }
  }
  if ((mouseX > 1160) && (mouseX < 1280) && (mouseY > 660) && (mouseY < 720)) {          //start/stop print 
    if (printStarted == false) {
      Printer.loadGCode(Printer.resetTransmit(GCodeFilename, "LaserMod.gcode", float(layerHeight), reflectHeight, float(testFrequency)));
      //Printer.loadGCode(GCodeFilename);
      println("Attempting to send GCode data");
      Printer.sendString("M4 P15\n");
      Printer.ACK = true;
      printStarted = true;
      layerCount = 0;
    } else {
      Printer.abort();
      printStarted = false;
    }
  }
  if ((mouseX > 1157) && (mouseX < 1277) && (mouseY > 368) && (mouseY < 418)) {          //disable motors
    Printer.sendString("M18\n");
  }
  if ((mouseX > 1157) && (mouseX < 1277) && (mouseY > 418) && (mouseY < 468)) {          //get stats
    Printer.sendString("M105\n");
  }
  if ((mouseX > 1157) && (mouseX < 1277) && (mouseY > 468) && (mouseY < 518)) {          //set temperature
    println("Setting Temperatures\nExtruder: " + extruderTemp +"\nBed: " + bedTemp);
    Printer.sendString("M104 S" + int(extruderTemp) +"\n");
    Printer.sendString("M140 S" + int(bedTemp) + "\n");
  }
}
void keyPressed() {
  if (started == false) {
    if ((mouseX > 540) && (mouseX < 740) && (mouseY > 285) && (mouseY < 335)) {            //G-Code filename
      if (key != CODED) {
        if (key == BACKSPACE) {                                                
          if (GCodeFilename.length() > 0) {
            GCodeFilename = GCodeFilename.substring(0, GCodeFilename.length()-1);
          }
        } else if (textWidth(GCodeFilename + key) < 192) {                           
          GCodeFilename = GCodeFilename + key;
        }
      }
    }
    if ((mouseX > 540) && (mouseX < 740) && (mouseY > 335) && (mouseY < 385)) {            //data filenames
      if (key!= CODED) {
        if (key == BACKSPACE) {                                                
          if (dataFilename.length() > 0) {
            dataFilename = dataFilename.substring(0, dataFilename.length()-1);
          }
        } else if (textWidth(dataFilename + key) < 192) {
          dataFilename = dataFilename + key;
        }
      }
    }
    if ((mouseX > 540) && (mouseX < 740) && (mouseY > 435) && (mouseY < 485)) {           //test Frequency
      if (key!= CODED) {
        if (key == BACKSPACE) {                                                
          if (testFrequency.length() > 0) {
            testFrequency = testFrequency.substring(0, testFrequency.length()-1);
          }
        } else if (textWidth(testFrequency + key) < 192) {
          testFrequency = testFrequency + key;
        }
      }
    }
    if ((mouseX > 540) && (mouseX < 740) && (mouseY > 485) && (mouseY < 535)) {         //layer height
      if (key!= CODED) {
        if (key == BACKSPACE) {                                                
          if (layerHeight.length() > 0) {
            layerHeight = layerHeight.substring(0, layerHeight.length()-1);
          }
        } else if (textWidth(layerHeight + key) < 192) {
          layerHeight = layerHeight + key;
        }
      }
    }
  }
  if ((mouseX > 1157) && (mouseX < 1277) && (mouseY > 5) && (mouseY < 55)) {            //picture layerHeight entry
    if (printStarted == false) {
      if (key != CODED) {
        if (key == BACKSPACE) {
          if (layerHeight.length() > 0) {
            layerHeight = layerHeight.substring(0, layerHeight.length()-1);
          }
        } else if (textWidth(layerHeight + key) < 35) {
          layerHeight = layerHeight + key;
        }
      }
    }
  }
  if ((mouseX > 1157) && (mouseX < 1277) && (mouseY > 507) && (mouseY < 557)) {          //extruder target
    if (key != CODED) {
      if (key == BACKSPACE) {
        if (extruderTemp.length() > 0) {
          extruderTemp = extruderTemp.substring(0, extruderTemp.length()-1);
        }
      } else if (textWidth(extruderTemp + key) < 35) {
        extruderTemp = extruderTemp + key;
      }
    }
  }
  if ((mouseX > 1157) && (mouseX < 1277) && (mouseY > 557) && (mouseY < 607)) {          //bed target
    if (key != CODED) {
      if (key == BACKSPACE) {
        if (bedTemp.length() > 0) {
          bedTemp = bedTemp.substring(0, bedTemp.length()-1);
        }
      } else if (textWidth(bedTemp + key) < 35) {
        bedTemp = bedTemp + key;
      }
    }
  }
}
void mainMenu() {
  background(50);
  strokeWeight(1);
  fill(127);
  rect(width/2, 310, 200, 50);                                                         //G-Code filename box
  rect(width/2, height/2, 200, 50);                                                    //data filename box
  rect(width/2, 410, 200, 50);                                                         //start box
  rect(width/2, 460, 200, 50);                                                         //test Frequency box
  rect(width/2, 510, 200, 50);                                                         //layer height box
  fill(0);
  text("GCode Filename", 595, 315);                                                                                                                                         
  text("Data Filename", 595, 365);                                                  
  text("Test Frequency", 605, 465);  
  text("Layer Height", 615, 515);                                                      //change button colors durong scrollover to display values

  if ((mouseX > 540) && (mouseX < 740) && (mouseY > 285) && (mouseY < 335)) {          //G-Code filename
    fill(212);
    rect(width/2, 310, 200, 50);

    fill(0);
    float cursorPosition = textWidth(GCodeFilename) + 544;
    line(cursorPosition, 335, cursorPosition, 285);
    text(GCodeFilename, 544, 315);
  }

  if ((mouseX > 540) && (mouseX < 740) && (mouseY > 335) && (mouseY < 385)) {          //data filename
    fill(212);
    rect(width/2, height/2, 200, 50);

    fill(0);
    float cursorPosition = textWidth(dataFilename) + 544;
    line(cursorPosition, 385, cursorPosition, 335);
    text(dataFilename, 544, 365);
  }
  if ((mouseX > 540) && (mouseX < 740) && (mouseY > 385) && (mouseY < 435)) {          //start
    fill(212);
    rect(width/2, 410, 200, 50);
  }
  if ((mouseX > 540) && (mouseX < 740) && (mouseY > 435) && (mouseY < 485)) {         //test Frequency
    fill(212);
    rect(width/2, 460, 200, 50);

    fill(0);
    float cursorPosition = textWidth(testFrequency) + 635;
    line(cursorPosition, 485, cursorPosition, 435);
    text(testFrequency, 635, 465);
  }
  if ((mouseX > 540) && (mouseX < 740) && (mouseY > 485) && (mouseY < 535)) {         //layer height
    fill(212);
    rect(width/2, 510, 200, 50);

    fill(0);
    float cursorPosition = textWidth(layerHeight) + 635;
    line(cursorPosition, 485, cursorPosition, 535);
    text(layerHeight, 635, 515);
  }
  fill(0);
  text("Start", 625, 415);
}
void dataMenu() {
  strokeWeight(1);
  fill(127);
  rect(1217, 25, 120, 50);
  fill(0);

  if ((mouseX > 1157) && (mouseX < 1277) && (mouseY > 0) && (mouseY < 50)) {               
    fill(212);
    rect(1217, 25, 120, 50);
    fill(0);
  }
  text("Main Menu", 1185, 30);  
  stroke(0);
  strokeWeight(7);
  line(1153, 0, 1153, height);

  stroke(162, 162, 162);
  strokeWeight(3);
  line(0, height-15, 1150, height-15);
  line(15, 0, 15, height);

  stroke(50);
  strokeWeight(1);
  for (int i = 1; i < 12; i++) {
    line((i*100)+15, 0, (i*100)+15, height);
  }
  stroke(0);
}
void printMenu() {
  strokeWeight(1);
  fill(127);
  rect(1217, 393, 120, 50);                                     //disable motors box
  rect(1217, 443, 120, 50);                                     //get stats box
  rect(1217, 493, 120, 50);                                     //set temperature box
  rect(1217, 543, 120, 50);                                     //extruder temperatue box
  rect(1217, 593, 120, 50);                                     //bed temperature box
  rect(1217, 643, 120, 50);                                     //progress box
  rect(1217, 693, 120, 50);                                     //start/stop print box

  fill(0);                                                      //display text
  text("Extruder Target:", 1170, 537);
  text(extruderTemp + " C", 1205, 557);
  text("Bed Target:", 1185, 587);
  text(bedTemp + " C", 1205, 607);                                                         //change box colors during scrollover and display values

  if ((mouseX > 1157) && (mouseX < 1277) && (mouseY > 368) && (mouseY < 418)) {           //disable motors
    fill(212);
    rect(1217, 393, 120, 50);
  }
  if ((mouseX > 1157) && (mouseX < 1277) && (mouseY > 418) && (mouseY < 468)) {            //get stats
    fill(212);
    rect(1217, 443, 120, 50);
  }
  if ((mouseX > 1157) && (mouseX < 1277) && (mouseY > 468) && (mouseY < 518)) {           //set temperature
    fill(212);
    rect(1217, 493, 120, 50);
  }
  if ((mouseX > 1157) && (mouseX < 1277) && (mouseY > 518) && (mouseY < 568)) {           //extruder temperature
    fill(212);
    rect(1217, 543, 120, 50);

    fill(0);
    text(extruderTemp + " C", 1205, 547);

    float cursorPosition = textWidth(extruderTemp) + 1205;                                        
    line(cursorPosition, 518, cursorPosition, 568);
  }
  if ((mouseX > 1157) && (mouseX < 1277) && (mouseY > 557) && (mouseY < 607)) {             //bed temperature
    fill(212);
    rect(1217, 593, 120, 50);

    fill(0);
    text(bedTemp + " C", 1205, 597);

    float cursorPosition = textWidth(bedTemp) + 1205;                                        
    line(cursorPosition, 568, cursorPosition, 618);
  }
  if ((mouseX > 1157) && (mouseX < 1277) && (mouseY > 657) && (mouseY < 717)) {            //start/stop print
    fill(212);
    rect(1217, 693, 120, 50);
  }
  fill(0);
  text("Disable Motors", 1183, 397);                                                      //display more text
  text("Get Stats", 1190, 447);
  text("Set Temperature", 1170, 497);
  if (printStarted == false) {
    text("Start Print", 1192, 697);
    text("Progress", 1195, 647);
  } else {
    text("Stop Print", 1192, 697);
    text(Printer.getProgress(), 1170, 640);
  }
}