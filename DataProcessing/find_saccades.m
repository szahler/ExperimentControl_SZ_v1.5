function [ saccade ] = find_saccades(pupil_position, saccade_threshold)
%UNTITLED2 Summary of this function goes here
%   Detailed explanation goes here

velocity = [0; diff(pupil_position)];
velocityBool = abs(velocity)>2;
saccade = zeros(length(pupil_position),1);
for i = 11:length(velocityBool)-11
    if velocityBool(i) == 1 && ~any(saccade(i-6:i-1))
        sacAmp = nanmean(pupil_position(i+5:i+10))-nanmean(pupil_position(i-10:i-5));
        if abs(sacAmp)>saccade_threshold 
            saccade(i,1) = sacAmp;
        end
    end
end

end

