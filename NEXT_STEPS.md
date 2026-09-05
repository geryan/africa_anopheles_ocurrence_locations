# NEXT_STEPS.md — where this got to, and what is left

Last updated 2026-09-03. Read `CLAUDE.md` first for the working rules — particularly the
one about never saving a project CSV out of Excel.

---

## Start here — the whole job on one page

Updated 2026-09-03. Everything below this section is background and detail; you do not
need it to finish.

> **Counts below are the 2026-09-03 starting position and are now out of date.** Step 1
> is part done and step 2 is finished; 78 decisions are in place and 55 labels are still
> open. `CLAUDE.md` § "Where this is up to" has the current state — trust it over the
> numbers here. The mechanics in §1 below are still accurate.

**The end state** is three files in `output/`. Two are already final unless you change a
label. The third — `affiliation_simple_coords_*.csv` — has 117 labels waiting on a
coordinate decision from you. That is the job.

**Where decisions live:** one file, `data/affiliation_decisions.csv`. You never edit the
output files. Coordinates get into it via a spreadsheet; label fixes get into it by hand.

### Step 0 — one-time setup — DONE 2026-09-03

`pandas`, `xlrd` and `openpyxl` are installed and the rebuild runs on this machine. A
clean run reproduces the reference output exactly and verify passes. Nothing to do here.

The check count is 36 with no decisions and 41 once the decisions file holds any. Both are
correct; the rise is the five extra checks that confirm your decisions landed.

### Step 1 — coordinates: 146 yes/no answers in one spreadsheet

```bash
Rscript R/coord_review.R          # builds data/coord_review.xlsx
```

Open `data/coord_review.xlsx` in Excel (this one file is safe to open in Excel — it is
xlsx, not csv). Work down column A, `accepted`:

- `case = missing` (88 rows, one per label): `yes` if the proposed coordinate is right,
  `no` if not. Evidence to decide from is on the same row: `latitude`, `longitude`,
  `precision`, `confidence`, `source_url`, `google_maps`, `resolved_name`, `affiliation`.
  Nineteen rows are city centroids and five are programme headquarters — `precision`
  tells you which; say `no` to those if a centroid is not good enough for your purpose.
- `case = conflict` (58 rows, two per label): `yes` on the one you want, `no` on the other.
- Wrong on both? Type your own `latitude`/`longitude` into a row and mark it `yes`.

Save. Then:

```bash
Rscript R/coord_review.R          # your answers -> data/affiliation_decisions.csv
python3 R/tidy_affiliations.py && python3 R/verify_affiliations.py
```

You can stop and resume at any point; the sheet keeps your answers. When every label is
settled, `coord_status` in the output has no `missing` or `conflict` left.

### Step 2 — labels: merge the duplicates

Some `affiliation_simple` values are the same place under different spellings. Fixing
these is optional for a usable table, but it is why ten Bamako labels currently get ten
separate rows. Record each fix as a line in `data/affiliation_decisions.csv`, opened in
**RStudio, never Excel**:

```
label_rename,Wits Unitversity South Africa,Wits University South Africa,,,typo,2026-09-03
label_rename,UTHB United States,UTMB United States,,,typo,2026-09-03
accept_as_is,IRD France,,,,checked; one site,2026-09-03
```

Where to find them, in order of certainty: `same_coord_group` in the xlsx (10 groups,
near-certain), `output/review_simple_conflicts.csv` (22, mostly typos),
`output/review_simple_lumping.csv` (133, judgement calls — skip if you do not care about
that granularity). Rebuild after each batch. **Do labels after coordinates**: when you
merge label A into B, also blank A's `accepted` in the xlsx, or its coordinate decision
will be reported as `no_match` on the next rebuild.

### Step 3 — read the rebuild output, every time

The rebuild prints `N decisions applied` or shouts `!! N decision(s) did NOT apply`, and
`verify` ends `41 checks, 0 failed` or names what failed. A decision that did not apply is
almost always a mistyped target; `output/decisions_report.csv` says which.

### Ignore everything else

`aff_audit_plan.md`, `AFFILIATION_CLEANING_README.md`, `GEOCODING_NOTES.md` are the
record of how the data got into this state — reference, not tasks. `review_encoding_repairs`,
`review_us_uk_tokens`, `review_labels_collapsed` are optional spot-checks.
`review_missing_coords.csv` and `proposed_decisions_coords.csv` are superseded by the
xlsx. `R/tidy_affiliations.R` has never been run; use the Python.

---

## State

