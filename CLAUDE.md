# CLAUDE.md

Guidance for Claude (and people) working in this repository.

## What this repo is

A reproducible MATLAB build of the census datasets that
[Generic_Bugsplat](https://github.com/nicklasorte/Generic_Bugsplat) and
[Census_Functions](https://github.com/nicklasorte/Census_Functions) load:
2020 Census tract population, internal points, urban area (UA) membership,
and FCC Partial Economic Areas (PEAs). The code, the small source files, and
the outputs are all committed. The large TIGER/Line downloads live in
`cache/` (ignored by Git).

## Run it

```matlab
init_build_census_datasets_rev1        % build, validate, save (minutes; uses data/tiger<year>/derived)
results = runtests("tests")            % tests
```

Every TIGER/Line release builds into `data/tiger<year>/` and
`reports/tiger<year>/`. Set `tiger_year` in the entry script (2026 is the
default and most recent; 2023 is the release the legacy files used). Both are
committed. Set `cfg.tf_rebuild_blocks = true` to redo the 6 GB block pass
instead of reading `derived/`.

To add a release, build it with its year, run the tests, and commit its
`data/tiger<year>/` and `reports/tiger<year>/` folders. Don't overwrite
another release's folder.

To make a newer release the default, change `cfg.default_tiger_year` and the
`tiger_year` default in `census_config_rev1`, and the default year in the
entry scripts. The tests load the default release, so update the hard-coded
`tiger2026` paths in their comments too.

## Output contract (don't break it)

Downstream code indexes these by column number, so:

- Keep the file names and variable names, including the `2023` in file names
  and the variable `new_full_census_2020` inside the UA file.
- Never reorder or change the meaning of existing columns. Add new columns
  only at the end, and document them in `README.md` and in the builder's
  help text.
- `cell_pea_census_data_2020` column 9 holds tract latitude only (N x 1).
  This matches the legacy file on purpose; the N x 2 version is column 10.
- GEOIDs are stored as `double` (exact for 11- and 12-digit codes).
  Generic_Bugsplat matches UA and PEA column 6 against
  `new_full_census_2020(:,1)` with `==`, so those must stay tract GEOIDs.

Column definitions are in `README.md`.

## Rules for changes

- Follow the MATLAB conventions in this repo: `snake_case`, `_revN` file
  suffixes (bump the suffix for a behavior change), `arguments` blocks, and
  `error()` with an identifier instead of silent fixes.
- No invented constants. Expected totals and URLs live in
  `src/census_config_rev1.m` with their source.
- Any build change must keep `validate_census_datasets_rev1` passing, and the
  tests must pass before you commit. Add a test for new behavior.
- Assign blocks to tracts by GEOID prefix, never by point-in-polygon, except
  the documented Connecticut repeated tract codes.
- Assign tracts to PEAs by county (47 CFR Part 27 list plus
  `data/raw/county_fips_changes.csv`). If a new county code appears, the
  build fails; add the code to that CSV with its source.
- `tools/reference_python/` is an independent reimplementation used to
  cross-check the MATLAB build. Keep it in step when rules change. Each script
  takes `<cache_folder> <repo_folder> <tiger_year>`.

## Known facts that are easy to get wrong

- TIGER/Line block files keep the 2020 county codes for Connecticut, while
  tracts use the 2022 planning-region codes. Match Connecticut blocks by tract
  code; codes 990000 and 990100 repeat and are resolved with `inpolygon`.
- The Census Bureau web firewall sometimes rejects one exact URL (seen for the
  Hawaii tract file). `download_source_rev1` retries with a query string.
- The 2026 Gazetteer is `|`-delimited; earlier ones are tab-delimited.
- Tract population totals: 331,449,281 (50 states and DC), 3,285,874 (Puerto
  Rico), 338,021 (Island Areas), 335,073,176 in all.
