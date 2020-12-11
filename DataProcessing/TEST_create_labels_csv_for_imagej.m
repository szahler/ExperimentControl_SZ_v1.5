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

for SESSION = 1:numel(sessions)
% for SESSION = 27
    
    fprintf('\nProcessing experiment %d of %d\n\n', SESSION, numel(sessions));
   
    
    % ============================
    % PUPIL ======================
    % ============================
    % if pupil data is present, assmble pupil time series
    pupil_csv = all_files(find(contains({all_files.name}, sessions(SESSION).fname) & contains({all_files.name}, '_pupil') & endsWith({all_files.name}, '.csv'))).name;
    pupil_data_original = importPupilCSV(pupil_csv);
    pupil_data = table2array(pupil_data_original);
                

    tmpPupil = table2array(pupil_data_original);
    poses_x = tmpPupil(:,[1 3 9 11]);
    poses_y = tmpPupil(:,[2 4 10 12]);
    
    ImJ_export = [];
    for i = 1:10000
        ImJ_export = vertcat(ImJ_export,[poses_x(i,:)' poses_y(i,:)' ones(4,1)*i]);
    end
    ImJ_export = [(1:size(ImJ_export, 1))' ImJ_export];

    headers = {'', 'X', 'Y', 'Slice'};
    csvwrite_with_headers(fullfile(sessions(SESSION).folder, [sessions(SESSION).fname '_pose.csv']),ImJ_export, headers)

end

fprintf('\nDone processing!\n');


