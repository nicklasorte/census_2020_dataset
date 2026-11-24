"""Independent Python reference implementation of the dataset build.

The MATLAB pipeline (init_build_census_datasets_rev1.m) is the code of record.
This script reimplements the same rules separately so that the two can be
compared. It reads the outputs of stage_a.py and writes .mat files with
scipy.io.savemat.

Usage: python3 stage_b.py <cache_folder> <repo_folder> <tiger_year>
"""
import csv
import io
import pickle
import re
import sys
import zipfile
from collections import defaultdict

import numpy as np
import scipy.io as sio
import shapefile
from shapely.geometry import shape
from shapely.ops import unary_union

CACHE, REPO, TIGER = sys.argv[1], sys.argv[2], int(sys.argv[3])
DATA = f'{REPO}/data/tiger{TIGER}'   # every release has its own folder


def reader(path):
    z = zipfile.ZipFile(path)
    base = [x for x in z.namelist() if x.endswith('.shp')][0][:-4]
    return shapefile.Reader(shp=io.BytesIO(z.read(base + '.shp')),
                            dbf=io.BytesIO(z.read(base + '.dbf')),
                            shx=io.BytesIO(z.read(base + '.shx')))


def boundary_latlon(geom):
    """Shapefile-style boundary: every ring followed by a NaN row, [lat lon]."""
    polys = [geom] if geom.geom_type == 'Polygon' else list(geom.geoms)
    parts = []
    for p in polys:
        for ring in [p.exterior] + list(p.interiors):
            xy = np.asarray(ring.coords)
            parts.append(np.column_stack([xy[:, 1], xy[:, 0]]))
            parts.append(np.array([[np.nan, np.nan]]))
    return np.vstack(parts) if parts else np.zeros((0, 2))


tracts = pickle.load(open(f'{CACHE}/ref_tracts.pkl', 'rb'))
tract_pop, tract_ua, tract_urban = {}, {}, {}
for r in csv.DictReader(open(f'{DATA}/derived/tract_block_summary.csv')):
    tract_pop[r['GEOID']] = int(r['POP'])
    tract_urban[r['GEOID']] = int(r['URBAN_POP'])
    if r['UACE_MIN'] != 'NaN':
        tract_ua[r['GEOID']] = [int(r['UACE_MIN'])]
pieces = {}
for r in csv.DictReader(open(f'{DATA}/derived/bg_ua_pieces.csv')):
    pieces[(r['BG_GEOID'], int(r['UACE']))] = (int(r['POP']), float(r['LAT']), float(r['LON']))

# ---- F2 / F1 ---------------------------------------------------------------
geoid = [g for g, _, _ in tracts]
n = len(geoid)
F2 = np.full((n, 7), np.nan)
for i, (g, la, lo) in enumerate(tracts):
    F2[i, 0] = float(g)
    F2[i, 1] = la
    F2[i, 2] = lo
    F2[i, 3] = tract_pop.get(g, 0)
    u = tract_ua.get(g)
    F2[i, 4] = min(u) if u else np.nan
    F2[i, 6] = tract_urban.get(g, 0)

# PEA by county
xml = open(f'{REPO}/data/raw/ecfr_47cfr_part27_subpartA.xml', encoding='utf-8').read()
seg = xml[xml.find('<DIV9 N="Appendix A to Subpart A of Part 27"'):]
seg = seg[:seg.find('</DIV9>')]
rows = []
for tr in re.findall(r'<TR>(.*?)</TR>', seg, re.S):
    td = [re.sub('<[^>]+>', '', c).strip() for c in re.findall(r'<TD[^>]*>(.*?)</TD>', tr, re.S)]
    if len(td) == 4:
        rows.append(td)
c2p = {r[1]: int(r[0]) for r in rows}
chg = {r['current_county_fips']: r['cfr_county_fips'] for r in csv.DictReader(open(f'{REPO}/data/raw/county_fips_changes.csv'))}
assert all(p == 1 for k, p in c2p.items() if k.startswith('09'))


def pea_of_county(c):
    c = chg.get(c, c)
    return c2p[c]


for i, g in enumerate(geoid):
    F2[i, 5] = pea_of_county(g[:5])

F1 = F2[:, :4].copy()

