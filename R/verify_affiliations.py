# -*- coding: utf-8 -*-
"""Assertions over the produced deliverables. Fails loudly."""
import pandas as pd, numpy as np, re, random, unicodedata, collections

import os
SRC  = os.environ.get('AFFIL_PROJECT_ROOT', '.')
OUT   = os.path.join(SRC, 'output')          # reports and review lists
FINAL = os.path.join(OUT, 'final')            # the three deliverables
D1 = pd.read_csv(f'{FINAL}/affiliations_complete.csv', dtype=str)
D2 = pd.read_csv(f'{FINAL}/affiliation_lookup.csv', dtype=str)
D3 = pd.read_csv(f'{FINAL}/affiliation_simple_coords_with_notes.csv', dtype=str)
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

# tidy drops the ABSENT placeholder of any paper the additions file supplies, so
# the expected row count is 1273 + added - replaced. Recomputed here from the
# spreadsheet rather than taken on trust.
#
# That needs the paper each spreadsheet row ends up under, and the spreadsheet's
# own citation text will not do: it is damaged (mojibake, the us/uk replace,
# drag-down page numbers) while the additions file carries the clean
# twatasha_todo.csv form. Comparing raw text is how 23 of 59 placeholders
# survived unnoticed until 2026-09-11 -- tidy made that mistake and this file
# repeated it, so the two agreed. The match is derived here independently of
# tidy's resolver: none of those damage types touches a citation's ASCII
# letters apart from us/uk, so the key keeps only those, us/uk neutralised, and
# falls back to ignoring digits when that is unambiguous. Continuation rows are
# forward-filled first, as tidy does.
def _skel(s, digits=True):
    if not isinstance(s, str): return None
    s = re.sub(r'<[^>]+>', '', s)
    s = re.sub(r'United States|usa|us', '\x01', s, flags=re.I)
    s = re.sub(r'United Kingdom|uk', '\x02', s, flags=re.I)
    s = re.sub(r'[^A-Za-z0-9\x01\x02]', '', s).lower()
    return s if digits else re.sub(r'\d', '', s)

def _lookup(key_fn):
    g = todo.groupby(todo.source_citation.map(key_fn)).source_citation
    return g.apply(lambda s: sorted(set(s))).to_dict()
_T = set(todo.source_citation)
_by_skel, _by_nodigit = _lookup(_skel), _lookup(lambda s: _skel(s, False))

def _paper(s):
    if not isinstance(s, str): return None
    if s in _T: return s
    for cands in (_by_skel.get(_skel(s)), _by_nodigit.get(_skel(s, False))):
        if cands and len(cands) == 1: return cands[0]
    return None

def _is_placeholder(s):
    return s.fillna('').str.strip().str.upper().isin(['', 'ABSENT'])

SUPPLIED = set(ADD.source_citation.map(_paper)) - {None}
_mask = orig['source_citation'].ffill().map(_paper).isin(SUPPLIED) & \
        _is_placeholder(orig['affiliation'])
N_REPLACED = int(_mask.sum())
def added_nonnull(col):
    if col not in ADD.columns: return 0
    return int((ADD[col].str.strip() != '').sum())

def canon(s):
    if not isinstance(s, str): return None
    s = unicodedata.normalize('NFKD', s)
    s = ''.join(c for c in s if not unicodedata.combining(c))
    s = re.sub(r'United States', 'us', s); s = re.sub(r'United Kingdom', 'uk', s)
    return re.sub(r'[^a-z0-9]', '', s.lower())

# Gia's lake-region rows. tidy appends them after every other row, so deliverable 1 is
# the N_BASE rows accounted for above, in order, then what survives of hers. Which of
# hers should survive is derived here, not taken from tidy: her citations resolve
# with _paper() above, and her affiliations are compared under canon() with this
# file's own reversal of the two known repairs, against the deliverable's own first
# N_BASE rows (which the checks below hold to the spreadsheet and the additions).
F_LAKE        = f'{SRC}/data/gia_final_data/lake_region_source_affiliations_africa.csv'
F_LAKE_COUNTS = f'{SRC}/data/gia_final_data/lake_region_source_counts.csv'
HAS_LAKE = os.path.exists(F_LAKE)
N_BASE = 1273 + N_ADDED - N_REPLACED
IHI = 'IHI Ifakara Tanzania'
def _unrepair(s):
    """Her text with `Centre` put back where the find-and-replace took it, and the
    one Mac Roman en dash read as Latin-1 corrected."""
    if not isinstance(s, str): return s
    if s.strip() != IHI: s = s.replace(IHI, 'Centre')
    return s.replace('Ð', '–')

