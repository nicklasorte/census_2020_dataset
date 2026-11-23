function checks = read_check_sources_rev1(cfg)
%READ_CHECK_SOURCES_REV1 Download and read the independent check sources.
%   checks = read_check_sources_rev1(cfg)
%
%   checks.cenpop:    2020 Centers of Population by tract (GEOID, POPULATION),
%                     an independent Census Bureau tabulation of tract population.
%   checks.gazetteer: Gazetteer tract file for cfg.gazetteer_year (GEOID,
%                     INTPTLAT, INTPTLONG).
%   Neither is used to build the outputs.

arguments
    cfg (1,1) struct
end

check_folder = fullfile(cfg.cache_folder, "check");

f = download_source_rev1(cfg.url.cenpop, check_folder, cfg.tf_redownload, cfg.download_retries);
o = detectImportOptions(f, "Delimiter", ",");
o = setvartype(o, ["STATEFP", "COUNTYFP", "TRACTCE"], "string");
cp = readtable(f, o);
checks.cenpop = table(cp.STATEFP + cp.COUNTYFP + cp.TRACTCE, cp.POPULATION, ...
    'VariableNames', {'GEOID', 'POPULATION'});

z = download_source_rev1(cfg.url.gazetteer, check_folder, cfg.tf_redownload, cfg.download_retries);
txt_files = unzip(z, fullfile(check_folder, "gazetteer"));
txt = string(txt_files(endsWith(txt_files, ".txt")));
% Gazetteer files up to 2025 are tab-delimited; the 2026 file uses "|".
o = detectImportOptions(txt, "Delimiter", ["\t", "|"], "VariableNamingRule", "preserve");
o.VariableNames = strtrim(o.VariableNames);
o = setvartype(o, ["USPS", "GEOID"], "string");
gz = readtable(txt, o);
checks.gazetteer = table(gz.GEOID, gz.INTPTLAT, gz.INTPTLONG, 'VariableNames', {'GEOID', 'INTPTLAT', 'INTPTLONG'});
end
