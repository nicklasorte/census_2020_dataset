function [cmp, summary] = compare_legacy_datasets_rev1(cfg, d)
%COMPARE_LEGACY_DATASETS_REV1 Tract-by-tract comparison with the legacy Census_Functions files.
%   [cmp, summary] = compare_legacy_datasets_rev1(cfg, d)
%
%   cfg: struct from census_config_rev1 (cfg.url.legacy_* name the files).
%   d:   struct with F2 (new tract array) and pea (new PEA cell).
%   cmp: one row per tract (new file order), written to
%        legacy_comparison_tracts.csv in cfg.report_folder (reports/tiger<year>/):
%          GEOID
%          POP_NEW, POP_LEGACY_2020, DELTA_POP_2020 (new - legacy,
%            Cascade_new_full_census_2020.mat), POP_LEGACY_UA, DELTA_POP_UA
%            (new - legacy, Cascade_new_full_census_2023_UA.mat)
%          LAT_NEW, LON_NEW, LAT_LEGACY, LON_LEGACY, LOCATION_CHANGED (1 if
%            either coordinate differs), LOCATION_SHIFT_M (WGS 84 geodesic
%            distance between the two points, meters)
%          UACE_NEW, UACE_LEGACY, UACE_CHANGED
%          PEA_NEW, PEA_LEGACY (NaN if the legacy PEA cell left the tract
%            out), PEA_CHANGED
%   summary: table of headline counts (init_compare_legacy_rev1 writes it to
%            legacy_comparison.md).
%
%   The legacy files came from TIGER/Line 2023; d comes from cfg.tiger_year.
%   The tract list is identical, so every difference is in a value, not a tract.

arguments
    cfg (1,1) struct
    d (1,1) struct
end

legacy_folder = fullfile(cfg.cache_folder, "legacy");
f20 = download_source_rev1(cfg.url.legacy_2020, legacy_folder, cfg.tf_redownload, cfg.download_retries);
fua = download_source_rev1(cfg.url.legacy_ua, legacy_folder, cfg.tf_redownload, cfg.download_retries);
fpea = download_source_rev1(cfg.url.legacy_pea, legacy_folder, cfg.tf_redownload, cfg.download_retries);
L20 = load(f20, "new_full_census_2020").new_full_census_2020;
LUA = load(fua, "new_full_census_2020").new_full_census_2020;
LPEA = load(fpea, "cell_pea_census_data_2020").cell_pea_census_data_2020;

F2 = d.F2;
geoid = F2(:, 1);
[tf20, i20] = ismember(geoid, L20(:, 1));
[tfua, iua] = ismember(geoid, LUA(:, 1));
if ~all(tf20) || ~all(tfua) || size(L20, 1) ~= numel(geoid) || size(LUA, 1) ~= numel(geoid)
    error("census:compare", "Legacy and new files don't hold the same tracts.");
end
if ~isequal(L20(i20, 1:3), LUA(iua, 1:3))
    error("census:compare", "Legacy 2020 and UA files disagree on tract locations.");
end

% Legacy PEA of each tract (NaN where the legacy point-in-polygon test missed it)
pea_g = vertcat(LPEA{:, 6});
pea_n = repelem(cell2mat(LPEA(:, 2)), cellfun(@numel, LPEA(:, 6)));
[tfp, ip] = ismember(geoid, pea_g);
pea_legacy = NaN(numel(geoid), 1);
pea_legacy(tfp) = pea_n(ip(tfp));

lat_legacy = LUA(iua, 2);
lon_legacy = LUA(iua, 3);
moved = F2(:, 2) ~= lat_legacy | F2(:, 3) ~= lon_legacy;
shift_m = distance(F2(:, 2), F2(:, 3), lat_legacy, lon_legacy, wgs84Ellipsoid("m"));
uace_legacy = LUA(iua, 5);
uace_changed = ~(F2(:, 5) == uace_legacy | (isnan(F2(:, 5)) & isnan(uace_legacy)));
pea_changed = ~(F2(:, 6) == pea_legacy);

cmp = table(compose("%011d", geoid), ...
    F2(:, 4), L20(i20, 4), F2(:, 4) - L20(i20, 4), LUA(iua, 4), F2(:, 4) - LUA(iua, 4), ...
    F2(:, 2), F2(:, 3), lat_legacy, lon_legacy, double(moved), shift_m, ...
    F2(:, 5), uace_legacy, double(uace_changed), F2(:, 6), pea_legacy, double(pea_changed), ...
    'VariableNames', {'GEOID', 'POP_NEW', 'POP_LEGACY_2020', 'DELTA_POP_2020', 'POP_LEGACY_UA', 'DELTA_POP_UA', ...
    'LAT_NEW', 'LON_NEW', 'LAT_LEGACY', 'LON_LEGACY', 'LOCATION_CHANGED', 'LOCATION_SHIFT_M', ...
    'UACE_NEW', 'UACE_LEGACY', 'UACE_CHANGED', 'PEA_NEW', 'PEA_LEGACY', 'PEA_CHANGED'});

if ~isfolder(cfg.report_folder)
    mkdir(cfg.report_folder);
end
writetable(cmp, fullfile(cfg.report_folder, "legacy_comparison_tracts.csv"));

%%%%%%%%%% Summary
s = @(x) sum(x);
items = [
    "Tracts compared", numel(geoid)
    "Tracts with a different population than legacy Cascade_new_full_census_2020", nnz(cmp.DELTA_POP_2020)
    "People in the wrong tract in legacy Cascade_new_full_census_2020 (sum of absolute deltas / 2)", s(abs(cmp.DELTA_POP_2020)) / 2
    "Tracts with a different population than legacy Cascade_new_full_census_2023_UA", nnz(cmp.DELTA_POP_UA)
    "Tracts whose location changed (TIGER/Line 2023 to " + cfg.tiger_year + " internal point)", nnz(moved)
    "Median location shift of changed tracts (m)", median(shift_m(moved))
    "95th percentile location shift of changed tracts (m)", prctile(shift_m(moved), 95)
    "Largest location shift (m)", max(shift_m)
    "Tracts whose urban area changed", nnz(uace_changed)
    "Tracts the legacy PEA cell left out", nnz(isnan(pea_legacy))
    "People the legacy PEA cell left out", s(F2(isnan(pea_legacy), 4))
    "Tracts assigned to a different PEA (among tracts legacy assigned)", nnz(pea_changed & ~isnan(pea_legacy))
    ];
summary = table(items(:, 1), str2double(items(:, 2)), 'VariableNames', {'Measure', 'Value'});
end
