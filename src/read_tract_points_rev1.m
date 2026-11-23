function tract_tbl = read_tract_points_rev1(tract_zips, unzip_folder)
%READ_TRACT_POINTS_REV1 Tract GEOID and internal point from TIGER/Line tract files.
%   tract_tbl = read_tract_points_rev1(tract_zips, unzip_folder)
%
%   tract_zips: string array of tl_YYYY_SS_tract.zip paths, in state FIPS order.
%   tract_tbl:  table with GEOID (string, 11 characters), STATEFP, TRACTCE,
%               LAT, LON (TIGER/Line INTPTLAT/INTPTLON), in state order and,
%               within a state, shapefile record order (as the legacy files).

arguments
    tract_zips (:,1) string
    unzip_folder (1,1) string
end

num_states = numel(tract_zips);
cell_tbl = cell(num_states, 1);
for state_idx = 1:num_states
    shp = read_shapefile_zip_rev1(tract_zips(state_idx), unzip_folder);
    T = readgeotable(shp);
    cell_tbl{state_idx} = table(string(T.GEOID), string(T.STATEFP), string(T.TRACTCE), ...
        str2double(T.INTPTLAT), str2double(T.INTPTLON), ...
        'VariableNames', {'GEOID', 'STATEFP', 'TRACTCE', 'LAT', 'LON'});
end
tract_tbl = vertcat(cell_tbl{:});

if any(strlength(tract_tbl.GEOID) ~= 11)
    error("census:tract", "Tract GEOIDs must have 11 characters.");
end
if numel(unique(tract_tbl.GEOID)) ~= height(tract_tbl)
    error("census:tract", "Duplicate tract GEOIDs.");
end
if any(isnan(tract_tbl.LAT) | isnan(tract_tbl.LON))
    error("census:tract", "Tract internal point did not parse.");
end
end
