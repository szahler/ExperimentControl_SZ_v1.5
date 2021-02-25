% DEFINE PROMPT FIELDS
prompt = {
    'Baseline period (s):',... % How long user wants the session to run
    'ITI Min (s):',... % minimum iti
    'ITI Max (s):',... % maximum iti
    'Number of trials:',... % how many trials
    'Percentage of opto only trials (0-100):',... % fraction of trials that will be opto only
    'Percentage of opto/puff trials (0-100):',... % fraction of trials that will be opto
    'Percentage of puff only trials (0-100):',... % fraction of trials that will be opto
    'Puff trials: percentage left (0-100):',... % Fraction of puff trials that will be left
    'Puff trials: percentage right (0-100):',... % Fraction of puff trials that will be right
    'Puff trials: percentage both (0-100):',... % Fraction of puff trials that will be both
    'Opto start offset (ms; must be positive):',... % time from arduino command message that opto starts
    'Opto duration (ms; must be positive):',... % duration that opto is left on
    'Puff start offset (ms; must be positive):',... % time from arduino command message that puff starts
    'Puff duration (ms; must be positive):',... % duration that solenoid is left on
    'Treatment (e.g. muscimol, acsf, cno):',... % indicate treatment condition
    'Notes:',...
    };

% FIELD CHECKING FUNCTIONS
errorcheck = @(answer) true; % DO NOT REMOVE - null error checking formula

% define individual error checking functions here
ec1 = @(answer) (str2num(answer{7}) + str2num(answer{8}) + str2num(answer{9})) == 100; % trials type percentages must sum to 100
ec2 = @(answer) (str2num(answer{10}) + str2num(answer{11}) + str2num(answer{12})) == 100; % puff trial percentages must sum to 100
% sum individual error checking functions here
errorcheck = @(answer) ec1(answer) & ec2(answer);
