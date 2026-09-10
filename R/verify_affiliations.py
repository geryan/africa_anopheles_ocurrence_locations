# -*- coding: utf-8 -*-
"""Assertions over the produced deliverables. Fails loudly."""
import pandas as pd, numpy as np, re, random, unicodedata

import os
SRC  = os.environ.get('AFFIL_PROJECT_ROOT', '.')
OUT  = os.path.join(SRC, 'output')
D1 = pd.read_csv(f'{OUT}/affiliations_complete_20260817.csv', dtype=str)
D2 = pd.read_csv(f'{OUT}/affiliation_lookup_20260817.csv', dtype=str)
D3 = pd.read_csv(f'{OUT}/affiliation_simple_coords_20260817.csv', dtype=str)
todo = pd.read_csv(f'{SRC}/output/twatasha_todo.csv', dtype=str)
orig = pd.read_excel(f'{SRC}/data/twatasha_final_data/Affiliation spreadsheet_version 3. 26 Sep. 2024.xlsx', dtype=str)
orig.columns = [c.strip() for c in orig.columns]
orig = orig.rename(columns={'affiliation - original': 'affiliation_original'})

# Rows appended from data/added_affiliations.csv are not in the spreadsheet, so
# every count taken off `orig` has to allow for them.
f_add = f'{SRC}/data/added_affiliations.csv'
if os.path.exists(f_add):
    ADD = pd.read_csv(f_add, dtype=str).fillna('')
    ADD = ADD[ADD.source_citation.str.strip() != '']
else:
    ADD = pd.DataFrame(columns=['source_citation', 'affiliation', 'affiliation_simple'])
N_ADDED = len(ADD)
def added_nonnull(col):
    if col not in ADD.columns: return 0
    return int((ADD[col].str.strip() != '').sum())

ok = []
def check(name, cond, detail=''):
    ok.append((name, bool(cond), detail))
    print(('PASS  ' if cond else 'FAIL  ') + name + (('  ' + detail) if detail else ''))

# --- shape ---------------------------------------------------------------
check(f'deliverable 1 has {1273 + N_ADDED} rows (1273 xlsx rows'
      + (f' + {N_ADDED} from added_affiliations.csv)' if N_ADDED else ')'),
      len(D1) == 1273 + N_ADDED, f'{len(D1)}')
check('column set unchanged',
      list(D1.columns) == ['source_citation', 'n', 'affiliation_original',
                           'affiliation', 'affiliation_simple'])

# --- source_citation / n integrity ---------------------------------------
T = set(todo.source_citation)
check('every source_citation is a verbatim twatasha_todo.csv value',
      D1.source_citation.isin(T).all(),
      f'{(~D1.source_citation.isin(T)).sum()} rows not matching')
nmap = dict(zip(todo.source_citation, todo.n))
bad_n = (D1.n.astype(str) != D1.source_citation.map(nmap).astype(str)).sum()
check('n agrees with twatasha_todo.csv on every row', bad_n == 0, f'{bad_n} mismatches')
# 541 of the 542 todo sources had an affiliation in version 3; the 542nd
# (Diop et al. 2002) is supplied by data/added_affiliations.csv, so the target
# rises as rows are added there.
n_src_expected = 541 + ADD.source_citation.nunique()
check(f'{n_src_expected} of 542 todo sources represented',
      D1.source_citation.nunique() == n_src_expected, str(D1.source_citation.nunique()))
check('no blank source_citation remains', D1.source_citation.notna().all())

# --- damage eradicated ----------------------------------------------------
MARK_A = set('√‚Ä†©≠¥£¢ß∞'); MARK_B = set('ÈÙËÏÌÓÔÒÚÛÊÁÎÍ')
for col in D1.columns:
    s = D1[col].dropna()
    a = s.map(lambda x: any(c in MARK_A for c in x)).sum()
    b = s.map(lambda x: any(c in MARK_B for c in x)).sum()
    check(f'no layer-A mojibake left in {col}', a == 0, f'{a}')
    check(f'no layer-B mojibake left in {col}', b == 0, f'{b}')

MID = re.compile(r'(?<=\w)United (?:States|Kingdom)|United (?:States|Kingdom)(?=\w)')
for col in ['affiliation_original', 'affiliation', 'affiliation_simple']:
    n = D1[col].dropna().map(lambda x: bool(MID.search(x))).sum()
    check(f'no mid-word United States/Kingdom left in {col}', n == 0, f'{n}')

