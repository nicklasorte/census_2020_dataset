%INIT_BUILD_CENSUS_DATASETS_REV1 Rebuild the census tract, urban area, and PEA datasets.
%   Run this script from anywhere. It downloads the Census Bureau sources
%   into cache/ (about 7 GB the first time), builds the four .mat files in
%   data/tiger<year>/, validates them, and writes
%   reports/tiger<year>/validation_report.md.
%
%   By default the 6 GB block pass is skipped when data/tiger<year>/derived/ already
%   holds its results (committed to the repo). Set tf_rebuild_blocks = true
%   below to redo it from the TIGER/Line block files.
%
%   Run the tests afterwards:  runtests("tests")

clear; close all;
repo_folder = string(fileparts(mfilename("fullpath")));
addpath(fullfile(repo_folder, "src"));

tiger_year = 2026;   % builds into data/tiger<year>/. 2026: most recent release.
                     % 2023: the release the legacy Census_Functions files used.
cfg = census_config_rev1(repo_folder, fullfile(repo_folder, "cache"), tiger_year);
cfg.tf_rebuild_blocks = false;           % true: redo the block pass (about 6 GB)
cfg.tf_redownload     = false;           % true: fetch every source again

tic;
[d, report] = build_census_datasets_rev1(cfg);
disp(report);
fprintf("Done in %.1f minutes.\n", toc / 60);