if HAS_LAKE:
    LAKE = pd.read_csv(F_LAKE, dtype=str, encoding='utf-8-sig', keep_default_na=False)
    _res = LAKE.source_citation.map(_paper)
    LAKE['paper'] = _res.fillna(LAKE.source_citation)
    # a citation of hers that is not on twatasha_todo.csv is its own key, byte for byte
    G_NEW = set(LAKE.source_citation[_res.isna()])
    G_N = dict(zip(LAKE.source_citation, LAKE.n))
    _base = D1.iloc[:N_BASE]
    _carried = set(zip(_base.source_citation, _base.affiliation.map(canon)))
    LAKE['kept'] = [(p, canon(_unrepair(a))) not in _carried
                    for p, a in zip(LAKE.paper, LAKE.affiliation)]
    N_LAKE, N_LAKE_KEPT = len(LAKE), int(LAKE.kept.sum())
else:
    G_NEW, G_N, N_LAKE, N_LAKE_KEPT = set(), {}, 0, 0

ok = []
def check(name, cond, detail=''):
    ok.append((name, bool(cond), detail))
    print(('PASS  ' if cond else 'FAIL  ') + name + (('  ' + detail) if detail else ''))

# --- shape ---------------------------------------------------------------
check(f'deliverable 1 has {N_BASE + N_LAKE_KEPT} rows (1273 xlsx rows'
      + (f' + {N_ADDED} added' if N_ADDED else '')
      + (f' - {N_REPLACED} ABSENT placeholder(s) replaced' if N_REPLACED else '')
      + (f' + {N_LAKE} lake - {N_LAKE - N_LAKE_KEPT} already on their paper' if HAS_LAKE else '')
      + ')',
      len(D1) == N_BASE + N_LAKE_KEPT, f'{len(D1)}')
# The invariant behind that count, asserted directly so it does not rest on the
# matcher above: a paper the additions file supplies keeps no ABSENT or empty row
# except the ones typed into that file itself.
if N_ADDED:
    _ph_d1  = D1[D1.source_citation.isin(SUPPLIED) & _is_placeholder(D1.affiliation)] \
                .groupby('source_citation').size()
    _ph_add = ADD[_is_placeholder(ADD.affiliation)].source_citation.map(_paper).value_counts()
    _left = _ph_d1.sub(_ph_add, fill_value=0)
    _left = _left[_left > 0]
    check('no supplied paper keeps a replaced ABSENT placeholder', len(_left) == 0,
          f'{int(_left.sum())} left over {len(_left)} paper(s)' if len(_left)
          else f'{int(_ph_d1.sum())} ABSENT row(s) remain, all typed into added_affiliations.csv')
# The rows absent_review.R writes are the answers in data/absent_review.xlsx, as
# many times as the sheet holds them. Until 2026-09-17 it wrote the answers of every
# already-supplied paper again on each run -- 66 duplicate rows reached deliverable
# 1 -- and the row count above could not see it, because it takes N_ADDED from this
# same file. So compare the file with the sheet itself.
F_ABSENT_SHEET = f'{SRC}/data/absent_review.xlsx'
if N_ADDED and os.path.exists(F_ABSENT_SHEET):
    _k = ['source_citation', 'affiliation', 'affiliation_simple']
    _sheet = pd.read_excel(F_ABSENT_SHEET, dtype=str).reindex(columns=_k).fillna('') \
               .apply(lambda s: s.str.strip())
    _sheet = _sheet[(_sheet.source_citation != '') & (_sheet.affiliation != '')]
    _owned = ADD[_k].apply(lambda s: s.str.strip())
    _owned = _owned[_owned.source_citation.isin(set(_sheet.source_citation))]
    _in_file  = collections.Counter(map(tuple, _owned.values))
    _in_sheet = collections.Counter(map(tuple, _sheet.values))
    _extra, _lost = _in_file - _in_sheet, _in_sheet - _in_file
    check('added_affiliations.csv holds each absent_review.xlsx answer as often as the sheet does',
          not _extra and not _lost,
          f'{sum(_extra.values())} extra row(s) over {len({c for c, _, _ in _extra})} paper(s), '
          f'{sum(_lost.values())} answer(s) missing' if (_extra or _lost)
          else f'{sum(_in_sheet.values())} answers')
