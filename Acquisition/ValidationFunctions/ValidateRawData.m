function ValidateRawData( nidaq )
% SZ: 12/01/2020

fprintf('\n\n====== Quick Data Validation ======\n\n');
fprintf('%d camera1 strobes\n', numel(idUniqueAboveThr(nidaq.data(5,:),2)));
fprintf('%d camera2 strobes\n', numel(idUniqueAboveThr(nidaq.data(7,:),2)));
fprintf('%d trigger strobes\n\n', numel(idUniqueAboveThr(nidaq.data(6,:),2)));

end

