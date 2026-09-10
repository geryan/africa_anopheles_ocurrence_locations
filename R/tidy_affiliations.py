# -*- coding: utf-8 -*-
"""
Reference implementation of the affiliation cleaning pipeline.
Mirrored by R/tidy_affiliations.R.
"""
import pandas as pd, numpy as np, re, unicodedata, hashlib, math, os, json, collections

# Paths are relative to the project root; run from there.
SRC   = os.environ.get('AFFIL_PROJECT_ROOT', '.')
OUT   = os.path.join(SRC, 'output')
os.makedirs(OUT, exist_ok=True)

# The three deliverables go in their own directory so they cannot be mistaken for
# the working files, the review lists, or the pre-decisions parity baseline.
FINAL = os.path.join(OUT, 'final')
os.makedirs(FINAL, exist_ok=True)

F_V3   = f'{SRC}/data/twatasha_final_data/Affiliation spreadsheet_version 3. 26 Sep. 2024.xlsx'
F_TODO = f'{SRC}/output/twatasha_todo.csv'
F_UE   = f'{SRC}/data/twatasha_final_data/unique_entries 26.sep.2024.xls'
F_ULL  = f'{SRC}/data/unique_affiliations_Lat_Long.csv'  # Mac Roman on disk


def read_xls(path):
    """Legacy BIFF8 .xls. pandas needs xlrd for these; if it is not installed,
    fall back to a LibreOffice conversion, which was how this was originally run."""
    try:
        return pd.read_excel(path, dtype=str)
    except ImportError:
        import subprocess, tempfile, glob, shutil
        soffice = shutil.which('soffice') or shutil.which('libreoffice')
        if soffice is None:
            raise SystemExit(
                'reading %s needs either `pip install xlrd` or LibreOffice on PATH' % path)
        tmp = tempfile.mkdtemp()
        subprocess.run([soffice, '--headless', '--convert-to', 'xlsx', '--outdir', tmp, path],
                       check=True, capture_output=True)
        return pd.read_excel(glob.glob(os.path.join(tmp, '*.xlsx'))[0], dtype=str)

F_DEC  = f'{SRC}/data/affiliation_decisions.csv'   # your judgement calls; may be absent
F_ADD  = f'{SRC}/data/added_affiliations.csv'      # rows version 3 never had; may be absent

DEC_COLS = ['decision_type', 'target', 'new_value', 'latitude', 'longitude',
            'note', 'decided_on']
DEC_TYPES = {'token_replacement', 'affiliation_relabel', 'label_rename',
             'coordinate', 'accept_as_is', 'note_only'}

DEC_REPORT = []                  # one row per decision: did it do anything?
def dec_log(d, status, n_affected=0, message=''):
    DEC_REPORT.append(dict(decision_type=d.get('decision_type', ''),
                           target=d.get('target', ''), new_value=d.get('new_value', ''),
                           latitude=d.get('latitude', ''), longitude=d.get('longitude', ''),
                           status=status, n_affected=int(n_affected), message=message,
                           note=d.get('note', ''), decided_on=d.get('decided_on', '')))

def load_decisions(path):
    """Read data/affiliation_decisions.csv. Absent file is fine: no decisions."""
    if not os.path.exists(path):
        return []
    d = pd.read_csv(path, dtype=str, encoding='utf-8', keep_default_na=False)
    missing = [c for c in DEC_COLS if c not in d.columns]
    if missing:
        raise SystemExit('%s is missing required columns: %s\nexpected header: %s'
                         % (path, ', '.join(missing), ','.join(DEC_COLS)))
    d = d[DEC_COLS]
    rows = []
    for _, r in d.iterrows():
        rec = {c: (r[c].strip() if isinstance(r[c], str) else '') for c in DEC_COLS}
        if not any(rec.values()):
            continue                              # blank spacer row
        rows.append(rec)
    return rows

DECISIONS = load_decisions(F_DEC)

CHANGES = []                     # cell-level diff log
def log(row, col, before, after, reason):
    nb, na = not isinstance(before, str), not isinstance(after, str)
    if nb and na: return                       # both missing: not a change
    if not (nb or na) and before == after: return
    if True:
        CHANGES.append(dict(row_xlsx=row, column=col, reason=reason,
                            before='' if before is None else before,
                            after='' if after is None else after))

# ---------------------------------------------------------------- encoding ----
MARK_A = set('√‚Ä†©≠¥£¢ß∞')      # UTF-8 bytes displayed through Mac Roman
MARK_B = set('ÈÙËÏÌÓÔÒÚÛÊÁÎÍ')   # CP1252 bytes displayed through Mac Roman

