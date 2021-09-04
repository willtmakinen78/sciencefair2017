import processing.serial.*;                                            //library imports
import processing.video.*;
import http.requests.*;

Capture video;                                                         //create objects
PImage displayImage;
Difference sub;
Threshold thresh;
Notification notify;
SerialCommunication Arduino;
SerialCommunication Printer;

boolean started = false;                                            //used to start and stop picture taking

String configFilename = "Config.txt";                               //filename strings           
String picFilename = "";
String GCodeFilename = "";

String extruderTemp = "185";                                        //parameter strings
String bedTemp = "60";
String frequency = "50";                                            //how often to take pictures

boolean buttonPressed = false;                                      //makes sure pictures only taken once per command

String[] calibrationNames;                                          //arrays to store filenames of pictures
String[] analysisNames;

int calibrationCounter = 0;                                         //counters incremented with each picture taken
int analysisCounter = 0;
boolean calibration;                                                //used to go into calibration/analysis mode

int[] subtractArray;                                                //pixel arrays for CV filters
int[] thresholdArray;

float percentAbove = 0;                                             //involved in determing success of each shot
boolean shotFailed = false;
int failCounter = 0;
boolean printFailed = false;

boolean printStarted = false;                                       //used for sending G-Code
int layerCount;

void setup() {
  size(1280, 720);

  Arduino = new SerialCommunication();                                       //initialize serial objects
  Printer = new SerialCommunication();

  calibrationNames = new String[100];                                        //create picture name arrays
  analysisNames = new String[100];

  sub = new Difference();                                                    //initialize camera filter libraries
  thresh = new Threshold(55);

  notify = new Notification(configFilename);                                 //initialize notification library

  displayImage = createImage(width, height, RGB);                            //image arrays
  subtractArray = new int[displayImage.pixels.length];
  thresholdArray = new int[displayImage.pixels.length];

  video = new Capture(this, "name=USB_Camera,size=1280x720,fps=8");          //start camera library
  video.start();

  Arduino.openPort(this, 1, 9600);                                           //open ports
  Printer.openPort(this, 0, 250000);

  rectMode(CENTER);
  textSize(12);
  strokeWeight(1);
}
void draw() {
  if (video.available()) {                                                    //get video    
    video.read();
  }
  if (printStarted == true) {                                                 //send G-Code file when instructed to do so
    int traval = Printer.transmit();
    if (traval < 0) {
      printStarted = false;
      println("Print Stopped");
    }
    if (Printer.layerChange == true) {                                           
      layerCount++;                                                           //increment layercount when the serial communication library reads one from the G-Code
      println("Layer: " + layerCount);

      if (layerCount % int(frequency) == 0) {                                              //if enough layers have been printed, modify the G-Code to move the print head aside and take a picture
        String[] zCommand = split(Printer.GCodeFile[Printer.lineNumber + 3], " ");
        float Height = float(zCommand[1].substring(1, zCommand[1].length() - 1));
        String newHeight = str(Height + 5);
        Printer.GCodeFile[Printer.lineNumber + 1] += "\nG1 Z" + newHeight + "\nG1 X250\nG1 Y305\nG1 X287\nG4 P500\nM42 P6 S255\nG4 P750\nG1 X250\nM42 P6 S0\n";
       // Printer.GCodeFile[Printer.tx_line + 1] += "\nG1 Y" + int(str(random(300, 307))) + " X250\nG1 X287\nG92 E0\nG1 E2 F2400\nG1 Z305\nG4 P500\nM42 P6 S255\nG4 P750\nM42 P6 S0\n";
       // Printer.GCodeFile[Printer.tx_line + 3] += "\nG1 E3 F2400\nG92 E0\nG1 X250\n";
        //println(Printer.GCodeFile[Printer.layerNumber + 3]);
        //println(Height);
        //println(newHeight);
      }
      Printer.layerChange = false;
    }
  }
  if (started == true) {
    notify.checkForStop();
    if (notify.stopped == true) {                                            //stop the print if the user wishes
      Printer.abort();
      Arduino.sendChar('s');                                                 //tell the arduino to disable the SSR
    }
    if (calibration == true) {                                               //calibration mode:
      failCounter = 0;
      printFailed = false;

      if (Arduino.trimmedString.equals("pic")) {                             //if the printer's digital pin is on, telling the arduino to take a picture, it will send "pic"
        if (buttonPressed == false) {                                        //only take one picture per signal

          delay(500);
          image(video, 0, 0);                                                //display the video feed, take a screenshot, and save it
          delay(250);
          calibrationNames[calibrationCounter] = picFilename + "_Calibration" + calibrationCounter + ".jpg";
          saveFrame(dataPath("") + "\\" + calibrationNames[calibrationCounter]);
          calibrationCounter++;
        }
        buttonPressed = true;
      } else {                                                               //otherwise display regular menu buttons
        buttonPressed = false;
        printMenu();
        picMenu();
      }
    } else {                                                                 //analysis mode:
      if (Arduino.trimmedString.equals("pic")) {                 
        if (buttonPressed == false) {                                        
          try {
            delay(500);
            image(video, 0, 0);                                              //same thing as before; display the video feed, take a screenshot, and save it
            delay(250);
            analysisNames[analysisCounter] = picFilename + "_Analysis" + analysisCounter + ".jpg";
            saveFrame(dataPath("") + "\\" + analysisNames[analysisCounter]);

            subtractArray = sub.subtract(calibrationNames[analysisCounter], analysisNames[analysisCounter]);            //then compare the analysis image to the calibration one, running it through the two filters
            thresholdArray = thresh.threshold(subtractArray);

            analysisCounter++;

            percentAbove = (thresh.aboveThreshold / thresholdArray.length) * 100;                  
            println("Percent of different pixels: " + percentAbove);
            if (percentAbove > 0.03) {                                       //if there are too many different pixels,
              if (shotFailed == false) {
                println("Shot Failed");                                      //declare the shot to be failed and increment the counter
                failCounter++;
              }
              shotFailed = true;
            }
            if (failCounter > 2) {                                           //after 3 failed shots, send the notification and declare the entire print to be failed
              println("Print Failed");
              failCounter = -2000;
              notify.sendNotification();
            }
          }
          catch (Exception e) {
            println("Could not apply filter: " + e);
          }
          buttonPressed = true;
        }
      } else {                                                              //show menus when not taking pictures
        printMenu();
        picMenu();
        buttonPressed = false;
        shotFailed = false;
      }
    }
  } else {                                                                  //when not taking pictures of prints, display opening menus
    printMenu();
    mainMenu();
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
   // println("Printer: " + Printer.trimmedString);
  }
}
void mousePressed() {                                                                    //fairly sef-explanatory; any time the mouse is clicked read ts x-y coordinates and determine which button is being clicked
  if (started == false) {
    if ((mouseX > 540) && (mouseX < 740) && (mouseY > 385) && (mouseY < 435)) {          //calibration
      started = true;
      calibration = true;
      notify.getFirstTweet();
    }
    if ((mouseX > 540) && (mouseX < 740) && (mouseY > 435) && (mouseY < 485)) {          //analysis
      started = true;
      calibration = false;
      notify.getFirstTweet();
    }
  } else {
    if ((mouseX > 540) && (mouseX < 740) && (mouseY > 385) && (mouseY < 435)) {          //main menu
      started = false;
      calibration = false;
      Arduino.sendChar('g');                                                             //tell arduino to re-enable SSR
    }
  }
  if ((mouseX > 1160) && (mouseX < 1280) && (mouseY > 660) && (mouseY < 720)) {          //start/stop print 
    if (printStarted == false) {
      Printer.loadGCode(GCodeFilename);
      Printer.resetTransmit();
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
void keyPressed() {                                                                      //keyboard events, same as above, used for filename/parameter entry
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
  if ((mouseX > 540) && (mouseX < 740) && (mouseY > 335) && (mouseY < 385)) {            //picture filenames
    if (key!= CODED) {
      if (key == BACKSPACE) {                                                
        if (picFilename.length() > 0) {
          picFilename = picFilename.substring(0, picFilename.length()-1);
        }
      } else if (textWidth(picFilename + key) < 192) {
        picFilename = picFilename + key;
      }
    }
  }
  if ((mouseX > 1157) && (mouseX < 1277) && (mouseY > 5) && (mouseY < 55)) {            //picture frequency entry
    if (printStarted == false) {
      if (key != CODED) {
        if (key == BACKSPACE) {
          if (frequency.length() > 0) {
            frequency = frequency.substring(0, frequency.length()-1);
          }
        } else if (textWidth(frequency + key) < 35) {
          frequency = frequency + key;
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
  calibrationCounter = 0;
  analysisCounter = 0;

  fill(127);
  rect(width/2, 310, 200, 50);                                                         //G-Code filename box
  rect(width/2, height/2, 200, 50);                                                    //picture filename box
  rect(width/2, 410, 200, 50);                                                         //calibration box
  rect(width/2, 460, 200, 50);                                                         //analysis box

  fill(0);
  text("GCode Filename", 595, 315);                                                    //change button colors durong scrollover to display values
  text("Picture Filename", 595, 365);  

  if ((mouseX > 540) && (mouseX < 740) && (mouseY > 285) && (mouseY < 335)) {          //G-Code filename
    fill(212);
    rect(width/2, 310, 200, 50);

    fill(0);
    float cursorPosition = textWidth(GCodeFilename) + 544;
    line(cursorPosition, 335, cursorPosition, 285);
    text(GCodeFilename, 544, 315);
  }

  if ((mouseX > 540) && (mouseX < 740) && (mouseY > 335) && (mouseY < 385)) {          //picture filename
    fill(212);
    rect(width/2, height/2, 200, 50);

    fill(0);
    float cursorPosition = textWidth(picFilename) + 544;
    line(cursorPosition, 385, cursorPosition, 335);
    text(picFilename, 544, 365);
  }
  if ((mouseX > 540) && (mouseX < 740) && (mouseY > 385) && (mouseY < 435)) {          //calibration
    fill(212);
    rect(width/2, 410, 200, 50);
  }
  if ((mouseX > 540) && (mouseX < 740) && (mouseY > 435) && (mouseY < 485)) {          //analysis
    fill(212);
    rect(width/2, 460, 200, 50);
  }
  fill(0);
  text("Calibrate", 615, 415); 
  text("Analyze", 617, 465);
}
void picMenu() {
  fill(127);
  rect(width/2, height/2, 200, 50);                                                    //calibration/analysis box
  rect(width/2, 410, 200, 50);                                                         //main menue box
  fill(0);
  text("Main Menu", 605, 415);
  
  if ((mouseX > 540) && (mouseX < 740) && (mouseY > 385) && (mouseY < 435)) {          //change color of main menu box during scrollover
    fill(212);
    rect(width/2, 410, 200, 50);

    fill(0);
    text("Main Menu", 605, 415);
  }
  fill(255);
  text("Percent of Different Pixels: " + percentAbove, 5, 15);                          //display different pixels
  
  fill(0);
  if (calibration == true) {                                                            //text changes based on calibration/analysis mode
    text("Calibration", 607, 365);
  } else {
    text("Analysis", 615, 365);                                                         //in anaysis mode display the most recent picture comparison
    displayImage.loadPixels();
    displayImage.pixels = thresholdArray;
    displayImage.updatePixels();
    image(displayImage, 427, 450, video.width/3, video.height/3);
  }
  image(video, 427, 30, video.width/3, video.height/3);                                 //in both modes show a live video feed from the camera
}
void printMenu() {
  if (started == false) {                                       //change background based on current mode
    background(255);
  } else {
    background(50);
  }
  fill(127);
  rect(1217, 30, 120, 50);                                      //frequency box
  rect(1217, 393, 120, 50);                                     //disable motors box
  rect(1217, 443, 120, 50);                                     //get stats box
  rect(1217, 493, 120, 50);                                     //set temperature box
  rect(1217, 543, 120, 50);                                     //extruder temperatue box
  rect(1217, 593, 120, 50);                                     //bed temperature box
  rect(1217, 643, 120, 50);                                     //progress box
  rect(1217, 693, 120, 50);                                     //start/stop print box

  fill(0);
  text("Picture Frequency: ", 1165, 25);                        //display text
  text(frequency, 1210, 47);
  text("Extruder Target:", 1170, 537);
  text(extruderTemp + " C", 1205, 557);
  text("Bed Target:", 1185, 587);
  text(bedTemp + " C", 1205, 607);                                                         //change box colors during scrollover and display values

  if ((mouseX > 1157) && (mouseX < 1277) && (mouseY > 5) && (mouseY < 55)) {               //frequency
    fill(212);
    rect(1217, 30, 120, 50);

    fill(0);
    text(frequency, 1210, 37);

    float cursorPosition = textWidth(frequency) + 1210;                                        
    line(cursorPosition, 5, cursorPosition, 55);
  }
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