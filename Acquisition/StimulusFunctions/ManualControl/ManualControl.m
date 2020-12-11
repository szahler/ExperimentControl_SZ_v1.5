function ManualControl(config)

a = serial(config.behavior_com);
a.BaudRate=9600;
fopen(a);
pause(2)

ogbox_serial = serial(config.ogbox_com);
ogbox_serial.BaudRate=9600;
fopen(ogbox_serial);
pause(2)

hFig = figure('Position', [0,0,600,200], 'CloseRequestFcn',@manual_control_closereq, 'MenuBar', 'none', 'ToolBar', 'none', 'Name', 'Manual Behavior Control', 'NumberTitle', 'off');
movegui(hFig,'center');
hGroup_puff = uibuttongroup('Units','Normalized','Position',[0 0 1/2 1]);
hGroup_opto = uibuttongroup('Units','Normalized','Position',[1/2 0 1/2 1]);

% Airpuff group
default_airpuff_duration = 50; % ms
default_opto_duration = 250; % ms
default_opto_intensity = 3000;
default_opto_cyclelength = 0; % ms
default_opto_pulselength = 0; % ms

uicontrol('Style','Text','String','Puff Control','FontSize',16,...
    'Parent',hGroup_puff,'Units','normalized','Position',[1/4 7/8 1/2 1/8]);

hField(1) = uicontrol('Style','edit','String',num2str(default_airpuff_duration),...
    'Parent',hGroup_puff,'Units','normalized','Position',[1/4 5/8 1/2 1/8],...
    'BackgroundColor','white');
uicontrol('Style','Text','String','Duration (ms)',...
    'Parent',hGroup_puff,'Units','normalized','Position',[1/4 4/8 1/2 1/8]);

uicontrol('Style','pushbutton','Parent',hGroup_puff,'Units','normalized',...
    'String','Left','Position',[1/8 1/8 2/8 1/8],'Callback',@left_airpuff_button_callback);
uicontrol('Style','pushbutton','Parent',hGroup_puff,'Units','normalized',...
    'String','Right','Position',[5/8 1/8 2/8 1/8],'Callback',@right_airpuff_button_callback);

% Opto group

uicontrol('Style','Text','String','Opto Control','FontSize',16,...
    'Parent',hGroup_opto,'Units','normalized','Position',[1/4 7/8 1/2 1/8]);

hField(2) = uicontrol('Style','edit','String',num2str(default_opto_duration),...
    'Parent',hGroup_opto,'Units','normalized','Position',[0 5/8 1/2 1/8],...
    'BackgroundColor','white');
uicontrol('Style','Text','String','Duration (ms)',...
    'Parent',hGroup_opto,'Units','normalized','Position',[0 4/8 1/2 1/8]);

hField(3) = uicontrol('Style','edit','String',num2str(default_opto_intensity),...
    'Parent',hGroup_opto,'Units','normalized','Position',[0 3/8 1/2 1/8],...
    'BackgroundColor','white');
uicontrol('Style','Text','String','OGBox Intensity (0-4095)',...
    'Parent',hGroup_opto,'Units','normalized','Position',[0 2/8 1/2 1/8]);

hField(4) = uicontrol('Style','edit','String',num2str(default_opto_cyclelength),...
    'Parent',hGroup_opto,'Units','normalized','Position',[1/2 5/8 1/2 1/8],...
    'BackgroundColor','white');
uicontrol('Style','Text','String','OGBox Cycle Width (ms)',...
    'Parent',hGroup_opto,'Units','normalized','Position',[1/2 4/8 1/2 1/8]);

hField(5) = uicontrol('Style','edit','String',num2str(default_opto_pulselength),...
    'Parent',hGroup_opto,'Units','normalized','Position',[1/2 3/8 1/2 1/8],...
    'BackgroundColor','white');
uicontrol('Style','Text','String','OGBox Pulse Width (ms)',...
    'Parent',hGroup_opto,'Units','normalized','Position',[1/2 2/8 1/2 1/8]);

uicontrol('Style','pushbutton','Parent',hGroup_opto,'Units','normalized',...
    'String','Opto!','Position',[1/4 1/8 1/2 1/8],'Callback',@opto_button_callback);



guidata(hFig,struct('parameters', [default_airpuff_duration, default_opto_duration], 'hField', hField));


    function left_airpuff_button_callback(src,event)
        data = guidata(src);
        new_airpuff_duration = str2num(get(data.hField(1),'String'));
        
        [ ~, commands] = GenerateCommandMessage('default');
        commands.l_puff = new_airpuff_duration;

        fprintf(GenerateCommandMessage(commands))
        fprintf('\n\n')
        fprintf(a, GenerateCommandMessage(commands));
    end

    function right_airpuff_button_callback(src,event)
        data = guidata(src);
        new_airpuff_duration = str2num(get(data.hField(1),'String'));
        
        [ ~, commands] = GenerateCommandMessage('default');
        commands.r_puff = new_airpuff_duration;

        fprintf(GenerateCommandMessage(commands))
        fprintf('\n\n')
        fprintf(a, GenerateCommandMessage(commands));
    end

    function opto_button_callback(src,event)
        data = guidata(src);
        new_opto_duration = str2num(get(data.hField(2),'String'));
        new_opto_intensity = str2num(get(data.hField(3),'String'));
        new_opto_cyclelength = str2num(get(data.hField(4),'String'));
        new_opto_pulselength = str2num(get(data.hField(5),'String'));
        
        % Set OGBox parameters
        ogbox_commands.opto_intensity = new_opto_intensity;
        ogbox_commands.opto_cyclelength = new_opto_cyclelength;
        ogbox_commands.opto_pulselength = new_opto_pulselength;
        fprintf(ogbox_serial, OGBoxMessage(ogbox_commands)); % send command to arduino
        fprintf('Setting OGBox to: %s\n', OGBoxMessage(ogbox_commands))
        pause(0.01);
        
        [ ~, commands] = GenerateCommandMessage('default');
        commands.opto_duration = new_opto_duration;

        fprintf(GenerateCommandMessage(commands))
        fprintf('\n\n')
        fprintf(a, GenerateCommandMessage(commands));
    end
% 
    function manual_control_closereq(src,callbackdata)
        data = guidata(src);
        fclose(ogbox_serial);
        fclose(a);
        delete(gcf)
    end

end