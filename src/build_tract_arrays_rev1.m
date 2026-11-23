function [new_full_census_2020_4col, new_full_census_2020_ua] = build_tract_arrays_rev1(tract_tbl, tract_sum, pea_counties, county_changes)
%BUILD_TRACT_ARRAYS_REV1 Build the two tract arrays.
%   [F1, F2] = build_tract_arrays_rev1(tract_tbl, tract_sum, pea_counties, county_changes)
%
%   F2 (saved as Cascade_new_full_census_2023_UA.mat, variable new_full_census_2020):
%       1) Geo Id, 2) Center Lat, 3) Center Lon, 4) Population, 5) UA Number
%       (legacy columns, same meaning), then new columns:
%       6) PEA Number, 7) Urban Population (POP20 of the tract's blocks that
%       are in any urban area).
%   F1 (saved as Cascade_new_full_census_2020.mat, variable new_full_census_2020):
%       columns 1-4 of F2.
%   "Center" is the TIGER/Line internal point (INTPTLAT/INTPTLON).

arguments
    tract_tbl table
    tract_sum table
    pea_counties table
    county_changes table
end

[tf, loc] = ismember(tract_tbl.GEOID, tract_sum.GEOID);
if ~all(tf) || height(tract_sum) ~= height(tract_tbl)
    error("census:tract", "Block summary and tract list don't hold the same tracts.");
end
s = tract_sum(loc, :);
pea_num = assign_county_pea_rev1(extractBefore(tract_tbl.GEOID, 6), pea_counties, county_changes);

new_full_census_2020_ua = [str2double(tract_tbl.GEOID), tract_tbl.LAT, tract_tbl.LON, ...
    s.POP, s.UACE_MIN, pea_num, s.URBAN_POP];
new_full_census_2020_4col = new_full_census_2020_ua(:, 1:4);
end
