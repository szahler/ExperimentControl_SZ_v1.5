function config = SetParameters(ExperimentName, config)
% DO NOT CHANGE UNLESS YOU KNOW WHAT YOU'RE DOING
% DT: 2/19/2019

% get experiment-specific prompts
run([ExperimentName '_SETPARAMETERS']);

% load default answers, request user input, and save answers as default
prompt = [{'Mouse ID (5 char):','Session Number (2 char):'} prompt];

try load(fullfile(config.code_folder, 'StimulusFunctions/default_user_input.mat')); catch; end

try answer = inputdlg(prompt, ExperimentName, 1, DefaultAnswers.(ExperimentName)); % Syntax for arguments: prompt, dialogue title, # lines, default answers
catch; answer = inputdlg(prompt, ExperimentName, 1); end % Syntax for arguments: prompt, dialogue title, # lines

if ~isempty(answer)
    DefaultAnswers.(ExperimentName) = answer;
    save(fullfile(config.code_folder, 'StimulusFunctions/default_user_input.mat'), 'DefaultAnswers');

    Today = datetime('today'); DateFormat = 'yyyymmdd';
    config.experiment.mouse_id = answer{1};
    config.experiment.date = datestr(Today, DateFormat);
    config.experiment.session = answer{2};
    config.experiment.session_name = strcat(config.experiment.date, '_', config.experiment.session ,  '_', config.experiment.mouse_id);
    config.experiment.name = ExperimentName;
    config.experiment.answer = answer(3:end);
    config.canceled = false;
else
    config.canceled = true;
end

end