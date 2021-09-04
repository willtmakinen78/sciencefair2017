# Science Fair 2017
Listed in this repository are some of the files used for the development of my Junior year science fair project, in which I characterized the an FDM 3D printing process in real time.

This project was an extension of the work started the previous summer at the NASA Langely Research Center with Dr. Godfrey Sauti. The goal was to add sensors to an FDM 3D printer to detect errors in real time, allowing the print to either be stopped or correcting for them and continuing the print. More details can be seen in the `Poster.pdf` file, however a brief rundown of each sensor/error detection system is provided below:

### Load Cell: Layer Adhesion
The entire print bed was mounted on top of a load cell. This measuered changes in force upon the print bed to be measured each layer, allowing for layer adhesion errors to be detected. This is because as the print layers peeled up (either from the bed or in the middle of the part), the would push against the print head as it passed over them, resulting in a spike in force. If this happened too many layers in a row, the print head and print bed temperatures would be increased in order to promote better adhesion and remedy the problem.

### Camera: General Print Errors
This detection method was geared towards industrial applications, in which many copies of an object might be printed at once. First, a calibration print would be run, where care would be taken to ensure optimal printing. During this print, a camera would take pictures every few layers, and stored as reference images. Then, when the subsequent "production" prints were run, pictured would be taken at identical points during the prints and compared to the reference pictures (all other aspects of the pictures, such as the background, lighting, etc. would remain constant). After performing some pixel math, the number of different pixels was calculated. If the number of different pixels reached a predefined threshold, the print was declared a failure and the user notified.

This portion of the project resulted in a Patent, No. 11,084,091. A PDF of it is visible in the file `Patent.pdf`.

### Laser + Photoresistors: 
This system was designed to detect print peeling as well. After each layer, a laser pointer connected to the extruder would scan across the entire x-axis pointing at an array of photoresistors. It was situated at a height such that any layer peeling or print artifacts, due to bad bed adhesion, improper print temperature, etc. would block the laser pointer, resulting in a change in resistance across the photoresistors. Again, if this change occurred too many times in a row, an error was declared and a notification sent to the user.

## System Overview
Aside from the sensors themselves, the error detection system consisted of 3 main components: a host computer running a java program, an arduino reading all of the sensors, and the printer itself. The java program served as the host. It was responsible for sending gcode commands to the printer, including special ones when a picture or, loadcell reading, or laser pointer scan needed to be taken. It also proceessed the camera and sensor inputs and determined if the print was failed or not, attempting to remedy it or communicating with the web interface to notify the user. The arduino interfaced directly with the sensor and 3d printer hardware, sending preprocesed inputs to the host computer, while the printer did the actual printing and movement. This description can be seen in more detail in the `flow` folder.
