function SESSION = AirpuffRandom_OptoRandom( config, a )
% DT: 2/21/2019
% SZ: 2/24/2020
global canceling
fprintf('Running %s...\n\n', config.experiment.name);

% START OGBox ARDUINO --------------------------------------------------
try
    fprintf('Initializing OGBox arduino\n');
    ogbox_serial = serial(config.ogbox_com);
    ogbox_serial.BaudRate=9600;
    fopen(ogbox_serial);
    pause(2)
    OGBox_started = true;
catch ME
    OGBox_started = false;
    fprintf('Problem with OGBox...\n');
    canceling.cancel_requested = true;
end

try
    cd('C:\Users\Evan Feinberg\Desktop\ExperimentControl_SZ_v1.4\OSC_send_receive')
    version -java
    javaaddpath('javaosctomatlab.jar');
    import com.illposed.osc.*;
    import java.lang.String
    receiver =  OSCPortIn(2323);
    osc_method = String('/number');
    osc_listener = MatlabOSCListener();
    receiver.addListener(osc_method,osc_listener);
    receiver.startListening();
    osc_matrix = NaN(10000,4,'double');
catch
    fprintf('\nRESTART MATLAB\n');
end

% PARSE EXPERIMENTAL PARAMETERS
answer = config.experiment.answer;
j = 1;
SESSION.ui.baseline = str2num(answer{j}); j = j + 1;
SESSION.ui.iti_min = str2num(answer{j}); j = j + 1;
SESSION.ui.iti_max = str2num(answer{j}); j = j + 1;
SESSION.ui.num_trials = str2num(answer{j}); j = j + 1;
SESSION.ui.left_airpuff_percent = str2num(answer{j}); j = j + 1;
SESSION.ui.puff_offset = str2num(answer{j}); j = j + 1;
SESSION.ui.puff_duration = str2num(answer{j}); j = j + 1;
SESSION.ui.opto_trials_percentage = str2num(answer{j}); j = j + 1;
SESSION.ui.opto_offset = str2num(answer{j}); j = j + 1;
SESSION.ui.opto_duration = str2num(answer{j}); j = j + 1;
SESSION.ui.opto_intensity = str2num(answer{j}); j = j + 1;
SESSION.ui.opto_cyclelength = str2num(answer{j}); j = j + 1;
SESSION.ui.opto_pulselength = str2num(answer{j}); j = j + 1;

% GENERATE SESSION VARIABLES

%%%%%%%NEW%%%%%%
unique_trial_types = allcomb(SESSION.ui.opto_duration, SESSION.ui.opto_intensity, SESSION.ui.opto_cyclelength, SESSION.ui.opto_pulselength);
all_trials = repmat(unique_trial_types,ceil(SESSION.ui.num_trials/size(unique_trial_types,1)),1);
num_trials = size(all_trials, 1);
random_order = randperm(num_trials);
all_trials_randomized = all_trials(random_order,:);
all_trials_randomized = all_trials_randomized(1:SESSION.ui.num_trials,:);
SESSION.trials.opto_duration = all_trials_randomized(:,1);
SESSION.trials.opto_intensity = all_trials_randomized(:,2);
SESSION.trials.opto_cyclelength = all_trials_randomized(:,3);
SESSION.trials.opto_pulselength = all_trials_randomized(:,4);

%%%%%%%NEW%%%%%%

num_trials = SESSION.ui.num_trials;

SESSION.trials.trial = (1:num_trials)';
SESSION.trials.iti = rand(num_trials,1).*(SESSION.ui.iti_max-SESSION.ui.iti_min)+SESSION.ui.iti_min;

SESSION.trials.airpuff_left = rand(num_trials,1) < SESSION.ui.left_airpuff_percent/100;
SESSION.trials.airpuff_left = logical(SESSION.trials.airpuff_left);
SESSION.trials.airpuff_right = logical(~SESSION.trials.airpuff_left);
SESSION.trials.opto = logical(rand(num_trials,1) < SESSION.ui.opto_trials_percentage/100);

%Relabel trials with intensity of 0 as non-opto
SESSION.trials.opto(SESSION.trials.opto_intensity==0) = 0;
%Relabel intensity/cyclelength/duration/pulselength of non-opto trials
SESSION.trials.opto_duration(SESSION.trials.opto==0) = 0;
SESSION.trials.opto_intensity(SESSION.trials.opto==0) = 0;
SESSION.trials.opto_cyclelength(SESSION.trials.opto==0) = 0;
SESSION.trials.opto_pulselength(SESSION.trials.opto==0) = 0;
%
[~, default_commands] = GenerateCommandMessage('default');
commands = default_commands;
fprintf(a, GenerateCommandMessage(commands)); % send command to arduino

