# Plan: rebuild the 2020 census tract, urban area, and PEA datasets

This plan describes how to rebuild four `.mat` files from
[nicklasorte/Census_Functions](https://github.com/nicklasorte/Census_Functions)
from public sources, with all MATLAB code and source data kept in this
repository so that anyone can reproduce the files and trace every number.

**Status**: Draft for review. No build code is written yet. Decisions D1-D5
need an answer before the build starts.

## Files to rebuild

| # | File | Variable | Shape | Contents |
|---|---|---|---|---|
| F1 | `Cascade_new_full_census_2020.mat` | `new_full_census_2020` | 85,529 x 4 `double` | Tract GEOID, latitude, longitude, population |
| F2 | `Cascade_new_full_census_2023_UA.mat` | `new_full_census_2020` | 85,529 x 5 `double` | F1 columns plus the 2020 urban area code (UACE), `NaN` if not urban |
| F3 | `cell_urbanarea_census_data_2020_2023.mat` | `cell_ua_census_data_2020` | 2,633 x 9 `cell` | One row per urban area, with its tracts |
| F4 | `cell_pea_census_data_2020_2023.mat` | `cell_pea_census_data_2020` | 416 x 9 `cell` | One row per FCC Partial Economic Area (PEA), with its tracts |

F2 deliberately reuses the variable name `new_full_census_2020`, as the
legacy file does, so that existing `load` calls keep working.

The legacy code that produced F2-F4 is
`init_scrap_2023_census_pop_data_rev8_block_into_tract.m`. F1 came from an
earlier revision (`rev5` or `rev6`).

## Legacy file audit

I loaded all four legacy files and compared them with Census Bureau and FCC
sources. Every number in this section comes from that comparison.

### Common tract geography (F1 and F2)

- 85,529 tracts from the TIGER/Line **2023** vintage: 50 states, DC, Puerto
  Rico, and the four Island Areas (FIPS 60, 66, 69, and 78). Connecticut uses
  the 2022 planning-region county codes (`09110`-`09190`), 884 tracts.
- Columns 2-3 are the TIGER/Line internal point (`INTPTLAT`, `INTPTLON`). They
  match the 2023 Gazetteer tract file exactly for all 85,396 tracts that it
  covers. The other 133 are Island Area tracts (18, 57, 26, and 32).
- Rows are in state FIPS order, and within each state, in TIGER/Line shapefile
  record order. They aren't sorted by GEOID.
- F1 and F2 have identical columns 1-3.

### F1: tract populations are wrong

F1's population column is correct in total but wrong at the tract level:

- National, state, Puerto Rico, and Island Area totals match the published
  2020 counts. The total is 335,073,176.
- Only 55,349 of 84,512 non-Connecticut tracts match the Census Bureau tract
  counts in `CenPop2020_Mean_TR.txt`. The sum of absolute tract errors is
  146,739,382, so about 73 million people sit in the wrong tract.
- 20,402 tracts have a population of zero; the correct number is 629.
- Example: Schleicher County, Texas (one tract, `48413950300`) shows 240,652
  people. Its 2020 count is 2,451.

**F2's population column is correct**: all 84,512 non-Connecticut tracts match
`CenPop2020_Mean_TR.txt` exactly. The fix for F1 is to make it equal to
columns 1-4 of a correctly built F2.

Any analysis that loaded F1 for tract-level population (for example,
`find_pop_impact_contours_rev1.m`-style population-inside-contour counts)
should be rerun after the rebuild.

### F2: urban area assignment

- 72,968 tracts carry a UACE; 2,633 distinct urban areas.
- The rule in `rev8`: a tract gets every UACE of its blocks (including blocks
  with zero population), and if there is more than one (1,150 tracts), the
  smallest UACE wins.
- Rebuilding that rule from the Census Bureau's `2020_UA_BLOCKS.txt` reproduces
  84,503 of 84,645 non-Connecticut tracts. The other 142 are explained as
  follows:
  - 102 Island Area tracts: `2020_UA_BLOCKS.txt` doesn't cover the Island
    Areas.
  - 40 tracts in Georgia and Louisiana: the legacy file uses the TIGER/Line
    2023 block UACE (for example, `03817` in place of `32194`). The 2023
    vintage reflects urban area changes made after the original 2020 release.

### F3: urban area cell

Column layout, from the `rev8` code and the file:

| Column | Contents |
|---|---|
| 1 | Urban area name |
| 2 | UACE |
| 3 | Empty (contours are saved separately, in `..._contours.mat`) |
| 4 | Urban area population, the sum of column 7 |
| 5 | `centroid(polyshape(lon, lat))` of the urban area boundary, as `[lat lon]` |
| 6 | Tract GEOIDs whose F2 UACE equals this urban area |
| 7 | Tract populations |
| 8 | Empty |
| 9 | Tract internal points, N x 2 `[lat lon]` |

Rows are sorted by population, descending, and urban areas with no assigned
tract are dropped. Every row's tracts, populations, and points match F2
exactly.

### F4: PEA cell

The column layout matches F3, with PEA name and PEA number in columns 1-2 and
the PEA boundary (`[lat lon]`, `NaN`-separated parts) in column 3. Rows are in
PEA number order, 1-416. Two defects:

- **Dropped tracts**: tracts are assigned by testing whether the internal point
  falls inside the FCC PEA polygon. 520 tracts, 492,278 people, fall outside
  every polygon, mostly on coastlines and islands (Florida, Puerto Rico,
  Michigan, and Hawaii lead). The PEA total is 334,580,898 against 335,073,176.
- **Column 9 holds only latitude**: the code writes `points_latlon(inside_idx)`
  instead of `points_latlon(inside_idx,:)`, so column 9 is N x 1. F3 has the
  correct N x 2 form.

PEAs are defined in
[47 CFR Part 27, Subpart A, Appendix A](https://www.ecfr.gov/current/title-47/chapter-I/subchapter-B/part-27/subpart-A)
as lists of counties. I assigned every tract to a PEA through its county FIPS
code with that list, plus a four-entry crosswalk for counties that changed
after 2010 (`02063` and `02066` to `02261`, `02158` to `02270`, and `46102` to
`46113`; all Connecticut counties are in PEA 1). The result:

- It agrees with the legacy polygon assignment for all 85,009 tracts that the
  legacy file assigned.
- It also assigns the 520 dropped tracts, with no geometry.

## Sources

All sources are public. I confirmed that each `census.gov` and `ecfr.gov` URL
downloads from this environment.

| ID | Source | Used for |
|---|---|---|
| S1 | TIGER/Line 2023 tracts, `TIGER2023/TRACT/tl_2023_<FIPS>_tract.zip`, 56 files | Tract list, row order, internal points |
| S2 | TIGER/Line 2023 blocks, `TIGER2023/TABBLOCK20/tl_2023_<FIPS>_tabblock20.zip`, 56 files, about 6 GB | Block `POP20` and `UACE20`, summed to tracts by GEOID prefix |
| S3 | TIGER/Line 2023 urban areas, `TIGER2023/UAC/tl_2023_us_uac20.zip` (74 MB) | Urban area names and boundaries (F3 columns 1 and 5) |
| S4 | 47 CFR Part 27 Appendix A to Subpart A, from the eCFR API | County-to-PEA list |
| S5 | FCC PEA boundary shapefile (fields `PEA_Name`, `PEA_Num`, `POPs_2010`, as read by `rev8`) | PEA names and boundaries (F4 columns 1, 3, and 5) |
| C1 | [2023 Gazetteer tract file](https://www2.census.gov/geo/docs/maps-data/data/gazetteer/2023_Gazetteer/2023_Gaz_tracts_national.zip) | Check: internal points |
| C2 | [2020 Centers of Population by tract](https://www2.census.gov/geo/docs/reference/cenpop2020/tract/CenPop2020_Mean_TR.txt) | Check: tract population |
| C3 | [2020 urban area block list](https://www2.census.gov/geo/docs/reference/ua/2020_UA_BLOCKS.txt) (295 MB) | Check: urban area assignment |

S1-S3 live under `https://www2.census.gov/geo/tiger/`. S2 is the same block
data that `rev8` used, so it reproduces the legacy method, including the 2023
urban area codes and the Connecticut planning-region GEOIDs. Blocks are
summed to tracts with the first 11 characters of `GEOID20`, a string
operation; no point-in-polygon tests are involved.

S5 is the one source that the build can't fetch: `fcc.gov` refuses automated
downloads from this environment. The shapefile that `rev8` read sits in your
local `Census_Functions\FCC_PEAs_Website` folder. Decision D4 covers this.

## Repository layout

```
census_2020_dataset/
├── PLAN.md
├── README.md                         Usage, column definitions, provenance
├── init_build_census_2020_datasets_rev1.m     Entry script
├── src/
│   ├── download_census_sources_rev1.m         websave, SHA-256 manifest
│   ├── read_tiger_tracts_rev1.m               S1
│   ├── summarize_tiger_blocks_rev1.m          S2 -> tract population, tract UACE set
│   ├── read_urban_areas_rev1.m                S3
│   ├── read_pea_county_list_rev1.m            S4
│   ├── read_pea_boundaries_rev1.m             S5
│   ├── build_tract_arrays_rev1.m              F1, F2
│   ├── build_ua_cell_rev1.m                   F3
│   ├── build_pea_cell_rev1.m                  F4
│   ├── validate_census_datasets_rev1.m        Checks; error() on failure
│   └── compare_legacy_datasets_rev1.m         Diff report against legacy files
├── tests/
│   └── test_census_datasets_rev1.m            matlab.unittest suite
├── data/
│   ├── raw/                  Small sources, unmodified, plus MANIFEST.csv
│   ├── derived/              Tract-level block summaries (CSV, a few MB)
│   ├── Cascade_new_full_census_2020.mat
│   ├── Cascade_new_full_census_2023_UA.mat
│   ├── cell_urbanarea_census_data_2020_2023.mat
│   ├── cell_urbanarea_census_data_2020_2023_contours.mat
│   └── cell_pea_census_data_2020_2023.mat
└── reports/
    └── legacy_comparison.md
```

`MANIFEST.csv` records the URL, download date, size, and SHA-256 hash of every
source, including the large ones that aren't committed.

## Build steps

1. **Download.** Fetch S1-S4 and C1-C3 with `websave` into a cache folder
   outside Git (default `C:\Local Matlab Data\census_2020_cache`, set in the
   entry script). Record hashes in `MANIFEST.csv` and verify them on later
   runs. A `tf_redownload` flag controls refetching.
2. **Tracts (S1).** Read each state's tract file with `readgeotable`, in
   state FIPS order, keeping record order. Keep `GEOID` as a string, and
   convert with `str2double` only when building the numeric arrays. Don't use
   `num2str` on GEOIDs.
3. **Blocks (S2).** For each state, read `GEOID20`, `POP20`, and `UACE20` from
   the block file's attribute table, without loading geometry. Sum `POP20` by
   `extractBefore(GEOID20, 12)` with `groupsummary`, and collect the unique
   non-empty `UACE20` values per tract. Write both to `data/derived/` so that
   later runs skip the 6 GB pass.
4. **F2.** Join tract populations and UACE onto S1 by GEOID. Where a tract has
   more than one UACE, keep the smallest (the `rev8` rule; see D2). Error if
   any tract fails to join.
5. **F1.** Take columns 1-4 of F2.
6. **F3.** For each urban area in S3 with at least one tract: name, UACE,
   population, `centroid(polyshape(lon, lat))`, tract GEOIDs, tract
   populations, and tract points (N x 2). Sort by population, descending.
   Save the contours version first, then the version with column 3 emptied, as
   `rev8` does.
7. **F4.** For each PEA in S5, assign tracts by county (D3), then fill the
   columns as in F3, with the PEA boundary in column 3 and the polygon centroid
   in column 5. Keep PEA number order.
8. **Validate**, then save all files with `-v7`.
9. **Compare** each output with its legacy file and write
   `reports/legacy_comparison.md`.

## Validation

`validate_census_datasets_rev1` runs these checks and calls `error()` on the
first failure. The unit tests rerun them on the saved files.

**Totals and structure**

- 85,529 tracts, unique 11-digit integer GEOIDs, no `NaN` in F1.
- Population: 50 states and DC 331,449,281; Puerto Rico 3,285,874; Island
  Areas 338,021; total 335,073,176.
- Latitude from -15 to 72 degrees; longitude from -180 to 180 degrees.

**Independent sources**

- Internal points equal C1 for all 85,396 Gazetteer tracts.
- Tract populations equal C2 for all 84,512 non-Connecticut tracts.
- Tract UACE agrees with C3 except for the 142 explained tracts. The report
  lists any other difference.

**Legacy agreement**

- F2: equal to the legacy file element for element, including row order and
  `NaN` placement.
- F1: equal to F2 columns 1-4. F1 is expected to differ from the legacy F1;
  the report quantifies the difference.
- F3: equal to the legacy file in every column.
- F4: columns 1-8 equal the legacy file, except for the 520 added tracts if
  D3 is accepted; column 9 differs if D5 is accepted.

**Internal consistency**

- F3 and F4 column 4 equal the sums of their column 7.
- F4 covers every tract exactly once (with D3), so its total is 335,073,176.

## Decisions needed

**D1. Tract geography.** Use the TIGER/Line 2023 tracts, as the legacy files
do (recommended). This keeps GEOIDs, row order, and Connecticut
planning-region codes compatible with existing code. The alternative, the
original 2020 tabulation tracts (85,528, with old Connecticut counties),
breaks GEOID matching with the legacy files.

**D2. Tracts in more than one urban area.** Keep the legacy rule, smallest
UACE (recommended, for a drop-in replacement). An alternative is to assign the
urban area that holds the most of the tract's population. That rule is more
defensible but changes 1,150 tracts at most.

**D3. Tract-to-PEA assignment.** Assign by county with the 47 CFR list
(recommended). It matches the legacy file wherever the legacy file assigned a
tract, recovers the 520 dropped tracts, and follows the legal definition of a
PEA. The alternative reproduces the polygon test and its dropped tracts.

**D4. FCC PEA boundaries.** Copy the shapefile from your local
`FCC_PEAs_Website` folder into `data/raw/` (recommended). The build then
matches legacy column 3 and column 5 exactly. The alternative builds PEA
boundaries by dissolving TIGER/Line county polygons by the 47 CFR list, which
is fully reproducible but changes column 3 and column 5 and has no land
polygon for PEA 416 (Gulf of Mexico).

**D5. F4 column 9.** Fix it to N x 2 `[lat lon]`, matching F3 (recommended).
Check first whether any downstream code reads F4 column 9 as latitude only.

## Follow-on work

These items are outside this plan and each needs a separate go-ahead:

- Rerun analyses that used legacy F1 tract populations, and quantify the
  change.
- Check whether `cell_pea_census_data_2020.mat`, `cell_pea_census_data.mat`,
  and the 2010 files share the F1 or F4 defects.
- Rebuild the 2010 tract file with the same pipeline.
