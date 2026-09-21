# Affiliation cleaning — what was done, what is left

Companion to `aff_audit_plan.md`, which sets out the file lineage and the full damage
inventory. This is the record of what the pipeline actually did and what still needs your
decision.

Deliverables produced 2026-08-17 from
`data/twatasha_final_data/Affiliation spreadsheet_version 3. 26 Sep. 2024.xlsx`,
`data/twatasha_final_data/unique_entries 26.sep.2024.xls`,
`data/unique_affiliations_Lat_Long.csv` and `output/twatasha_todo.csv`.

---

## Deliverables

| File | Rows | What it is |
|---|---|---|
| `output/affiliations_complete_20260817.csv` | 1273 | version 3 with the errors repaired. Columns `source_citation, n, affiliation_original, affiliation, affiliation_simple` |
| `output/affiliation_lookup_20260817.csv` | 1002 | distinct (`affiliation_simple`, `affiliation`) pairs, with `n_rows` |
| `output/affiliation_simple_coords_20260817.csv` | 398 | one row per `affiliation_simple`, with `latitude`, `longitude`, `coord_status`, `note`, `coord_source`, `n_rows` |

`coord_status` breakdown:

| status | n | meaning |
|---|---|---|
| `ok` | 262 | single unambiguous coordinate |
| `missing` | 88 | **no coordinate anywhere — these are the ones to go and find** |
| `conflict` | 29 | two or more coordinates on record; left blank for you to settle |
| `absent` | 19 | recorded as `ABSENT`, i.e. deliberately no location |

`source_citation` in deliverable 1 is byte-identical to `output/twatasha_todo.csv`, so it
still joins to `data/vector_extraction_data.csv`. It is deliberately excluded from
whitespace normalisation for that reason.

---

## What was changed, and what was not

1174 cells changed. Every one is listed in `output/diff_report_20260817.csv` with its
before, after and reason.

| reason | cells |
|---|---|
| encoding repaired | 411 |
| `source_citation` re-keyed to `twatasha_todo.csv` | 396 |
| whitespace normalised | 270 |
| mid-word `United States`/`United Kingdom` reversed | 62 |
| `n` re-keyed to `twatasha_todo.csv` | 11 |
| blank continuation row forward-filled | 11 |
| formatting-only duplicate label collapsed | 13 |

Per your instructions, the following were **not** changed and appear only in review lists:
typos, judgement calls about which institution a label denotes, coordinate conflicts, and
the standalone `US`→`United States` / `UK`→`United Kingdom` expansions.

### The mid-word US/UK reversal

The case of the original (`us`, `US`, `usa`, `USA`) is not recoverable from the string, so
it was inferred: the character following the substitution decides, falling back to the
preceding character when nothing follows. That yields `Museum` rather than `MUSeum`, and
`USTTB` rather than `usTTB`. All 21 distinct tokens and their proposed replacements are in
`output/review_us_uk_tokens.csv` — check them. They are:

```
August  Causeway  Campus  Infectieuses  Infectious  Just  Museum  Non-Infectious
Sustainable  Skukuza  Trust  Virus  campus  KNUST  USTTB
```

### The labels collapsed

Eight labels were merged into five, on formatting alone (case, trailing punctuation,
accents, one comma). Listed in `output/review_labels_collapsed.csv`:

```
CSRS Cote d'Ivoire          -> CSRS Côte d'Ivoire
UVM United states           -> UVM United States
UB United states            -> UB United States
LIN/IRD France              -> LIN-IRD France
ORSTOM Sénégal              -> ORSTOM Senegal
ORSTOM Sénégal.             -> ORSTOM Senegal
Centre Muraz Burkina Faso.  -> Centre Muraz Burkina Faso
Centre Muraz, Burkina Faso  -> Centre Muraz Burkina Faso
```

The `ORSTOM Sénégal` → `ORSTOM Senegal` direction was chosen by frequency (12 rows against
1), not by correctness. Reverse it if the accented form is the one you want.

---

## What needs your decision