def _A(s):
    try: return s.encode('mac_roman').decode('utf-8')
    except Exception: return None
def _B(s):
    try: return s.encode('mac_roman').decode('cp1252')
    except Exception: return None

def repair(s):
    """Undo layer A (repeatedly) then layer B, each gated on its signature."""
    if not isinstance(s, str): return s
    cur = s
    for _ in range(3):
        if any(c in MARK_A for c in cur):
            n = _A(cur)
            if n and n != cur: cur = n; continue
        break
    if any(c in MARK_B for c in cur):
        n = _B(cur)
        if n and n != cur: cur = n
    return cur

# ------------------------------------------------------------- whitespace ----
def squash(s):
    if not isinstance(s, str): return s
    s = s.replace('​', '')
    s = re.sub(r'\s+', ' ', s)
    return s.strip()

# ------------------------------------------------------------- us/uk repair ---
# Only mid-word occurrences are damage. Standalone ones are kept (user decision).
_MIDWORD = re.compile(r'(?<=\w)United (?:States|Kingdom)|United (?:States|Kingdom)(?=\w)')

def unreplace(s):
    """Restore mid-word `United States`/`United Kingdom` to us/US, uk/UK.
    Case is inferred from the immediately adjacent characters."""
    if not isinstance(s, str) or ('United States' not in s and 'United Kingdom' not in s):
        return s
    out, i = [], 0
    for m in _MIDWORD.finditer(s):
        out.append(s[i:m.start()])
        short  = 'us' if 'States' in m.group(0) else 'uk'
        before = s[m.start()-1] if m.start() > 0     else ''
        after  = s[m.end()]     if m.end() < len(s)  else ''
        # The following character decides: `MUnited Stateseum` is Museum, not MUSeum,
        # because the M is only capitalised as the first letter of the word. Fall back
        # to the preceding character when nothing follows (`CampUnited States` -> Campus,
        # `United StatesTTB` -> USTTB).
        if   after.isalpha():  upper = after.isupper()
        elif before.isalpha(): upper = before.isupper()
        else:                  upper = False
        out.append(short.upper() if upper else short)
        i = m.end()
    out.append(s[i:])
    return ''.join(out)

# ------------------------------------------------------------------ keys -----
def key(s):
    """Match key: encoding-repaired, us/uk-neutral, accent- and punctuation-free."""
    if not isinstance(s, str): return None
    s = repair(s)
    s = s.replace('United States', '\x01').replace('United Kingdom', '\x02')
    s = re.sub(r'usa', '\x01', s, flags=re.I)
    s = re.sub(r'us',  '\x01', s, flags=re.I)
    s = re.sub(r'uk',  '\x02', s, flags=re.I)
    s = re.sub(r'<[^>]+>', '', s)
    s = unicodedata.normalize('NFKD', s)
    s = ''.join(c for c in s if not unicodedata.combining(c))
    return re.sub(r'[^0-9a-z\x01\x02]+', '', s.lower())

def key_nodigit(s):
    k = key(s)
    return re.sub(r'\d', '', k) if k is not None else None

def label_key(s):
    """Formatting-insensitive key for affiliation_simple: case, punctuation, space."""
    if not isinstance(s, str): return None
    s = unicodedata.normalize('NFKD', s)
    s = ''.join(c for c in s if not unicodedata.combining(c))
    return re.sub(r'[^a-z0-9]', '', s.lower())

def join_key(s):
    """Key for joining labels ACROSS files. The coordinate files were snapshotted at
    different points in the find-and-replace history, so `CDC USA` there and
    `CDC United States` here are the same label. Used only to look coordinates up;
    the label form written out is untouched."""
    if not isinstance(s, str): return None
    s = s.replace('United States', '\x01').replace('United Kingdom', '\x02')
    s = re.sub(r'u\.?s\.?a\.?', '\x01', s, flags=re.I)
    s = re.sub(r'u\.?s\.?',     '\x01', s, flags=re.I)
    s = re.sub(r'u\.?k\.?',     '\x02', s, flags=re.I)
    s = unicodedata.normalize('NFKD', s)
    s = ''.join(c for c in s if not unicodedata.combining(c))
    return re.sub(r'[^a-z0-9\x01\x02]', '', s.lower())

