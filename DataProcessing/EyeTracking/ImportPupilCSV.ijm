file = File.openDialog("Select the text file to read"); 
allText = File.openAsString(file); 
text = split(allText, "\n"); 
hdr = split(text[0], ","); 

setSlice(1);

//these are the column indices 
iX = 1; 
iY = 2; 
iSlice = 3; 

for (i = 1; i < (text.length); i++){ 
    line = split(text[i], ","); 
    setSlice(parseInt(line[iSlice]));
 	makePoint(parseInt(line[iX]), parseInt(line[iY])); 
    roiManager("Add"); 
} 

//(text.length)