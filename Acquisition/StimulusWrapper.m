%% INITIALIZE SESSION PARAMETERS (RUN ONCE PER SESSION)
% SZ | v1.5 (12/10/2020)
% Clear the workspace and the screen
close all; clearvars; delete(instrfind)

config.enable_scanbox = false;
% config.scanbox_udp = udp('169.230.68.161', 'RemotePort', 7000);
config.behavior_com = 'COM3'; % original setup
config.ogbox_com = 'COM5'; 
config.strain_gauge_com = 'COM4';
config.nidaq_id = 'Dev2'; % original set
config.computer_name = 'Sebi 2P Room';
config.code_folder = 'C:\Users\feinberg lab\Desktop\ExperimentControl_SZ_v1.5\Acquisition';
config.data_folder = 'C:\Users\feinberg lab\Desktop\Data';
config.version = '1.5'; % DO NOT CHANGE
config.pupil_vid_flipped = false; % Set to 'true' if acquired video was flipped horizontally
config.strain_gauge_exist = true;
addpath(genpath(config.code_folder));

%==========================================================================
%% MANUALLY CONTROL SETUP (in progress)
ManualControl(config);
%% RUN AirpuffRandom_OptoRandom
debug_config =RunExperiment('AirpuffRandom_OptoRandom', config);

%% RUN AirpuffRandom_OptoRandom_ClosedLoop
% Must restart matlab before running this
debug_config =RunExperiment('AirpuffRandom_OptoRandom_ClosedLoop', config);

%% RUN AirpuffBehavior_Distractor_v1
debug_config =RunExperiment('AirpuffBehavior_Distractor_v1', config);