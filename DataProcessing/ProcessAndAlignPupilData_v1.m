function [ dm ] = ProcessAndAlignPupilData_v1( syncData, pupilData_original, traces_dombeck_dff )
% INPUTS
% syncData
% pupilData_original
% 

% find starts
if syncData.camera_strobe(1) == 1
    strobe_starts_all = find(circshift(diff(~syncData.camera_strobe), 1) == 1); % flip strobe upside down
else
    strobe_starts_all = find(circshift(diff(syncData.camera_strobe), 1) == 1); % 
end
puff_starts = find(circshift(diff(syncData.puff), 1) == 1);
trial_starts = find(circshift(diff(syncData.trials), 1) == 1);
twophoton_starts = find(circshift(diff(syncData.twophoton_strobe), 1) == 1, size(traces_dombeck_dff, 1));

% deal with strobe irregularities (the first strobe is blank, second two
% are very close together)
if numel(strobe_starts_all) == size(pupilData_original,1)
    disp('strobe matches frames: using third pupil frame and third strobe')
    strobe_starts = strobe_starts_all(3:end);
    pupilData = table2array(pupilData_original(3:end,:)); % starts at first normal frame (frames 1 and 2 have irregular exposures)
else
    disp('more vid than strobes')
    strobe_starts = strobe_starts_all(3:end);
    pupilData = table2array(pupilData_original(3:numel(strobe_starts)+2,:)); % starts at first normal frame (frames 1 and 2 have irregular exposures)
end

% Calculate pupil metrics
bad_pupil_frames = find(pupilData(:,16)-pupilData(:,14) < 140);
for i = 1:numel(bad_pupil_frames)
    pupilData(bad_pupil_frames(i)-3:bad_pupil_frames(i)+3, :) = NaN;
end

pupilx = (pupilData(:,1)+pupilData(:,3))./2 - (pupilData(:,9)+pupilData(:,11))./2;
pupily = (pupilData(:,2)+pupilData(:,4))./2 - (pupilData(:,10)+pupilData(:,12))./2;
pupildiameter = ((pupilData(:,3) - pupilData(:,1)) + (pupilData(:,4) - pupilData(:,2)))./2;
pupilx = pupilx * -1; % invert because imaging using hot mirror

% Calculate camera frame interval
pupil_frame_interval = round(mean(diff(syncData.micros(strobe_starts)./1000)));

% align puff
puff_closest_frames = zeros(size(puff_starts));
for i = 1:numel(puff_starts)
    [~, closest_frame] = min(abs(strobe_starts - puff_starts(i)));
    puff_closest_frames(i) = closest_frame;
end

% align trials
trial_closest_frames = zeros(size(trial_starts));
for i = 1:numel(trial_starts)
    [~, closest_frame] = min(abs(strobe_starts - trial_starts(i)));
    trial_closest_frames(i) = closest_frame;
end

% align twophoton
twophoton_closest_frames = zeros(size(twophoton_starts));
for i = 1:numel(twophoton_starts)
    [~, closest_frame] = min(abs(strobe_starts - twophoton_starts(i)));
    twophoton_closest_frames(i) = closest_frame;
end

%because there are more twophoton frames than camera strobes
twophoton_closest_frames_cropped = twophoton_closest_frames(find(twophoton_closest_frames==1, 1, 'last'):find(twophoton_closest_frames==max(twophoton_closest_frames), 1, 'first'));

% Construct datamatrix (dm)
dm.time = (0:pupil_frame_interval:pupil_frame_interval*numel(strobe_starts)-pupil_frame_interval)';
dm.twophoton = NaN(numel(strobe_starts), size(traces_dombeck_dff, 2));
dm.twophoton(twophoton_closest_frames_cropped, :) = traces_dombeck_dff(find(twophoton_closest_frames==1, 1, 'last'):find(twophoton_closest_frames==max(twophoton_closest_frames), 1, 'first'), :);
dm.twophoton = fillmissing(dm.twophoton, 'linear', 1);
dm.pupilx = pupilx;
dm.pupily = pupily;
dm.pupildiameter = pupildiameter;
dm.trials = trial_closest_frames;

%% Detect saccades

saccade_threshold = 3;
saccades_firstpass = find(abs(diff(dm.pupilx)) >= saccade_threshold);
saccades_secondpass = saccades_firstpass(~ismember([0; diff(saccades_firstpass)], 1:3));
dm.saccades = saccades_secondpass;

%% Determine saccade startpoint and endpoint
dm.saccades_start = NaN(size(dm.saccades));
dm.saccades_end = NaN(size(dm.saccades));
dm.saccades_amp = NaN(size(dm.saccades));

for i = 1:numel(dm.saccades)
    dm.saccades_start(i) = mean(dm.pupilx(dm.saccades(i)-3:dm.saccades(i)-1));
    dm.saccades_end(i) = mean(dm.pupilx(dm.saccades(i)+3:dm.saccades(i)+6));
    dm.saccades_amp(i) = dm.saccades_end(i) - dm.saccades_start(i);
end



end

