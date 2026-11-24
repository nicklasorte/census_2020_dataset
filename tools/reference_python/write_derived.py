"""Usage: python3 write_derived.py <cache_folder> <repo_folder> <tiger_year>
cache_folder holds tract/, block/, and other/ with the TIGER/Line zips for tiger_year."""
import sys
CACHE, REPO, YEAR = sys.argv[1], sys.argv[2], int(sys.argv[3])
DATA = f'{REPO}/data/tiger{YEAR}'   # every release has its own folder
FIPS = open(f'{REPO}/tools/reference_python/state_fips.txt').read().split()
"""Write stage_a.py results to data/tiger<year>/derived CSV files (same columns as the MATLAB build)."""
import csv, os, pickle, sys
tracts = pickle.load(open(f'{CACHE}/ref_tracts.pkl', 'rb'))
tract_pop, tract_ua, pieces = pickle.load(open(f'{CACHE}/ref_stage_a.pkl', 'rb'))
urban = {}
for (bg, u), v in pieces.items():
    urban[bg[:11]] = urban.get(bg[:11], 0) + v[0]
os.makedirs(f'{DATA}/derived', exist_ok=True)
with open(f'{DATA}/derived/tract_block_summary.csv', 'w', newline='') as f:
    w = csv.writer(f, lineterminator='\n'); w.writerow(['GEOID', 'POP', 'UACE_MIN', 'NUM_UACE', 'URBAN_POP'])
    for g, _, _ in tracts:
        u = tract_ua.get(g, [])
        w.writerow([g, tract_pop.get(g, 0), min(u) if u else 'NaN', len(u), urban.get(g, 0)])
with open(f'{DATA}/derived/bg_ua_pieces.csv', 'w', newline='') as f:
    w = csv.writer(f, lineterminator='\n'); w.writerow(['BG_GEOID', 'TRACT_GEOID', 'UACE', 'POP', 'LAT', 'LON'])
    for (bg, u) in sorted(pieces):
        p, la, lo = pieces[(bg, u)]
        w.writerow([bg, bg[:11], u, p, repr(la), repr(lo)])
