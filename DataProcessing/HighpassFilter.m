function [corrected_trace, baseline_trace, baseline_mean] = HighpassFilter(trace, filterWidth, frameRate)
% trace: 2-photon or photometry calcium transient
% filterWidth: desired filter width in seconds. change based on gcamp decay
% rate (~3 seconds gcamp6f and ~10-15 seconds gcamp6s)
% frameRate: data acquisition frames per second

baseline_percentile = 8; % Dombeck uses 8th percentile

%%%HP filter for baseline wiggle/drift, using the system from Dombeck et
%%%al. as a crude approximation (just subtracts sliding estimate of
%%%baseline)

frames = numel(trace);
binsize = filterWidth*frameRate;
binsize = round((binsize-2)/2)*2+2;
baseline_trace = zeros(size(trace));

for i = 1:frames
    
    if i < binsize/2 + 1
        baseline_trace(i) = prctile(trace(1:i+binsize/2), baseline_percentile);
    elseif i > frames - binsize/2
        baseline_trace(i) = prctile(trace(i-binsize/2:frames), baseline_percentile);
    else
        baseline_trace(i) = prctile(trace(i-binsize/2:i+binsize/2), baseline_percentile);
    end
    
end


baseline_mean = prctile(trace,baseline_percentile);
corrected_trace = trace - baseline_trace + baseline_mean;%add back mean of baseline_percentile

end