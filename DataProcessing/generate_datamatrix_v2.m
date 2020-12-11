%% Select folder to process
clear all;
addpath(genpath('C:\Users\Evan\Google Drive\Feinberg\Code\Utilities'))
addpath(genpath('C:\Users\Evan\Google Drive\Feinberg\Code\ExperimentControl\ExperimentControl_v1.1\DataProcessing'))

process_this_folder = 'Z:\Behavior\WhiskerPuff';

%% Generate list of experiments
OVERWRITE_DATAMATRIX = 0; % Keep previous datamatrix files == 0, reprocess previous datamatrix files == 1
all_files = subdir(process_this_folder);
sessions = IdentifySessionBehaviorFiles(all_files, OVERWRITE_DATAMATRIX);

%% GENERATE DATAMATRIX: Iterate through experiments and merge 2P, pupil, and behavior data

for SESSION = 1:numel(sessions)
%     for SESSION = 8
    
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
        if contains(pupil_csv, 'PupilMar27')
            pupil_data_original = importPupilCSV_PupilMar27(pupil_csv);
            pupil_data_original = pupil_data_original(:,[13:18, 7:12, 19:24, 1:6]);
            pupil_data = table2array(pupil_data_original);
        elseif contains(pupil_csv, 'PupilMay21')
            pupil_data_original = importPupilCSV_PupilMar27(pupil_csv);
            pupil_data_original = pupil_data_original(:,[13:18, 7:12, 19:24, 1:6]);
            pupil_data = table2array(pupil_data_original);
        elseif contains(pupil_csv, 'DT_PupilTrack_20190112')
            pupil_data_original = importPupilCSV_v2(pupil_csv);
            pupil_data = table2array(pupil_data_original);
        end
        
        if numel(nidaq.events.camera_strobe) < size(pupil_data,1)
            fprintf('%s: camera strobes (%d) LESS than frames (%d)\n\n', sessions(SESSION).fname, numel(nidaq.events.camera_strobe), size(pupil_data,1));
            skip_pupil = 1;
        elseif numel(nidaq.events.camera_strobe) > size(pupil_data,1)
            fprintf('%s: camera strobes (%d) GREATER than frames (%d)\n\n', sessions(SESSION).fname, numel(nidaq.events.camera_strobe), size(pupil_data,1));
            skip_pupil = 1;
        else
            skip_pupil = 0;
        end
        
        if skip_pupil == 0
            if numel(nidaq.events.encoder_strobe) > size(pupil_data,1)
                fprintf('%s has %d fewer pupil frames than encoder strobes\n\n', sessions(SESSION).fname, numel(nidaq.events.encoder_strobe)-size(pupil_data,1));
                pupil_data_tmp = NaN(numel(nidaq.events.encoder_strobe), size(pupil_data,2));
                missing_camera_frames = ~ismembertol(nidaq.events.encoder_strobe,nidaq.events.camera_strobe, 10, 'DataScale', 1);
                pupil_data_tmp(~missing_camera_frames,:) = pupil_data;
                pupil_data = pupil_data_tmp;
                pupil_data = fillmissing(pupil_data,'linear',1);
            end
            if numel(nidaq.events.encoder_strobe) < size(pupil_data,1)
                fprintf('%s has more pupil frames than encoder strobes\n\n', sessions(SESSION).fname);
            end
            
            % create pupil tseries
            pupilx = (pupil_data(:,1)+pupil_data(:,4))./2 - (pupil_data(:,13)+pupil_data(:,16))./2;
            pupily = (pupil_data(:,8)+pupil_data(:,11))./2 - (pupil_data(:,14)+pupil_data(:,17))./2;
            pupild = pupil_data(:,11) - pupil_data(:,8);
            eyelid_gap = pupil_data(:,23) - pupil_data(:,20);
            
            dm.tseries.pupilx = pupilx(1:numel(dm.tseries.time));
            dm.tseries.pupily = pupily(1:numel(dm.tseries.time));
            dm.tseries.pupild = pupild(1:numel(dm.tseries.time));
            dm.tseries.eyelid_gap = eyelid_gap(1:numel(dm.tseries.time));
            
            % identify bad frames (Pupil_Left, Pupil_Right, Reflection_Left, or Reflection_Right have likelihood below threshold, e.g. 0.2)
            badframes = sum(pupil_data(:,[3 6 15 18])<0.2, 2)>0;
            dm.tseries.badframes = badframes(1:numel(dm.tseries.time));
            try
                for i = 1:numel(find(dm.tseries.badframes))
                    dm.tseries.badframes(badframes(i)-4:badframes(i)+4) = 1;
                end
            catch
            end
            
            % identify "blips" (i.e. frames where pupilx jumps for 1-2 frames)
            %         dm.tseries.blips = IdentifyBlips(dm.tseries.pupilx, 2, 2, 3);
            %         dm.tseries.pupilx(find(dm.tseries.blips)) = NaN;
            %         dm.tseries.pupilx = fillmissing(dm.tseries.pupilx, 'linear');
            
            % Flip pupilx if the video was captured on a mirror without camera correction (only applies to a few videos
            if contains(pupil_csv, strsplit(num2str(20190307:20190315), ' '))
                dm.tseries.pupilx = dm.tseries.pupilx * -1;
            end
            
            % Detect saccades
%             saccade_threshold = 4;
%             saccades_firstpass = find(abs(diff(dm.tseries.pupilx)) >= saccade_threshold);
%             saccades_secondpass = saccades_firstpass(~ismember([0; diff(saccades_firstpass)], 1:3));
            
            saccade_threshold = 3;
            saccade_threshold2 = 4;
            saccades_firstpass = find(abs(diff(dm.tseries.pupilx)) >= saccade_threshold);
            saccades_secondpass = saccades_firstpass(~ismember([0; diff(saccades_firstpass)], 1:3));
            saccades_secondpass(saccades_secondpass<100 | saccades_secondpass>numel(dm.tseries.pupilx)-100) = [];
            saccades_thirdpass = saccades_secondpass;
            for i = 1:numel(saccades_secondpass)
                if abs(mean(dm.tseries.pupilx(saccades_secondpass(i)-3:saccades_secondpass(i)-1))-mean(dm.tseries.pupilx(saccades_secondpass(i)+3:saccades_secondpass(i)+5))) < saccade_threshold2
                    saccades_thirdpass(i) = NaN;
                end
            end
            saccades_thirdpass(isnan(saccades_thirdpass)) = [];
            
            
            dm.events.saccades = saccades_thirdpass;
%             dm.events.saccades = saccades_secondpass;
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
            scatter(find(dm.tseries.badframes), ones(size(find(dm.tseries.badframes))), 'kx')
            title(sprintf('%s: saccade detection', sessions(SESSION).fname))
            
            dm.tseries.saccades = NaN(size(dm.tseries.pupilx));
            dm.tseries.saccades(dm.events.saccades) = dm.events.saccades_amp;
            
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
    
    % DEBUG INFORMATION
    dm.debug.filename = dm.experiment.filename;
    dm.debug.encoderstrobe = numel(nidaq.events.encoder_strobe);
    dm.debug.camerastrobe = numel(nidaq.events.camera_strobe);
    dm.debug.frames = size(pupil_data_original,1);
    missing_camera_frames = ~ismembertol(nidaq.events.encoder_strobe,nidaq.events.camera_strobe, 10, 'DataScale', 1);
    dm.debug.missingstrobes = sprintf('%d,', find(missing_camera_frames));
    
    % Save file as filename.datamatrix
    metadata = dm.experiment;
    debug = dm.debug;
    save(fullfile(sessions(SESSION).folder, [sessions(SESSION).fname '_datamatrix']), 'dm', 'metadata', 'debug');
    

    
end

fprintf('\nDone processing!\n');


%%
figure; hold on
plot(nidaq.traces.camera_strobe)
plot(nidaq.traces.encoder_strobe)
plot(nidaq.traces.airpuff)


