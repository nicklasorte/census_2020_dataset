# Plan and decisions

This file records the plan for rebuilding the Census_Functions datasets and
the decisions made along the way. For how to run the build and what each
column holds, see [README.md](README.md).

**Status**: Done. The build, checks, tests, and outputs are in this
repository. Last full MATLAB run: 2026-11-23, R2025b, TIGER/Line 2026.

## Goal

Rebuild these legacy files from public sources with MATLAB code that anyone
can rerun, and keep them loadable by
[Generic_Bugsplat](https://github.com/nicklasorte/Generic_Bugsplat)
(`scrap_data_pop_geo_id_pea_ua_2023_rev12_zone.m` and the functions it
calls) without code changes:

| Legacy file | Variable |
|---|---|
| `Cascade_new_full_census_2020.mat` | `new_full_census_2020` |
| `Cascade_new_full_census_2023_UA.mat` | `new_full_census_2020` |
| `cell_urbanarea_census_data_2020_2023.mat` | `cell_ua_census_data_2020` |
| `cell_pea_census_data_2020_2023.mat` | `cell_pea_census_data_2020` |

## Audit of the legacy files

- `Cascade_new_full_census_2020.mat`: state totals were right, but only
  55,349 of 84,512 non-Connecticut tracts had the right population (about 73
  million people in the wrong tract). The UA file's population column was
  correct for every tract.
- `cell_pea_census_data_2020_2023.mat`: the point-in-polygon assignment left
  520 tracts (492,278 people) out of every PEA, and column 9 holds only
  latitude (an indexing slip in `rev8`).
- The UA file and UA cell were consistent with each other and with the 2023
  TIGER/Line block data.

## Decisions

| # | Question | Decision |
|---|---|---|
| D1 | Which tract geography? | The most recent TIGER/Line release (2026). Same 85,529 tracts and GEOIDs as the legacy files, including the Connecticut planning-region codes. |
| D2 | Tract touching more than one urban area? | Keep the legacy rule: the smallest UACE. |
| D3 | Tract-to-PEA assignment? | By county, from the 47 CFR Part 27 county list. It matches the legacy assignment for all 85,009 tracts the legacy file placed and adds the 520 it missed. |
| D4 | PEA boundaries? | The FCC PEA shapefile, committed in `data/raw/FCC_PEAs_Website/`. Boundaries match the legacy file exactly. |
| D5 | PEA column 9? | Keep it as latitude only for now; tract `[lat lon]` is the new column 10. |
| D6 | Smaller unit for urban areas? | Add block-group-level urban pieces as UA columns 10-14, built from blocks, so the urban population is exact. Columns 6-7 stay tract-level because Generic_Bugsplat matches them against the tract GEOIDs of a zone. |
| D7 | New columns? | Only at the end of each output: tract array columns 6-7, UA cell columns 10-14, PEA cell column 10. |

## Verification

- `validate_census_datasets_rev1` runs inside the build and stops it before
  saving if a check fails. Results: [reports/validation_report.md](reports/validation_report.md).
- The MATLAB block pass over all 56 state-equivalents was run on 2026-11-23.
  Its tract results equal the committed `data/derived/tract_block_summary.csv`
  exactly, and its block group points agree to within 5e-13 degrees.
- An independent Python implementation (`tools/reference_python/`) produced
  the committed `.mat` files. The MATLAB build reproduces them exactly,
  except for polygon centroids (UA and PEA column 5), which differ by at most
  1.8e-8 degrees because MATLAB uses `polyshape` and Python uses Shapely.
- `tests/test_census_datasets_rev1.m` covers the committed data, the build
  functions, a replay of the Generic_Bugsplat zone workflow, and a full
  rebuild compared with the committed data.

## Follow-on work

Not started; each needs a go-ahead:

- Rerun analyses that used the legacy `Cascade_new_full_census_2020.mat` for
  tract population.
- Use UA columns 10-14 in Generic_Bugsplat for exact urban population inside
  a zone.
- Rebuild the 2010 file with the same pipeline.