check('column set unchanged',
      list(D1.columns) == ['source_citation', 'n', 'affiliation_original',
                           'affiliation', 'affiliation_simple'])

# --- source_citation / n integrity ---------------------------------------
T = set(todo.source_citation)
# Her rows may also carry a citation of hers that is not on twatasha_todo.csv, as
# delivered; every other row must be on it.
_bad_cit = int((~D1.source_citation.iloc[:N_BASE].isin(T)).sum()
               + (~D1.source_citation.iloc[N_BASE:].isin(T | G_NEW)).sum())
check('every source_citation is a verbatim twatasha_todo.csv value'
      + (", or one of Gia's own for a paper not on it" if HAS_LAKE else ''),
      _bad_cit == 0, f'{_bad_cit} rows not matching')
nmap = dict(zip(todo.source_citation, todo.n))
nmap.update({c: G_N[c] for c in G_NEW})
bad_n = (D1.n.astype(str) != D1.source_citation.map(nmap).astype(str)).sum()
check('n agrees with twatasha_todo.csv on every row'
      + (", or with Gia's file for her own papers" if HAS_LAKE else ''),
      bad_n == 0, f'{bad_n} mismatches')
# 541 of the 542 todo sources had an affiliation in version 3; the 542nd
# (Diop et al. 2002) came from data/added_affiliations.csv. Assert the invariant
# rather than a count, because a citation supplied by that file may be one that
# already had a row -- an ABSENT placeholder being replaced -- or a wholly new
# one, and arithmetic on 541 cannot tell the two apart.
_unrepresented = set(todo.source_citation) - set(D1.source_citation)
check(f'every todo source is represented ({len(set(todo.source_citation) & set(D1.source_citation))} of {todo.source_citation.nunique()})',
      len(_unrepresented) == 0,
      '' if not _unrepresented else f'{len(_unrepresented)} missing')
check('no blank source_citation remains', D1.source_citation.notna().all())

# --- damage eradicated ----------------------------------------------------
MARK_A = set('√‚Ä†©≠¥£¢ß∞'); MARK_B = set('ÈÙËÏÌÓÔÒÚÛÊÁÎÍ')
for col in D1.columns:
    s = D1[col].dropna()
    exempt = ''
    if col == 'source_citation' and G_NEW:
        # A citation of Gia's that is not on twatasha_todo.csv is the key that joined
        # vector_extraction_data.csv, mojibake and all: rule 3 keeps it as delivered.
        n_ex = int(s.isin(G_NEW).sum()); s = s[~s.isin(G_NEW)]
        exempt = f" ({n_ex} rows of Gia's own citations exempt)"
    a = s.map(lambda x: any(c in MARK_A for c in x)).sum()
    b = s.map(lambda x: any(c in MARK_B for c in x)).sum()
    check(f'no layer-A mojibake left in {col}', a == 0, f'{a}{exempt}')
    check(f'no layer-B mojibake left in {col}', b == 0, f'{b}{exempt}')

MID = re.compile(r'(?<=\w)United (?:States|Kingdom)|United (?:States|Kingdom)(?=\w)')
for col in ['affiliation_original', 'affiliation', 'affiliation_simple']:
    n = D1[col].dropna().map(lambda x: bool(MID.search(x))).sum()
    check(f'no mid-word United States/Kingdom left in {col}', n == 0, f'{n}')

for col in ['affiliation', 'affiliation_simple']:
    n = D1[col].dropna().map(lambda x: x != x.strip() or '  ' in x or '​' in x
                                        or '\n' in x or '\r' in x).sum()
    check(f'{col} whitespace normalised', n == 0, f'{n}')

# --- deliverable 2 / 3 consistency ---------------------------------------
p1 = set(map(tuple, D1.dropna(subset=['affiliation', 'affiliation_simple'])
             [['affiliation_simple', 'affiliation']].values))
p2 = set(map(tuple, D2[['affiliation_simple', 'affiliation']].values))
check('deliverable 2 is exactly the distinct pairs of deliverable 1', p1 == p2,
      f'{len(p1 ^ p2)} symmetric difference')
