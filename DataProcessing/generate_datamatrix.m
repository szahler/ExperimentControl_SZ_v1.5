%% Select folder to process
clear all;
addpath(genpath('C:\Users\Evan\Google Drive\Feinberg\Code\Utilities'))
addpath(genpath('C:\Users\Evan\Google Drive\Feinberg\Code\ExperimentControl\ExperimentControl_v1.0\DataProcessing'))

% process_this_folder = 'Z:\TwoPhoton\20190306';
process_this_folder = 'Z:\Behavior\WhiskerPuff';

%% Generate list of experiments
OVERWRITE_DATAMATRIX = 1; % Keep previous datamatrix files == 0, reprocess previous datamatrix files == 1
all_files = subdir(process_this_folder);
sessions = IdentifySessionBehaviorFiles(all_files, OVERWRITE_DATAMATRIX);

%% GENERATE DATAMATRIX: Iterate through experiments and merge 2P, pupil, and behavior data

% for SESSION = 1:numel(sessions)
for SESSION = 1
    
    fprintf('\nProcessing experiment %d of %d\n\n', SESSION, numel(sessions));
    
    % Check which data types were acquired
    if any(contains({all_files.name}, '.signals') & contains({all_files.name}, sessions(SESSION).fname))
        twophoton_acquired = 1;
    else
        twophoton_acquired = 0;
    end
        
    if any(contains({all_files.name}, '_pupil') & contains({all_files.name}, sessions(SESSION).fname) & contains({all_files.name}, '.csv'))
        pupil_acquired = 1;
    else
        pupil_acquired = 0;
    end
    
    % Load behavior file
    load(fullfile(sessions(SESSION).folder, [sessions(SESSION).fname '_behavior']))
    
    % collect experiment metadata and parameters
    dm.experiment.filename = config.experiment.session_name;
    dm.experiment.animal = config.experiment.mouse_id;
    dm.experiment.date = config.experiment.date;
    dm.experiment.session = config.experiment.session;
    try
        dm.experiment.version = config.experiment.version;
    catch
        dm.experiment.version = '1.0';
    end
    dm.experiment.function = config.experiment.name;
    dm.experiment.parameters = experiment.ui;
    dm.experiment.twophoton_acquired = twophoton_acquired;
    dm.experiment.pupil_acquired = pupil_acquired;
    
    % get nidaq traces
    nidaq.traces.camera_strobe = nidaq.data(2,:);
    nidaq.traces.twophoton_strobe = nidaq.data(3,:);
    nidaq.traces.encoder_strobe = nidaq.data(4,:);
    nidaq.traces.trial = nidaq.data(5,:);
    nidaq.traces.led = nidaq.data(6,:);
    nidaq.traces.airpuff = nidaq.data(7,:);
    
    % identify nidaq events
    nidaq.events.camera_strobe = idUniqueAboveThr(nidaq.data(2,:), 2)';
    nidaq.events.twophoton_strobe = idUniqueAboveThr(nidaq.data(3,:), 2)';
    nidaq.events.encoder_strobe = idUniqueAboveThr(nidaq.data(4,:), 2)';
    nidaq.events.encoder_strobe = nidaq.events.encoder_strobe(nidaq.events.encoder_strobe>3000);
    nidaq.events.trial = idUniqueAboveThr(nidaq.data(5,:), 2)';
    nidaq.events.led = idUniqueAboveThr(nidaq.data(6,:), 2)';
    nidaq.events.airpuff = idUniqueAboveThr(nidaq.data(7,:), 2)';
    
    % make time tseries
    num_frames = numel(nidaq.events.encoder_strobe);
    dm.tseries.time = (0:0.02:(num_frames-1)*0.02)';
    
    % make wheel encoder tseries
    dm.tseries.wheel_encoder = encoder;
    
    % ============================
    % TWO-PHOTON =================
    % ============================
    % if twophoton data is present, assmble the segment and time series
    if twophoton_acquired

        % identify motion correction suffix
        [~,signal_fname] = fileparts(all_files(contains({all_files.name}, '.signals') & contains({all_files.name}, dm.experiment.filename)).name);
        if numel(strsplit(signal_fname, '_')) == 4
            tmp = strsplit(signal_fname, '_');
            mc_type = tmp{end};
        else
            mc_type = '';
        end
        
        % load twophoton files
        twop_fname = fullfile(sessions(SESSION).folder, sprintf('%s_%s', sessions(SESSION).fname, mc_type));
        dm.segment.mean = imread([twop_fname '_average'], 'png');
        load([twop_fname '.segment'], '-mat')
        load([twop_fname '.signals'], '-mat')
        
        % REMOVE BLANK ROIS
        orig_sig = sig;
        orig_np = np;
        orig_mask = mask;
        orig_np_mask = np_mask;
        
        % identify blank traces and eliminate them
        bad_rois = find(isnan(sig(1,:)));
        if ~isempty(bad_rois)
            for i = numel(bad_rois):-1:1
                sig(:,bad_rois(i)) = [];
                np(:,bad_rois(i)) = [];
                mask(ismember(mask(:), bad_rois(i)+1:max(mask(:)))) = mask(ismember(mask(:), bad_rois(i)+1:max(mask(:))))-1;
                np_mask(bad_rois(i), :) = [];
                vert(bad_rois(i)) = [];
            end
        end
        
        dm.segment.mask = mask;
        dm.segment.np_mask = np_mask(:,1);
        dm.segment.centroids = FindMaskCentroids(dm.segment.mask);
        
        % align twophoton strobes to wheel encoder strobes
        twop_frames = NaN(size(nidaq.events.twophoton_strobe));
        
        for i = 1:numel(nidaq.events.twophoton_strobe)
            [~, closest_frame] = min(abs(nidaq.events.encoder_strobe - nidaq.events.twophoton_strobe(i)));
            twop_frames(i) = closest_frame;
        end
        twop_frames = twop_frames(nidaq.events.encoder_strobe(end) > nidaq.events.twophoton_strobe);

        % check whether twophoton_strobe is longer or shorter than the traces
        if numel(twop_frames) > size(sig,1)
            twop_frames = twop_frames(1:size(sig,1)); % this is necessary because scanbox sometimes generates several extra strobes at the end
        end
        
        % create twophoton tseries
        dm.tseries.twophoton_raw = NaN(numel(dm.tseries.wheel_encoder), size(sig, 2));
        dm.tseries.twophoton_raw(twop_frames, :) = sig(1:numel(twop_frames), :);
        dm.tseries.twophoton_raw = fillmissing(dm.tseries.twophoton_raw, 'linear', 1);
        dm.tseries.twophoton_raw(1:twop_frames(1),:) = NaN;
        
        dm.tseries.twophoton_np = NaN(numel(dm.tseries.wheel_encoder), size(sig, 2));
        dm.tseries.twophoton_np(twop_frames, :) = np(1:numel(twop_frames), :);
        dm.tseries.twophoton_np = fillmissing(dm.tseries.twophoton_np, 'linear', 1);
        dm.tseries.twophoton_np(1:twop_frames(1),:) = NaN;
        
        % ============================
        % TODO =======================
        % ============================
        % corrected_trace: twophoton_raw - twophoton_np * subCoef;
        % baseline: baseline was the eighth percentile spanning 500 frames
        % (~ 30 s) around each frame (Harvey)
        % dm.tseries.twophoton_dff (corrected_trace - corrected_trace_baseline)/uncorrected_baseline
        
        % tmp dff
        dm.tseries.twophoton_dff = NaN(numel(dm.tseries.wheel_encoder), size(sig, 2));
        for ROI = 1:size(dm.tseries.twophoton_dff, 2)
            
            trace = dm.tseries.twophoton_raw(:,ROI);
            
            prctile = 10;
            winSize = 15*15.5;
            
