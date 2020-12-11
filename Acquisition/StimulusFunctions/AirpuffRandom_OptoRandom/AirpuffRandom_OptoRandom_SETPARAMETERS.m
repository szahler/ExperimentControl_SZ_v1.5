% DEFINE PROMPT FIELDS
prompt = {
    'Baseline period (s):',... % How long user wants the session to run
    'ITI Min (s):',... % minimum iti
    'ITI Max (s):',... % maximum iti
    'Number of trials:',... % how many trials
    'Percentage of left puffs trials (0-100):',... % Fraction of trials that will be left
    'Puff start offset (ms; must be positive):',... % time from arduino command message that puff starts
    'Puff duration (ms; must be positive):',... % duration that solenoid is left on
    'Percentage opto trials (0-100):',... % fraction of trials that will be opto
    'Opto start offset (ms; must be positive):',... % time from arduino command message that opto starts
    'Opto duration (ms; comma deliniated [e.g. "200,400,600"]):',... 
    'Opto intensity (0-4095; comma deliniated [e.g. "1000,2000,3000"]):',...
    'Opto cyclelength (ms; comma deliniated [e.g. "20,40"]):',... 
    'Opto pulselength (ms; comma deliniated [e.g. "5,10"]):',... 
    'Treatment (e.g. muscimol, acsf, cno):',... % indicate treatment condition
    'Notes:',...
    };