function [tract_sum, ua_pieces, block_check] = summarize_state_blocks_rev1(block_shp, state_tracts, tract_shp)
%SUMMARIZE_STATE_BLOCKS_REV1 Sum one state's 2020 Census blocks to tracts and urban pieces.
%   [tract_sum, ua_pieces, block_check] = summarize_state_blocks_rev1(block_shp, state_tracts, tract_shp)
%
%   block_shp:    TIGER/Line tl_YYYY_SS_tabblock20.shp
%   state_tracts: rows of the tract table for this state (GEOID, TRACTCE, ...)
%   tract_shp:    TIGER/Line tract .shp for this state (used only where a
%                 block's tract code matches more than one tract; see below)
%
%   tract_sum: one row per tract in state_tracts, in the same order:
%       GEOID, POP (sum of POP20), UACE_MIN (smallest UACE20 of any block in
%       the tract, NaN if none; legacy rev8 rule), NUM_UACE, URBAN_POP (POP20
%       of blocks with a UACE20).
%   ua_pieces: one row per (block group, urban area) pair with at least one
%       urban block: BG_GEOID (12 characters), TRACT_GEOID, UACE, POP,
%       LAT, LON. LAT/LON is the POP20-weighted mean of the blocks' internal
%       points, or the plain mean when POP is 0.
%   block_check: struct with the block count and population, for validation.
%
%   Blocks are assigned to tracts by GEOID prefix (string match, no
%   geometry). Exception: Connecticut blocks still carry the 2020 county
%   codes, but tracts use the 2022 planning-region codes, so Connecticut
%   blocks are matched by tract code (TRACTCE20 = TRACTCE). Two Connecticut
%   water tract codes (990000, 990100) repeat across planning regions; blocks
%   with a repeated code are placed by testing their internal point against
%   the candidate tract polygons with inpolygon.

arguments
    block_shp (1,1) string {mustBeFile}
    state_tracts table
    tract_shp (1,1) string {mustBeFile}
end

B = readgeotable(block_shp);
num_blocks = height(B);
geoid20 = string(B.GEOID20);
tractce20 = string(B.TRACTCE20);
blockce20 = string(B.BLOCKCE20);
pop = double(B.POP20);
uace = str2double(string(B.UACE20));   % "" -> NaN (not urban)
lat = str2double(string(B.INTPTLAT20));
lon = str2double(string(B.INTPTLON20));
if any(isnan(pop)) || any(isnan(lat)) || any(isnan(lon))
    error("census:block", "Block attributes did not parse in %s", block_shp);
end
bad_uace = ~ismissing(string(B.UACE20)) & strlength(string(B.UACE20)) > 0 & isnan(uace);
if any(bad_uace)
    error("census:block", "Unparseable UACE20 in %s", block_shp);
end

%%%%%%%%%% Tract of each block
state_fips = extractBefore(geoid20(1), 3);
direct_tract = extractBefore(geoid20, 12);
[tf_direct, loc] = ismember(direct_tract, state_tracts.GEOID);
if all(tf_direct)
    block_tract_idx = loc;
else
    % Connecticut-style mismatch: match on tract code within the state.
    [tf_code, loc_code] = ismember(tractce20, state_tracts.TRACTCE);
    if ~all(tf_code)
        error("census:block", "%d blocks in state %s match no tract.", nnz(~tf_code), state_fips);
    end
    block_tract_idx = loc_code;
    [code_list, ~, code_grp] = unique(state_tracts.TRACTCE);
    code_count = accumarray(code_grp, 1);
    dup_codes = code_list(code_count > 1);
    if ~isempty(dup_codes)
        S = shaperead(tract_shp, "UseGeoCoords", true);
        s_geoid = string({S.GEOID})';
        for k = 1:numel(dup_codes)
            cand = find(state_tracts.TRACTCE == dup_codes(k));
            blk = find(tractce20 == dup_codes(k));
            hit = false(numel(blk), numel(cand));
            for c = 1:numel(cand)
                s = S(s_geoid == state_tracts.GEOID(cand(c)));
                % Built-ins considered: isinterior(polyshape) needs a planar
                % polyshape per tract; inpolygon handles NaN-separated parts.
                hit(:, c) = inpolygon(lon(blk), lat(blk), s.Lon, s.Lat);
            end
            if any(sum(hit, 2) ~= 1)
                error("census:block", "Blocks with tract code %s in state %s are not inside exactly one tract.", dup_codes(k), state_fips);
            end
            [~, which_c] = max(hit, [], 2);
            block_tract_idx(blk) = cand(which_c);
        end
    end
end

%%%%%%%%%% Tract sums
num_tracts = height(state_tracts);
tract_pop = accumarray(block_tract_idx, pop, [num_tracts 1]);
is_urban = ~isnan(uace);
urban_pop = accumarray(block_tract_idx(is_urban), pop(is_urban), [num_tracts 1]);
uace_min = accumarray(block_tract_idx(is_urban), uace(is_urban), [num_tracts 1], @min, NaN);
uace_num = accumarray(block_tract_idx(is_urban), uace(is_urban), [num_tracts 1], @(v) numel(unique(v)), 0);
tract_sum = table(state_tracts.GEOID, tract_pop, uace_min, uace_num, urban_pop, ...
    'VariableNames', {'GEOID', 'POP', 'UACE_MIN', 'NUM_UACE', 'URBAN_POP'});

%%%%%%%%%% Urban pieces: (block group, urban area)
u_idx = find(is_urban);
bg_geoid = state_tracts.GEOID(block_tract_idx(u_idx)) + extractBefore(blockce20(u_idx), 2);
[grp, bg_key, uace_key] = findgroups(bg_geoid, uace(u_idx));
p = pop(u_idx);
piece_pop = accumarray(grp, p);
w_lat = accumarray(grp, p .* lat(u_idx));
w_lon = accumarray(grp, p .* lon(u_idx));
m_lat = accumarray(grp, lat(u_idx), [], @mean);
m_lon = accumarray(grp, lon(u_idx), [], @mean);
lon_span = accumarray(grp, lon(u_idx), [], @(v) max(v) - min(v));
if any(lon_span > 180)
    error("census:block", "An urban block group crosses the antimeridian; the mean longitude would be wrong.");
end
piece_lat = m_lat;
piece_lon = m_lon;
has_pop = piece_pop > 0;
piece_lat(has_pop) = w_lat(has_pop) ./ piece_pop(has_pop);
piece_lon(has_pop) = w_lon(has_pop) ./ piece_pop(has_pop);
ua_pieces = table(bg_key, extractBefore(bg_key, 12), uace_key, piece_pop, piece_lat, piece_lon, ...
    'VariableNames', {'BG_GEOID', 'TRACT_GEOID', 'UACE', 'POP', 'LAT', 'LON'});

block_check = struct('state', state_fips, 'num_blocks', num_blocks, 'pop', sum(pop), ...
    'urban_pop', sum(pop(is_urban)));
end
