function [idx] = ch_idx(channels, channel_string)
%ch_idx Identify cell containing 'channel string'

idx = [];
for i = 1:length(channels)
    if ~isempty(strfind(channels{:,i}{1,1}, channel_string))
        idx = [idx; i];
    end
end

end

