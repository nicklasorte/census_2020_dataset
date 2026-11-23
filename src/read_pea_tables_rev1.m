function [pea_names, pea_counties, county_changes] = read_pea_tables_rev1(cfg)
%READ_PEA_TABLES_REV1 FCC Partial Economic Area names and county lists.
%   [pea_names, pea_counties, county_changes] = read_pea_tables_rev1(cfg)
%
%   pea_names:      PEA_Num, PEA_Name, from FCC DA 14-759, Appendix A
%                   (transcribed to data/raw/pea_names_DA-14-759.csv).
%   pea_counties:   PEA_Num, FIPS (5-character string), County, State, from
%                   47 CFR Part 27, Appendix A to Subpart A (eCFR XML in data/raw).
%   county_changes: current county FIPS -> FIPS used in the 47 CFR list, for
%                   counties created or renamed after 2010.

arguments
    cfg (1,1) struct
end

%%%%%%%%%% PEA names
o = detectImportOptions(cfg.file.pea_names);
o = setvartype(o, "PEA_Name", "string");
pea_names = readtable(cfg.file.pea_names, o);
if ~isequal(pea_names.PEA_Num(:)', 1:cfg.expected.num_pea)
    error("census:pea", "PEA name list must hold PEAs 1 to %d in order.", cfg.expected.num_pea);
end

%%%%%%%%%% PEA county list from the eCFR XML
% Built-ins considered: htmlTree needs Text Analytics Toolbox (not
% installed); readstruct returns mixed-content structs whose shape varies
% with the <br/> tags in the header row. The table body is regular, so a
% regexp over its <TR> rows is the simplest reliable parse.
txt = fileread(cfg.file.pea_counties);
start_idx = strfind(txt, '<DIV9 N="Appendix A to Subpart A of Part 27"');
if numel(start_idx) ~= 1
    error("census:pea", "Appendix A to Subpart A not found in %s", cfg.file.pea_counties);
end
seg = txt(start_idx:end);
seg = seg(1:strfind(seg, '</DIV9>') - 1);
rows = regexp(seg, '<TR>(.*?)</TR>', 'tokens');
num_rows = numel(rows);
pea_num = NaN(num_rows, 1);
fips = strings(num_rows, 1);
county = strings(num_rows, 1);
state = strings(num_rows, 1);
for k = 1:num_rows
    td = regexp(rows{k}{1}, '<TD[^>]*>(.*?)</TD>', 'tokens');
    if numel(td) ~= 4
        continue   % header row (TH cells)
    end
    pea_num(k) = str2double(td{1}{1});
    fips(k) = strtrim(td{2}{1});
    county(k) = strtrim(td{3}{1});
    state(k) = strtrim(td{4}{1});
end
keep = ~isnan(pea_num);
pea_counties = table(pea_num(keep), fips(keep), county(keep), state(keep), ...
    'VariableNames', {'PEA_Num', 'FIPS', 'County', 'State'});
if ~isequal(unique(pea_counties.PEA_Num)', 1:cfg.expected.num_pea)
    error("census:pea", "47 CFR county list must cover every PEA.");
end
if any(strlength(pea_counties.FIPS) ~= 5) || numel(unique(pea_counties.FIPS)) ~= height(pea_counties)
    error("census:pea", "47 CFR county FIPS codes must be unique 5-character codes.");
end
ct = startsWith(pea_counties.FIPS, "09");
if any(pea_counties.PEA_Num(ct) ~= 1)
    error("census:pea", "The Connecticut crosswalk assumes every Connecticut county is in PEA 1.");
end

%%%%%%%%%% County changes since the 2010-based list
o = detectImportOptions(cfg.file.county_changes);
o = setvartype(o, ["current_county_fips", "cfr_county_fips", "note"], "string");
county_changes = readtable(cfg.file.county_changes, o);
end
