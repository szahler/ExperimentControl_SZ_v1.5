function [ message, output_commands] = GenerateCommandMessage( requested_commands )
% DT: 2/19/2019
% v1.2: updated to include opto_duration and opto_offset for
% BehaviorControl_v2 arduino script

% default_commands = struct('trigger',-1,'led_x',0,'led_y',0,'led_duration',0,'led_brightness',0,...
% 'led_delay',0,'l_puff',0,'r_puff',0,'led_square_diameter',0,...
% 'led_drift_direction',0,'led_drift_delay',0,'background_brightness',0, 'opto_duration',0, 'opto_offset',0);

default_commands = struct('trigger',-1,'puff_offset',0,'l_puff',0,'r_puff',0,'opto_offset',0,'opto_duration',0);

if isstruct(requested_commands)
    message = sprintf('%d,', cell2mat(struct2cell(requested_commands)));
    message(end) = '';
    output_commands = requested_commands;
elseif strcmp(requested_commands, 'default')
    message = sprintf('%d,', cell2mat(struct2cell(default_commands)));
    message(end) = '';
    output_commands = default_commands;
elseif strcmp(requested_commands, 'TriggerOn')
    default_commands.trigger = 1;
    message = sprintf('%d,', cell2mat(struct2cell(default_commands)));
    message(end) = '';
    output_commands = default_commands;
elseif strcmp(requested_commands, 'TriggerOff')
    default_commands.trigger = 0;
    message = sprintf('%d,', cell2mat(struct2cell(default_commands)));
    message(end) = '';
    output_commands = default_commands;
end

end