for col in ['affiliation', 'affiliation_simple']:
    n = D1[col].dropna().map(lambda x: x != x.strip() or '  ' in x or '​' in x or '\n' in x).sum()
    check(f'{col} whitespace normalised', n == 0, f'{n}')

# --- deliverable 2 / 3 consistency ---------------------------------------
p1 = set(map(tuple, D1.dropna(subset=['affiliation', 'affiliation_simple'])
             [['affiliation_simple', 'affiliation']].values))
p2 = set(map(tuple, D2[['affiliation_simple', 'affiliation']].values))
check('deliverable 2 is exactly the distinct pairs of deliverable 1', p1 == p2,
      f'{len(p1 ^ p2)} symmetric difference')
check('deliverable 2 has no duplicate rows', not D2.duplicated(['affiliation_simple', 'affiliation']).any())
check('deliverable 3 keys are unique', not D3.affiliation_simple.duplicated().any())
check('deliverable 3 covers every affiliation_simple in deliverable 1',
      set(D3.affiliation_simple) == set(D1.affiliation_simple.dropna()),
      f'{len(set(D3.affiliation_simple) ^ set(D1.affiliation_simple.dropna()))} difference')
check('every deliverable 2 label appears in deliverable 3',
      set(D2.affiliation_simple) <= set(D3.affiliation_simple))

# --- coordinates ----------------------------------------------------------
lat = pd.to_numeric(D3.latitude, errors='coerce'); lon = pd.to_numeric(D3.longitude, errors='coerce')
check('all present latitudes parse as numbers',
      (D3.latitude.notna() == lat.notna()).all(),
      f'{(D3.latitude.notna() & lat.isna()).sum()} unparseable')
check('all present longitudes parse as numbers',
      (D3.longitude.notna() == lon.notna()).all())
check('latitudes within [-90, 90]', ((lat.dropna() >= -90) & (lat.dropna() <= 90)).all())
check('longitudes within [-180, 180]', ((lon.dropna() >= -180) & (lon.dropna() <= 180)).all())
HAS_COORD = D3.coord_status.isin(['ok', 'decided'])
check('coordinates present exactly when coord_status is ok or decided',
      (lat.notna() == HAS_COORD).all(),
      f'{(lat.notna() != HAS_COORD).sum()} rows disagree')
check('coord_status vocabulary',
      set(D3.coord_status) <= {'ok', 'decided', 'missing', 'conflict', 'absent'},
      str(sorted(set(D3.coord_status))))
print('\ncoord_status:', D3.coord_status.value_counts().to_dict())