estimated_time_remaining = round(sum(SESSION.trials.iti) + SESSION.ui.baseline);
time_elapsed_timer = tic;

% BASELINE
fprintf('Starting baseline period\n\n');
delay = SESSION.ui.baseline;
prev_delay = SESSION.ui.iti_min;
iti_start = tic;
while toc(iti_start) < delay
    if canceling.cancel_requested == true; break; end % cancel handling
    pause(0.0001) %essential for cancel callback
end

% MAIN LOOP
if canceling.cancel_requested ~= true
    for TRIAL = 1:num_trials
        if canceling.cancel_requested == true; break; end % cancel handling
        fprintf('Trial %d out of %d\n', TRIAL, num_trials);
        fprintf('%d seconds remaining\n', round(estimated_time_remaining - toc(time_elapsed_timer)));
        
        % STIMULUS (actual stimulus timing is carried out on arduino)
        
        %%%%%NEW%%%%%
        % OGBOX
        % Set OGBox parameters
        ogbox_commands.opto_intensity = SESSION.trials.opto_intensity(TRIAL);
        ogbox_commands.opto_cyclelength = SESSION.trials.opto_cyclelength(TRIAL);
        ogbox_commands.opto_pulselength = SESSION.trials.opto_pulselength(TRIAL);
        fprintf(ogbox_serial, OGBoxMessage(ogbox_commands)); % send command to arduino
        pause(0.01);
        %%%%%NEW%%%%%
        
        first_loop = 1;
        
        stim_start = tic;
        while toc(stim_start) < (SESSION.ui.puff_duration + SESSION.ui.puff_offset)/1000
            if first_loop == 1

                % generate command message
                commands = default_commands;

                if SESSION.trials.opto(TRIAL) == 1
                    commands.opto_duration = SESSION.ui.opto_duration;
                    commands.opto_offset = SESSION.ui.opto_offset;
                end

                if SESSION.trials.airpuff_left(TRIAL) == 1
                    commands.l_puff = SESSION.ui.puff_duration;
                    commands.puff_offset = SESSION.ui.puff_offset;
                    message = GenerateCommandMessage(commands);
                    fprintf('LEFT!\n');
                else
                    commands.r_puff = SESSION.ui.puff_duration;
                    commands.puff_offset = SESSION.ui.puff_offset;
                    message = GenerateCommandMessage(commands);
                    fprintf('RIGHT!\n');
                end

                fprintf(a, message); % send command to arduino
                fprintf([message '\n\n']);
                fprintf([OGBoxMessage(ogbox_commands) '\n\n'])
                first_loop = 0;

            else
                pause(0.0001) %essential for cancel callback
            end
        end
        
        iti_period = 1;
        
        iti_start = tic;
        count = 1;
        delay = SESSION.trials.iti(TRIAL);
        min_frames = SESSION.ui.iti_min*50; %Minimum time mouse must fixate in peripheral position
        while iti_period==1
            if toc(iti_start) > delay
                iti_period=0;
                prev_delay = delay;
            end

            osc_message = osc_listener.getMessageArgumentsAsDouble(); 
            if ~isempty(osc_message) 
                osc_matrix(count,:) = osc_message;
                if count>=min_frames
                    pupil_pos=osc_matrix(count-min_frames+1:count,2)-osc_matrix(count-min_frames+1:count,1);
                    left_bound = osc_matrix(count,3);
                    right_bound = osc_matrix(count,4);
                    if prev_delay > SESSION.ui.iti_min %If the mouse moved its eye since the previous peripheral position-triggered puff
                        if sum(abs(diff(pupil_pos))>10)==0 %if there is no saccade or blink in the last 2 seconds
                            if sum(isnan(pupil_pos))==0 %if there is no NaN in the last 2 seconds
                                if sum(pupil_pos<left_bound)==min_frames || sum(pupil_pos>right_bound)==min_frames
                                    iti_period = 0;
                                    prev_delay = SESSION.ui.iti_min;
                                    fprintf('\nTrigger!!\n');
                                end
                            end                
                        end 
                    end
                end
                count=count+1;
                if canceling.cancel_requested == true; break; end % cancel handling
                pause(0.0001) %essential for cancel callback            
            end     
        end
    end
end

% record last completed trial
if exist('TRIAL')
    SESSION.trials.last_completed_trial = TRIAL-1;
else
    SESSION.trials.last_completed_trial = 0;
end

fprintf(a, GenerateCommandMessage(default_commands)); % send default command string to arduino

if canceling.cancel_requested == false
    fprintf('\nExperiment complete! Shutting down acquisition...\n\n');
else
    fprintf('\nExperiment CANCELED! Shutting down acquisition...\n\n');
end

end

