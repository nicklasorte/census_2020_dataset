function cell_pea_census_data_2020 = build_pea_cell_rev1(F2, pea_names, pea_shp)
%BUILD_PEA_CELL_REV1 PEA cell, one row per FCC Partial Economic Area (1-416).
%   cell_pea_census_data_2020 = build_pea_cell_rev1(F2, pea_names, pea_shp)
%
%   F2:        tract array from build_tract_arrays_rev1 (column 6 = PEA number)
%   pea_names: PEA_Num, PEA_Name from FCC DA 14-759 (a check on the shapefile)
%   pea_shp:   FCC PEA shapefile (data/raw/FCC_PEAs_Website/FCC_PEAs_website.shp)
%
%   Columns 1-9 keep the legacy layout used by Generic_Bugsplat
%   (pea_impact_overlap_xor_2020_rev2 reads 6 and 7; the PEA table reads 1,
%   2, and 4; plot_pea_overlap_2023_rev3_filename reads 3 and 5):
%       1) PEA Name, 2) PEA Num, 3) PEA {Lat/Lon} boundary from the FCC
%       shapefile, each part followed by a NaN row, 4) PEA Pop (sum of
%       column 7), 5) PEA Centroid [lat lon] (centroid of polyshape(lon, lat),
%       as in the legacy rev8 code), 6) Census {Geo ID}, 7) Census
%       {Population}, 8) [] (legacy NLCD slot), 9) Census Centroid, latitude
%       only (N x 1, kept as in the legacy file).
%   New column: 10) Census Centroid [lat lon] (N x 2).
%
%   Tracts are assigned by county (F2 column 6, from the 47 CFR Part 27
%   county list), so every tract lands in exactly one PEA. The legacy file
%   tested tract centers against these polygons, which matched the county
%   assignment for every tract it placed but left 520 coastal and island
%   tracts out.

arguments
    F2 (:,7) double
    pea_names table
    pea_shp (1,1) string {mustBeFile}
end

S = shaperead(pea_shp);
num_pea = numel(S);
shp_num = [S.PEA_Num]';
shp_name = string({S.PEA_Name})';
if ~isequal(shp_num, pea_names.PEA_Num) || ~isequal(strtrim(shp_name), pea_names.PEA_Name)
    error("census:pea", "FCC PEA shapefile numbers or names don't match FCC DA 14-759.");
end

warn_state = warning("off", "MATLAB:polyshape:repairedBySimplify");
restore_warn = onCleanup(@() warning(warn_state));
cell_pea_census_data_2020 = cell(num_pea, 10);
for pea_idx = 1:num_pea
    pea_num = shp_num(pea_idx);
    temp_lon = S(pea_idx).X(:);
    temp_lat = S(pea_idx).Y(:);
    [cent_x, cent_y] = centroid(polyshape(temp_lon, temp_lat));
    inside_idx = find(F2(:, 6) == pea_num);
    cell_pea_census_data_2020{pea_idx, 1} = char(strtrim(shp_name(pea_idx)));
    cell_pea_census_data_2020{pea_idx, 2} = pea_num;
    cell_pea_census_data_2020{pea_idx, 3} = [temp_lat, temp_lon];
    cell_pea_census_data_2020{pea_idx, 4} = sum(F2(inside_idx, 4));
    cell_pea_census_data_2020{pea_idx, 5} = [cent_y, cent_x];
    cell_pea_census_data_2020{pea_idx, 6} = F2(inside_idx, 1);
    cell_pea_census_data_2020{pea_idx, 7} = F2(inside_idx, 4);
    cell_pea_census_data_2020{pea_idx, 8} = zeros(1, 0);
    cell_pea_census_data_2020{pea_idx, 9} = F2(inside_idx, 2);
    cell_pea_census_data_2020{pea_idx, 10} = F2(inside_idx, [2, 3]);
end
end