check('deliverable 2 has no duplicate rows', not D2.duplicated(['affiliation_simple', 'affiliation']).any())
check('deliverable 3 keys are unique', not D3.affiliation_simple.duplicated().any())
# affiliation_simple_coords.csv is the with_notes file cut to three columns:
# same rows, same order, same text.
_d3n = pd.read_csv(f'{FINAL}/affiliation_simple_coords_with_notes.csv', dtype=str, keep_default_na=False)
_d3s = pd.read_csv(f'{FINAL}/affiliation_simple_coords.csv', dtype=str, keep_default_na=False)
_c3 = ['affiliation_simple', 'latitude', 'longitude']
check('affiliation_simple_coords.csv is exactly the three coordinate columns of the with_notes file',
      list(_d3s.columns) == _c3 and _d3s.equals(_d3n[_c3]),
      f'columns {list(_d3s.columns)}, {len(_d3s)} rows against {len(_d3n)}')
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
    # Gia's rows are exempt: a relabel written for spreadsheet rows does not move hers
    # (her rows keep her labels until merged in label_review.xlsx)
    rl = dec[dec.decision_type == 'affiliation_relabel']
    wrong = []
    _b1 = D1.iloc[:N_BASE]
    for _, r in rl.iterrows():
        got = set(_b1.loc[_b1.affiliation == r.target.strip(), 'affiliation_simple'].dropna())
        if got != {r.new_value.strip()}:
            wrong.append((r.target[:40], sorted(got)))
    check('every affiliation_relabel took effect', len(wrong) == 0, str(wrong[:5]))

    # lake_relabel is the same assertion WITHOUT the exemption, so it is checked
    # against the whole of deliverable 1 rather than its first N_BASE rows: the
    # point of the type is that Gia's rows move too, and a check that looked only
    # at the spreadsheet rows would pass a run in which none of hers had budged.
    lr = dec[dec.decision_type == 'lake_relabel']
    if len(lr):
        wrong = []
        for _, r in lr.iterrows():
            got = set(D1.loc[D1.affiliation == r.target.strip(), 'affiliation_simple'].dropna())
            if got != {r.new_value.strip()}:
                wrong.append((r.target[:40], sorted(got)))
        check("every lake_relabel took effect, Gia's rows included",
              len(wrong) == 0, str(wrong[:5]))

    DECIDED_LABELS = set(dec.loc[dec.decision_type.isin(
        ['label_rename', 'coordinate', 'accept_as_is', 'note_only']), 'target'].str.strip())
    DECIDED_LABELS |= set(dec.loc[dec.decision_type.isin(
        ['label_rename', 'affiliation_relabel', 'lake_relabel']), 'new_value'].str.strip())
    DECIDED_AFFILS = set(dec.loc[dec.decision_type.isin(
        ['affiliation_relabel', 'lake_relabel']), 'target'].str.strip())
else:
    print('SKIP  decisions checks (no decisions file or report present)')
    DECIDED_LABELS, DECIDED_AFFILS = set(), set()

# --- content preservation: 20 random cells re-read from the xlsx ----------

# Rows dropped as replaced ABSENT placeholders shift every position after them,
# so compare against the rows that actually survived, in order. Added rows sit
# after these and are not part of a content-preservation check.
orig_kept = orig[~_mask].reset_index(drop=True) if N_REPLACED else orig

random.seed(20260817)
idx = random.sample(range(len(orig_kept)), 20)
drift = []
skipped = 0
for i in idx:
    for col in ['affiliation', 'affiliation_simple']:
        b, a = orig_kept[col].iloc[i], D1[col].iloc[i]
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

