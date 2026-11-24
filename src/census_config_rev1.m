function cfg = census_config_rev1(repo_folder, cache_folder)
%CENSUS_CONFIG_REV1 Settings, source URLs, and expected values for the build.
%   cfg = census_config_rev1(repo_folder, cache_folder)
%
%   Every URL and expected value is listed here so that one file shows what
%   the build depends on. Change tiger_year to rebuild from a newer
%   TIGER/Line release; the population totals stay the same because every
%   TIGER/Line block file carries the 2020 Census counts (POP20).

arguments
    repo_folder (1,1) string
    cache_folder (1,1) string = fullfile(repo_folder, "cache")
end

cfg = struct();
cfg.repo_folder  = repo_folder;
cfg.cache_folder = cache_folder;
cfg.raw_folder     = fullfile(repo_folder, "data", "raw");
cfg.derived_folder = fullfile(repo_folder, "data", "derived");
cfg.data_folder    = fullfile(repo_folder, "data");
cfg.report_folder  = fullfile(repo_folder, "reports");

%%%%%%%%%% Source vintages (most recent releases as of 2026-11-23)
cfg.tiger_year     = 2026;   % TIGER/Line shapefiles: tracts, blocks, urban areas, states
cfg.gazetteer_year = 2026;   % Gazetteer tract file, used only as a check

ty = string(cfg.tiger_year);
tiger = "https://www2.census.gov/geo/tiger/TIGER" + ty + "/";
cfg.url.state  = tiger + "STATE/tl_" + ty + "_us_state.zip";
cfg.url.tract  = tiger + "TRACT/tl_" + ty + "_%s_tract.zip";          % %s = state FIPS
cfg.url.block  = tiger + "TABBLOCK20/tl_" + ty + "_%s_tabblock20.zip"; % %s = state FIPS
cfg.url.uac    = tiger + "UAC20/tl_" + ty + "_us_uac20.zip";

%%%%%%%%%% Independent check sources (not used to build the outputs)
zy = string(cfg.gazetteer_year);
cfg.url.gazetteer = "https://www2.census.gov/geo/docs/maps-data/data/gazetteer/" + zy + "_Gazetteer/" + zy + "_Gaz_tracts_national.zip";
cfg.url.cenpop    = "https://www2.census.gov/geo/docs/reference/cenpop2020/tract/CenPop2020_Mean_TR.txt";
cfg.url.ecfr_pea  = "https://www.ecfr.gov/api/versioner/v1/full/2026-11-20/title-47.xml?part=27&subpart=A";

%%%%%%%%%% Legacy files (Census_Functions, built from TIGER/Line 2023), for compare_legacy_datasets_rev1
legacy = "https://raw.githubusercontent.com/nicklasorte/Census_Functions/main/";
cfg.url.legacy_2020 = legacy + "Cascade_new_full_census_2020.mat";
cfg.url.legacy_ua   = legacy + "Cascade_new_full_census_2023_UA.mat";
cfg.url.legacy_pea  = legacy + "cell_pea_census_data_2020_2023.mat";

%%%%%%%%%% Committed raw files (small, kept in data/raw)
cfg.file.pea_names      = fullfile(cfg.raw_folder, "pea_names_DA-14-759.csv");     % FCC DA 14-759, Appendix A
cfg.file.pea_counties   = fullfile(cfg.raw_folder, "ecfr_47cfr_part27_subpartA.xml"); % 47 CFR Part 27 App. A to Subpart A
cfg.file.county_changes = fullfile(cfg.raw_folder, "county_fips_changes.csv");
cfg.file.pea_shp        = fullfile(cfg.raw_folder, "FCC_PEAs_Website", "FCC_PEAs_website.shp"); % FCC PEA boundaries

%%%%%%%%%% Expected 2020 Census resident population (exact)
% 50 states + DC: 2020 Census apportionment-base resident population, 331,449,281.
% Puerto Rico: 3,285,874. Island Areas (2020 Island Areas Censuses):
% American Samoa 49,710; Guam 153,836; Northern Mariana Islands 47,329;
% U.S. Virgin Islands 87,146.
cfg.expected.pop_50_dc       = 331449281;
cfg.expected.pop_pr          = 3285874;
cfg.expected.pop_island      = [60 49710; 66 153836; 69 47329; 78 87146];
cfg.expected.pop_total       = 331449281 + 3285874 + 49710 + 153836 + 47329 + 87146; % 335,073,176
cfg.expected.num_pea         = 416;

%%%%%%%%%% Build flags
cfg.tf_redownload    = false;  % true: fetch every source again
cfg.tf_rebuild_blocks = false; % true: redo the block pass even if data/derived exists
cfg.download_retries = 5;
cfg.tf_write_manifest = true; % false: skip hashing the sources (about 6 GB when blocks are cached)
end