# ================================================================ load ========
v3 = pd.read_excel(F_V3, dtype=str)
v3.columns = [c.strip() for c in v3.columns]
v3 = v3.rename(columns={'affiliation - original': 'affiliation_original'})
v3 = v3[['source_citation', 'n', 'affiliation_original', 'affiliation', 'affiliation_simple']]
v3['row_xlsx'] = np.arange(len(v3)) + 2

# Papers that are in twatasha_todo.csv but were never given an affiliation in
# either round cannot be fixed by a decision: there is no row to decide about.
# They are appended here from data/added_affiliations.csv rather than typed into
# the version 3 spreadsheet, so that file stays the artefact it was delivered as
# and every hand-entered row remains visible and reversible in one place.
# row_xlsx from 90001 up marks a row as coming from that file, not a spreadsheet
# row, which keeps the change log honest.
ADD_COLS = ['source_citation', 'affiliation', 'affiliation_simple', 'note', 'added_on']
N_ADDED = 0
N_REPLACED = 0
if os.path.exists(F_ADD):
    add = pd.read_csv(F_ADD, dtype=str).fillna('')
    missing_cols = [c for c in ADD_COLS if c not in add.columns]
    if missing_cols:
        raise SystemExit(f'{F_ADD} is missing columns: {", ".join(missing_cols)}')
    add = add[add.source_citation.str.strip() != ''].reset_index(drop=True)
    if len(add):
        blank_to_na = lambda s: s.where(s.str.strip() != '', np.nan)
        extra = pd.DataFrame({
            'source_citation': add.source_citation.values,
            'n': np.nan,
            'affiliation_original': np.nan,
            'affiliation': blank_to_na(add.affiliation).values,
            'affiliation_simple': blank_to_na(add.affiliation_simple).values,
            'row_xlsx': np.arange(len(add)) + 90001,
        })[v3.columns]
        v3 = pd.concat([v3, extra], ignore_index=True)
        N_ADDED = len(add)

        # A paper whose affiliation the source recorded as ABSENT keeps a
        # placeholder row saying so. Once a real affiliation is supplied for that
        # paper the placeholder is not just redundant, it is wrong -- it would
        # show the paper as both known and unknown. So for any citation this file
        # supplies, its ABSENT (or empty) rows are dropped.
        supplied = set(add.source_citation)
        aff_txt  = v3.affiliation.fillna('').str.strip().str.upper()
        dead = (v3.source_citation.isin(supplied) & (aff_txt.isin(['', 'ABSENT']))
                & (v3.row_xlsx < 90001))
        N_REPLACED = int(dead.sum())
        for i in np.where(dead)[0]:
            log(v3.row_xlsx.iloc[i], 'affiliation', v3.affiliation.iloc[i], None,
                'ABSENT placeholder replaced by added_affiliations.csv')
        v3 = v3[~dead].reset_index(drop=True)

ORIG = v3.copy()

todo = pd.read_csv(F_TODO, dtype=str)
ue   = read_xls(F_UE)
ull  = pd.read_csv(F_ULL, dtype=str, encoding='mac_roman')

# ============================================ step 2: repair encoding =========
for col in ['source_citation', 'affiliation_original', 'affiliation', 'affiliation_simple']:
    new = v3[col].map(repair)
    for i in range(len(v3)):
        log(v3.row_xlsx.iloc[i], col, v3[col].iloc[i], new.iloc[i], 'encoding')
    v3[col] = new
for col in ['affiliation', 'affiliation_simple', 'Note']:
    ue[col] = ue[col].map(repair)
for col in ['affiliation', 'affiliation_simple', 'Note']:
    ull[col] = ull[col].map(repair)

# =================================== step 3: restore source_citation & n ======
v3['source_citation'] = v3.source_citation.ffill()
for i in range(len(v3)):
    log(v3.row_xlsx.iloc[i], 'source_citation', ORIG.source_citation.iloc[i],
        v3.source_citation.iloc[i], 'blank-continuation-row (forward fill)') \
        if not isinstance(ORIG.source_citation.iloc[i], str) else None

todo_exact  = dict(zip(todo.source_citation, todo.source_citation))
todo_k      = todo.groupby(todo.source_citation.map(key)).source_citation.first().to_dict()
_kn         = todo.groupby(todo.source_citation.map(key_nodigit)).source_citation.apply(
                  lambda s: sorted(set(s))).to_dict()
todo_n      = dict(zip(todo.source_citation, todo.n))

