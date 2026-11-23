import shapefile, zipfile, io, sys, numpy as np, pickle
fips=open('/home/claude/cache/fips.txt').read().split()
rows=[]
for f in fips:
    z=zipfile.ZipFile(f'/home/claude/cache/tract/tl_2026_{f}_tract.zip')
    n=[x for x in z.namelist() if x.endswith('.dbf')][0]
    r=shapefile.Reader(dbf=io.BytesIO(z.read(n)))
    names=[x[0] for x in r.fields[1:]]
    if f=='01': print(names)
    gi,la,lo=names.index('GEOID'),names.index('INTPTLAT'),names.index('INTPTLON')
    for rec in r.iterRecords(): rows.append((rec[gi],float(rec[la]),float(rec[lo])))
print(len(rows))
pickle.dump(rows,open('/home/claude/ref/tracts.pkl','wb'))
