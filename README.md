# census_2020_dataset

MATLAB code and data to rebuild the 2020 Census tract, urban area, and FCC
Partial Economic Area (PEA) datasets used by
[Generic_Bugsplat](https://github.com/nicklasorte/Generic_Bugsplat) and
[Census_Functions](https://github.com/nicklasorte/Census_Functions), from
public Census Bureau and FCC sources.

The outputs drop into existing code: same file names, same variable names,
and the same columns in the same order. New columns are added only at the
end.

## Quick start

```matlab
init_build_census_datasets_rev1     % build, validate, and save everything
results = runtests("tests")         % run the tests
```

Requires MATLAB R2025b with the Mapping Toolbox. The first run downloads
about 150 MB (tracts, urban areas, check files) into `cache/`. To redo the
block pass from the TIGER/Line block files (about 6 GB), set
`cfg.tf_rebuild_blocks = true` in the entry script; otherwise the build reads
the committed block results in `data/derived/`.

## Outputs

All in `data/`.

| File | Variable | Size |
|---|---|---|
| `Cascade_new_full_census_2023_UA.mat` | `new_full_census_2020` | 85,529 x 7 `double` |
| `Cascade_new_full_census_2020.mat` | `new_full_census_2020` | 85,529 x 4 `double` |
| `cell_urbanarea_census_data_2020_2023.mat` | `cell_ua_census_data_2020` | 2,633 x 14 `cell` |
| `cell_pea_census_data_2020_2023.mat` | `cell_pea_census_data_2020` | 416 x 10 `cell` |
| `census_2020_tracts.csv` | | Tract array as text |

The file names keep `2023` so existing `load` calls work. The data comes from
the 2026 TIGER/Line release, which carries the 2020 Census counts.

### Tract array (`Cascade_new_full_census_2023_UA.mat`)

| Column | Contents |
|---|---|
| 1 | Tract GEOID (11 digits) |
| 2 | Latitude of the TIGER/Line internal point |
| 3 | Longitude of the TIGER/Line internal point |
| 4 | 2020 Census population |
| 5 | Urban area code (UACE) or `NaN`: the smallest UACE of any block in the tract (legacy rule) |
| 6 | *New.* PEA number |
| 7 | *New.* Urban population: population of the tract's blocks that are in any urban area |

`Cascade_new_full_census_2020.mat` holds columns 1-4.

### Urban area cell

One row per urban area that has at least one tract in column 5 above, sorted
by column 4, descending.

| Column | Contents |
|---|---|
| 1 | Urban area name |
| 2 | UACE |
| 3 | Empty (boundaries are in `cache/cell_urbanarea_census_data_2020_2023_contours.mat`) |
| 4 | Population: sum of column 7 |
| 5 | Centroid of the urban area boundary, `[lat lon]` |
| 6 | Tract GEOIDs (tracts whose UACE is this urban area) |
| 7 | Tract populations |
| 8 | Empty |
| 9 | Tract internal points, `[lat lon]` |
| 10 | *New.* Block group GEOIDs (12 digits) of this urban area's pieces |
| 11 | *New.* Piece population: blocks of this urban area within the block group |
| 12 | *New.* Piece point, `[lat lon]`: population-weighted mean of the blocks' internal points |
| 13 | *New.* Parent tract GEOID of each piece (matches the tract array, column 1) |
| 14 | *New.* Urban area population from blocks: sum of column 11 |

Columns 10-14 count only the blocks that are in the urban area, so a tract
split between an urban area and rural land, or between two urban areas, is
counted in the right place. To use them with a zone's tract list, select the
pieces whose column 13 is in the zone.

### PEA cell

One row per PEA, 1-416, in number order.

| Column | Contents |
|---|---|
| 1 | PEA name |
| 2 | PEA number |
| 3 | PEA boundary from the FCC shapefile, `[lat lon]`, each part followed by a NaN row |
| 4 | Population: sum of column 7 |
| 5 | Centroid of the PEA boundary, `[lat lon]` |
| 6 | Tract GEOIDs |
| 7 | Tract populations |
| 8 | Empty |
| 9 | Tract latitude only (N x 1, as in the legacy file) |
| 10 | *New.* Tract internal points, `[lat lon]` |

## Method

1. **Tracts.** GEOID and internal point from the TIGER/Line tract files for
   all 56 state-equivalents (50 states, DC, Puerto Rico, and the four Island
   Areas).
2. **Blocks.** Each TIGER/Line block file gives `POP20` (2020 Census
   population) and `UACE20` (urban area) for every 2020 block. Blocks are
   summed to tracts by GEOID prefix. Connecticut blocks keep the 2020 county
   codes while tracts use the 2022 planning regions, so they're matched by
   tract code; two repeated water tract codes are resolved by testing the
   block's internal point against the tract polygons.
3. **Urban areas.** A tract's UACE is the smallest UACE among its blocks
   (the legacy rule). Urban pieces are the urban blocks summed by block group
   and urban area.
4. **PEAs.** Tracts are assigned through their county, using the county list
   in 47 CFR Part 27, Appendix A to Subpart A, plus a crosswalk for counties
   created or renamed since 2010 (`data/raw/county_fips_changes.csv`). The
   boundaries and names come from the FCC PEA shapefile.

## Checks

The build stops before saving if any check fails. The results are in
[`reports/validation_report.md`](reports/validation_report.md). The checks
include:

- Population totals equal the published 2020 counts exactly: 331,449,281
  (50 states and DC), 3,285,874 (Puerto Rico), and each Island Area.
- Tract population equals the Census Bureau's independent 2020 Centers of
  Population tract file for every tract outside Connecticut.
- Internal points equal the 2026 Gazetteer.
- Every tract is in exactly one PEA, and urban area and PEA rows match the
  tract array.

The tests also rerun the block pass for DC and Connecticut and compare it
with `data/derived/`, and they replay the Generic_Bugsplat zone workflow on a
test zone. An independent Python reimplementation in
`tools/reference_python/` produces the same outputs.

## Changes from the legacy Census_Functions files

Per-tract differences are in
[`reports/legacy_comparison_tracts.csv`](reports/legacy_comparison_tracts.csv),
with a summary in [`reports/legacy_comparison.md`](reports/legacy_comparison.md).
Regenerate both with `init_compare_legacy_rev1`.

Run with the same TIGER/Line 2023 files as the legacy build
(`init_reproduce_legacy_2023_rev1`), the code reproduces the legacy files
exactly except for the three intended fixes below (2020 file populations,
520 PEA tracts, two Connecticut water tracts). See
[`reports/legacy_2023_reproduction.md`](reports/legacy_2023_reproduction.md).
To build from another release, pass the year as the third argument of
`census_config_rev1`.


- `Cascade_new_full_census_2020.mat` had tract populations assigned to the
  wrong tracts (about 73 million people). It now equals columns 1-4 of the
  UA file, which was already correct.
- The PEA cell placed tracts by testing their center against the PEA polygon,
  which left 520 coastal and island tracts (492,278 people) out. Tracts are
  now assigned by county, so the PEA populations sum to the national total.
- Internal points come from the 2026 TIGER/Line release; about 20,000 tracts
  moved slightly from the 2023 release.
- Two Connecticut water tracts with repeated tract codes now get their own
  blocks.

## Sources

| Source | Use |
|---|---|
| [TIGER/Line 2026](https://www2.census.gov/geo/tiger/TIGER2026/): STATE, TRACT, TABBLOCK20, UAC20 | Tracts, blocks, urban areas |
| FCC PEA shapefile (`data/raw/FCC_PEAs_Website/`) | PEA boundaries and names |
| [47 CFR Part 27, Appendix A to Subpart A](https://www.ecfr.gov/current/title-47/chapter-I/subchapter-B/part-27/subpart-A) | PEA county list |
| FCC DA 14-759, Appendix A (`data/raw/DA-14-759A2.pdf`) | PEA names (check) |
| [2020 Centers of Population by tract](https://www2.census.gov/geo/docs/reference/cenpop2020/tract/CenPop2020_Mean_TR.txt) | Population check |
| [2026 Gazetteer tract file](https://www2.census.gov/geo/docs/maps-data/data/gazetteer/2026_Gazetteer/2026_Gaz_tracts_national.zip) | Internal point check |

`data/raw/MANIFEST.csv` records the size and SHA-256 hash of every source
file used for the committed outputs.