The automated repair is finished and verified. The three deliverables are in `output/` and
`python3 R/verify_affiliations.py` passes 41 assertions against them — last confirmed
2026-08-17, in an environment that had pandas.

What was repaired, all of it logged cell by cell in `output/diff_report_20260817.csv`:

| | cells |
|---|---|
| encoding (two stacked corruptions) | 411 |
| `source_citation` re-keyed to `twatasha_todo.csv` | 396 |
| whitespace | 270 |
| mid-word `United States`/`United Kingdom` reversed | 62 |
| `n` re-keyed | 11 |
| blank continuation rows forward-filled | 11 |
| formatting-only duplicate labels collapsed | 13 |

What remains is judgement work. Nothing below was decided unilaterally.

---

## The queue, roughly in order of value

### 1. Coordinates — 88 missing (proposed), 29 conflicting — do this in the spreadsheet

**Update 2026-08-24: there is now a spreadsheet loop for this.** `R/coord_review.R`
maintains `data/coord_review.xlsx`, and converts your answers into the `coordinate` rows of
`data/affiliation_decisions.csv`. You never hand-edit the decisions file for coordinates.

```bash
Rscript R/coord_review.R      # build/refresh the sheet
# open data/coord_review.xlsx, put yes/no in column A, save
Rscript R/coord_review.R      # answers -> data/affiliation_decisions.csv
python3 R/tidy_affiliations.py && python3 R/verify_affiliations.py   # needs pandas
```

Run it as often as you like. Every run reads your answers, rewrites the decisions file, and
rebuilds the sheet **with your answers still in it**. Settled rows sink to the bottom but
stay, so you can change your mind.

**146 rows over 117 labels — one row per candidate coordinate.** The 88 missing labels get
one row each carrying the proposed coordinate. The 29 conflicts get one row *per competing
coordinate*, so you tick the one you want rather than transcribing a lat/long.

Columns A–F are the ones you work in:

| column | |
|---|---|
| `accepted` | you fill this: `yes`, `no`, or blank. `y`/`x`/`1` also read as yes |
| `status` | `open`, `settled`, or `rejected - needs a new coordinate` |
| `affiliation_simple` | the label |
| `affiliation_simple_v3` | its version-3 spelling, where that differs (see below) |
| `n_affiliations` | how many distinct affiliation strings the label covers |
| `affiliation` | those strings, pipe-separated |

Then `case` (`missing` / `conflict` / `manual`), the coordinate, `precision`, `confidence`,
`resolved_name`, and a `your_note` column that becomes the decision's note. The rest —
`source_url`, `google_maps`, `nearest_existing_label`, `geocoder_notes` — are evidence to
decide from.

Things it will not let you do: accept two coordinates for one label (it stops and writes
nothing), put anything other than yes/no/blank in column A, or lose your non-coordinate
decisions — `label_rename` and friends are preserved verbatim.

To reject a coordinate and flag it for re-geocoding, put `no` against every candidate for
that label; status becomes `rejected - needs a new coordinate`. To supply your own
coordinate, overwrite `latitude`/`longitude` on a row and mark it yes.

**The sheet is `.xlsx`, not `.csv`, deliberately.** Excel round-trips xlsx as UTF-8 without
touching the accents, so this is the one project file that is safe to open and save.
Verified through a full round-trip on `São Tomé`, `Côte d'Ivoire` and `Allé`. Rule 1 in
`CLAUDE.md` still applies to every CSV in the project.

**Read `precision` before accepting in bulk.** Of the 88: 25 building, 39 campus, 19 city
centroid, 5 programme headquarters. The 24 city/HQ rows are not institution locations.
`resolved_name` is the geocoder's own account of what it found — it is where an
interpretation error shows up, so read it alongside the coordinate.

`n_affiliations` is worth watching. `LSTM United Kingdom` covers 23 distinct affiliation
strings and `CDC USA` 19; accepting one coordinate for those is a bigger call than for the
median label, which covers one. That is the lumping question from §3 surfacing here.

The old bulk-adopt path still exists — `cp output/proposed_decisions_coords.csv
data/affiliation_decisions.csv` — and was tested: all 88 apply, `missing` drops to 0,
verify passes 41/41. It accepts every proposal including the 24 weak ones, so prefer the
sheet.

Six conflicts are substantive and quick to settle; the rest differ by under 7 km:

```
Wits University South Africa   5825 km   latitude sign error: -26.1899 vs +26.1929
CIRAD France                    393 km
BRL Zimbabwe                    365 km   Harare vs Chiredzi
IHI Tanzania                    323 km   Dar es Salaam vs Ifakara — both real IHI sites
LSTM United Kingdom             161 km   -5.4080 is in the Irish Sea; -2.9716 is Liverpool
University of Wales UK           84 km   Lampeter vs Cardiff
```