def resolve(sc):
    if not isinstance(sc, str): return None, 'blank'
    if sc in todo_exact: return sc, 'exact'
    k = key(sc)
    if k in todo_k: return todo_k[k], 'us-uk-neutral key'
    c = _kn.get(key_nodigit(sc))
    if c and len(c) == 1: return c[0], 'digit-stripped key (drag-down page number)'
    if c: return None, f'ambiguous ({len(c)} candidates)'
    return None, 'unmatched'

res = v3.source_citation.map(resolve)
v3['sc_resolved'] = [r[0] for r in res]
v3['sc_how']      = [r[1] for r in res]
UNMATCHED = v3[v3.sc_resolved.isna()].copy()

for i in range(len(v3)):
    if isinstance(v3.sc_resolved.iloc[i], str):
        log(v3.row_xlsx.iloc[i], 'source_citation', v3.source_citation.iloc[i],
            v3.sc_resolved.iloc[i], 're-keyed to twatasha_todo.csv (%s)' % v3.sc_how.iloc[i])
v3['source_citation'] = v3.sc_resolved.fillna(v3.source_citation)

n_new = v3.source_citation.map(todo_n)
for i in range(len(v3)):
    if isinstance(n_new.iloc[i], str):
        log(v3.row_xlsx.iloc[i], 'n', v3.n.iloc[i], n_new.iloc[i], 're-keyed to twatasha_todo.csv')
v3['n'] = n_new.fillna(v3.n)

# ================================= step 4: reverse mid-word us/uk =============
# Decisions of type `token_replacement` override the inferred case for a whole
# whitespace-delimited token; anything not overridden falls through to unreplace().
TOKEN_OVERRIDE = {}
for d in DECISIONS:
    if d['decision_type'] != 'token_replacement':
        continue
    if not d['target'] or not d['new_value']:
        dec_log(d, 'bad_decision', 0, 'token_replacement needs target and new_value')
        continue
    TOKEN_OVERRIDE[d['target']] = d['new_value']

def apply_token_overrides(s):
    if not isinstance(s, str) or not TOKEN_OVERRIDE:
        return s, 0
    hits = 0
    for broken, fixed in TOKEN_OVERRIDE.items():
        if broken in s:
            s, k = re.subn(r'(?<!\w)' + re.escape(broken) + r'(?!\w)',
                           lambda _m, f=fixed: f, s)
            hits += k
    return s, hits

TOKEN_HITS = collections.Counter()
def unreplace_decided(s):
    s, _ = apply_token_overrides(s)
    return unreplace(s)

TOKENS = collections.Counter()
for col in ['affiliation_original', 'affiliation', 'affiliation_simple']:
    for i, s in enumerate(v3[col]):
        if isinstance(s, str):
            for broken in TOKEN_OVERRIDE:
                TOKEN_HITS[broken] += len(re.findall(
                    r'(?<!\w)' + re.escape(broken) + r'(?!\w)', s))
    new = v3[col].map(unreplace_decided)
    for i in range(len(v3)):
        b, a = v3[col].iloc[i], new.iloc[i]
        if isinstance(b, str) and b != a:
            log(v3.row_xlsx.iloc[i], col, b, a, 'mid-word US/UK find-replace reversed')
            for m in _MIDWORD.finditer(b):
                lo = b.rfind(' ', 0, m.start()) + 1
                hi = b.find(' ', m.end());  hi = len(b) if hi < 0 else hi
                tok = b[lo:hi].strip(' .,;:()[]')
                TOKENS[(col, tok, unreplace(tok))] += 1
    v3[col] = new
for col in ['affiliation', 'affiliation_simple']:
    ue[col]  = ue[col].map(unreplace_decided)
    ull[col] = ull[col].map(unreplace_decided)
for d in DECISIONS:
    if d['decision_type'] == 'token_replacement' and d['target'] in TOKEN_OVERRIDE:
        n = TOKEN_HITS.get(d['target'], 0)
        dec_log(d, 'applied' if n else 'no_match', n,
                '' if n else 'token not present in the spreadsheet')

# =========================================== step 5: whitespace ===============
# source_citation is deliberately excluded: it must stay byte-identical to
# twatasha_todo.csv so it still joins back to vector_extraction_data.csv.
for col in ['affiliation_original', 'affiliation', 'affiliation_simple']:
    new = v3[col].map(squash)
    for i in range(len(v3)):
        log(v3.row_xlsx.iloc[i], col, v3[col].iloc[i], new.iloc[i], 'whitespace normalised')
    v3[col] = new
for d in (ue, ull):
    for col in ['affiliation', 'affiliation_simple']:
        d[col] = d[col].map(squash)

