"""Write stage_a.py results to data/derived CSV files (same columns as the MATLAB build)."""
import csv, pickle, sys
CACHE, REPO = sys.argv[1], sys.argv[2]
tracts = pickle.load(open(f'{CACHE}/ref_tracts.pkl', 'rb'))
tract_pop, tract_ua, pieces = pickle.load(open(f'{CACHE}/ref_stage_a.pkl', 'rb'))
urban = {}
for (bg, u), v in pieces.items():
    urban[bg[:11]] = urban.get(bg[:11], 0) + v[0]
with open(f'{REPO}/data/derived/tract_block_summary.csv', 'w', newline='') as f:
    w = csv.writer(f, lineterminator='\n'); w.writerow(['GEOID', 'POP', 'UACE_MIN', 'NUM_UACE', 'URBAN_POP'])
    for g, _, _ in tracts:
        u = tract_ua.get(g, [])
        w.writerow([g, tract_pop.get(g, 0), min(u) if u else 'NaN', len(u), urban.get(g, 0)])
with open(f'{REPO}/data/derived/bg_ua_pieces.csv', 'w', newline='') as f:
    w = csv.writer(f, lineterminator='\n'); w.writerow(['BG_GEOID', 'TRACT_GEOID', 'UACE', 'POP', 'LAT', 'LON'])
    for (bg, u) in sorted(pieces):
        p, la, lo = pieces[(bg, u)]
        w.writerow([bg, bg[:11], u, p, repr(la), repr(lo)])