# --- Gia's lake-region rows -----------------------------------------------
if HAS_LAKE:
    _lake_d1 = D1.iloc[N_BASE:].reset_index(drop=True)
    _unrep = set(LAKE.paper) - set(D1.source_citation)
    check(f"every paper of Gia's is represented ({LAKE.paper.nunique()} papers, "
          f"{len(G_NEW)} of them not on twatasha_todo.csv)",
          not _unrep, f'{len(_unrep)} missing')

    # Hers, as a multiset of (paper, affiliation): each row once, less those whose
    # paper already carried the affiliation. Catches a lost row and a duplicate alike.
    _kept = LAKE[LAKE.kept].reset_index(drop=True)
    _want = collections.Counter(zip(_kept.paper, _kept.affiliation.map(lambda a: canon(_unrepair(a)))))
    _got  = collections.Counter(zip(_lake_d1.source_citation, _lake_d1.affiliation.map(canon)))
    check("Gia's rows appear once each, except where their paper already carried the affiliation",
          _want == _got,
          f'{sum((_got - _want).values())} extra, {sum((_want - _got).values())} missing'
          if _want != _got else f'{N_LAKE_KEPT} kept, {N_LAKE - N_LAKE_KEPT} already on their paper')

    _emb = sum(int(D1[c].dropna().map(lambda x: IHI in x and x.strip() != IHI).sum())
               for c in ['affiliation', 'affiliation_simple'])
    check('no `IHI Ifakara Tanzania` left inside a longer affiliation or label', _emb == 0, f'{_emb}')
    _dash = sum(int(D1[c].dropna().str.contains('Ð').sum()) for c in ['affiliation', 'affiliation_simple'])
    check('no `Ð` left in affiliation or affiliation_simple', _dash == 0, f'{_dash}')

    # Her coordinates land verbatim on every label of hers that is live and that no
    # decision has touched. A merged, renamed, decided or conflicted label is skipped:
    # the decision checks above cover those.
    _lc = pd.read_csv(F_LAKE_COUNTS, dtype=str, encoding='utf-8-sig', keep_default_na=False)
    _d3 = D3.set_index('affiliation_simple')
    _bad, _n_ok, _n_skip = [], 0, 0
    for _, r in _lc.iterrows():
        lab = ' '.join(_unrepair(r.affiliation_simple).split())
        if lab not in _d3.index or lab in DECIDED_LABELS or \
           _d3.loc[lab, 'coord_status'] in ('decided', 'conflict'):
            _n_skip += 1
            continue
        row = _d3.loc[lab]
        _n_ok += 1
        if row.coord_status != 'ok' or \
           abs(float(row.latitude) - float(r.latitude)) > 1e-9 or \
           abs(float(row.longitude) - float(r.longitude)) > 1e-9:
            _bad.append((lab, row.coord_status, row.latitude, row.longitude))
    check("every coordinate of Gia's landed verbatim on its live, undecided label",
          not _bad, str(_bad[:5]) if _bad
          else f'{_n_ok} checked; {_n_skip} unused, merged, decided or in conflict')

    random.seed(20260917)
    _drift, _skip = [], 0
    if len(_kept) == len(_lake_d1):
        for i in random.sample(range(len(_kept)), min(20, len(_kept))):
            for col in ['affiliation', 'affiliation_simple']:
                b, a = _unrepair(_kept[col].iloc[i]), _lake_d1[col].iloc[i]
                if canon(b) == canon(a):
                    continue
                if b.strip() in DECIDED_LABELS or (isinstance(a, str) and a.strip() in DECIDED_LABELS):
                    _skip += 1
                    continue
                _drift.append((i, col, b, a))
    check("20 random rows of Gia's: content unchanged apart from the known repairs",
          len(_kept) == len(_lake_d1) and not _drift,
          f'{len(_drift)} drifted' + (f', {_skip} explained by decisions' if _skip else ''))
    for d in _drift[:10]:
        print('   lake row', d[0], d[1], '\n      before:', repr(d[2])[:160], '\n      after :', repr(d[3])[:160])

# --- no content lost -----------------------------------------------------
# The replaced placeholders were non-null in the spreadsheet ('ABSENT' is a
# value), so they come off the expected count too.
_replaced_nonnull = {}
for _c in ['affiliation', 'affiliation_simple', 'affiliation_original']:
    _replaced_nonnull[_c] = int(orig.loc[_mask, _c].notna().sum())

for col in ['affiliation', 'affiliation_simple', 'affiliation_original']:
    lake_nn = int((LAKE.loc[LAKE.kept, col].str.strip() != '').sum()) \
              if HAS_LAKE and col in LAKE.columns else 0
    expect = orig[col].notna().sum() + added_nonnull(col) - _replaced_nonnull[col] + lake_nn
    check(f'{col} non-null count preserved',
          expect == D1[col].notna().sum(),
          f'{expect} -> {D1[col].notna().sum()}'
          + (f' (incl. {added_nonnull(col)} added)' if added_nonnull(col) else '')
          + (f' (incl. {lake_nn} of Gia\'s)' if lake_nn else ''))

print('\n%d checks, %d failed' % (len(ok), sum(1 for _, c, _ in ok if not c)))
raise SystemExit(1 if any(not c for _, c, _ in ok) else 0)
