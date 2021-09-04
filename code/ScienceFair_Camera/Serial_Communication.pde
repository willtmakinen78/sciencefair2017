class SerialCommunication {
  int progress;
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
  boolean layerChange = false;
  boolean changeOnce = false;
  int lineNumber;

  SerialCommunication() {
    filename = null;
    resetTransmit();
  }
  String getProgress() {
    String returnString;
    try {
      returnString = (str(tx_line) + "/" + str(GCodeFile.length) 
        + "\n" + str(float(tx_line) / float(GCodeFile.length) * 100) + "%");
    }
    catch( Exception e ) {
      println( e );
      returnString = "failed";
    }
    return returnString;
  }

  void openPort(ScienceFair_Camera context, int which_port, int baud) {
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
  String[] getPortList() {
    return Serial.list();
  }
  boolean loadGCode(String file_in) {
    if ( GCodeFile != null ) {
      closeGCode();
    }
    try {
      GCodeFile = loadStrings(file_in);
      return true;
    } 
    catch ( Exception e ) {
      println("Failed to open GCode file: " + file_in );
      return false;
    }
  }
  void closeGCode() {
    if (GCodeFile != null) {
      try {
        GCodeFile = null;
      } 
      catch (Exception e) {
        println("Error closing GCode file: " + e );
      }
    }
  }
  void abort() {
    println("Stop printing");
    ABORT = true;
  }
  void resetTransmit() {
    tx_line = 0;
    ACK = true;
    ABORT = false;
    inString = null;

    if (filename != null) {
      if (GCodeFile != null) {
        closeGCode();
      }
      loadGCode(filename);
    }
  }
  int transmit() {
    try {
      if (tx_line >= GCodeFile.length - 1) {
        //notify.sendNotification();
        abort();
      }
    }  
    catch (Exception e) {
      println("GCodeFile not defined: " + e);
    }
    if (ABORT == true) {
      sendString("G1 X0 Y0\n");
      return -1;
    } 
    if (port == null || GCodeFile == null ) {
      return -1;
    }
    cmd = trim(GCodeFile[tx_line]);

    String modifiedCMD;

    if ( cmd == null ) {
      println("The command is null");
      return -1;
    }
    if (cmd.equals("")) {
      cmd = "M4 P1";
    }
    if (changeOnce == false) {
      if (cmd.equals("; layer change")) {
        layerChange = true;
        lineNumber = tx_line;
      }
      changeOnce = true;
    }
    String[] cmdList = split(cmd, " ");
    if (cmdList[0].equals(";")) {
      modifiedCMD = "M4 P1";
    } else {
      modifiedCMD = cmd;
    }
    modifiedCMD += "\n";
    if (ACK == true) {
      //println("Sending: " + modifiedCMD );
      port.write(modifiedCMD);
      tx_line++;
      changeOnce = false;
      ACK = false;
    }
    return tx_line;
  }
  void sendString(String val) {
    try {
      port.write(val);
    }
    catch (Exception e) {
      println("Error on method send(): " + e);
    }
  }
  void sendChar(char val) {
    try {
      port.write(val);
    }
    catch (Exception e) {
      println("Error on method send(): " + e);
    }
  }
  void readPort(String data) {
    if (ABORT) return;

    try {
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
    if (trimmedString.equals("ok")) {
      ACK = true;
      return;
    } else {
      //ACK = false;
      return;
    }
  }
}