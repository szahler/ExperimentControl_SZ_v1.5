function SESSION = AirpuffBehavior_Distractor_v1( config, a )
% DT: 10/9/2020

global canceling
fprintf('Running %s...\n\n', config.experiment.name);

% PARSE EXPERIMENTAL PARAMETERS
answer = config.experiment.answer;
j = 1;
SESSION.ui.baseline = str2num(answer{j}); j = j + 1;
SESSION.ui.iti_min = str2num(answer{j}); j = j + 1;
SESSION.ui.iti_max = str2num(answer{j}); j = j + 1;
SESSION.ui.num_trials = str2num(answer{j}); j = j + 1;
SESSION.ui.percent_opto_only = str2num(answer{j}); j = j + 1;
SESSION.ui.percent_opto_puff = str2num(answer{j}); j = j + 1;
SESSION.ui.percent_puff_only = str2num(answer{j}); j = j + 1;
SESSION.ui.left_airpuff_percent = str2num(answer{j}); j = j + 1;
SESSION.ui.right_airpuff_percent = str2num(answer{j}); j = j + 1;
SESSION.ui.both_airpuff_percent = str2num(answer{j}); j = j + 1;
SESSION.ui.opto_offset = str2num(answer{j}); j = j + 1;
SESSION.ui.opto_duration = str2num(answer{j}); j = j + 1;
SESSION.ui.puff_offset = str2num(answer{j}); j = j + 1;
SESSION.ui.puff_duration = str2num(answer{j}); j = j + 1;
SESSION.ui.treatment = answer{j}; j = j + 1;
SESSION.ui.notes = answer{j}; j = j + 1;

% GENERATE SESSION VARIABLES

num_trials = SESSION.ui.num_trials;
num_opto_only = floor(num_trials * SESSION.ui.percent_opto_only/100);
num_opto_puff = ceil(num_trials * SESSION.ui.percent_opto_puff/100);
num_puff_only = num_trials - num_opto_only - num_opto_puff;

SESSION.trials.trial = (1:num_trials)';
SESSION.trials.iti = rand(num_trials,1).*(SESSION.ui.iti_max-SESSION.ui.iti_min)+SESSION.ui.iti_min;

SESSION.trials.airpuff_left = [];
SESSION.trials.airpuff_right = [];
SESSION.trials.opto = [];

% airpuff only trials
num_leftpuff_trials = round(num_puff_only*(SESSION.ui.left_airpuff_percent/100));
SESSION.trials.airpuff_left = [SESSION.trials.airpuff_left; true(num_leftpuff_trials,1)];
SESSION.trials.airpuff_right = [SESSION.trials.airpuff_right; false(num_leftpuff_trials,1)];

num_rightpuff_trials = round(num_puff_only*(SESSION.ui.right_airpuff_percent/100));
SESSION.trials.airpuff_left = [SESSION.trials.airpuff_left; false(num_rightpuff_trials,1)];
SESSION.trials.airpuff_right = [SESSION.trials.airpuff_right; true(num_rightpuff_trials,1)];

num_bothpuff_trials = num_puff_only - num_rightpuff_trials - num_leftpuff_trials;
SESSION.trials.airpuff_left = [SESSION.trials.airpuff_left; true(num_bothpuff_trials,1)];
SESSION.trials.airpuff_right = [SESSION.trials.airpuff_right; true(num_bothpuff_trials,1)];

SESSION.trials.opto = [SESSION.trials.opto; false(num_puff_only,1)];

% opto/airpuff trials
num_leftpuff_trials = round(num_opto_puff*(SESSION.ui.left_airpuff_percent/100));
SESSION.trials.airpuff_left = [SESSION.trials.airpuff_left; true(num_leftpuff_trials,1)];
SESSION.trials.airpuff_right = [SESSION.trials.airpuff_right; false(num_leftpuff_trials,1)];

num_rightpuff_trials = round(num_opto_puff*(SESSION.ui.right_airpuff_percent/100));
SESSION.trials.airpuff_left = [SESSION.trials.airpuff_left; false(num_rightpuff_trials,1)];
SESSION.trials.airpuff_right = [SESSION.trials.airpuff_right; true(num_rightpuff_trials,1)];

