function message = OGBoxMessage( requested_commands )
% Author: DT
% 1/28/2020

message = sprintf('%d,', cell2mat(struct2cell(requested_commands)));
message(end) = '';

end

