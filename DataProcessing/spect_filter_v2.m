function [spectTimes,photoSig,isoSig] = spect_filter(rx,Fs)
% Spectral filtering of raw photometry signal (zeroLag)

freqRange = 100:5:600; % Frequencies to calculate spectrogram in Hz
winSize = 0.04; % Window size for spectrogram (sec)
spectSample = 0.005; % Step size for spectrogram (sec)
inclFreqWin = 3; % Number of frequency bins to average (on either side of peak freq)

% Convert spectrogram window size and overlap from time to samples
spectWindow = 2.^nextpow2(Fs .* winSize);
spectOverlap = ceil(spectWindow - (spectWindow .* (spectSample ./ winSize)));
disp(['Calculating spectrum using window size ', num2str(spectWindow ./ Fs)])

% Create low pass filter for final data
lpFilt = designfilt('lowpassiir','FilterOrder',8, 'PassbandFrequency',300,...
    'PassbandRipple',0.01, 'SampleRate',Fs);

% Calculate spectrogram
[spectVals,spectFreqs,spectTimes]=spectrogram(rx,spectWindow,spectOverlap,freqRange,Fs);
spectAmpVals = double(abs(spectVals));

% Find the two carrier frequencies
avgFreqAmps = mean(spectAmpVals,2);
[pks,locs]=findpeaks(double(avgFreqAmps),'SortStr','descend','NPeaks',2); %SZ Edit to find the two tallest peaks
locs = sort(locs); %SZ Edit to sort peak location by index

% Calculate signal at each frequency band
sig1 = mean(abs(spectVals((locs(1)-inclFreqWin):(locs(1)+inclFreqWin),:)),1);
sig2 = mean(abs(spectVals((locs(2)-inclFreqWin):(locs(2)+inclFreqWin),:)),1);
    
% Low pass filter the signals
filtSig1 = filtfilt(lpFilt,double(sig1)); % gCaMP
filtSig2 = filtfilt(lpFilt,double(sig2)); % isosbestic

photoSig = filtSig1;
isoSig = filtSig2;

