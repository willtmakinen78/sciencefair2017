from sys import argv
from random import randint

script, from_file, to_file, frequency = argv

lineCount = 0

beforeLayerList = []
afterLayerList = []

with open(from_file) as input_file:
	inputLines = input_file.readlines()

for i, line in enumerate(inputLines):
	if "; layer change" in line:
		beforeLayerList.append(lineCount)
		
	if "; after layer change" in line:
		afterLayerList.append(lineCount)
	lineCount += 1
	
counter = 1
for i in range(len(beforeLayerList)):	
	if (counter % int(frequency) == 0):
		inputLines[beforeLayerList[i] + 1] += "G1 Y%d G1 X250\nG1 X287\nG92 E0\nG1 E5 F2400\nG1 Z295\nG4 P750\n" % randint(303, 307)
	counter += 1
	
counter = 1
for i in range(len(afterLayerList)):	
	if (counter % int(frequency) == 0):
		inputLines[afterLayerList[i]] += "G1 X250\n"
	counter += 1

with open(to_file, 'w') as output_file:
	output_file.writelines(inputLines)
	
print "Done"