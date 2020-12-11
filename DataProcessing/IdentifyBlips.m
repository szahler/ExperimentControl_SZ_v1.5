function blips = IdentifyBlips(pupilx, saccade_threshold, tol, max_length)

blips = zeros(size(pupilx));

for blip_length = 1:max_length
    
    for i = 2:numel(pupilx)-blip_length
        if all(abs(pupilx(i-1) - pupilx(i:i+blip_length-1)) > saccade_threshold) && abs((pupilx(i-1)-pupilx(i)) + (pupilx(i+blip_length-1)-pupilx(i+blip_length))) < tol
            blips(i:i+blip_length-1) = 1;
        end
    end

end

end