# ============ step 5b: collapse formatting-only affiliation_simple duplicates ==
lab = v3.affiliation_simple.dropna()
freq = lab.value_counts()
groups = collections.defaultdict(set)
for v in set(lab): groups[label_key(v)].add(v)
CANON = {}
COLLAPSED = []
for k, vs in groups.items():
    if len(vs) > 1:
        winner = sorted(vs, key=lambda x: (-freq[x], x))[0]
        for v in vs:
            CANON[v] = winner
            if v != winner:
                COLLAPSED.append(dict(label_key=k, from_label=v, n_rows=int(freq[v]),
                                      to_label=winner, n_rows_target=int(freq[winner])))
new = v3.affiliation_simple.map(lambda x: CANON.get(x, x))
for i in range(len(v3)):
    log(v3.row_xlsx.iloc[i], 'affiliation_simple', v3.affiliation_simple.iloc[i],
        new.iloc[i], 'formatting-only duplicate label collapsed')
v3['affiliation_simple'] = new
for d in (ue, ull):
    d['affiliation_simple'] = d.affiliation_simple.map(lambda x: CANON.get(x, x))

# ============ step 5c: apply the label decisions ==============================
# Order matters. affiliation_relabel moves individual affiliation strings onto a
# different label; label_rename then renames (and thereby merges) whole labels.

for d in DECISIONS:
    if d['decision_type'] != 'affiliation_relabel':
        continue
    if not d['target'] or not d['new_value']:
        dec_log(d, 'bad_decision', 0, 'affiliation_relabel needs target and new_value')
        continue
    hit = v3.affiliation == d['target']
    if not hit.any():
        dec_log(d, 'no_match', 0, 'no row has that exact affiliation string')
        continue
    for i in np.where(hit)[0]:
        log(v3.row_xlsx.iloc[i], 'affiliation_simple', v3.affiliation_simple.iloc[i],
            d['new_value'], 'decision: affiliation_relabel')
    v3.loc[hit, 'affiliation_simple'] = d['new_value']
    dec_log(d, 'applied', int(hit.sum()))

RENAME = {}
for d in DECISIONS:
    if d['decision_type'] != 'label_rename':
        continue
    if not d['target'] or not d['new_value']:
        dec_log(d, 'bad_decision', 0, 'label_rename needs target and new_value')
        continue
    if d['target'] in RENAME and RENAME[d['target']] != d['new_value']:
        dec_log(d, 'bad_decision', 0,
                'target already renamed to %r elsewhere' % RENAME[d['target']])
        continue
    RENAME[d['target']] = d['new_value']

def resolve_renames(mapping):
    """Follow chains (A->B, B->C gives A->C). Returns (resolved, cycles)."""
    out, cycles = {}, set()
    for start in mapping:
        seen, cur = [start], mapping[start]
        while cur in mapping:
            if cur in seen:
                cycles.update(seen)
                break
            seen.append(cur)
            cur = mapping[cur]
        else:
            out[start] = cur
            continue
        out[start] = start                     # cycle: leave untouched
    return out, cycles

RENAME, RENAME_CYCLES = resolve_renames(RENAME)
labels_now = set(v3.affiliation_simple.dropna())
for d in DECISIONS:
    if d['decision_type'] != 'label_rename' or d['target'] not in RENAME:
        continue
    if d['target'] in RENAME_CYCLES:
        dec_log(d, 'cycle', 0, 'label_rename chain loops back on itself; not applied')
        continue
    n = int((v3.affiliation_simple == d['target']).sum())
    dec_log(d, 'applied' if n else 'no_match', n,
            '' if n else 'no row currently carries that label')

if RENAME:
    before = v3.affiliation_simple.copy()
    after = before.map(lambda x: RENAME.get(x, x) if isinstance(x, str) else x)
    for i in range(len(v3)):
        log(v3.row_xlsx.iloc[i], 'affiliation_simple', before.iloc[i], after.iloc[i],
            'decision: label_rename')
    v3['affiliation_simple'] = after
    for d_ in (ue, ull):
        d_['affiliation_simple'] = d_.affiliation_simple.map(
            lambda x: RENAME.get(x, x) if isinstance(x, str) else x)

# ================================================ deliverable 1 ===============
D1 = v3[['source_citation', 'n', 'affiliation_original', 'affiliation', 'affiliation_simple']].copy()
D1.to_csv(f'{FINAL}/affiliations_complete_20260817.csv', index=False, encoding='utf-8')

