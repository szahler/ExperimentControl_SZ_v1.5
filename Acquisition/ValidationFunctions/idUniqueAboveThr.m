function [res] = idUniqueAboveThr(data,thr)
%IDUNIQUEABOVETHR Identifies idxs when data crosses some threshold (in
%positive direction). Returns idxs of first points after crossing for each
%crossing
% SAL; 1/4/2019
% DT; 2/21/2019 function returns empty if data does not cross
% threshold

xyz = find(data > thr);
if ~isempty(xyz)
    abc = xyz(find(diff(xyz)~=1)+1);
    res = [xyz(1), abc];
else
    res = [];
end

end