%             trace_baseline = runningPrctile(trace, round(winSize), prctile);
            [~, trace_baseline] = HighpassFilter(trace, 30, 15.5);
            dm.tseries.twophoton_dff(:,ROI) = (trace - trace_baseline)./trace_baseline;
        end
        
        
    end
    
    % ============================
    % PUPIL ======================
    % ============================
    % if pupil data is present, assmble pupil time series
    if pupil_acquired
        % load pupil data
        pupil_csv = all_files(find(contains({all_files.name}, sessions(SESSION).fname) & contains({all_files.name}, '_pupil') & endsWith({all_files.name}, '.csv'))).name;
        if contains({all_files.name}, 'PupilMar27')
            pupil_data_original = importPupilCSV_PupilMar27(pupil_csv);
            pupil_data_original = pupil_data_original(:,[13:18, 7:12, 19:24, 1:6]);
            pupil_data = table2array(pupil_data_original);
        elseif contains({all_files.name}, 'DT_PupilTrack_20190112')
            pupil_data_original = importPupilCSV_v2(pupil_csv);
            pupil_data = table2array(pupil_data_original);
        end
        
        % create 
        dm.tseries.pupilx = (pupil_data(:,1)+pupil_data(:,4))./2 - (pupil_data(:,13)+pupil_data(:,16))./2;
        dm.tseries.pupily = (pupil_data(:,8)+pupil_data(:,11))./2 - (pupil_data(:,14)+pupil_data(:,17))./2;
        dm.tseries.pupild = pupil_data(:,11) - pupil_data(:,8);
        dm.tseries.eyelid_gap = pupil_data(:,23) - pupil_data(:,20);
        
        % identify when eyelids close and label as bad frames
