function [cell_ua_census_data_2020, cell_ua_contours] = build_ua_cell_rev2(F2, ua_pieces, uac_shp)
%BUILD_UA_CELL_REV2 Urban area cell, one row per urban area with tracts.
%   [cell_ua_census_data_2020, cell_ua_contours] = build_ua_cell_rev2(F2, ua_pieces, uac_shp)
%
%   Columns 1-9 keep the legacy layout used by Generic_Bugsplat
%   (urban_area_impact_overlap_xor_2020_rev2 reads 1, 2, 4, 6, and 7):
%       1) UA Name, 2) UACE, 3) [] (boundary only in cell_ua_contours),
%       4) UA Population (sum of column 7), 5) UA Centroid [lat lon]
%       (centroid of polyshape(lon, lat) of the boundary),
%       6) Census Tract Geo Id (tracts whose F2 column 5 is this UACE),
%       7) Tract Population, 8) [], 9) Tract Center [lat lon].
%   New columns, from 2020 Census blocks (block group level):
%       10) Block Group Geo Id of each urban piece (blocks of this urban area
%           inside one block group), 11) Piece Population,
%       12) Piece Center [lat lon] (population-weighted block internal points),
%       13) Parent Tract Geo Id of each piece (matches F2 column 1),
%       14) UA Population from blocks (sum of column 11).
%   Rows are sorted by column 4, descending, with ties kept in shapefile
%   record order (a stable sort, as the legacy rev8 code did; rev1 broke ties
%   by UACE). Urban areas with no assigned tract are dropped, as in the
%   legacy file.

arguments
    F2 (:,7) double
    ua_pieces table
    uac_shp (1,1) string {mustBeFile}
end

S = shaperead(uac_shp);
num_ua = numel(S);
uace_all = str2double(string({S.UACE20}))';
tract_uace = F2(:, 5);

ua_pieces = sortrows(ua_pieces, "BG_GEOID");
[tf_piece, piece_ua_idx] = ismember(ua_pieces.UACE, uace_all);
if ~all(tf_piece)
    error("census:ua", "Block UACE20 codes missing from the urban area file: %s", ...
        strjoin(string(unique(ua_pieces.UACE(~tf_piece))), ", "));
end

warn_state = warning("off", "MATLAB:polyshape:repairedBySimplify");
restore_warn = onCleanup(@() warning(warn_state));
cell_all = cell(num_ua, 14);
keep = false(num_ua, 1);
for ua_idx = 1:num_ua
    inside_idx = find(tract_uace == uace_all(ua_idx));
    if isempty(inside_idx)
        continue
    end
    keep(ua_idx) = true;
    poly_contour = polyshape(S(ua_idx).X, S(ua_idx).Y);
    [cent_x, cent_y] = centroid(poly_contour);
    p = ua_pieces(piece_ua_idx == ua_idx, :);
    cell_all{ua_idx, 1} = char(S(ua_idx).NAME20);
    cell_all{ua_idx, 2} = uace_all(ua_idx);
    cell_all{ua_idx, 3} = [S(ua_idx).Y(:), S(ua_idx).X(:)];
    cell_all{ua_idx, 4} = sum(F2(inside_idx, 4));
    cell_all{ua_idx, 5} = [cent_y, cent_x];
    cell_all{ua_idx, 6} = F2(inside_idx, 1);
    cell_all{ua_idx, 7} = F2(inside_idx, 4);
    cell_all{ua_idx, 8} = zeros(1, 0);
    cell_all{ua_idx, 9} = F2(inside_idx, [2, 3]);
    cell_all{ua_idx, 10} = str2double(p.BG_GEOID);
    cell_all{ua_idx, 11} = p.POP;
    cell_all{ua_idx, 12} = [p.LAT, p.LON];
    cell_all{ua_idx, 13} = str2double(p.TRACT_GEOID);
    cell_all{ua_idx, 14} = sum(p.POP);
end
cell_all = cell_all(keep, :);
[~, order_idx] = sort(cell2mat(cell_all(:, 4)), "descend");   % sort is stable
cell_ua_contours = cell_all(order_idx, :);
cell_ua_census_data_2020 = cell_ua_contours;
cell_ua_census_data_2020(:, 3) = {zeros(1, 0)};
end
