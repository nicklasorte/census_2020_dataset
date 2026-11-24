function tests = test_census_datasets_rev1
%TEST_CENSUS_DATASETS_REV1 Tests for the committed datasets and the build functions.
%   Run from the repo folder:  results = runtests("tests")
%
%   Tests that need the network or the downloaded cache are filtered (not
%   failed) when those aren't available.
tests = functiontests(localfunctions);
end

function setupOnce(tc)
repo_folder = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(fullfile(repo_folder, "src"));
tc.TestData.cfg = census_config_rev1(repo_folder);
data = fullfile(repo_folder, "data");
d.F1 = getfield(load(fullfile(data, "Cascade_new_full_census_2020.mat"), "new_full_census_2020"), "new_full_census_2020");
d.F2 = getfield(load(fullfile(data, "Cascade_new_full_census_2023_UA.mat"), "new_full_census_2020"), "new_full_census_2020");
d.ua = getfield(load(fullfile(data, "cell_urbanarea_census_data_2020_2023.mat"), "cell_ua_census_data_2020"), "cell_ua_census_data_2020");
d.pea = getfield(load(fullfile(data, "cell_pea_census_data_2020_2023.mat"), "cell_pea_census_data_2020"), "cell_pea_census_data_2020");
tc.TestData.d = d;
end

%%%%%%%%%% Committed data
function testValidationPasses(tc)
report = validate_census_datasets_rev1(tc.TestData.d, tc.TestData.cfg.expected);
verifyTrue(tc, all(report.Pass));
end

function testIndependentSources(tc)
try
    checks = read_check_sources_rev1(tc.TestData.cfg);
catch err
    assumeFail(tc, "Check sources unavailable: " + err.message);
end
report = validate_census_datasets_rev1(tc.TestData.d, tc.TestData.cfg.expected, checks);
verifyTrue(tc, all(report.Pass));
verifyTrue(tc, any(contains(report.Check, "CenPop2020")));
verifyTrue(tc, any(contains(report.Check, "Gazetteer")));
end

function testLegacyLayout(tc)
% Column count, classes, and shapes that Generic_Bugsplat and Census_Functions code expect.
d = tc.TestData.d;
verifySize(tc, d.F1, [size(d.F2, 1) 4]);
verifyGreaterThanOrEqual(tc, size(d.F2, 2), 5);
verifyClass(tc, d.F2, "double");
verifyGreaterThanOrEqual(tc, size(d.ua, 2), 9);
verifyGreaterThanOrEqual(tc, size(d.pea, 2), 9);
verifyEqual(tc, size(d.pea, 1), 416);
for k = [1 size(d.ua, 1)]
    verifyClass(tc, d.ua{k, 1}, "char");
    verifySize(tc, d.ua{k, 5}, [1 2]);
    verifyEqual(tc, size(d.ua{k, 6}, 2), 1);
    verifyEqual(tc, size(d.ua{k, 7}, 2), 1);
    verifyEqual(tc, size(d.ua{k, 9}, 2), 2);
end
for k = [1 412 416]
    verifyClass(tc, d.pea{k, 1}, "char");
    verifySize(tc, d.pea{k, 5}, [1 2]);
    verifyEqual(tc, size(d.pea{k, 3}, 2), 2);
    verifyEqual(tc, size(d.pea{k, 9}, 2), 1);   % latitude only, as in the legacy file
end
verifyEqual(tc, d.pea{1, 1}, 'New York, NY');
verifyEqual(tc, d.pea{416, 1}, 'Gulf of Mexico');
verifyEmpty(tc, d.pea{416, 6});
end

function testBugsplatWorkflow(tc)
% Reproduce the Generic_Bugsplat zone workflow on a synthetic zone: tracts
% whose center is inside the zone (census2020_xor_poly_miti_rev2), then the
% urban area and PEA impact sums (urban_area_impact_overlap_xor_2020_rev2,
% pea_impact_overlap_xor_2020_rev2).
d = tc.TestData.d;
zone = polyshape([-77.6 -76.6 -76.6 -77.6], [38.5 38.5 39.4 39.4]);   % around Washington, DC
inside = isinterior(zone, d.F2(:, 3), d.F2(:, 2));
zone_geoid = d.F2(inside, 1);
verifyGreaterThan(tc, numel(zone_geoid), 500);