%         eyelid_below_threshold = find(dm.tseries.eyelid_gap < 80);
        
        eyelid_below_threshold = find(pupil_data(:,3)<0.1 | pupil_data(:,6)<0.1);
        dm.tseries.badframes = zeros(size(dm.tseries.time));
        try
        for i = 1:numel(eyelid_below_threshold)
            dm.tseries.badframes(eyelid_below_threshold(i)-4:eyelid_below_threshold(i)+4) = 1;
        end
        catch
        end
        
        % identify "blips" (i.e. frames where pupilx jumps for 1-2 frames)
        dm.tseries.blips = IdentifyBlips(dm.tseries.pupilx, 2, 2, 3);
        dm.tseries.pupilx(find(dm.tseries.blips)) = NaN;
        dm.tseries.pupilx = fillmissing(dm.tseries.pupilx, 'linear');
        
        % Flip pupilx if a hot mirror was used to collect pupil video
        try % try/catch needed for the first few experiments (20190307-20190315) that didn't record that metadata
            dm.experiment.pupil_hotmirror = config.experiment.pupil_hotmirror;
            if dm.experiment.pupil_hotmirror == 1
                dm.tseries.pupilx = dm.tseries.pupilx * -1;
            end
        catch
            dm.experiment.pupil_hotmirror = 1;
            dm.tseries.pupilx = dm.tseries.pupilx * -1;
        end
        
        % Detect saccades
        saccade_threshold = 3;
        saccades_firstpass = find(abs(diff(dm.tseries.pupilx)) >= saccade_threshold);
        saccades_secondpass = saccades_firstpass(~ismember([0; diff(saccades_firstpass)], 1:3));
        dm.events.saccades = saccades_secondpass;
        dm.events.saccades = dm.events.saccades(~ismember(dm.events.saccades, find(dm.tseries.badframes))); % remove saccades within bad frames

        % Determine saccade startpoint and endpoint
        dm.events.saccades_start = NaN(size(dm.events.saccades));
        dm.events.saccades_end = NaN(size(dm.events.saccades));
        dm.events.saccades_amp = NaN(size(dm.events.saccades));

        for i = 1:numel(dm.events.saccades)

            if dm.events.saccades(i)-3 > 0
                dm.events.saccades_start(i) = mean(dm.tseries.pupilx(dm.events.saccades(i)-3:dm.events.saccades(i)-1));
            else
                dm.events.saccades_start(i) = mean(dm.tseries.pupilx(1:dm.events.saccades(i)-1));
            end

            if numel(dm.tseries.pupilx) - dm.events.saccades(i) >= 4
                dm.events.saccades_end(i) = mean(dm.tseries.pupilx(dm.events.saccades(i)+3:dm.events.saccades(i)+4));
            else
                dm.events.saccades_end(i) = mean(dm.tseries.pupilx(dm.events.saccades(i)+3:dm.events.saccades(i)+(numel(dm.tseries.pupilx) - dm.events.saccades(i))));
            end
            dm.events.saccades_amp(i) = dm.events.saccades_end(i) - dm.events.saccades_start(i);
        end
        
        
        figure
        plot(dm.tseries.pupilx); hold on
        for i = 1:numel(dm.events.saccades)
            if dm.events.saccades_amp(i) > 0
                plot([dm.events.saccades(i) dm.events.saccades(i)], [dm.events.saccades_start(i) dm.events.saccades_start(i) + dm.events.saccades_amp(i)], 'r:', 'LineWidth', 1.5)
            else
                plot([dm.events.saccades(i) dm.events.saccades(i)], [dm.events.saccades_start(i) dm.events.saccades_start(i) + dm.events.saccades_amp(i)], 'g:', 'LineWidth', 1.5)
            end
        end
        
        
    end
    
    % ============================
    % BEHAVIOR/STIMULUS ==========
    % ============================
    % trial tseries
    trial_frames = NaN(size(nidaq.events.trial));
    for i = 1:numel(nidaq.events.trial)
        [~, closest_frame] = min(abs(nidaq.events.encoder_strobe - nidaq.events.trial(i)));
        trial_frames(i) = closest_frame;
    end
    dm.tseries.trial = zeros(numel(dm.tseries.wheel_encoder), 1);
    dm.tseries.trial(trial_frames, :) = 1;
    
    % leftpuff
    leftpuff_frames = NaN(size(nidaq.events.airpuff));
    for i = 1:numel(nidaq.events.trial)
        [~, closest_frame] = min(abs(nidaq.events.encoder_strobe - nidaq.events.airpuff(i)));
        leftpuff_frames(i) = closest_frame;
    end
    
    if numel(nidaq.events.trial) == numel(experiment.trials.trial)
        dm.tseries.leftpuff = zeros(numel(dm.tseries.wheel_encoder), 1);
        dm.tseries.leftpuff(leftpuff_frames(experiment.trials.airpuff_left), :) = 1;
    else  % in v1.0 if you cancel an experiment it records the planned trials rather than the ones that were actually executed
        dm.tseries.leftpuff = zeros(numel(dm.tseries.wheel_encoder), 1);
        dm.tseries.leftpuff(leftpuff_frames(experiment.trials.airpuff_left(1:numel(nidaq.events.trial))), :) = 1;
    end
    
    % rightpuff
    rightpuff_frames = NaN(size(nidaq.events.airpuff));
    for i = 1:numel(nidaq.events.trial)
        [~, closest_frame] = min(abs(nidaq.events.encoder_strobe - nidaq.events.airpuff(i)));
        rightpuff_frames(i) = closest_frame;
    end
    
    if numel(nidaq.events.trial) == numel(experiment.trials.trial)
        dm.tseries.rightpuff = zeros(numel(dm.tseries.wheel_encoder), 1);
        dm.tseries.rightpuff(rightpuff_frames(experiment.trials.airpuff_right), :) = 1;
    else  % in v1.0 if you cancel an experiment it records the planned trials rather than the ones that were actually executed
        dm.tseries.rightpuff = zeros(numel(dm.tseries.wheel_encoder), 1);
        dm.tseries.rightpuff(rightpuff_frames(experiment.trials.airpuff_right(1:numel(nidaq.events.trial))), :) = 1;
    end
    
    % led tseries
    led_frames = NaN(size(nidaq.events.led));
    for i = 1:numel(nidaq.events.led)
        [~, closest_frame] = min(abs(nidaq.events.encoder_strobe - nidaq.events.led(i)));
        led_frames(i) = closest_frame;
    end
    dm.tseries.led = zeros(numel(dm.tseries.wheel_encoder), 1);
    dm.tseries.led(led_frames, :) = 1;
    
    % ============================
    % Create events
    % ============================
	dm.events.trial = find(dm.tseries.trial);
    dm.events.leftpuff = find(dm.tseries.leftpuff);
    dm.events.rightpuff = find(dm.tseries.rightpuff);
    dm.events.led = find(dm.tseries.led);
    
    % ============================
    % TODO =======================
    % ============================
%     if pupil_acquired
%         dm.events.saccade
%     end
    
    switch dm.experiment.function
        case {'ArrayDriftingBar'}
            dm.led.titles = {'up', 'right', 'down', 'left', 'blank'};
            dm.led.ids = 1:5;
            dm.led.order = reshape(experiment.trials.led_drift, numel(experiment.trials.led_drift), 1);
        case {'AirpuffBlocks'}
        otherwise
            disp('Experiment function not recognized')
    end
        
    % Save file as filename.datamatrix
    
    metadata = dm.experiment;
    save(fullfile(sessions(SESSION).folder, [sessions(SESSION).fname '_datamatrix']), 'dm', 'metadata');
    
end

fprintf('\nDone processing!\n');