# --- decisions ------------------------------------------------------------
F_DEC = os.path.join(SRC, 'data', 'affiliation_decisions.csv')
F_REP = os.path.join(OUT, 'decisions_report.csv')
if os.path.exists(F_DEC) and os.path.exists(F_REP):
    dec = pd.read_csv(F_DEC, dtype=str, keep_default_na=False)
    # NB on an empty frame df.apply(axis=1) returns a column-less Series, and using it
    # as a mask drops every column. Only filter when there is something to filter.
    if len(dec):
        dec = dec[dec.apply(lambda r: any(str(x).strip() for x in r), axis=1)]
    rep = pd.read_csv(F_REP, dtype=str, keep_default_na=False)
    check('every decision reached the report', len(rep) == len(dec), f'{len(rep)} vs {len(dec)}')
    bad = rep[rep.status != 'applied']
    check('every decision applied', len(bad) == 0,
          '; '.join(f'{r.status}: {r.target[:40]}' for _, r in bad.iterrows()))

    # decided coordinates land verbatim -- on the exact label, or on the single label
    # sharing its join key (the coordinate files spell some labels differently)
    def _jk(s):
        s = s.replace('United States', '\x01').replace('United Kingdom', '\x02')
        s = re.sub(r'u\.?s\.?a\.?', '\x01', s, flags=re.I)
        s = re.sub(r'u\.?s\.?',     '\x01', s, flags=re.I)
        s = re.sub(r'u\.?k\.?',     '\x02', s, flags=re.I)
        s = unicodedata.normalize('NFKD', s)
        s = ''.join(c for c in s if not unicodedata.combining(c))
        return re.sub(r'[^a-z0-9\x01\x02]', '', s.lower())
    D3_JK = D3.affiliation_simple.map(_jk)
    cd = dec[dec.decision_type == 'coordinate']
    drift = []
    for _, r in cd.iterrows():
        row = D3[D3.affiliation_simple == r.target.strip()]
        if len(row) != 1:
            row = D3[D3_JK == _jk(r.target.strip())]
        if len(row) != 1:
            drift.append((r.target, 'not exactly one row in deliverable 3')); continue
        if row.coord_status.iloc[0] != 'decided':
            drift.append((r.target, 'coord_status is %s' % row.coord_status.iloc[0])); continue
        if abs(float(row.latitude.iloc[0]) - float(r.latitude)) > 1e-9 or \
           abs(float(row.longitude.iloc[0]) - float(r.longitude)) > 1e-9:
            drift.append((r.target, 'coordinate does not match the decision'))
    check('every coordinate decision landed verbatim', len(drift) == 0, str(drift[:5]))

    # renamed-away labels are gone
    rn = dec[dec.decision_type == 'label_rename']
    live = set(D3.affiliation_simple)
    stale = [r.target for _, r in rn.iterrows()
             if r.target.strip() in live and r.target.strip() != r.new_value.strip()]
    check('no renamed-away label survives in deliverable 3', len(stale) == 0, str(stale[:5]))

    # relabelled affiliations sit under the decided label
    rl = dec[dec.decision_type == 'affiliation_relabel']
    wrong = []
    for _, r in rl.iterrows():
        got = set(D1.loc[D1.affiliation == r.target.strip(), 'affiliation_simple'].dropna())
        if got != {r.new_value.strip()}:
            wrong.append((r.target[:40], sorted(got)))
    check('every affiliation_relabel took effect', len(wrong) == 0, str(wrong[:5]))
    DECIDED_LABELS = set(dec.loc[dec.decision_type.isin(
        ['label_rename', 'coordinate', 'accept_as_is', 'note_only']), 'target'].str.strip())
    DECIDED_LABELS |= set(dec.loc[dec.decision_type.isin(
        ['label_rename', 'affiliation_relabel']), 'new_value'].str.strip())
    DECIDED_AFFILS = set(dec.loc[dec.decision_type == 'affiliation_relabel', 'target'].str.strip())
else:
    print('SKIP  decisions checks (no decisions file or report present)')
    DECIDED_LABELS, DECIDED_AFFILS = set(), set()

# --- content preservation: 20 random cells re-read from the xlsx ----------
def canon(s):
    if not isinstance(s, str): return None
    s = unicodedata.normalize('NFKD', s)
    s = ''.join(c for c in s if not unicodedata.combining(c))
    s = re.sub(r'United States', 'us', s); s = re.sub(r'United Kingdom', 'uk', s)
    return re.sub(r'[^a-z0-9]', '', s.lower())

random.seed(20260817)
idx = random.sample(range(len(orig)), 20)
drift = []
skipped = 0
for i in idx:
    for col in ['affiliation', 'affiliation_simple']:
        b, a = orig[col].iloc[i], D1[col].iloc[i]
        if canon(b) == canon(a):
            continue
        # a deliberate decision is not drift
        if (isinstance(b, str) and b.strip() in DECIDED_LABELS) or \
           (isinstance(a, str) and a.strip() in DECIDED_LABELS) or \
           (isinstance(D1.affiliation.iloc[i], str) and
            D1.affiliation.iloc[i] in DECIDED_AFFILS):
            skipped += 1
            continue
        drift.append((i + 2, col, b, a))
check('20 random rows: affiliation content unchanged apart from known repairs',
      len(drift) == 0,
      f'{len(drift)} drifted' + (f', {skipped} explained by decisions' if skipped else ''))
for d in drift[:10]:
    print('   row', d[0], d[1], '\n      before:', repr(d[2])[:160], '\n      after :', repr(d[3])[:160])

# --- no content lost -----------------------------------------------------
for col in ['affiliation', 'affiliation_simple', 'affiliation_original']:
    expect = orig[col].notna().sum() + added_nonnull(col)
    check(f'{col} non-null count preserved',
          expect == D1[col].notna().sum(),
          f'{expect} -> {D1[col].notna().sum()}'
          + (f' (incl. {added_nonnull(col)} added)' if added_nonnull(col) else ''))

print('\n%d checks, %d failed' % (len(ok), sum(1 for _, c, _ in ok if not c)))
raise SystemExit(1 if any(not c for _, c, _ in ok) else 0)
