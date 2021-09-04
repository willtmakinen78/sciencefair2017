class Difference {
  PImage full;                              //variables
  PImage empty;
  PImage output;

  int loc;

  float fullR;
  float fullG;
  float fullB;

  float emptyR;
  float emptyG;
  float emptyB;

  float differenceR;
  float differenceG;
  float differenceB;

  float totalDifference;
  float outputBrightness;

  int[] outputArray;

  Difference() {                           //no initialization functions
  }
  int[] subtract(String fullFileName, String emptyFileName) {                  //this subtract filter takes the two comparison images' filenames as paramters and returns a pixel array for the resulting image
    try {
      full = loadImage(fullFileName);                                          //load in the images
      empty = loadImage(emptyFileName);
      output = createImage(full.width, full.height, RGB);
      outputArray = new int[output.pixels.length];

      full.loadPixels();                                                        //load the pixel arrays for each image
      empty.loadPixels();
      output.loadPixels();
      
      for (int x = 0; x < full.width; x++) {                                    //go through each pixel in each array
        for (int y = 0; y < full.height; y++) {
          loc = x + y * full.width;

          fullR = red(full.pixels[loc]);                                        //extract the RGB values for each pixel
          fullG = green(full.pixels[loc]);
          fullB = blue(full.pixels[loc]);

          emptyR = red(empty.pixels[loc]);
          emptyG = green(empty.pixels[loc]);
          emptyB = blue(empty.pixels[loc]);

          differenceR = abs(fullR - emptyR);                                     //take the abs. val of each difference
          differenceG = abs(fullG - emptyG);
          differenceB = abs(fullB - emptyB);
  
          totalDifference = differenceR + differenceG + differenceB;             //export a grayscale image, with the intensity value being the average difference of each of the RGB values
          outputBrightness = totalDifference / 3;
          outputBrightness = constrain(outputBrightness, 0, 255);

          output.pixels[loc] = color(outputBrightness);                           //load the pixels into the output array
          outputArray[loc] = output.pixels[loc];
        }
      }
    }
    catch (Exception e) {
      println("Could not load filter image: " + e );
    }
    return outputArray;
  }
  void display() {                                                  //not used, can display the result
    output.updatePixels();
    image(output, 0, 0);
  }
}