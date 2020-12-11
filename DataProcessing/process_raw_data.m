%% Select folder to process
clear all;
addpath(genpath('C:\Users\Evan\Google Drive\Feinberg\Code\Utilities'))

process_this_folder = 'C:\Users\Evan\Box Sync\Data\2P Traces\20190306';

%% Generate list of experiments
all_files = subdir(process_this_folder);
behavior_files = all_files(endsWith({all_files.name}, '_behavior.mat'));
for i = 1:numel(behavior_files)
    session_names(i).folder = behavior_files(i).folder;
    session_names(i).fname = behavior_files(i).name(end-30:end-13);
end

%% GENERATE DATAMATRIX: Iterate through experiments and merge 2P, pupil, and behavior data

for SESSION = 1:numel(session_names)
    
    % find experiment metadata and parameters
    dm.experiment.path = 
    
    % start tseries (time) - use encoder strobe for timekeeping
    
    
    % if twophoton data is present, assmble the segment and time series
    
    
    % if pupil data is present, assmble pupil time series
    
    
    % if wheel encoder is present, assemble
    
    
    % assemble airpuff and led time series
    
end

%% Save file as filename_datamatrix.mat


