function [ timestamp_intervals ] = GetPupilVidTimestamps( vid_name )
%UNTITLED2 Summary of this function goes here
%   Detailed explanation goes here

vidObj = VideoReader(vid_name);

vidHeight = vidObj.Height;
vidWidth = vidObj.Width;
% Create a MATLAB® movie structure array, s.

s = struct('cdata',zeros(vidHeight,vidWidth,3,'uint8'),...
    'colormap',[]);

% Read one frame at a time using readFrame until the end of the file is reached. Append data from each video frame to the structure array.

k = 1;
while hasFrame(vidObj)
    s(k).cdata = readFrame(vidObj);
    k = k+1;
end

% collect timestamp values
for j = 1:numel(s)
    s(j).timestamp_bytes = s(j).cdata(1,1:4);
end

% convert uint8 to bits
for j = 1:numel(s)
    s(j).timestamp_bits = [];
    for k = 1:4
        if s(j).timestamp_bytes(k) == 0
            tmp = zeros(1,8);
            s(j).timestamp_bits = [s(j).timestamp_bits tmp];
        elseif  s(j).timestamp_bytes(k) == 1
            tmp = [zeros(1,7) 1];
            s(j).timestamp_bits = [s(j).timestamp_bits tmp];
        else
            tmp = d2b(double(s(j).timestamp_bytes(k)));
            tmp = padarray(tmp,[0,8-numel(tmp)],'pre');
            s(j).timestamp_bits = [s(j).timestamp_bits tmp];
        end
    end
end

% convert bits to second_count, cycle_count, and cycle_offset
for j = 1:numel(s)
    s(j).Second_count = b2d(s(j).timestamp_bits(1:7));
    s(j).Cycle_count = b2d(s(j).timestamp_bits(8:20));
    s(j).Cycle_offset = b2d(s(j).timestamp_bits(21:32));
end

% add seconds together due to repeats

SecondCycleRestart = find(diff([s.Second_count]) < 0) + 1;

Second_count_norepeats = [s.Second_count];
for i = 1:numel(SecondCycleRestart)
    Second_count_norepeats(SecondCycleRestart(i):end) = Second_count_norepeats(SecondCycleRestart(i):end)+128;
end

% determine timestamp intervals (maybe)

timestamp_intervals = diff(Second_count_norepeats'+[s.Cycle_count]'./8000);


end