# ---- UA cell ---------------------------------------------------------------
uac = reader(f'{CACHE}/other/tl_{TIGER}_us_uac20.zip')
ua_rows = []
for sr in uac.iterShapeRecords():
    rec = sr.record
    uace = int(rec['UACE20'])
    idx = np.where(F2[:, 4] == uace)[0]
    if idx.size == 0:
        continue
    geom = shape(sr.shape.__geo_interface__)
    cen = geom.centroid
    pc = sorted(k for k in pieces if k[1] == uace)
    pg = np.array([float(k[0]) for k in pc]).reshape(-1, 1)
    ppop = np.array([pieces[k][0] for k in pc], float).reshape(-1, 1)
    ppt = np.array([[pieces[k][1], pieces[k][2]] for k in pc]).reshape(-1, 2)
    ptr = np.array([float(k[0][:11]) for k in pc]).reshape(-1, 1)
    ua_rows.append([rec['NAME20'], float(uace), np.zeros((1, 0)),
                    float(F2[idx, 3].sum()), np.array([[cen.y, cen.x]]),
                    F2[idx, 0].reshape(-1, 1), F2[idx, 3].reshape(-1, 1), np.zeros((1, 0)),
                    F2[idx, 1:3], pg, ppop, ppt, ptr, float(ppop.sum())])
ua_rows.sort(key=lambda r: -r[3])  # stable: ties keep shapefile record order (legacy rule)


def to_cell(rows, ncol):
    c = np.empty((len(rows), ncol), dtype=object)
    for i, r in enumerate(rows):
        for j in range(ncol):
            c[i, j] = r[j]
    return c


cell_ua = to_cell(ua_rows, 14)
cell_ua_slim = cell_ua.copy()
for i in range(cell_ua_slim.shape[0]):
    cell_ua_slim[i, 2] = np.zeros((1, 0))

# ---- PEA cell --------------------------------------------------------------
pea = shapefile.Reader(f'{REPO}/data/raw/FCC_PEAs_Website/FCC_PEAs_website')
pea_rows = []
for sr in pea.iterShapeRecords():
    p = int(sr.record['PEA_Num'])
    pts = np.array(sr.shape.points)
    parts = list(sr.shape.parts) + [len(pts)]
    b = np.vstack([np.vstack([pts[parts[k]:parts[k + 1]][:, ::-1], [np.nan, np.nan]]) for k in range(len(parts) - 1)])
    cen = shape(sr.shape.__geo_interface__).centroid
    idx = np.where(F2[:, 5] == p)[0]
    pea_rows.append([sr.record['PEA_Name'].strip(), float(p), b, float(F2[idx, 3].sum()), np.array([[cen.y, cen.x]]),
                     F2[idx, 0].reshape(-1, 1), F2[idx, 3].reshape(-1, 1), np.zeros((1, 0)),
                     F2[idx, 1].reshape(-1, 1), F2[idx, 1:3]])
cell_pea = to_cell(pea_rows, 10)

out = f'{REPO}/tools/reference_python/out/{TIGER}'
import os
os.makedirs(out, exist_ok=True)
sio.savemat(f'{out}/Cascade_new_full_census_2020.mat', {'new_full_census_2020': F1}, do_compression=True)
sio.savemat(f'{out}/Cascade_new_full_census_2023_UA.mat', {'new_full_census_2020': F2}, do_compression=True)
sio.savemat(f'{out}/cell_urbanarea_census_data_2020_2023.mat', {'cell_ua_census_data_2020': cell_ua_slim}, do_compression=True)
sio.savemat(f'{out}/cell_pea_census_data_2020_2023.mat', {'cell_pea_census_data_2020': cell_pea}, do_compression=True)
print('tracts', n, 'pop', F2[:, 3].sum(), 'UA rows', len(ua_rows), 'PEA pop', sum(r[3] for r in pea_rows))

# Tract array as text (same columns as the MATLAB build's census_2020_tracts.csv)
with open(f'{out}/census_2020_tracts.csv', 'w', newline='') as f:
    w = csv.writer(f, lineterminator='\n')
    w.writerow(['GEOID', 'LAT', 'LON', 'POP', 'UACE', 'PEA_NUM', 'URBAN_POP'])
    for r in F2:
        w.writerow([f'{int(r[0]):011d}', repr(float(r[1])), repr(float(r[2])), int(r[3]),
                    'NaN' if np.isnan(r[4]) else int(r[4]), int(r[5]), int(r[6])])
