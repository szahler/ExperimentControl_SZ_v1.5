function config = RunExperiment(ExperimentName, config)
% DO NOT CHANGE UNLESS YOU KNOW WHAT YOU'RE DOING
% DT: 2/19/2019
% v1.2: added opto nidaq channel

fprintf('\n\n===================================================\n');
config = SetParameters(ExperimentName, config);

config.session_rng = rng('shuffle');

global canceling
canceling.hfig = figure('Position', [500,500,200,50], 'CloseRequestFcn',@end_experiment_closereq, 'MenuBar', 'none', 'ToolBar', 'none');
canceling.hbutton = uicontrol('Style','pushbutton','Units','normalized',...
    'String',sprintf('STOP EXPERIMENT'),'FontSize',12,'Position',[1/16 1/16 14/16 14/16],'Callback',@end_experiment_callback);
canceling.cancel_requested = false;

config.startup.nidaq = 0;
config.startup.arduino = 0;
config.startup.twophoton = 0;
config.startup.experiment = 0;

if config.canceled == false

    %INITIALIZE NI DAQ AND START DATA ACQUISITION -----------------------------
    try
        fprintf('Initializing NI-DAQ\n');
        deviceID = config.nidaq_id;
        s = daq.createSession('ni');
        s.Rate = 2500;
        s.IsContinuous = true;
        config.nidaq_sampling_rate = s.Rate;

        %define and add analog input channels
        l_airpuff_ch = 'ai0';
        r_airpuff_ch = 'ai1';
        opto_on_ch = 'ai2';
        pupil_camera_ch = 'ai3';
        camera_trigger_ch = 'ai4';
        camera2_ch = 'ai5';
        strain_gauge_ch = 'ai6';

        s.addAnalogInputChannel(deviceID, l_airpuff_ch, 'Voltage');
        s.addAnalogInputChannel(deviceID, r_airpuff_ch, 'Voltage');
        s.addAnalogInputChannel(deviceID, opto_on_ch, 'Voltage');
        s.addAnalogInputChannel(deviceID, pupil_camera_ch, 'Voltage');
        s.addAnalogInputChannel(deviceID, camera_trigger_ch, 'Voltage');
        s.addAnalogInputChannel(deviceID, camera2_ch, 'Voltage');
        s.addAnalogInputChannel(deviceID, strain_gauge_ch, 'Voltage');

        nChannels = numel(s.Channels);
        for i = 1:nChannels
            s.Channels(i).TerminalConfig = 'SingleEnded';
        end
        
        channels{1} = {'l_airpuff_ch',l_airpuff_ch};
        channels{2} = {'r_airpuff_ch',r_airpuff_ch};
        channels{3} = {'opto_on_ch',opto_on_ch};
        channels{4} = {'pupil_camera_ch',pupil_camera_ch};
        channels{5} = {'camera_trigger_ch',camera_trigger_ch};
        channels{6} = {'camera2_ch',camera2_ch};
        channels{7} = {'strain_gauge_ch',strain_gauge_ch};

        %begin acquisition
        fprintf('Starting NI-DAQ acquisition\n');
        nidaq_fid = fopen(fullfile(config.data_folder, 'temp_nidaq_log.bin'),'w+');
        lh = addlistener(s,'DataAvailable',@(src,event)logData(src,event,nidaq_fid));
        s.startBackground();

        config.startup.nidaq = 1;
    
    catch ME
        
        config.startup.nidaq = 0;
        fprintf('Problem with NI-DAQ...\n');
        
    end

    % START BEHAVIOR ARDUINO --------------------------------------------------
    if config.startup.nidaq == 1
        try
            fprintf('Initializing behavior arduino\n');
            a = serial(config.behavior_com);
            a.BaudRate=9600;
            a.InputBufferSize = 1500000; % can record up to 166.67 minutes worth of encoder data
            fopen(a);
            pause(2)
            fprintf('Starting camera/encoder trigger\n');
            fprintf(a, GenerateCommandMessage('TriggerOn')); % send command to arduino
    
            config.startup.arduino = 1;
            
        catch ME

            config.startup.arduino = 0;
            fprintf('Problem with Arduino...\n');
            
        end
    end
    
    % START STRAIN GAUGE ARDUINO ------------------------------------------
    if config.startup.nidaq == 1
        if config.strain_gauge_exist == true
            try
                fprintf('Initializing strain gauge arduino\n');
                b = serial(config.strain_gauge_com);
                b.BaudRate=9600;
                fopen(b);
                pause(2)
                fprintf('Zeroing strain gauge measurement\n');
                fprintf(b, '1'); % send command to arduino

                config.startup.strain_gauge = 1;

            catch ME

                config.startup.strain_gauge = 0;
                fprintf('Problem with strain gauge...\n');

            end
        else
            config.startup.strain_gauge = 0;
        end
    end
    
    % START TWO-PHOTON --------------------------------------------------------
    if config.startup.arduino == 1
        if config.enable_scanbox == true && exist('config.scanbox_udp')
            fopen(config.scanbox_udp); 
            fprintf('Starting 2P acquisition\n')
            fprintf(config.scanbox_udp,sprintf(['A' config.experiment.mouse_id]));    % Send animal name
            pause (1);
            fprintf(config.scanbox_udp,sprintf(['U' config.experiment.date]));        % Send field (date)
            fprintf(config.scanbox_udp,sprintf('E%s',config.experiment.session));     % Send session number
            fprintf(config.scanbox_udp,'G');                                          % Go! Start 2P sampling
            fprintf(config.scanbox_udp,sprintf(['M' config.experiment.name]));        % Send stim name
            pause(2);
            
            config.startup.twophoton = 1;
            
        else
            
            config.startup.twophoton = 0;
            fprintf('Skipping 2P\n')
        end
    end
    
    
    % BEGIN EXPERIMENT --------------------------------------------------------
    if config.startup.arduino == 1
        fprintf('\n')
        try
            experiment = feval(ExperimentName, config, a);
            
            config.startup.experiment = 1;
            
        catch ME
            config.startup.experiment = 0;
        end
    end
    
    
    % STOP TWO-PHOTON ---------------------------------------------------------
    if config.enable_scanbox == true && config.startup.twophoton == 1 && exist('config.scanbox_udp')
        fprintf('Stopping 2P acquisition...\n')
        fprintf(config.scanbox_udp,'S'); % Stop 2P sampling
        fclose(config.scanbox_udp);
        pause(2)
    end
    
    % STOP BEHAVIOR ARDUINO ---------------------------------------------------
    if config.startup.arduino == 1
        fprintf('Stopping camera/encoder trigger\n')
        fprintf(a, GenerateCommandMessage('TriggerOff')) % send command to arduino
        fprintf('Closing behavior arduino\n\n')
        fclose(a);
    end
    
    % STOP STRAIN GAUGE ARDUINO ---------------------------------------------------
    if config.startup.strain_gauge == 1
        fprintf('Closing strain gauge arduino\n\n')
        fclose(b);
    end
    
    % STOP NI DAQ -------------------------------------------------------------
    if config.startup.nidaq == 1
        pause(2);
        s.stop();               %stops ni daq
        fprintf('DATA ACQUISITION DONE; STOP CAMERA\n')

        %read out nidaq data
        frewind(nidaq_fid);
        nidaq.channels = channels;
        nidaq.data = fread(nidaq_fid,[nChannels+1,inf],'double');
        fclose(nidaq_fid);
    end
    
    config.CancelRequested = canceling.cancel_requested;
    
    if config.startup.experiment == 1
        % VALIDATE DATA
        ValidateRawData(nidaq);

        % SAVE DATA, CONFIG, AND BEHAVIOR/STIM PARAMETERS
        [status, msg, msgID] = mkdir(fullfile(config.data_folder, config.experiment.date));
        save(fullfile(config.data_folder, config.experiment.date, [config.experiment.session_name '_behavior']), 'nidaq', 'experiment', 'config');
    end
        
else
    fprintf('No parameters entered...\n')
end

% cleanup
try delete(a); catch; end
try delete(s); catch; end
try delete(canceling.hfig); catch; end

if exist('ME'); rethrow(ME); end

end

function end_experiment_callback(src,event)
    global canceling
    set(canceling.hbutton, 'String', 'Canceling...', 'enable','off')
    canceling.cancel_requested = true;
end

function end_experiment_closereq(src,callbackdata)
    global canceling
    if canceling.cancel_requested == false
        set(canceling.hbutton, 'String', 'Canceling...', 'enable','off')
        canceling.cancel_requested = true;
    else
        delete(canceling.hfig);
    end
end
