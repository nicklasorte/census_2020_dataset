"""Usage: python3 read_tracts.py <cache_folder> <repo_folder> <tiger_year>
cache_folder holds tract/, block/, and other/ with the TIGER/Line zips for tiger_year."""
import sys
CACHE, REPO, YEAR = sys.argv[1], sys.argv[2], int(sys.argv[3])
DEFAULT_YEAR = 2026   # most recent release; its outputs live in data/, others in data/tiger<year>/
DATA = f'{REPO}/data' if YEAR == DEFAULT_YEAR else f'{REPO}/data/tiger{YEAR}'
FIPS = open(f'{REPO}/tools/reference_python/state_fips.txt').read().split()
import shapefile, zipfile, io, sys, numpy as np, pickle
fips=FIPS
rows=[]
for f in fips:
    z=zipfile.ZipFile(f'{CACHE}/tract/tl_{YEAR}_{f}_tract.zip')
    n=[x for x in z.namelist() if x.endswith('.dbf')][0]
    r=shapefile.Reader(dbf=io.BytesIO(z.read(n)))
    names=[x[0] for x in r.fields[1:]]
    if f=='01': print(names)
    gi,la,lo=names.index('GEOID'),names.index('INTPTLAT'),names.index('INTPTLON')
    for rec in r.iterRecords(): rows.append((rec[gi],float(rec[la]),float(rec[lo])))
print(len(rows))
pickle.dump(rows,open(f'{CACHE}/ref_tracts.pkl','wb'))
