from sys import argv											#argument library

script, from_file, to_file, print_speed = argv					#require the input, output, and infill speeds (mm/sec) to start the program

speed = str(int(print_speed) * 60) + ".000"						#convert mm/sec to mm/min
print "Infill Speed: %s" %speed

lineCount = 0
firstPerimeter = True
perimeterStarted = False

with open(from_file) as input_file:								#open the input Gcode and save it to the input_file object
	inputLines = input_file.readlines()							#save each line of the input file as a separate string in the list inputLines

for i, line in enumerate(inputLines):							#go through each item(line) in the list
	if "; start perimeter" in line:								#Slic3r inserts this command at the start of each layer/perimeter
		# inputLines[i] = "M42 P11 S255\n"
		perimeterStarted = True									#tell the program that the printer is now making perimeter moves
		if firstPerimeter == True:								#the first perimeter command is always the skirt, don't record force data for it
			perimeterStarted = False
			firstPerimeter = False
		
	command = inputLines[i].split()								#split each line of the file into its individual space-separated commands
	for j, block in enumerate(command):							#go through each word in the line list
		if "F" + speed in block:								#if it finds an infill command:
			perimeterStarted = False							#tell the program that the printer is no longer printing perimeters
			command.insert(j + 1, "\nM42 P11 S0\n")				#insert the Mcode command that will notify the arduino of the change, which will in turn notify the processing sketch
			edited_command = " ".join(command)					#after inserting the command, recombine the line back into one string
			inputLines[i] = edited_command						#replace the old line with the new one
			
	if perimeterStarted == True:								#if it is still a perimeter (i.e. an infill command hasn't made perimeterStarted false),
		inputLines[i] += "G4 P1\n"								#add the short delay Mcode command to the string, to keep D4 on the RAMPS board high
			
	lineCount += 1												#increment the counter and move on to the next line the next time around the for loop
	
#for i, line in enumerate(inputLines):
	#inputLines[i] += "G4 P1\n"
	
with open(to_file, 'w') as output_file:							#output the modified commands to a new output file
	output_file.writelines(inputLines)