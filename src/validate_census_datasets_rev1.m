function report = validate_census_datasets_rev1(d, expected, checks)
%VALIDATE_CENSUS_DATASETS_REV1 Run every check on the built datasets.
%   report = validate_census_datasets_rev1(d, expected, checks)
%
%   d:        struct with fields F1, F2, ua (cell_ua_census_data_2020), and
%             pea (cell_pea_census_data_2020).
%   expected: cfg.expected from census_config_rev1.
%   checks:   optional struct with independent sources:
%               .cenpop    table GEOID (string), POPULATION (CenPop2020_Mean_TR)
%               .gazetteer table GEOID (string), INTPTLAT, INTPTLONG
%   report:   table of check name, result, and detail.
%
%   Runs all checks, then raises one error listing every failure, so a
%   single run shows everything that is wrong.

arguments
    d (1,1) struct
    expected (1,1) struct
    checks (1,1) struct = struct()
end

names = strings(0, 1);
pass = false(0, 1);
detail = strings(0, 1);
    function add(name, ok, msg)
        names(end + 1, 1) = name;
        pass(end + 1, 1) = ok;
        detail(end + 1, 1) = msg;
    end

F1 = d.F1;
F2 = d.F2;
geoid = F2(:, 1);
pop = F2(:, 4);
state = floor(geoid / 1e9);
n = size(F2, 1);

%%%%%%%%%% Structure
add("F2 has 7 columns", size(F2, 2) == 7, sprintf("%d x %d", size(F2)));
add("F1 equals F2 columns 1-4", isequal(F1, F2(:, 1:4)), "");
add("GEOIDs unique 11-digit integers", numel(unique(geoid)) == n && all(geoid == round(geoid)) ...
    && all(geoid >= 1e9 & geoid < 1e11), sprintf("%d tracts", n));
add("No NaN outside UA column", ~any(isnan(F2(:, [1:4, 6, 7])), 'all'), "");
ua_col = F2(:, 5);
add("UA codes are positive integers or NaN", all(isnan(ua_col) | (ua_col > 0 & ua_col == round(ua_col))), ...
    sprintf("%d tracts in an urban area", nnz(~isnan(ua_col))));
add("Latitude and longitude in range", all(F2(:, 2) >= -15 & F2(:, 2) <= 72 & F2(:, 3) >= -180 & F2(:, 3) <= 180), "");
add("Urban population <= population", all(F2(:, 7) <= pop & F2(:, 7) >= 0), "");
add("Tracts with no UA have no urban population", all(F2(isnan(ua_col), 7) == 0), "");

%%%%%%%%%% Population totals
add("Total population", sum(pop) == expected.pop_total, sprintf("%d (expected %d)", sum(pop), expected.pop_total));
is_50dc = state <= 56;
add("Population, 50 states and DC", sum(pop(is_50dc)) == expected.pop_50_dc, sprintf("%d", sum(pop(is_50dc))));
add("Population, Puerto Rico", sum(pop(state == 72)) == expected.pop_pr, sprintf("%d", sum(pop(state == 72))));
for k = 1:size(expected.pop_island, 1)
    s = expected.pop_island(k, 1);
    add(sprintf("Population, FIPS %d", s), sum(pop(state == s)) == expected.pop_island(k, 2), sprintf("%d", sum(pop(state == s))));
end

%%%%%%%%%% Urban area cell
ua = d.ua;
num_ua = size(ua, 1);
ua_rows_ok = true;
shape_ok = true;
for k = 1:num_ua
    g = ua{k, 6};
    expected_g = geoid(ua_col == ua{k, 2});
    ua_rows_ok = ua_rows_ok && isequal(g, expected_g) && isequal(ua{k, 7}, pop(ua_col == ua{k, 2})) ...
        && ua{k, 4} == sum(ua{k, 7}) && isequal(ua{k, 9}, F2(ua_col == ua{k, 2}, [2, 3])) ...
        && ua{k, 14} == sum(ua{k, 11}) && all(ismember(ua{k, 13}, geoid)) ...
        && all(floor(ua{k, 10} / 10) == ua{k, 13});
    shape_ok = shape_ok && size(g, 2) == 1 && size(ua{k, 9}, 2) == 2 && isequal(size(ua{k, 5}), [1 2]) ...
        && size(ua{k, 12}, 2) == 2 && ischar(ua{k, 1});