| File | Rows | Question it poses |
|---|---|---|
| `review_us_uk_tokens.csv` | 21 | is each inferred replacement right? |
| `review_simple_conflicts.csv` | 22 | one affiliation string carrying two or more labels — typo or real distinction? |
| `review_simple_lumping.csv` | 133 | one label covering several affiliation strings — same place or not? |
| `review_coord_conflicts.csv` | 29 | which of the competing coordinates is right? |
| `review_missing_coords.csv` | 117 | 88 to geocode, plus the 29 conflicts |
| `review_unmatched_sources.csv` | 1 | Diop et al. 2002 was never given an affiliation in either round |
| `review_encoding_repairs.csv` | 411 | spot-check the encoding repairs |
| `review_labels_collapsed.csv` | 8 | the merges listed above |

Worth looking at first, from `review_coord_conflicts.csv`:

```
Wits University South Africa   5825 km   latitude sign error: -26.1899 vs +26.1929
CIRAD France                    393 km
BRL Zimbabwe                    365 km   Harare vs Chiredzi
IHI Tanzania                    323 km   Dar es Salaam vs Ifakara, both real IHI sites
LSTM United Kingdom             161 km   -5.4080 is in the Irish Sea; -2.9716 is Liverpool
University of Wales UK           84 km   Lampeter vs Cardiff
```

The remaining 23 differ by 7 km or less, most by a few hundred metres.

Note also that because the standalone expansions were kept, `CDC United States` in the
spreadsheet and `CDC USA` in `unique_entries` are the same institution recorded twice with
different coordinates — that is why `CDC United States` shows as a conflict. Same for
`Norte Dame`, `Bacilligen` and `Tulane`. Deciding those is a matter of picking one
coordinate, not of relabelling.

---

## Reproducing this

Two implementations, and one caveat.

`R/tidy_affiliations.py` is the reference. It was run, and `R/verify_affiliations.py`
asserts 36 properties over its output — row count, `n` agreement with
`twatasha_todo.csv`, absence of every damage signature, key uniqueness and coverage across
the three deliverables, coordinate parsing and range, non-null counts preserved, and a
re-read of 20 random cells against the original spreadsheet. All 36 pass.

```
python3 R/tidy_affiliations.py && python3 R/verify_affiliations.py
```

`R/tidy_affiliations.R` was a transcription of it. **It was never run**, it never mirrored
the later Python changes, and it was deleted on 2026-09-21; the paragraph below is kept as
the record of what it was. R was not
installed in the environment where this was written and neither apt nor CRAN was
reachable, so it could not be tested. Do not assume it works. It carries two guards:

* a self-test that runs 11 known repairs before touching any data and stops if `iconv` on
  your machine does not support the `macintosh` encoding as the repair assumes;
* a parity check that compares its three deliverables, cell by cell, against the frozen
  pre-decisions copies in `output/parity_baseline/` and stops on any difference.

If both pass, the two implementations agree and you can delete the parity section. If the
parity check fails, the baseline CSVs are the ones to trust — they are what the tested
implementation produced.

Encoding repair in R, for reference:

```r
# layer A: UTF-8 bytes displayed through Mac Roman   "Deuxi√®me" -> "Deuxième"
raw <- iconv(s, from = "UTF-8", to = "macintosh", toRaw = TRUE)[[1]]
out <- rawToChar(raw); Encoding(out) <- "UTF-8"

# layer B: CP1252 bytes displayed through Mac Roman  "GÈnÈtique" -> "Génétique"
raw <- iconv(s, from = "UTF-8", to = "macintosh", toRaw = TRUE)[[1]]
out <- iconv(rawToChar(raw), from = "windows-1252", to = "UTF-8")
```

`data/unique_affiliations_Lat_Long.csv` is stored on disk in Mac Roman. Read it with
`locale = locale(encoding = "macintosh")` or it will mangle.

---

## One thing you did not ask about

`data/unique_entries_tidy_20250203.xls` and `.csv` are identical to
`data/twatasha_final_data/unique_entries 26.sep.2024.xls` in all 510 × 5 cells. The
February 2025 pass changed nothing. Nothing was lost by starting again from the September
2024 file.