Note the `CDC United States` / `CDC USA` class of conflict: the same institution was
recorded under two label spellings because the find-and-replace hit one file and not the
other, and the two rows carry different coordinates. Deciding these means picking a
coordinate, not relabelling. Same for `Norte Dame`, `Bacilligen`, `Tulane`.

Thirteen labels are in this class, and all are conflicts: `CDC USA`, `Griffin Laboratory
U.S`, `IC UK`, `ICAPB UK`, `Norte Dame US`, `Tulane University USA`, `UC Davis USA`,
`UM U.S`, `UVM USA`, `Ualbany U.S`, `University of Wales UK`, `UoE UK`, `Yale USA`. They
exist only in the coordinate files, never in version 3, so they have no affiliation text of
their own. The sheet matches them to their v3 counterpart using a transcription of
`join_key()` from `tidy_affiliations.py:164` and shows it in `affiliation_simple_v3` —
which is how `CDC USA` picks up `CDC United States` and its 19 affiliation strings.

Also `Ualbany U.S`: the two candidates are `2.6850312` and `42.6850273` — a dropped leading
`4`, the same class of error as the `Wits` sign flip. Both are in the sheet as candidates.

### 2. Labels that are probably typos — `review_simple_conflicts.csv`, 22 rows

One affiliation string carrying two or more labels. Some are plainly typos:

```
Wits Unitversity / Wits Univeristy / Wits University    South Africa
UY1 Cameroon vs UYI Cameroon          (digit one vs letter I)
UoK Sudan vs UofK Sudan
CNRFP Burina faso vs CNRFP Burkina Faso
MRC Gambia vs MRC The Gambia
CREC vs CREC Benin
```

Others are real questions — `IRD Cameroon` vs `OCEAC Cameroon` for the same laboratory,
`MRTC Mali` vs `ENMP Mali` vs `UB Mali` for the Bamako institutions, `CEMTROD Portugal`
vs `IHMT Portugal`. These need someone who knows the institutions.

Record as `label_rename` (typo or merge) or `affiliation_relabel` (this string belongs
under that label).

### 3. Labels covering possibly-distinct places — `review_simple_lumping.csv`, 133 rows

Largest lumps: `SAP Italy` (45 distinct affiliation strings), `OCEAC Cameroon` (28),
`LSTM United Kingdom` (23), `IRD France` (19), `CDC United States` (19), `UCAD Senegal`
(17), `UC United States` (16).

`IRD France` spans the Montpellier campus, the Faculté de Pharmacie, the Centre of Biology
and Management of Populations, and a bare "Institute of Research for Development, France".
Whether that is one location is a judgement call about how coarse the geocoding should be.

Watch for composite affiliations naming two institutions in two countries, e.g.
`Division of Parasitic Diseases, CDC, Atlanta, GA, USA, and Kenya Medical Research
Institute …` currently sitting under `CDC United States`.

`accept_as_is` marks a label as checked without changing anything — the review list then
shows `reviewed = TRUE` and it stops demanding attention.

### 4. Spot-checks — low effort, worth doing once

- `review_us_uk_tokens.csv`, 21 rows. The case of the original (`us` / `US` / `usa`) is
  not recoverable from the string and was inferred. `Museum`, `Campus`, `KNUST`, `USTTB`,
  `Skukuza`, `Infectieuses` all look right, but confirm.
- `review_encoding_repairs.csv`, 411 rows. Skim for anything that looks worse after repair
  than before.
- `review_labels_collapsed.csv`, 8 rows. In particular `ORSTOM Sénégal` → `ORSTOM Senegal`
  was chosen by frequency (12 rows against 1), not by correctness.

### 4b. Merge candidates surfaced by the geocoding

Thirty of the 88 landed within 500 m of an existing coordinate for the same institution,
and 29 of them fall into 10 same-place groups — including **ten** Bamako labels that are all
the Point G campus. `nearest_existing_label` and `same_coord_group` in
`output/proposed_coords_missing88_20260818.csv` are the working lists. Several are
unambiguous (`UTHB` is a typo for `UTMB`; `INSPQ Ivory Coast` and `IPR Ivory Coast` are one
site; `RTI Madagascar` is IRD Madagascar). Record as `label_rename`.

### 5. One paper with no affiliation at all