end
add("UA rows match F2 (tracts, populations, points, sums)", ua_rows_ok, sprintf("%d urban areas", num_ua));
add("UA column shapes match the legacy layout", shape_ok, "");
all_ua_tracts = vertcat(ua{:, 6});
add("Every urban tract is in exactly one UA row", numel(all_ua_tracts) == nnz(~isnan(ua_col)) ...
    && numel(unique(all_ua_tracts)) == numel(all_ua_tracts), sprintf("%d tracts", numel(all_ua_tracts)));
ua_pop = cell2mat(ua(:, 4));
add("UA rows sorted by population, descending", issorted(ua_pop, "descend"), "");
block_urban = sum(cell2mat(ua(:, 14)));
add("Block-level UA population <= urban population of all tracts", block_urban <= sum(F2(:, 7)), ...
    sprintf("%d of %d (rest is in UAs with no assigned tract)", block_urban, sum(F2(:, 7))));

%%%%%%%%%% PEA cell
pea = d.pea;
add("PEA cell has 416 rows, PEA 1-416 in order", size(pea, 1) == expected.num_pea ...
    && isequal(cell2mat(pea(:, 2))', 1:expected.num_pea), "");
all_pea_tracts = vertcat(pea{:, 6});
add("Every tract is in exactly one PEA", numel(all_pea_tracts) == n && isempty(setxor(all_pea_tracts, geoid)), ...
    sprintf("%d tracts", numel(all_pea_tracts)));
add("PEA populations sum to the total", sum(cell2mat(pea(:, 4))) == expected.pop_total, ...
    sprintf("%d", sum(cell2mat(pea(:, 4)))));
pea_ok = true;
for k = 1:size(pea, 1)
    idx = F2(:, 6) == pea{k, 2};
    b = pea{k, 3};
    pea_ok = pea_ok && isequal(pea{k, 6}, geoid(idx)) && isequal(pea{k, 7}, pop(idx)) ...
        && pea{k, 4} == sum(pea{k, 7}) && isequal(pea{k, 9}, F2(idx, 2)) && isequal(pea{k, 10}, F2(idx, [2 3])) ...
        && isequal(size(pea{k, 5}), [1 2]) && size(b, 2) == 2 && (isempty(b) || all(isnan(b(end, :)))) ...
        && ischar(pea{k, 1});
end
add("PEA rows match F2 and the legacy layout", pea_ok, "");

%%%%%%%%%% Independent sources
if isfield(checks, "cenpop")
    cp = checks.cenpop;
    sel = state ~= 9 & (state <= 56 | state == 72);   % CenPop covers 50 states, DC, PR; Connecticut uses 2020 counties
    [tf, loc] = ismember(geoid(sel), str2double(cp.GEOID));
    ok = all(tf) && isequal(pop(sel), cp.POPULATION(loc));
    add("Tract population equals CenPop2020 (non-Connecticut)", ok, sprintf("%d of %d tracts match", ...
        nnz(tf & pop(sel) == cp.POPULATION(max(loc, 1))), nnz(sel)));
end
if isfield(checks, "gazetteer")
    gz = checks.gazetteer;
    [tf, loc] = ismember(geoid, str2double(gz.GEOID));
    dlat = abs(F2(tf, 2) - gz.INTPTLAT(loc(tf)));
    dlon = abs(F2(tf, 3) - gz.INTPTLONG(loc(tf)));
    add("Internal points equal the Gazetteer", all(dlat < 1e-6 & dlon < 1e-6) && nnz(tf) == height(gz), ...
        sprintf("%d tracts compared, max difference %.2g degrees", nnz(tf), max([dlat; dlon; 0])));
end

report = table(names, pass, detail, 'VariableNames', {'Check', 'Pass', 'Detail'});
if ~all(pass)
    error("census:validate", "Validation failed:\n%s", strjoin("  " + names(~pass) + "  " + detail(~pass), newline));
end
end
