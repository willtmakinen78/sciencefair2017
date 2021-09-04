import processing.serial.*;               //import library objects

PrintWriter output;                       //create library objects
Notification notify;
SerialCommunication Arduino;
SerialCommunication Printer;

boolean fileCreated = false;              //used to only create the output file once, rather than 60 times/sec

float force;                              //variables to store arduino readings
float input;                              
float mappedForce;

boolean started = false;                  //determines whether or not to display the graph
boolean perimeterStarted = false;         //made true when gcode perimeter commands are being executed

int startTime;                            //will store the millis() value at which the program started
int currentTime;                          //store the elapsed time since startTime
int lineTime;                             //stores the millis() time at which the last line was drawn
int numberTime;                           //stores the millis() time at which the kast time stamp was displayed
int perimeterTime;
int lineInterval = 100;                   //how frequently the line graph will be updated 
int numberInterval = 1000;                //how frequently the timestamp will be updated
boolean perimeterTimeOnce = false;

float[] graphedForce;                     //stores the last 100 force values
String[] graphedTime;                     //stores the last 10 timestamps

String GCodeFilename = "";                //filename variables
String dataFilename = "";
String configFilename = "Config.txt";

String extruderTemp = "185";              //parameter strings
String bedTemp = "60";
String speed = "60";

int perimeterDelay = 750;                 //how long to wait after the start of a layer to begin analyzing perimeter values
int failThreshold = 20;                   //how far above the average a force value must be to be considered failed adhesion
int failedLayerThreshold = 3;             //how many individual layers must fail for the entire print to be declared a failure
int fixThreshold = 2;                     //nimber of tries will be taken to fix the print

float averageForce = 0;                   //stores each layer's average force
float forceSum = 0;                       //used to calculate the average force
float perimeterCounter = 1;               //makes sure that the first force reading for each perimter is set to the average

boolean layerFailed = false;              //error correction values
int failCounter = 0;                     
int fixCounter = 0;
int extruderFix = 10;
int bedFix = 5;

boolean printStarted = false;            //used for sending gcode

