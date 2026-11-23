function [tract_sum, ua_pieces, block_checks] = build_block_summaries_rev1(cfg, tract_tbl, state_fips, tf_write)
%BUILD_BLOCK_SUMMARIES_REV1 Block pass over every state (about 6 GB of downloads).
%   [tract_sum, ua_pieces, block_checks] = build_block_summaries_rev1(cfg, tract_tbl, state_fips, tf_write)
%
%   Set tf_write to false to process a subset of states (for example, to
%   split a long run); only a full run writes the data/derived CSV files.
%
%   Writes data/derived/tract_block_summary.csv and data/derived/bg_ua_pieces.csv.
%   When both files exist and cfg.tf_rebuild_blocks is false, reads them
%   instead of downloading blocks. Each state's result is also cached in
%   cache/block_summary/ so that an interrupted run resumes where it stopped.

arguments
    cfg (1,1) struct
    tract_tbl table
    state_fips (:,1) string
    tf_write (1,1) logical = true
end

tract_csv = fullfile(cfg.derived_folder, "tract_block_summary.csv");
piece_csv = fullfile(cfg.derived_folder, "bg_ua_pieces.csv");
if tf_write && ~cfg.tf_rebuild_blocks && isfile(tract_csv) && isfile(piece_csv)
    [tract_sum, ua_pieces] = read_derived(tract_csv, piece_csv);
    block_checks = struct([]);
    return
end

num_states = numel(state_fips);
cell_tract = cell(num_states, 1);
cell_piece = cell(num_states, 1);
block_checks = repmat(struct('state', "", 'num_blocks', 0, 'pop', 0, 'urban_pop', 0), num_states, 1);
state_cache = fullfile(cfg.cache_folder, "block_summary");
if ~isfolder(state_cache)
    mkdir(state_cache);
end
for state_idx = 1:num_states
    fips = state_fips(state_idx);
    cache_file = fullfile(state_cache, "block_summary_" + fips + "_" + cfg.tiger_year + ".mat");
    state_tracts = tract_tbl(tract_tbl.STATEFP == fips, :);
    if isfile(cache_file) && ~cfg.tf_rebuild_blocks
        S = load(cache_file, "ts", "up", "bc");
    else
        fprintf("Blocks %s (%d of %d)\n", fips, state_idx, num_states);
        block_zip = download_source_rev1(sprintf(cfg.url.block, fips), ...
            fullfile(cfg.cache_folder, "block"), cfg.tf_redownload, cfg.download_retries);
        tract_zip = download_source_rev1(sprintf(cfg.url.tract, fips), ...
            fullfile(cfg.cache_folder, "tract"), false, cfg.download_retries);
        block_shp = read_shapefile_zip_rev1(block_zip, fullfile(cfg.cache_folder, "unzip"));
        tract_shp = read_shapefile_zip_rev1(tract_zip, fullfile(cfg.cache_folder, "unzip"));
        [S.ts, S.up, S.bc] = summarize_state_blocks_rev1(block_shp, state_tracts, tract_shp);
        ts = S.ts; up = S.up; bc = S.bc; %#ok<NASGU> saved below
        save(cache_file, "ts", "up", "bc");
        rmdir(fileparts(block_shp), "s");   % unzipped block files are large; keep only the zip
    end
    cell_tract{state_idx} = S.ts;
    cell_piece{state_idx} = S.up;
    block_checks(state_idx) = S.bc;
end
tract_sum = vertcat(cell_tract{:});
ua_pieces = vertcat(cell_piece{:});
if ~tf_write
    return
end

if ~isfolder(cfg.derived_folder)
    mkdir(cfg.derived_folder);
end
writetable(tract_sum, tract_csv);
writetable(ua_pieces, piece_csv);
% Always continue from the CSV text so that a fresh run and a run from the
% committed CSV files produce identical outputs.
[tract_sum, ua_pieces] = read_derived(tract_csv, piece_csv);
end

function [tract_sum, ua_pieces] = read_derived(tract_csv, piece_csv)
% GEOIDs must be read as text, or readtable drops their leading zeros.
o = detectImportOptions(tract_csv);
o = setvartype(o, "GEOID", "string");
o = setvartype(o, ["POP", "UACE_MIN", "NUM_UACE", "URBAN_POP"], "double");
tract_sum = readtable(tract_csv, o);
o = detectImportOptions(piece_csv);
o = setvartype(o, ["BG_GEOID", "TRACT_GEOID"], "string");
o = setvartype(o, ["UACE", "POP", "LAT", "LON"], "double");
ua_pieces = readtable(piece_csv, o);
end
