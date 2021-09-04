class Threshold {
  int loc;                                                      //variables
  float threshold;
  float brightness;
  int[] pixelArray;

  float aboveThreshold = 0;

  Threshold(int threshold_) {                                    //initialization funtion creates an output array and the threshold value
    pixelArray = new int[width * height];
    threshold = threshold_;
  }
  int[] threshold(int[] inputArray) {                            //takes the output array from the difference filter as a parameter
    aboveThreshold = 0;

    try {
      pixelArray = inputArray;
      for (int x = 0; x < width; x++) {                           //go through each pixel
        for (int y = 0; y < height; y++) {
          loc = x + y * width;

          if (brightness(pixelArray[loc]) > threshold) {          //determine if its intensity is above or below the threshold
            pixelArray[loc] = color(255);
            aboveThreshold++;
          } else if (brightness(pixelArray[loc]) < threshold) {   //make each pixel back or white accordingly
            pixelArray[loc] = color(0);
          }
        }
      }
    }
    catch (Exception e) {
      println("Could not open threshold image: " + e );
    }
    return pixelArray;                                            //export array
  }
}