num_bothpuff_trials = num_opto_puff - num_rightpuff_trials - num_leftpuff_trials;
SESSION.trials.airpuff_left = [SESSION.trials.airpuff_left; true(num_bothpuff_trials,1)];
SESSION.trials.airpuff_right = [SESSION.trials.airpuff_right; true(num_bothpuff_trials,1)];

SESSION.trials.opto = [SESSION.trials.opto; true(num_opto_puff,1)];

% opto only trials
SESSION.trials.airpuff_left = [SESSION.trials.airpuff_left; false(num_opto_only,1)];
SESSION.trials.airpuff_right = [SESSION.trials.airpuff_right; false(num_opto_only,1)];
SESSION.trials.opto = [SESSION.trials.opto; true(num_opto_only,1)];

% randomize trials
random_order = randperm(num_trials);
SESSION.trials.airpuff_left = SESSION.trials.airpuff_left(random_order);
SESSION.trials.airpuff_right = SESSION.trials.airpuff_right(random_order);
SESSION.trials.opto = SESSION.trials.opto(random_order);

% Define default commands
[~, default_commands] = GenerateCommandMessage('default');

%
estimated_time_remaining = round(sum(SESSION.trials.iti) + SESSION.ui.baseline);
time_elapsed_timer = tic;

% BASELINE
fprintf('Starting baseline period\n\n');
delay = SESSION.ui.baseline;
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
        fprintf('%d seconds remaining (%d min)\n', round(estimated_time_remaining - toc(time_elapsed_timer)), round(round(estimated_time_remaining - toc(time_elapsed_timer))/60));
        
        % STIMULUS (actual stimulus timing is carried out on arduino)
        stim_start = tic;
        first_loop = 1;
        while toc(stim_start) < (SESSION.ui.puff_duration + SESSION.ui.puff_offset)/1000
            if first_loop == 1
                
                % generate command message
                commands = default_commands;
                
                if SESSION.trials.opto(TRIAL) == 1
                    commands.opto_duration = SESSION.ui.opto_duration;
                    commands.opto_offset = SESSION.ui.opto_offset;
                    fprintf('OPTO! ');
                end
                
                if SESSION.trials.airpuff_left(TRIAL) == 1 && SESSION.trials.airpuff_right(TRIAL) == 0
                    commands.l_puff = SESSION.ui.puff_duration;
                    commands.puff_offset = SESSION.ui.puff_offset;
                    fprintf('LEFT PUFF!\n');
                elseif SESSION.trials.airpuff_right(TRIAL) == 1 && SESSION.trials.airpuff_left(TRIAL) == 0
                    commands.r_puff = SESSION.ui.puff_duration;
                    commands.puff_offset = SESSION.ui.puff_offset;
                    fprintf('RIGHT PUFF!\n');
                elseif SESSION.trials.airpuff_right(TRIAL) == 1 && SESSION.trials.airpuff_left(TRIAL) == 1
                    commands.l_puff = SESSION.ui.puff_duration;
                    commands.r_puff = SESSION.ui.puff_duration;
                    commands.puff_offset = SESSION.ui.puff_offset;
                    fprintf('BOTH PUFF!\n');
                else
                    fprintf('OPTO ONLY CONTROL!\n');
                end
                
                message = GenerateCommandMessage(commands);
                
                fprintf(a, message); % send command to arduino
                fprintf([message '\n\n']);
                first_loop = 0;
                
            else
                pause(0.0001) %essential for cancel callback
            end
        end
        
        % ITI
        delay = SESSION.trials.iti(TRIAL) - SESSION.ui.puff_offset/1000;
        iti_start = tic;
        while toc(iti_start) < delay
            if canceling.cancel_requested == true; break; end % cancel handling
            pause(0.0001) %essential for cancel callback
        end
    end
end

% record last completed trial
if exist('TRIAL')
    SESSION.trials.last_completed_trial = TRIAL;
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

