function [mask_centroids,mask_values] = FindMaskCentroids(mask)
% find mask centroids

% mask = segment.mask;

mask_values = unique(mask);
mask_values = mask_values(2:end); % exclude 0

mask_centroids = zeros(numel(mask_values),2);

for i=1:numel(mask_values)
    bin_mask = mask == mask_values(i);
    tmp = regionprops(bin_mask, 'centroid');
    try
        mask_centroids(i,:) = tmp.Centroid;
    catch
        mask_centroids(i,:) = NaN;
    end
end
end