# ================================================ deliverable 2 ===============
D2 = (v3.dropna(subset=['affiliation', 'affiliation_simple'])[['affiliation_simple', 'affiliation']]
        .drop_duplicates()
        .sort_values(['affiliation_simple', 'affiliation'], key=lambda s: s.str.lower()))
D2['n_rows'] = D2.apply(
    lambda r: int(((v3.affiliation == r.affiliation) &
                   (v3.affiliation_simple == r.affiliation_simple)).sum()), axis=1)
D2.to_csv(f'{FINAL}/affiliation_lookup_20260817.csv', index=False, encoding='utf-8')

# ================================================ deliverable 3 ===============
def fnum(x):
    if not isinstance(x, str): return np.nan
    x = x.strip().rstrip(',').strip()
    if x.upper() == 'ABSENT': return np.nan
    try: return float(x)
    except Exception: return np.nan

def haversine(a, b, c, d):
    R = 6371.0; p = math.radians
    x = math.sin(p(c-a)/2)**2 + math.cos(p(a))*math.cos(p(c))*math.sin(p(d-b)/2)**2
    return 2*R*math.asin(math.sqrt(x))

for d in (ue, ull):
    d['lat'] = d.Latitude.map(fnum); d['lon'] = d.Longitude.map(fnum)
    d['absent'] = d.Latitude.astype(str).str.strip().str.upper().eq('ABSENT') | \
                  d.Longitude.astype(str).str.strip().str.upper().eq('ABSENT')

# unique_entries (round 2) is the authority; unique_affiliations_Lat_Long (round 1)
# is consulted only for labels round 2 never covered. Conflicts are therefore
# computed within one source at a time, never manufactured by mixing the two.
ue['lk']  = ue.affiliation_simple.map(join_key)
ull['lk'] = ull.affiliation_simple.map(join_key)
ue,  ull  = ue.assign(src='unique_entries 26.sep.2024'), \
            ull.assign(src='unique_affiliations_Lat_Long')

CONFLICTS = []
resolved = {}
def absorb(frame):
    for k, d in frame.dropna(subset=['lk']).groupby('lk'):
        if k in resolved and resolved[k][2] in ('ok', 'conflict'):
            continue
        pairs = d.dropna(subset=['lat', 'lon'])[['lat', 'lon']].drop_duplicates().values
        note  = '; '.join(sorted({x for x in d.Note.dropna() if x.strip()}))
        srcs  = d.src.iloc[0]
        if len(pairs) == 0:
            resolved[k] = (np.nan, np.nan, 'absent' if d.absent.any() else 'missing', note, srcs)
        elif len(pairs) == 1:
            resolved[k] = (pairs[0][0], pairs[0][1], 'ok', note, srcs)
        else:
            mx = max(haversine(*pairs[i], *pairs[j])
                     for i in range(len(pairs)) for j in range(i+1, len(pairs)))
            resolved[k] = (np.nan, np.nan, 'conflict', note, srcs)
            CONFLICTS.append(dict(affiliation_simple=d.affiliation_simple.iloc[0],
                                  coord_file_label=d.affiliation_simple.iloc[0],
                                  n_candidates=len(pairs), max_separation_km=round(mx, 4),
                                  candidates='; '.join(f'{a},{b}' for a, b in pairs),
                                  source=srcs, note=note))
absorb(ue)
absorb(ull)

# `coordinate` decisions win over everything the source files say.
COORD_DECISION = {}
for d in DECISIONS:
    if d['decision_type'] != 'coordinate':
        continue
    try:
        la, lo = float(d['latitude']), float(d['longitude'])
    except (ValueError, TypeError):
        dec_log(d, 'bad_coordinate', 0, 'latitude/longitude do not parse as numbers')
        continue
    if not (-90 <= la <= 90 and -180 <= lo <= 180):
        dec_log(d, 'bad_coordinate', 0, 'outside [-90,90] / [-180,180]')
        continue
    COORD_DECISION[d['target']] = (la, lo, d.get('note', ''), d)

D3 = pd.DataFrame({'affiliation_simple':
                   sorted(set(v3.affiliation_simple.dropna()), key=str.lower)})
