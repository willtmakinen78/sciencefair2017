class SerialCommunication {
  int progress;                              //variable setup
  int tx_line;

  Serial port;   

  String[] GCodeFile;

  int BAUD_RATE;

  boolean ACK;           
  boolean ABORT;         

  String filename;
  String[] lines;
  String inString;
  String trimmedString = "";

  String cmd = "";

  boolean perimeterStarted = false;
  boolean firstPerimeter = true;

  SerialCommunication() {
    filename = null;
    resetTransmit();
  }
  String getProgress() {                             //returns current place in G-Code file
    String returnString;                      
    try {
      returnString = (str(tx_line) + "/" + str(GCodeFile.length) 
        + "\n" + str(float(tx_line) / float(GCodeFile.length) * 100) + "%");
    }
    catch(Exception e) {
      println(e);
      returnString = "failed";
    }
    return returnString;
  }
  void openPort(ScienceFair_Force context, int which_port, int baud) {                      //begin serial communicaTIONS with serial devices
    BAUD_RATE = baud;

    if ( which_port < 0 || which_port >= Serial.list().length ) {
      println("Error: serial port selection is out of range");
    }
    if (port != null) {
      // Close the port.
      port.stop();
    } 
    println("Opening Serial Port:");
    try {
      port = new Serial(context, Serial.list()[which_port], BAUD_RATE);
      port.bufferUntil('\n');

      println("Serial port open");
    } 
    catch (Exception e) {
      port = null;
      println("Failed to open serial port");
    }
  }
  String[] getPortList() {                        //somewhat unnecessary, but not too hard to include
    return Serial.list();
  }
  boolean loadGCode(String file_in) {            //loads G-Code file into a list of strings
    if (GCodeFile != null) {
      closeGCode();
    }
    try {
      GCodeFile = loadStrings(file_in);
      return true;
    } 
    catch (Exception e) {
      println("Failed to open GCode file: " + file_in );
      return false;
    }
  }
  void closeGCode() {                                    //clears the G-Code list
    if (GCodeFile != null) {
      try {
        GCodeFile = null;
      } 
      catch (Exception e) {
        println("Error closing GCode file: " + e );
      }
    }
  }
  void abort() {                                    //stops printing
    println("Stop printing");
    ABORT = true;
  }
  void resume() {                                   //resumes printing
    ABORT = false;
    ACK = true;
    sendString("M4 P1\n");
  }
  void resetTransmit() {                            //resets all variables
    tx_line = 0;
    ACK = true;
    ABORT = false;
    inString = null;
    firstPerimeter = true;

    if (filename != null) {
      if (GCodeFile != null) {
        closeGCode();
      }
      loadGCode(filename);
    }
  }
  int transmit(String speed) {                                  //the main meat and potatoes; used to send G-Code to printer
     try {
      if (tx_line >= GCodeFile.length - 1) {                    //stop if the end of the G-Code file has been reached
        abort();
      }
    }  
    catch (Exception e) {
      println("GCodeFile not defined: " + e);
    }
    if (ABORT == true) {                                        //home axis when stopping print
      sendString("G1 X0 Y0\n");
      return -1;
    } 
    if (port == null || GCodeFile == null ) {                   //make sure there is a G-Code file toread and a port to send it to
      return -1;
    }
    cmd = trim(GCodeFile[tx_line]);                             //clean up the current G-Code line

    String modifiedCMD;

    if (cmd == null) {                                          //if there is no command for whatever reason, exit the function
      println("The command is null");
      return -1;
    }
    if (cmd.equals("")) {                                       //if the G-Code line is blank, change it to a short delay to trigger the printer's acnkowledgement
      cmd = "M4 P1";
    } else if (cmd.equals("; start perimeter")) {               //if perimter commands are being sent:
      //println("Perimewter started");
      perimeterStarted = true;                                  //update the variable, but not for the first perimeter
      if (firstPerimeter == true) {
        perimeterStarted = false;
        firstPerimeter = false;
      }
      //if (perimterStarted == true) {
      //  modifiedCMD = "\nM42 P11 S255";
      //}
    }
    String[] cmdList = split(cmd, " ");                       

    if (cmdList[0].equals(";")) {                              //split each line into its individual commands, for a list for those
      modifiedCMD = "M4 P1";
    } else {
      modifiedCMD = cmd;
    }
    for (int i = 0; i < cmdList.length; i++) {                //go though each command looking for a printing speed increase signifying the start of infill
      if (cmdList[i].equals("F" + speed + "00")) {
        //println(cmdList[i]);
        perimeterStarted = false;
        modifiedCMD += "\nM42 P11 S0";                       //once found, toggle the printer's digital pin to notify the ardiuno
      }
    }  
    //if (perimeterStarted == true) {
    //  modifiedCMD += "\n G4 P1";
    //}
    modifiedCMD += "\n";
    if (ACK == true) {                                      //only send new commands after the previous one has been acknowledged
      println("Sending: " + modifiedCMD );
      port.write(modifiedCMD);
      tx_line++;
      ACK = false;
    }
    return tx_line;                                         //return the G-Code line number
  }
  void sendString(String val) {                             //send an individual string
    try {
      port.write(val);
    }
    catch (Exception e) {
      println("Error on method send(): " + e);
    }
  }
  void sendChar(char val) {                                //send an individual character
    try {
      port.write(val);
    }
    catch (Exception e) {
      println("Error on method send(): " + e);
    }
  }
  void readPort(String data) {                            //called in serialEvent in main sketch
    if (ABORT) return;

    try {                                                 //clean up and save the value read from the serial port
      inString = data;
      if (inString != null) {
        trimmedString = trim(inString);
      }
    } 
    catch( Exception e ) {
      println("Serial Event error: " + e );
      return;
    }
    //println("Recieved: " + trimmedString);
    if (trimmedString.equals("ok")) {                    //look for the printer's acknowledgement
      ACK = true;
      return;
    } else {
      ACK = false;
      return;
    }
  }
}