`review_unmatched_sources.csv`: Diop et al. 2002, *Role of Anopheles melas … in a mangrove
swamp in Saloum (Senegal)*, Parasite 9(3):239-46. It is in `twatasha_todo.csv` but was
never given an affiliation in either round. Needs the paper pulled up and the affiliation
entered — most likely into a new row appended to the version 3 spreadsheet, which is a
decision about process rather than data.

---

## The loop

**Coordinates** — via the spreadsheet, never by hand:

```bash
# 1. Rscript R/coord_review.R          build/refresh data/coord_review.xlsx
# 2. open the sheet, fill column A with yes/no, save
# 3. Rscript R/coord_review.R          answers -> data/affiliation_decisions.csv
# 4. rebuild + check
python3 R/tidy_affiliations.py && python3 R/verify_affiliations.py
```

**Everything else** — labels, typos, tokens — by editing the decisions file directly:

```bash
# 1. edit data/affiliation_decisions.csv  (in RStudio, or any plain-text editor)
# 2. rebuild
python3 R/tidy_affiliations.py
# 3. check nothing silently failed to apply
python3 R/verify_affiliations.py
```

`coord_review.R` only ever rewrites the `coordinate` rows for labels the sheet covers. Any
other decision row you have written, and any hand-written `coordinate` row for a label
outside the sheet, is passed through untouched — it says how many of each it kept.

The run prints a decisions summary and shouts about anything that did not apply.
`output/decisions_report.csv` has the detail. `verify_affiliations.py` fails if any
decision was a no-op, which is the guard against a mistyped target quietly doing nothing.

Because everything is regenerated from the decisions file, the review lists shrink as work
proceeds, and the whole cleanup stays reproducible from the original spreadsheets.

---

## Corrections to earlier notes

- **`BRL Zimbabwe`'s 365 km coordinate conflict is not an error.** Blair Research Laboratory
  is in Harare; the de Beers Research Laboratory is a separate field station at Chiredzi.
  Two sites, two correct coordinates, one label.
- **The MRC Sierra Leone address in the project note is wrong.** "5 Frazier Davis Drive,
  Freetown" matches no affiliation in the corpus; the papers say P.O. Box 81, **Bo**.
- **A residual find-and-replace bug**: `United States.A.` is `U.S.A.` with `US` expanded, in
  `Bacilligen United States` and `ND United States`. The mid-word reversal missed it because
  the surrounding full stops are not word characters. Fixable with a `token_replacement` row.

## Things deliberately not done

- **Standalone `US` → `United States` expansions were kept**, per instruction; only
  mid-word damage was reversed. The side effect is that `CDC USA` and `CDC United States`
  remain distinct label spellings across files. The coordinate lookup already treats them
  as the same label; the deliverables do not merge them.
- **Coordinate conflicts were not auto-resolved**, not even the 15 that differ by under
  300 m. All 29 are blank and flagged.
- **No typo was corrected** beyond pure formatting (case, trailing punctuation, accents,
  one stray comma).

## Known soft spots

- **`pandas` is not installed on this machine** (checked `python3`,
  `/opt/homebrew/bin/python3`, `/usr/bin/python3` on 2026-08-24). `tidy_affiliations.py`
  and `verify_affiliations.py` therefore cannot run here, despite being the tested
  reference. `pip install pandas xlrd` fixes it. Nothing in the repo warned about this,
  which is why it is here.
- `R/tidy_affiliations.R` has never been run. Treat its first execution as a test. If its
  self-test or parity check fails, the shipped CSVs in `output/shipped/` are the trusted
  artefacts. R 4.6.1 is installed with `readxl`, `readr`, `dplyr`, `stringi` and (added
  2026-08-24) `writexl`; `openxlsx` is absent.
- `R/coord_review.R` is tested for its own loop — answers survive a rebuild, yes/no
  normalisation, the duplicate-accept guard, preservation of non-coordinate decisions, and
  the UTF-8 round-trip. What has **not** been tested is the decisions file it produces
  actually flowing through `tidy_affiliations.py`, because pandas is missing. Do that once
  before trusting a large batch of accepts.
- `affiliation_simple` values that are actually full affiliation text (about 30 of them,
  e.g. `Blair and de Beers Research Laboratories, P.O. Box 8105. Causeway. Zimbabwe`)
  were left alone. They work as labels but are ugly, and several are among the 88 missing
  coordinates. Worth giving them proper short labels via `label_rename` while geocoding.
- The `n` column was carried through from `twatasha_todo.csv` unchanged and is the count
  of occurrence records per paper, not per affiliation. Do not sum it across the
  affiliation rows of one paper.
