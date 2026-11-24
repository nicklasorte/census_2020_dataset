"""Python cross-check of compare_legacy_datasets_rev1.m. Usage: compare_legacy.py <legacy_folder> <repo_folder>"""
import csv, sys
import numpy as np, scipy.io as sio
from pyproj import Geod
L, REPO = sys.argv[1], sys.argv[2]
F2 = sio.loadmat(f'{REPO}/data/Cascade_new_full_census_2023_UA.mat')['new_full_census_2020']
L20 = sio.loadmat(f'{L}/Cascade_new_full_census_2020.mat')['new_full_census_2020']
LUA = sio.loadmat(f'{L}/Cascade_new_full_census_2023_UA.mat')['new_full_census_2020']
P = sio.loadmat(f'{L}/cell_pea_census_data_2020_2023.mat')['cell_pea_census_data_2020']
i20 = {g: i for i, g in enumerate(L20[:, 0])}; iua = {g: i for i, g in enumerate(LUA[:, 0])}
pea = {}
for k in range(P.shape[0]):
    for g in P[k, 5].ravel():
        pea[g] = float(P[k, 1].ravel()[0])
geod = Geod(ellps='WGS84')
rows = []
for r in F2:
    g = r[0]; a = L20[i20[g]]; b = LUA[iua[g]]
    _, _, dist = geod.inv(r[2], r[1], b[2], b[1])
    moved = int(r[1] != b[1] or r[2] != b[2])
    ua_ch = int(not (r[4] == b[4] or (np.isnan(r[4]) and np.isnan(b[4]))))
    pl = pea.get(g, np.nan)
    rows.append([g, r[3], a[3], r[3] - a[3], b[3], r[3] - b[3], r[1], r[2], b[1], b[2], moved, dist,
                 r[4], b[4], ua_ch, r[5], pl, int(not r[5] == pl)])
def f(v):
    if isinstance(v, int): return str(v)
    if np.isnan(v): return 'NaN'
    return str(int(v)) if float(v).is_integer() else repr(float(v))
with open(f'{REPO}/reports/legacy_comparison_tracts.csv', 'w', newline='') as fh:
    w = csv.writer(fh, lineterminator='\n')
    w.writerow(['GEOID', 'POP_NEW', 'POP_LEGACY_2020', 'DELTA_POP_2020', 'POP_LEGACY_UA', 'DELTA_POP_UA',
                'LAT_NEW', 'LON_NEW', 'LAT_LEGACY', 'LON_LEGACY', 'LOCATION_CHANGED', 'LOCATION_SHIFT_M',
                'UACE_NEW', 'UACE_LEGACY', 'UACE_CHANGED', 'PEA_NEW', 'PEA_LEGACY', 'PEA_CHANGED'])
    for r in rows:
        w.writerow([f'{int(r[0]):011d}'] + [f(v) for v in r[1:]])
R = np.array([r[1:] for r in rows], float)
moved = R[:, 9] == 1; d = R[:, 10]
print('tracts', len(R), 'pop diff 2020', int((R[:, 2] != 0).sum()), 'misplaced', np.abs(R[:, 2]).sum() / 2,
      'pop diff UA', int((R[:, 4] != 0).sum()), 'moved', int(moved.sum()), 'median m', np.median(d[moved]),
      'p95', np.percentile(d[moved], 95), 'max', d.max(), 'ua changed', int(R[:, 13].sum()),
      'pea missing', int(np.isnan(R[:, 15]).sum()), 'pop', R[np.isnan(R[:, 15]), 0].sum(),
      'pea changed', int(((R[:, 16] == 1) & ~np.isnan(R[:, 15])).sum()))
