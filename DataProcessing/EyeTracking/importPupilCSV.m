function PupilData = importPupilCSV(filename, startRow, endRow)
%IMPORTFILE Import numeric data from a text file as a matrix.

% Works with pupil data generated by DT_PupilTrack_20190112

%   PupilData =
%   IMPORTFILE(FILENAME) Reads data from text file FILENAME for the default
%   selection.
%
%   PupilData =
%   IMPORTFILE(FILENAME, STARTROW, ENDROW) Reads data from rows STARTROW
%   through ENDROW of text file FILENAME.
%
% Example:
%   PupilData = importfile('DT134_20190112_000_2019-01-12-105315-0000DeepCut_resnet50_DT_PupilTrack_2019011220190112shuffle1_1030000.csv', 4, 11552);
%
%    See also TEXTSCAN.

% Auto-generated by MATLAB on 2019/01/15 13:31:37

%% Initialize variables.
delimiter = ',';
if nargin<=2
    startRow = 4;
    endRow = inf;
end

%% Format for each line of text:
%   column1: double (%f)
%	column2: double (%f)
%   column3: double (%f)
%	column4: double (%f)
%   column5: double (%f)
%	column6: double (%f)
%   column7: double (%f)
%	column8: double (%f)
%   column9: double (%f)
%	column10: double (%f)
%   column11: double (%f)
%	column12: double (%f)
%   column13: double (%f)
%	column14: double (%f)
%   column15: double (%f)
%	column16: double (%f)
%   column17: double (%f)
%	column18: double (%f)
%   column19: double (%f)
%	column20: double (%f)
%   column21: double (%f)
%	column22: double (%f)
%   column23: double (%f)
%	column24: double (%f)
%   column25: double (%f)
% For more information, see the TEXTSCAN documentation.
formatSpec = '%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%[^\n\r]';

%% Open the text file.
fileID = fopen(filename,'r');

%% Read columns of data according to the format.
% This call is based on the structure of the file used to generate this
% code. If an error occurs for a different file, try regenerating the code
% from the Import Tool.
dataArray = textscan(fileID, formatSpec, endRow(1)-startRow(1)+1, 'Delimiter', delimiter, 'TextType', 'string', 'EmptyValue', NaN, 'HeaderLines', startRow(1)-1, 'ReturnOnError', false, 'EndOfLine', '\r\n');
for block=2:length(startRow)
    frewind(fileID);
    dataArrayBlock = textscan(fileID, formatSpec, endRow(block)-startRow(block)+1, 'Delimiter', delimiter, 'TextType', 'string', 'EmptyValue', NaN, 'HeaderLines', startRow(block)-1, 'ReturnOnError', false, 'EndOfLine', '\r\n');
    for col=1:length(dataArray)
        dataArray{col} = [dataArray{col};dataArrayBlock{col}];
    end
end

%% Close the text file.
fclose(fileID);

%% Remove unnecessary columns
dataArray2 = dataArray(:,[2 3 5 6 8 9 11 12 14 15 17 18 20 21 23 24]);

%% Create output variable
PupilData = table(dataArray2{1:end}, 'VariableNames', {'Pupil_Left_X','Pupil_Left_Y','Pupil_Right_X','Pupil_Right_Y','Pupil_Top_X','Pupil_Top_Y','Pupil_Bottom_X','Pupil_Bottom_Y','Reflection_Left_X','Reflection_Left_Y','Reflection_Right_X','Reflection_Right_Y','Eyelid_Top_X','Eyelid_Top_Y','Eyelid_Bottom_X','Eyelid_Bottom_Y'});

% save([filename(1:19) '.pupil'], PupilData)

