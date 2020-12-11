cd('C:\Users\Evan Feinberg\Desktop\ExperimentControl_SZ_v1.4\OSC_send_receive')
version -java
javaaddpath('javaosctomatlab.jar');
import com.illposed.osc.*;
import java.lang.String
receiver =  OSCPortIn(2323);
osc_method = String('/number');
osc_listener = MatlabOSCListener();
receiver.addListener(osc_method,osc_listener);
receiver.startListening();

osc_matrix = NaN(150000,4,'double');
min_frames = SESSION.ui.iti_min*50; %Minimum time mouse must fixate in peripheral position

execute_puff = 0;
count = 1;
while execute_puff==0
    osc_message = osc_listener.getMessageArgumentsAsDouble(); 
    if ~isempty(osc_message) 
        osc_matrix(count,:) = osc_message;
        if count>=100
            pupil_pos=osc_matrix(count-99:count,2)-osc_matrix(count-99:count,1);
            left_bound = osc_matrix(count,3);
            right_bound = osc_matrix(count,4);
            if sum(abs(diff(pupil_pos))>10)==0 %if there is no saccade or blink in the last 2 seconds
                if sum(isnan(pupil_pos))==0 %if there is no NaN in the last 2 seconds
                    if sum(pupil_pos<left_bound)==100 || sum(pupil_pos>right_bound)==100
                        execute_puff=1
                    end
                end
            end       
        end
        count=count+1;
    end 
end

receiver.stopListening();
receiver=0;

figure; plot(osc_matrix(:,2)-osc_matrix(:,1));

%%
u = udp('127.0.0.1',4242);
fopen(u);
%%
oscsend(u,'/start','f', 45);
%%
fclose(u);

%%

cd('C:\Users\Evan Feinberg\Desktop\ExperimentControl_SZ_v1.4\OSC_send_receive')
version -java
javaaddpath('javaosctomatlab.jar');
import com.illposed.osc.*;
import java.lang.String
receiver =  OSCPortIn(2323);
osc_method = String('/number');
osc_listener = MatlabOSCListener();
receiver.addListener(osc_method,osc_listener);
receiver.startListening();

osc_matrix = NaN(150000,4,'double');
min_frames = 100; %Minimum time mouse must fixate in peripheral position
count = 1;
iti_start = tic;
while toc(iti_start) < 12                    
    osc_message = osc_listener.getMessageArgumentsAsDouble(); 
    if ~isempty(osc_message) 
        osc_matrix(count,:) = osc_message;
        if count>=min_frames
            pupil_pos=osc_matrix(count-min_frames+1:count,2)-osc_matrix(count-min_frames+1:count,1);
            left_bound = osc_matrix(count,3);
            right_bound = osc_matrix(count,4);
            pupil_pos(count-1)
            if sum(abs(diff(pupil_pos))>10)==0 %if there is no saccade or blink in the last 2 seconds
                if sum(isnan(pupil_pos))==0 %if there is no NaN in the last 2 seconds
                    if sum(pupil_pos<left_bound)==min_frames || sum(pupil_pos>right_bound)==min_frames
                        execute_trial = 1;                             
                    end
                end                
            end       
        end
        count=count+1;
        pause(0.0001) %essential for cancel callback
    end 
end