D3['lk'] = D3.affiliation_simple.map(join_key)
D3['latitude']     = D3.lk.map(lambda k: resolved.get(k, (np.nan,)*5)[0])
D3['longitude']    = D3.lk.map(lambda k: resolved.get(k, (np.nan,)*5)[1])
D3['coord_status'] = D3.lk.map(lambda k: resolved.get(k, (np.nan, np.nan, 'missing', '', ''))[2])
D3['note']         = D3.lk.map(lambda k: resolved.get(k, (np.nan, np.nan, '', '', ''))[3])
D3['coord_source'] = D3.lk.map(lambda k: resolved.get(k, (np.nan, np.nan, '', '', ''))[4])
D3.loc[D3.affiliation_simple == 'ABSENT', 'coord_status'] = 'absent'

D3_JK = D3.affiliation_simple.map(join_key)
for lbl, (la, lo, nt, d) in COORD_DECISION.items():
    hit = D3.affiliation_simple == lbl
    how = ''
    if not hit.any():
        # The coordinate files spell some labels differently from the spreadsheet
        # (`CDC USA` there, `CDC United States` here). A decision written against the
        # coordinate-file spelling is honoured by matching on join_key, provided that
        # resolves to exactly one label.
        jk = join_key(lbl)
        cand = D3.affiliation_simple[D3_JK == jk].tolist()
        if len(cand) == 1:
            hit = D3.affiliation_simple == cand[0]
            how = 'matched via join key to %r' % cand[0]
        elif len(cand) > 1:
            dec_log(d, 'no_match', 0, 'ambiguous: join key matches %s' % cand)
            continue
    if not hit.any():
        dec_log(d, 'no_match', 0, 'no affiliation_simple by that name (check spelling, '
                                  'and apply label_rename first if you renamed it)')
        continue
    D3.loc[hit, ['latitude', 'longitude', 'coord_status', 'coord_source']] = \
        [la, lo, 'decided', 'affiliation_decisions.csv']
    if nt:
        D3.loc[hit, 'note'] = nt
    dec_log(d, 'applied', int(hit.sum()), how)

D3['n_rows'] = D3.affiliation_simple.map(v3.affiliation_simple.value_counts()).fillna(0).astype(int)
D3 = D3.drop(columns='lk')
D3.to_csv(f'{FINAL}/affiliation_simple_coords_20260817.csv', index=False, encoding='utf-8')

# ------------------------------------- accept_as_is / note_only -------------
REVIEWED = set()
for d in DECISIONS:
    if d['decision_type'] not in ('accept_as_is', 'note_only'):
        continue
    tgt = d['target']
    known = (tgt in set(v3.affiliation_simple.dropna())) or \
            (tgt in set(v3.affiliation.dropna()))
    REVIEWED.add(tgt)
    dec_log(d, 'applied' if known else 'no_match', 1 if known else 0,
            '' if known else 'target matches no affiliation or affiliation_simple')

for d in DECISIONS:
    if d['decision_type'] not in DEC_TYPES:
        dec_log(d, 'bad_decision', 0,
                'unknown decision_type; expected one of: %s' % ', '.join(sorted(DEC_TYPES)))

def mark_reviewed(df, col):
    if len(df) == 0:
        df = df.copy(); df['reviewed'] = pd.Series(dtype=bool); return df
    df = df.copy()
    df['reviewed'] = df[col].isin(REVIEWED)
    return df

DR = pd.DataFrame(DEC_REPORT, columns=['decision_type', 'target', 'new_value', 'latitude',
                                       'longitude', 'status', 'n_affected', 'message',
                                       'note', 'decided_on'])
DR.to_csv(f'{OUT}/decisions_report.csv', index=False, encoding='utf-8')

# ================================================= review lists ===============
pd.DataFrame([dict(column=c, broken_token=b, proposed=a, n_occurrences=int(n))
              for (c, b, a), n in sorted(TOKENS.items())]) \
  .to_csv(f'{OUT}/review_us_uk_tokens.csv', index=False, encoding='utf-8')

enc = pd.DataFrame([c for c in CHANGES if c['reason'] == 'encoding'])
enc.to_csv(f'{OUT}/review_encoding_repairs.csv', index=False, encoding='utf-8')

# affiliation -> >1 affiliation_simple
rows = []
d = v3.dropna(subset=['affiliation', 'affiliation_simple'])
for a, sub in d.groupby('affiliation'):
    labs = sorted(set(sub.affiliation_simple))
    if len(labs) > 1:
        rows.append(dict(issue='one affiliation, several affiliation_simple',
                         affiliation=a, affiliation_simple_values=' | '.join(labs),
                         n_values=len(labs), n_rows=len(sub)))
mark_reviewed(pd.DataFrame(rows, columns=['issue', 'affiliation', 'affiliation_simple_values',
                                          'n_values', 'n_rows']), 'affiliation') \
    .to_csv(f'{OUT}/review_simple_conflicts.csv', index=False, encoding='utf-8')

