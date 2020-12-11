function sessions = IdentifySessionBehaviorFiles( all_files, OVERWRITE_DATAMATRIX, filter )
%UNTITLED5 Summary of this function goes here
%   Detailed explanation goes here

if OVERWRITE_DATAMATRIX == 1
    behavior_files = all_files(endsWith({all_files.name}, '_behavior.mat'));
else
    behavior_files = all_files(endsWith({all_files.name}, '_behavior.mat'));
    datamatrix_files = all_files(endsWith({all_files.name}, '_datamatrix.mat'));
    
    for SESSION = 1:numel(datamatrix_files)
        datamatrix_session_filenames{SESSION} = datamatrix_files(SESSION).name(end-32:end-15);
    end
    
    datamatrix_file_exists = contains({behavior_files.name}', datamatrix_session_filenames);
    behavior_files = behavior_files(~datamatrix_file_exists);
    
end

% animal filter
if isfield(filter, 'animal')
    behavior_files = behavior_files(contains({behavior_files.name}', filter.animal));
end

% date filter
if isfield(filter, 'date')
    tmp_date_filter = strsplit(num2str(filter.date), ' ');
    behavior_files = behavior_files(contains({behavior_files.name}', tmp_date_filter));
end

behavior_filenames = {behavior_files.name}';

if isempty(behavior_filenames)
    fprintf('\n\nNo matching files found\n\n');
    sessions = [];
else
    fprintf('\nMatching files:\n')
    fprintf('%s\n',behavior_filenames{:})
    fprintf('\n')

    for SESSION = 1:numel(behavior_files)
        sessions(SESSION).folder = behavior_files(SESSION).folder;
        sessions(SESSION).fname = behavior_files(SESSION).name(end-30:end-13);
    end
end

end

