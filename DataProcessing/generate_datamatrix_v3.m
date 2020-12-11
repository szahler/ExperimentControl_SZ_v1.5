%% Select folder to process
clear all;
addpath(genpath('C:\Users\Evan\Google Drive\Feinberg\Code\Utilities'))
addpath(genpath('C:\Users\Evan\Documents\MATLAB\TDTMatlabSDK\TDTSDK'))
addpath(genpath('C:\Users\Evan\Google Drive\Feinberg\Code\ExperimentControl\ExperimentControl_v1.2\DataProcessing'))

process_this_folder = 'Z:\Behavior\WhiskerPuff';

%% Generate list of experiments
clear filter; filter.null = 1;
% filter.date = [20190727:20190802];
% filter.animal = {'DT190', 'DT191', 'DT192', 'DT193', 'DT194'};

OVERWRITE_DATAMATRIX = 0; % Keep previous datamatrix files == 0, reprocess previous datamatrix files == 1
all_files = subdir(process_this_folder);
sessions = IdentifySessionBehaviorFiles(all_files, OVERWRITE_DATAMATRIX, filter);

%% GENERATE DATAMATRIX: Iterate through experiments and merge 2P, pupil, and behavior data

for SESSION = 1:numel(sessions)
% for SESSION = 7
    clearvars -except SESSION process_this_folder OVERWRITE_DATAMATRIX all_files sessions filter
    % for SESSION = 1
    
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
    
    if any(contains({all_files.name}, '_photometry') & contains({all_files.name}, sessions(SESSION).fname))
        photometry_acquired = 1;
    else
        photometry_acquired = 0;
    end
    
    % Load behavior file
    load(fullfile(sessions(SESSION).folder, [sessions(SESSION).fname '_behavior']))
    
    % collect experiment metadata and parameters
    dm.experiment.filename = config.experiment.session_name;
    dm.experiment.animal = config.experiment.mouse_id;
    dm.experiment.date = config.experiment.date;
    dm.experiment.session = config.experiment.session;
    try
        dm.experiment.version = config.version;
    catch
        dm.experiment.version = '1.0';
    end
    dm.experiment.function = config.experiment.name;
    dm.experiment.parameters = experiment.ui;
    dm.experiment.twophoton_acquired = twophoton_acquired;
    dm.experiment.pupil_acquired = pupil_acquired;
    dm.experiment.photometry_acquired = photometry_acquired;
    
    % get nidaq traces
    nidaq.traces.camera_strobe = nidaq.data(2,:);
    nidaq.traces.twophoton_strobe = nidaq.data(3,:);
    nidaq.traces.encoder_strobe = nidaq.data(4,:);
    nidaq.traces.trial = nidaq.data(5,:);
    if strcmp(dm.experiment.function, 'AirpuffRandom_OptoRandom')
        nidaq.traces.trial = nidaq.data(7,:);
    end
    nidaq.traces.led = nidaq.data(6,:);
    nidaq.traces.airpuff = nidaq.data(7,:);
    nidaq.traces.opto = nidaq.data(8,:);
    
    % identify nidaq events
    nidaq.events.camera_strobe = idUniqueAboveThr(nidaq.traces.camera_strobe, 2)';
    nidaq.events.twophoton_strobe = idUniqueAboveThr(nidaq.traces.twophoton_strobe, 2)';
    nidaq.events.encoder_strobe = idUniqueAboveThr(nidaq.traces.encoder_strobe, 2)';
    nidaq.events.encoder_strobe = nidaq.events.encoder_strobe(nidaq.events.encoder_strobe>3000);
    nidaq.events.trial = idUniqueAboveThr(nidaq.traces.trial, 2)';
    nidaq.events.led = idUniqueAboveThr(nidaq.traces.led, 2)';
    nidaq.events.airpuff = idUniqueAboveThr(nidaq.traces.airpuff, 2)';
    nidaq.events.opto = idUniqueAboveThr(nidaq.traces.opto, 2)';
    
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
        elseif contains(pupil_csv, 'PupilJun22')
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
    % PHOTOMETRY ======================
    % ============================
    % if photometry data is present, assmble photometry time series
    if photometry_acquired
        %         % use pre-processed photometry signal
        %         photometry_block = fileparts(all_files(find(contains({all_files.name}, sessions(SESSION).fname) & contains({all_files.name}, '_photometry'),1)).name);
        %         photometry_data = TDTbin2mat(photometry_block);
        %         frameTime = photometry_data.epocs.Ep1_.onset;
        %         sig405 =  photometry_data.streams.x405G.data ;
        %         sig470 = photometry_data.streams.x470G.data ;
        %         reg = polyfit(sig405, sig470, 1);
        %         a = reg(1);
        %         b = reg(2);
        %         controlFit = a.*sig405 + b;
        %         df_photometry = (sig470 - controlFit)./ controlFit;
        %         photoTime = ([1:size(photometry_data.streams.x470G.data,2)] .* (1/photometry_data.streams.x470G.fs));
        
        % Use Chris Donahue code to process raw photometry data
        photometry_block = fileparts(all_files(find(contains({all_files.name}, sessions(SESSION).fname) & contains({all_files.name}, '_photometry'),1)).name);
        photometry_data = TDTbin2mat(photometry_block);
        if size(photometry_data.streams.Fi1r.data,1)==4
            rx = photometry_data.streams.Fi1r.data(3,:); % Raw Freq modulated signal
            Fs = photometry_data.streams.Fi1r.fs; % Sampling rate
            [photoTime,sig470,sig405] = spect_filter_v2(rx,Fs);
        elseif  size(photometry_data.streams.Fi1r.data,1)==6
            rx = photometry_data.streams.Fi1r.data(5,:); % Raw Freq modulated signal
            rx2 = photometry_data.streams.Fi1r.data(6,:);
            Fs = photometry_data.streams.Fi1r.fs; % Sampling rate
            [~,sig470(1,:),sig405(1,:)] = spect_filter_v2(rx,Fs);
            [photoTime,sig405(2,:),sig470(2,:)] = spect_filter_v2(rx2,Fs); %405 and 470 are switched for 2-channel
        end
        frameTime = photometry_data.epocs.Ep1_.onset;
        df_photometry = NaN(size(sig470,1), size(sig470,2));
        for channel = 1:size(sig470,1)
            reg = polyfit(sig405(channel,:), sig470(channel,:), 1);
            a = reg(1);
            b = reg(2);
            controlFit = a.*sig405(channel,:) + b;
            df_photometry(channel,:) = (sig470(channel,:) - controlFit)./ controlFit;
        end
        
        test_phototime = ([1:size(photometry_data.streams.x470G.data,2)] .* (1/photometry_data.streams.x470G.fs));
        disp(test_phototime(1:10))
        
        disp(photoTime(1:10))
        
        % Align photometry trace to camera
        photometryFrameIdx = zeros(size(frameTime, 1), 1);
        [~, photometryFrameIdx(1)] = min(abs(photoTime - frameTime(1)));
        [~, photometryFrameIdx(2)] = min(abs(photoTime - frameTime(2)));
        frame_separation = photometryFrameIdx(2) - photometryFrameIdx(1);
        for i = 3:numel(frameTime)
            shortPhotoTime = photoTime(photometryFrameIdx(i-1):photometryFrameIdx(i-1)+frame_separation*2);
            
            [~, tmp_idx] = min(abs(shortPhotoTime - frameTime(i)));
            photometryFrameIdx(i) = tmp_idx + photometryFrameIdx(i-1) - 1;
        end
        
        dm.tseries.photometry.sig405 = sig405(photometryFrameIdx);
        dm.tseries.photometry.sig470 = sig470(photometryFrameIdx);
        dm.tseries.photometry.df = df_photometry(photometryFrameIdx);
        
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
    
    % opto tseries
    opto_frames = NaN(size(nidaq.events.opto));
    for i = 1:numel(nidaq.events.opto)
        [~, closest_frame] = min(abs(nidaq.events.encoder_strobe - nidaq.events.opto(i)));
        opto_frames(i) = closest_frame;
    end
    dm.tseries.opto = zeros(numel(dm.tseries.wheel_encoder), 1);
    dm.tseries.opto(led_frames, :) = 1;
    
    % ============================
    % Create events
    % ============================
    dm.events.trial = find(dm.tseries.trial);
    dm.events.leftpuff = find(dm.tseries.leftpuff);
    dm.events.rightpuff = find(dm.tseries.rightpuff);
    dm.events.led = find(dm.tseries.led);
    dm.events.opto = find(dm.tseries.opto);
    
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
        case {'AirpuffRandom_OptoRandom'}
            %             dm.tseries.trial = or(dm.tseries.rightpuff, dm.tseries.leftpuff);
            %             dm.events.trial = find(dm.tseries.trial);
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
    
    % Quality Check
    figure; set(gcf, 'Position',  [100, 100, 1400, 1000])
    subplot(2,1,1)
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
    
    if isfield(dm.tseries, 'photometry')
        subplot(2,1,2)
        plot(dm.tseries.photometry.sig470); hold on
        plot(dm.tseries.photometry.sig405); hold on
        plot(dm.tseries.photometry.df*100); hold on
    end
    saveas(gcf, sprintf('%s\\%s_QUALITY_CHECK.png', sessions(SESSION).folder, sessions(SESSION).fname));
    
end

fprintf('\nDone processing!\n');


%%
figure; hold on
plot(nidaq.traces.camera_strobe)
plot(nidaq.traces.encoder_strobe)
plot(nidaq.traces.airpuff)