pea_num = find(strcmp(d.pea(:, 1), 'Baltimore, MD-Washington, DC'));
covered = sum(d.pea{pea_num, 7}(ismember(d.pea{pea_num, 6}, zone_geoid)));
verifyEqual(tc, covered, sum(d.F2(inside & d.F2(:, 6) == pea_num, 4)));
verifyGreaterThan(tc, covered / d.pea{pea_num, 4}, 0.3);

ua_idx = find(contains(d.ua(:, 1), "Washington--Arlington"));
verifyNumElements(tc, ua_idx, 1);
covered_ua = sum(d.ua{ua_idx, 7}(ismember(d.ua{ua_idx, 6}, zone_geoid)));
verifyGreaterThan(tc, covered_ua / sum(d.ua{ua_idx, 7}), 0.5);
% Block-group columns map back to the same zone through column 13.
bg_in = ismember(d.ua{ua_idx, 13}, zone_geoid);
verifyGreaterThan(tc, sum(d.ua{ua_idx, 11}(bg_in)) / d.ua{ua_idx, 14}, 0.5);
end

function testCsvMatchesMat(tc)
cfg = tc.TestData.cfg;
o = detectImportOptions(fullfile(cfg.data_folder, "census_2020_tracts.csv"));
o = setvartype(o, "GEOID", "string");
T = readtable(fullfile(cfg.data_folder, "census_2020_tracts.csv"), o);
verifyEqual(tc, str2double(T.GEOID), tc.TestData.d.F2(:, 1));
verifyEqual(tc, T.POP, tc.TestData.d.F2(:, 4));
verifyEqual(tc, T.PEA_NUM, tc.TestData.d.F2(:, 6));
end

function testBuildReproducesCommittedData(tc)
% Rebuild everything from data/derived into a temporary folder and compare
% with the committed outputs. Centroids of polygon boundaries (UA and PEA
% column 5) are compared within 1e-7 degrees (about 1 cm), because the
% committed files were cross-checked against an independent implementation;
% every other value must be identical.
cfg = tc.TestData.cfg;
out = string(tempname);
mkdir(out);
cleanup = onCleanup(@() rmdir(out, "s"));
cfg.data_folder = out;
cfg.report_folder = out;
cfg.tf_write_manifest = false;
cfg.tf_rebuild_blocks = false;
try
    d = build_census_datasets_rev1(cfg);
catch err
    if contains(err.identifier, "census:download")
        assumeFail(tc, "Sources unavailable: " + err.message);
    end
    rethrow(err);
end
c = tc.TestData.d;
verifyEqual(tc, d.F1, c.F1);
verifyEqual(tc, d.F2, c.F2);
verifySize(tc, d.ua, size(c.ua));
verifySize(tc, d.pea, size(c.pea));
verifyEqual(tc, d.ua(:, [1:4, 6:end]), c.ua(:, [1:4, 6:end]));
verifyEqual(tc, d.pea(:, [1:4, 6:end]), c.pea(:, [1:4, 6:end]));
verifyEqual(tc, cell2mat(d.ua(:, 5)), cell2mat(c.ua(:, 5)), "AbsTol", 1e-7);
verifyEqual(tc, cell2mat(d.pea(:, 5)), cell2mat(c.pea(:, 5)), "AbsTol", 1e-7);
end