pd.DataFrame(COLLAPSED).to_csv(f'{OUT}/review_labels_collapsed.csv', index=False, encoding='utf-8')

lump = (d.groupby('affiliation_simple')
          .agg(n_distinct_affiliations=('affiliation', 'nunique'), n_rows=('affiliation', 'size'))
          .reset_index().sort_values('n_distinct_affiliations', ascending=False))
lump['affiliations'] = lump.affiliation_simple.map(
    lambda s: ' | '.join(sorted(set(d.loc[d.affiliation_simple == s, 'affiliation']))))
mark_reviewed(lump[lump.n_distinct_affiliations > 1], 'affiliation_simple').to_csv(
    f'{OUT}/review_simple_lumping.csv', index=False, encoding='utf-8')

# label the conflicts by the spreadsheet's spelling where one exists, keeping the
# coordinate file's spelling alongside, so a decision made from this list targets a label
# that the deliverables actually contain
_v3_by_jk = {}
for _l in set(v3.affiliation_simple.dropna()):
    _v3_by_jk.setdefault(join_key(_l), []).append(_l)
for _c in CONFLICTS:
    _m = _v3_by_jk.get(join_key(_c['affiliation_simple']), [])
    if len(_m) == 1:
        _c['affiliation_simple'] = _m[0]
pd.DataFrame(CONFLICTS, columns=['affiliation_simple', 'coord_file_label', 'n_candidates',
                                 'max_separation_km', 'candidates', 'source', 'note']) \
    .sort_values('max_separation_km', ascending=False) \
    .to_csv(f'{OUT}/review_coord_conflicts.csv', index=False, encoding='utf-8')

D3[D3.coord_status.isin(['missing', 'conflict'])][
    ['affiliation_simple', 'coord_status', 'n_rows', 'note']].to_csv(
    f'{OUT}/review_missing_coords.csv', index=False, encoding='utf-8')
# coordinate conflicts that a decision has already settled drop out above, because
# coord_status becomes 'decided'.

miss_src = sorted(set(todo.source_citation) - set(v3.source_citation))
pd.concat([
    UNMATCHED[['row_xlsx', 'source_citation', 'sc_how', 'affiliation', 'affiliation_simple']]
        .assign(issue='v3 row not matched to twatasha_todo.csv'),
    pd.DataFrame([dict(issue='todo source never given an affiliation',
                       source_citation=s) for s in miss_src]),
]).to_csv(f'{OUT}/review_unmatched_sources.csv', index=False, encoding='utf-8')

# ==================================================== diff report =============
pd.DataFrame(CHANGES).to_csv(f'{OUT}/diff_report_20260817.csv', index=False, encoding='utf-8')

# ==================================================== checksums ==============
sums = {}
for f in sorted(os.listdir(OUT)):
    if f.endswith('.csv'):
        sums[f] = hashlib.sha256(open(f'{OUT}/{f}', 'rb').read()).hexdigest()
json.dump(sums, open(f'{OUT}/checksums.json', 'w'), indent=1)

print('rows', len(D1), '| deliverable2', len(D2), '| deliverable3', len(D3),
      ('| %d added from added_affiliations.csv' % N_ADDED) if N_ADDED else '',
      ('| %d ABSENT placeholder(s) replaced' % N_REPLACED) if N_REPLACED else '')
print('changes logged', len(CHANGES))
print('unmatched v3 rows', len(UNMATCHED), '| todo sources never filled', len(miss_src))
print('coord status:'); print(D3.coord_status.value_counts().to_string())
print('labels collapsed', len(COLLAPSED), '| coord conflicts', len(CONFLICTS))
print('us/uk tokens', len(TOKENS))
if DECISIONS:
    print('\ndecisions in %s: %d' % (F_DEC, len(DECISIONS)))
    print(DR.status.value_counts().to_string())
    bad = DR[DR.status != 'applied']
    if len(bad):
        print('\n!! %d decision(s) did NOT apply -- see output/decisions_report.csv' % len(bad))
        for _, r in bad.iterrows():
            print('   [%s] %s | %r -> %r | %s'
                  % (r.status, r.decision_type, r.target[:60], r.new_value[:40], r.message))
elif os.path.exists(F_DEC):
    print('\ndecisions file %s is empty (nothing to apply)' % F_DEC)
else:
    print('\nno decisions file at %s (nothing to apply)' % F_DEC)