void setup() { 
  size(1000, 1015);

  notify = new Notification(configFilename);                 //start the notification library

  Arduino = new SerialCommunication();                       //start serial communications
  Printer = new SerialCommunication();

  graphedForce = new float[width/10];                        //set the size of the data arrays
  graphedTime = new String[width/10];
  for (int i = 0; i < graphedTime.length; i++) {             //clear the timestamp array
    graphedTime[i] = "0";
  }
  Arduino.openPort(this, 0, 9600);                           //open ports
  Printer.openPort(this, 1, 250000);

  textSize(12);
  strokeWeight(1);
} 
void draw() {
  if (printStarted == true) {

    int traval = Printer.transmit(str(float(speed) * 60));                  //perform the gcode transmit method with the infill speed as an argument
    if (traval < 0) {
      printStarted = false;                                                 //stop sending when instructed
      println("Print Stopped");
    }
  }
  input = float(Arduino.trimmedString);                                    //convert to a float
  if (input == 666) {                                                      //when the arduino recieves the M-command for the start of a perimter, it will send 666
    perimeterStarted = true;                                               //tell it to start reading force values
    if (perimeterTimeOnce == false) {
      perimeterTime = millis();                                            //save the current time so it knows when to start reading force values
      perimeterTimeOnce = true;
    }
    Arduino.sendChar('p');
  } else if (input == 555) {                                               //when the arduino recieves the M-command for the start of infill, it will send 555
    perimeterStarted = false;                                              //tell it to stop reading force values
    perimeterTimeOnce = false;
    Arduino.sendChar('i');
  } else {
    mappedForce = map(input, 0, 1000, 0, height - 15);                     //map it to a useable range
    force = input;
  }
  if (started == true) {                                                   //everyting here will be used to display the graph and do analysis
    notify.checkForStop();                                                 //check for any stop tweets, tell arduino to shut down SSR if any are found
    if (notify.stopped == true) {
      Arduino.sendChar('s');                                               //if any are found, shut down the printer
    }  
    if (fileCreated == false) {                                            //only create the file once per graphing session, not 60 times/sec
      output = createWriter(dataFilename + ".csv");
      fileCreated = true;
    }
    if (millis() - lineTime >= lineInterval) {                             //if it has been more time than lineInterval since the data was last graphed,
      background(255);
      currentTime = millis() - startTime;                                  //update the current time

      fill(0);                                                             //formatting for displaying text

      if (perimeterStarted == true) {                                      //if a perimeter has started:
        text("Perimeter", 5, 12); 
        if ((millis() - perimeterTime) > perimeterDelay) {                 //wait for the head to move to the correct spot

          if (perimeterCounter < 10) {                                     //establish an initial average for the first second
            text("Establishing Initial Average", 5, 24);
            forceSum += force;
            averageForce = forceSum / perimeterCounter;
            println(averageForce);
          } else {                                                          //then start looking for errors
            if ((force > (averageForce + failThreshold)) || (force < (averageForce - failThreshold))) {                  //if there is a failure of adhesion:
              text("Failed Adhesion", 5, 24);

              if (layerFailed == false) {                                  //update the fail counter once per layer
                failCounter++;
                layerFailed = true;
              }
            } else {                                                       //otherwise update the average
              text("Successful Adhesion", 5, 24);
              forceSum += force;
              averageForce = forceSum / perimeterCounter;
            }
          }
          perimeterCounter++;
        }
      } else {                                                             //during infill reset all the variables
        text("Other", 5, 12);

        perimeterCounter = 1;
        averageForce = 0;
        forceSum = 0;
        layerFailed = false;
      }
      if (failCounter >= failedLayerThreshold) {                         //if enough layers have failed, modify print parameters
        fill(0);
        strokeWeight(0);
        fixCounter++;
        failCounter = 0;
        if (fixCounter > fixThreshold) {                                 //if parameters have been modified too many times and failures are still occuring,             
          text("Print Failed", 5, 48);
          notify.sendNotification();                                     //send the user a notification so they can stop the print
        } else {

          extruderTemp = str(float(extruderTemp) + extruderFix);         //otherwise modify print parameters
          bedTemp = str(float(bedTemp) + bedFix);
          Printer.sendString("G1 X250\nG1 Y305\nG1 X287\n");             //wipe the extruder and up temperatures
          Printer.sendString("M104 S" + extruderTemp +"\n");
          Printer.sendString("M190 S" + bedTemp +"\n");
          text("Attempt " + str(fixCounter) + "at fixing print", 5, 36);
          Printer.ACK = false;
          while (Printer.ACK == false) {
            text("Waiting for temperatures to be reached", 5, 48);
          }
          perimeterCounter = 1;                                          //reset all variables
          averageForce = 0;
          forceSum = 0;
          layerFailed = false;
          Printer.sendString("G1 X250\n");
          Printer.resume();
        }
      }
      output.print(currentTime);                                         //write the data to the output file
      output.print(",");
      output.println(force);

      stroke(0, 100);
      strokeWeight(1);
      line(0, height - 15, width, height - 15);                          //draw in x-axis line

      graphedForce[0] = mappedForce;                                     //set the first value of the array to the current force reading
      for (int i = graphedForce.length - 1; i > 0; i--) {                //shift everything over one place
        graphedForce[i] = graphedForce[i-1];
      }
      stroke(250, 200, 0);
      strokeWeight(3);
      for (int i = 1; i < graphedForce.length; i++) {                    //draw in the line graph
        line(i*10, height - (graphedForce[i] + 15), (i-1)*10, height - (graphedForce[i-1] + 15));
      }
      for (int i = 0; i < graphedTime.length; i++) {                      //draw in the vertical timestamp lines and the timestamps themseilves
        fill(0);
        strokeWeight(1);
        text(graphedTime[i], i*100, height - 2);
        stroke(0, 100);
        line(i*100, 0, i*100, height);
      }
      lineTime = millis();                                                //update linetime so it knows when to next update the graph
      graphMenu();                                                        //display control buttons
      printMenu();
    }
    if (millis() - numberTime >= numberInterval) {                        //only update the timestamp once a second
      graphedTime[0] = str(float(currentTime/1000));
      for (int i = graphedTime.length - 1; i > 0; i--) {
        graphedTime[i] = graphedTime[i-1];
      }
      numberTime = millis();                                              //update numberTime so it knows when to next update the timestamp
    }
  } else {                                                                //display opening menu (analysis is not running)
    printMenu();
    mainMenu();
  }
}
void serialEvent(Serial port) {                                           //triggers any time serial data is available
  if (port == Arduino.port) {
    String data = Arduino.port.readString();
    Arduino.readPort(data);
    //println("Arduino: " + data);
  }
  if (port == Printer.port) {
    String data = Printer.port.readString();
    Printer.readPort(data);
    println("Printer: " + data);
  }
}
void mousePressed() {                                                                      //fairly sef-explanatory; any time the mouse is clicked read ts x-y coordinates and determine which button is being clicked
  if (started == false) {
    if ((mouseX > 440) && (mouseX < 560) && (mouseY < 475) && (mouseY > 425)) {            //start analysis
      started = true;
      fileCreated = false;

      startTime = millis();
      lineTime = millis();
      numberTime = millis();

      failCounter = 0;
      fixCounter = 0;
      perimeterCounter = 0;

      notify.getFirstTweet();
    }
    if ((mouseX > 440) && (mouseX < 560) && (mouseY < 525) && (mouseY > 475)) {            //tare
      Arduino.sendChar('z');
    }
  } else {
    if ((mouseX > 900) && (mouseX < 1000) && (mouseY > 350) && (mouseY < 400)) {           //main menu
      output.flush();                                                                      //writes the remaining data to the file
      output.close();                                                                      //finishes the file
      started = false;
      fileCreated = false;
    }
  }
  if ((mouseX > 900) && (mouseX < 1000) && (mouseY > 662) && (mouseY < 712)) {             //disable motors
    Printer.sendString("M18\n");
  }
  if ((mouseX > 900) && (mouseX < 1000) && (mouseY > 712) && (mouseY < 762)) {             //get stats
    Printer.sendString("M105\n");
  }
  if ((mouseX > 900) && (mouseX < 1000) && (mouseY > 762) && (mouseY < 812)) {             //set temperatures
    println("Setting Temperatures\nExtruder: " + extruderTemp +"\nBed: " + bedTemp);
    Printer.sendString("M104 S" + int(extruderTemp) +"\n");
    Printer.sendString("M140 S" + int(bedTemp) + "\n");
  }
  if ((mouseX > 877) && (mouseX < 997) && (mouseY > 962) && (mouseY < 1012) ) {            //start/stop print
    if (printStarted == false) {
      Printer.loadGCode(GCodeFilename);
      Printer.resetTransmit();
      println("Attempting to send GCode data");
      Printer.sendString("M4 P15\n");
      Printer.ACK = true;
      printStarted = true;
    } else {
      Printer.abort();
      printStarted = false;
      Arduino.sendChar('g');
    }
  }
}
void keyPressed() {                                                                         //keyboard events, same as above, used for filename/parameter entry
  if (started == false) {
    if ((mouseX > 440) && (mouseX < 560) && (mouseY < 375) && (mouseY > 325)) {             //G-Code filename
      if (key != CODED) {
        if (key == BACKSPACE) {                                                 
          if (GCodeFilename.length() > 0) {
            GCodeFilename = GCodeFilename.substring(0, GCodeFilename.length()-1);
          }
        } else if (textWidth(GCodeFilename + key) < 120) {                           
          GCodeFilename = GCodeFilename + key;
        }
      }
    }
    if ((mouseX > 440) && (mouseX < 560) && (mouseY < 425) && (mouseY > 375)) {            //graph/data filename
      if (key != CODED) {
        if (key == BACKSPACE) {                                                 
          if (dataFilename.length() > 0) {
            dataFilename = dataFilename.substring(0, dataFilename.length()-1);
          }
        } else if (textWidth(dataFilename + key) < 120) {                           
          dataFilename = dataFilename + key;
        }
      }
    }
  }
  if ((mouseX > 900) && (mouseX < 1000) && (mouseY > 0) && (mouseY < 50)) {               //infill speed
    if (key != CODED) {
      if (key == BACKSPACE) {                                                 
        if (speed.length() > 0) {
          speed = speed.substring(0, speed.length()-1);
        }
      } else if (textWidth(speed + key) < 35) {                           
        speed = speed + key;
      }
    }
  }
  if ((mouseX > 900) && (mouseX < 1000) && (mouseY > 812) && (mouseY < 862)) {            //extruder temperature
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
  if ((mouseX > 900) && (mouseX < 1000) && (mouseY > 862) && (mouseY < 912)) {            //bed temperature
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
  fill(127);
  rect(440, 325, 120, 50); 
  rect(440, 375, 120, 50);                                              //filename box
  rect(440, 425, 120, 50);                                              //start box
  rect(440, 475, 120, 50);                                              //tare box
  rect(440, 525, 120, 50);                                              //reading box

  fill(0);
  text("Data Filename", 455, 406);                                                          //changes button colors during scrollover and displays values
  text("Gcode Filename", 455, 356);

  if ((mouseX > 440) && (mouseX < 560) && (mouseY < 375) && (mouseY > 325)) {               //G-Code filename
    fill(212);
    rect(440, 325, 120, 50);

    fill(0);
    text(GCodeFilename, 440, 356);

    float cursorPosition = textWidth(GCodeFilename) + 440;                                            
    line(cursorPosition, 325, cursorPosition, 375);
  }
  if ((mouseX > 440) && (mouseX < 560) && (mouseY < 425) && (mouseY > 375)) {                //data/graph filename
    fill(212);
    rect(440, 375, 120, 50);

    fill(0);
    text(dataFilename, 440, 406);

    float cursorPosition = textWidth(dataFilename) + 440;
    line(cursorPosition, 375, cursorPosition, 425);
  }
  if ((mouseX > 440) && (mouseX < 560) && (mouseY < 475) && (mouseY > 425)) {                 //start
    fill(212);
    rect(440, 425, 120, 50);
  }
  if ((mouseX > 440) && (mouseX < 560) && (mouseY < 525) && (mouseY > 475)) {                 //tare
    fill(212);
    rect(440, 475, 120, 50);
  }
  fill(0);
  text("Start Recording", 455, 456);                                     //start text
  text("Tare", 485, 506);                                                //tare text
  text("Current Reading:", 450, 547);                                    //reading text
  text(str(mappedForce), 490, 563);                                      //convert force vack into a string and display it
}
void graphMenu() {
  fill(127);
  rect(900, 350, 100, 50);                                                        //main menu box

  if ((mouseX > 900) && (mouseX < 1000) && (mouseY > 350) && (mouseY < 400)) {
    fill(212);
    rect(900, 350, 100, 50);
  }
  fill(0);
  text("Main Menu", 920, 380);
}
void printMenu() {
  if (started == false) {
    background(0);
  }
  fill(127);
  rect(900, 0, 100, 50);                            //infill box
  rect(900, 662, 100, 50);                          //disable motors box
  rect(900, 712, 100, 50);                          //get stats box
  rect(900, 762, 100, 50);                          //set temperature box
  rect(900, 812, 100, 50);                          //extruder target box
  rect(900, 862, 100, 50);                          //bed target box
  rect(900, 912, 100, 50);                          //progress box
  rect(900, 962, 100, 50);                          //start/stop print box

  fill(0);
  text("Infill Speed", 920, 20);                    //display text/values
  text(speed + " mm/s", 923, 37);
  text("Extruder Target", 903, 835);
  text(extruderTemp + " C", 940, 855);
  text("Bed Target", 920, 885);
  text(bedTemp + " C", 940, 905);                                                            //changes button colors during mouse rollover

  if ((mouseX > 900) && (mouseX < 1000) && (mouseY > 0) && (mouseY < 50)) {                  //infill
    fill(212);
    rect(900, 0, 100, 50);

    fill(0);
    text(speed, 940, 30);

    float cursorPosition = textWidth(speed) + 940;                                        
    line(cursorPosition, 0, cursorPosition, 50);
  }
  if ((mouseX > 900) && (mouseX < 1000) && (mouseY > 662) && (mouseY < 712)) {              //disable motors
    fill(212);
    rect(900, 662, 100, 50);
  }
  if ((mouseX > 900) && (mouseX < 1000) && (mouseY > 712) && (mouseY < 762)) {              //get stats
    fill(212);
    rect(900, 712, 100, 50);
  }
  if ((mouseX > 900) && (mouseX < 1000) && (mouseY > 762) && (mouseY < 812)) {               //set temperature
    fill(212);
    rect(900, 762, 100, 50);
  }
  if ((mouseX > 900) && (mouseX < 1000) && (mouseY > 812) && (mouseY < 862)) {               //extruder target
    fill(212);
    rect(900, 812, 100, 50);

    fill(0);
    text(extruderTemp + " C", 940, 845);

    float cursorPosition = textWidth(extruderTemp) + 940;                                        
    line(cursorPosition, 812, cursorPosition, 862);
  }
  if ((mouseX > 900) && (mouseX < 1000) && (mouseY > 862) && (mouseY < 912)) {                //bed target
    fill(212);
    rect(900, 862, 100, 50);

    fill(0);
    text(bedTemp + " C", 940, 895);

    float cursorPosition = textWidth(bedTemp) + 940;                                        
    line(cursorPosition, 862, cursorPosition, 912);
  }
  if ((mouseX > 900) && (mouseX < 1000) && (mouseY > 962) && (mouseY < 1012)) {              //start/stop
    fill(212);
    rect(900, 962, 100, 50);
  }
  fill(0);
  text("Disable Motors", 910, 693);
  text("Get Stats", 923, 743);
  text("Set Temperature", 902, 793);
  if (printStarted == false) {
    text("Start Print", 920, 992);
    text("Progress", 923, 942);
  } else {
    text("Stop Print", 920, 992);
    text(Printer.getProgress(), 905, 935);
  }
}