"""Usage: python3 stage_a.py <cache_folder> <repo_folder> <tiger_year>
cache_folder holds tract/, block/, and other/ with the TIGER/Line zips for tiger_year."""
import sys
CACHE, REPO, YEAR = sys.argv[1], sys.argv[2], int(sys.argv[3])
DATA = f'{REPO}/data/tiger{YEAR}'   # every release has its own folder
FIPS = open(f'{REPO}/tools/reference_python/state_fips.txt').read().split()
# Reference (independent) implementation of stage A: block attributes -> tract and BG-UA summaries
import shapefile, zipfile, io, numpy as np, pickle, collections, sys
from shapely.geometry import shape, Point
C=CACHE+'/'
fips=FIPS
def dbf(path):
    z=zipfile.ZipFile(path); n=[x for x in z.namelist() if x.endswith('.dbf')][0]
    return shapefile.Reader(dbf=io.BytesIO(z.read(n)))
tracts=pickle.load(open(C+'ref_tracts.pkl','rb'))
tract_pop=collections.Counter(); tract_ua=collections.defaultdict(set)
bg=collections.defaultdict(lambda:[0,0.0,0.0,0.0,0.0,0,[]])  # pop, wlat, wlon, slat, slon, n
# CT tract lookup
ct={}
for g,_,_ in tracts:
    if g[:2]=='09': ct.setdefault(g[5:11],[]).append(g)
ctpoly=None
for f in fips:
    r=dbf(C+f'block/tl_{YEAR}_{f}_tabblock20.zip')
    nm=[x[0] for x in r.fields[1:]]; I={k:nm.index(k) for k in ['GEOID20','POP20','UACE20','INTPTLAT20','INTPTLON20','TRACTCE20']}
    for rec in r.iterRecords():
        g=rec[I['GEOID20']]; p=int(rec[I['POP20']]); u=rec[I['UACE20']].strip()
        la=float(rec[I['INTPTLAT20']]); lo=float(rec[I['INTPTLON20']])
        if f=='09':
            c=ct[rec[I['TRACTCE20']]]
            if len(c)>1:
                if ctpoly is None:
                    zr=zipfile.ZipFile(C+f'tract/tl_{YEAR}_09_tract.zip'); base=[x for x in zr.namelist() if x.endswith('.shp')][0][:-4]
                    sr=shapefile.Reader(shp=io.BytesIO(zr.read(base+'.shp')),dbf=io.BytesIO(zr.read(base+'.dbf')),shx=io.BytesIO(zr.read(base+'.shx')))
                    ctpoly={rec2['GEOID']:shape(s.shape.__geo_interface__) for s,rec2 in zip(sr.shapeRecords(),sr.iterRecords())}
                hit=[x for x in c if ctpoly[x].covers(Point(lo,la))]
                if len(hit)!=1: raise SystemExit(f'CT block {g} ambiguous {hit}')
                t=hit[0]
            else: t=c[0]
            bgid=t+g[11]
        else:
            t=g[:11]; bgid=g[:12]
        tract_pop[t]+=p
        if u: tract_ua[t].add(int(u))
        if u:
            b=bg[(bgid,int(u))]; b[0]+=p; b[1]+=p*la; b[2]+=p*lo; b[3]+=la; b[4]+=lo; b[5]+=1; b[6].append(lo)
    print(f,len(r),flush=True)
out={}
for k,b in bg.items():
    lons=np.array(b[6])
    shift = (lons.max()-lons.min())>180
    if shift: raise SystemExit(f'antimeridian BG {k}')  # handled explicitly if it occurs
    if b[0]>0: out[k]=(b[0],b[1]/b[0],b[2]/b[0])
    else: out[k]=(0,b[3]/b[5],b[4]/b[5])
pickle.dump((dict(tract_pop),{k:sorted(v) for k,v in tract_ua.items()},out),open(C+'ref_stage_a.pkl','wb'))
print('tracts with pop entries',len(tract_pop),'total',sum(tract_pop.values()),'bg pieces',len(out))