function testLegacyComparisonCsv(tc)
% reports/legacy_comparison_tracts.csv must agree with the committed data.
cfg = tc.TestData.cfg;
f = fullfile(cfg.report_folder, "legacy_comparison_tracts.csv");
o = detectImportOptions(f);
o = setvartype(o, "GEOID", "string");
T = readtable(f, o);
F2 = tc.TestData.d.F2;
verifyEqual(tc, str2double(T.GEOID), F2(:, 1));
verifyEqual(tc, T.POP_NEW, F2(:, 4));
verifyEqual(tc, T.DELTA_POP_2020, T.POP_NEW - T.POP_LEGACY_2020);
verifyEqual(tc, T.DELTA_POP_UA, T.POP_NEW - T.POP_LEGACY_UA);
verifyEqual(tc, [T.LAT_NEW T.LON_NEW], F2(:, [2 3]));
verifyEqual(tc, T.LOCATION_CHANGED, double(T.LAT_NEW ~= T.LAT_LEGACY | T.LON_NEW ~= T.LON_LEGACY));
verifyTrue(tc, all(T.LOCATION_SHIFT_M(T.LOCATION_CHANGED == 0) == 0));
verifyEqual(tc, T.PEA_NEW, F2(:, 6));
verifyEqual(tc, sum(T.DELTA_POP_2020), 0);   % same total, different tracts
end

%%%%%%%%%% Build functions
function testAssignCountyPeaErrorsOnUnknownCounty(tc)
[~, pea_counties, county_changes] = read_pea_tables_rev1(tc.TestData.cfg);
verifyEqual(tc, assign_county_pea_rev1(["36061"; "09110"; "02063"; "46102"], pea_counties, county_changes), [1; 1; 264; 394]);
verifyError(tc, @() assign_county_pea_rev1("99999", pea_counties, county_changes), "census:pea");
end

function testPeaTables(tc)
[names, counties] = read_pea_tables_rev1(tc.TestData.cfg);
verifyEqual(tc, height(names), 416);
verifyEqual(tc, numel(unique(counties.PEA_Num)), 416);
verifyEqual(tc, counties.PEA_Num(counties.FIPS == "06037"), 2);   % Los Angeles County
end

function testBlockSummaryMatchesCommittedCsv(tc)
% Rerun the block pass for DC and Connecticut (repeated water tract codes)
% from the cached TIGER/Line files and compare with data/derived.
cfg = tc.TestData.cfg;
for fips = ["11", "09"]
    block_zip = fullfile(cfg.cache_folder, "block", sprintf("tl_%d_%s_tabblock20.zip", cfg.tiger_year, fips));
    tract_zip = fullfile(cfg.cache_folder, "tract", sprintf("tl_%d_%s_tract.zip", cfg.tiger_year, fips));
    if ~isfile(tract_zip) || ~isfile(block_zip)
        try
            block_zip = download_source_rev1(sprintf(cfg.url.block, fips), fullfile(cfg.cache_folder, "block"));
            tract_zip = download_source_rev1(sprintf(cfg.url.tract, fips), fullfile(cfg.cache_folder, "tract"));
        catch err
            assumeFail(tc, "TIGER/Line files unavailable: " + err.message);
        end
    end
    unzip_folder = fullfile(cfg.cache_folder, "unzip");
    tracts = read_tract_points_rev1(tract_zip, unzip_folder);
    [ts, up] = summarize_state_blocks_rev1(read_shapefile_zip_rev1(block_zip, unzip_folder), tracts, ...
        read_shapefile_zip_rev1(tract_zip, unzip_folder));
    [tract_sum, ua_pieces] = build_block_summaries_rev1(cfg, tracts, strings(0, 1));
    [tf, loc] = ismember(ts.GEOID, tract_sum.GEOID);
    verifyTrue(tc, all(tf));
    verifyEqual(tc, ts.POP, tract_sum.POP(loc));
    verifyEqual(tc, ts.UACE_MIN, tract_sum.UACE_MIN(loc));
    verifyEqual(tc, ts.URBAN_POP, tract_sum.URBAN_POP(loc));
    ref = ua_pieces(startsWith(ua_pieces.BG_GEOID, fips), :);
    up = sortrows(up, ["BG_GEOID", "UACE"]);
    ref = sortrows(ref, ["BG_GEOID", "UACE"]);
    verifyEqual(tc, up.BG_GEOID, ref.BG_GEOID);
    verifyEqual(tc, up.POP, ref.POP);
    verifyEqual(tc, [up.LAT up.LON], [ref.LAT ref.LON], "AbsTol", 1e-9);
end
end
