# CLAUDE.md — africa_anopheles_ocurrence_locations_cc

Context for Claude Code working in this repository. The **"Start here" section at the top
of `NEXT_STEPS.md`** is the whole job on one page; the rest of that file is background.

## Where this is up to — 2026-09-04, end of third session

Step 0 (environment) is **done and verified**. Step 2 (label merges) is **effectively
finished**. Step 1 (coordinate decisions) is **well under way**.

**The build is not clean right now, and fixing it is the first action.** Two dead
`coordinate` decisions are reporting `no_match` and verify ends `41 checks, 2 failed`:

```
[no_match] coordinate | 'CIRAD France'   -> no affiliation_simple by that name
[no_match] coordinate | 'MIVEGEC France' -> no affiliation_simple by that name
```

Both labels were merged away, but their sheet rows were still ticked `yes`, so
`coord_review.R` reclassified them to `case = manual` — which is exempt from the
merged-away guard — and re-wrote the decisions after they had been deleted from the CSV.
**Fix: blank `A101` and `A107` in `data/coord_review.xlsx`** (verify the row numbers with
`openpyxl` first; they shift when the sheet is rebuilt), save, then re-run
`Rscript R/coord_review.R` and rebuild. Deleting the rows from the CSV alone does not
work — the sheet puts them straight back.

State as of the last rebuild, with those two still failing: `data/affiliation_decisions.csv`
holds **99 decisions, 97 applying**. Deliverable 3 is **366 labels: 256 ok, 52 decided,
40 missing, 18 absent, 0 conflict**. The sheet is **128 candidate rows over 93 labels, 54
settled, 39 open**. Once `A101`/`A107` are blanked, expect 97 decisions all applying and
`41 checks, 0 failed`; the label and coord_status counts do not change.

**After that, the remaining work is the 39 open `missing` rows in `data/coord_review.xlsx`**
— ordinary one-at-a-time yes/no calls. Loop is `Rscript R/coord_review.R` → owner ticks
column A in Excel → same command again → `python3 R/tidy_affiliations.py &&
python3 R/verify_affiliations.py`.

Every `same_coord_group` in the sheet has been resolved. Group 3 (`C/O.U.A., Zona
Sanitaria s/n, Equatorial Guinea` / `EGMI Equatorial Guinea`) was deliberately **kept
separate** — no evidence they are the same place. Do not re-merge it.

The Montpellier merge (2026-09-04) folded `MIVEGEC France`, `CIRAD France`, `LIN France`,
`LIN-IRD France` and `LIN-IRD, 911 Av. Agropolis, 34394, Montpellier, France` into
**`MIVEGEC / CIRAD / LIN Montpellier`** — 32 rows, coordinate `43.6497961, 3.864301`
(CIRAD's, at 911 avenue Agropolis). The LIN pair had been sitting at `43.6451206,
2.64785`, 98 km west in the Tarn. `Campus international de Baillarguet France`,
`CIRAD-EMVT France` and `ISEM France` are separate Montpellier-area labels deliberately
**not** in that merge.

### The `ok` coordinate sweep — done, with a known blind spot

`R/check_coord_sanity.R` (new, 2026-09-04) sweeps every coordinate-bearing label, which
the sheet never shows. Expected country from both the label and its affiliation strings,
actual country from `maps::map.where`, then `sf::st_distance` to the expected country's
polygon with a **10 km** coastal tolerance. **24 of 296 flagged** into
`output/review_coord_sanity.csv`, worst-first, one Google Maps link per row. Idempotent;
globs the newest dated deliverable, so re-run it after any batch of merges.

Error classes it found: latitude sign flipped for southern-hemisphere cities (Wits,
Antananarivo), a leading digit lost from latitude (`RIHS Burkina Faso`, Dakar, `SU
Yemen`), longitude sign flipped (`INSERM France`), and a coordinate copied verbatim from
an adjacent unrelated label (`UNHCR Sudan` = Umeå; Rothamsted = Bamako). None of the
owner's `decided` rows was flagged. **Nothing in it has been acted on.**

**What it still cannot see:** right country, wrong place. The 98 km Montpellier error
passed it clean. Labels naming no country — `DU Durham`, `One World Development Group,
Florida`, and now `MIVEGEC / CIRAD / LIN Montpellier` — cannot be tested at all.

One other known problem, not blocking: one affiliation string can sit under two labels
where the source spreadsheet labelled the same text two ways. Cosmetic; not a pipeline
fault.

Do not re-audit the project or re-derive its history; it is recorded in
`aff_audit_plan.md` and `AFFILIATION_CLEANING_README.md` and does not need re-reading to
do the remaining work.

## What the project is for

Locating the research centres behind a corpus of Anopheles occurrence records, by
geocoding the author affiliations of each source paper. Three deliverables:

1. every (paper, affiliation, affiliation_simple) row — `output/affiliations_complete_*.csv`
2. affiliation → affiliation_simple lookup — `output/affiliation_lookup_*.csv`
3. affiliation_simple → latitude/longitude — `output/affiliation_simple_coords_*.csv`

`affiliation_simple` is a short label (`IRD France`, `MRTC Mali`) that unifies the many
long-form strings denoting one place. It is the join key for coordinates.

## Working rules, in order of how much damage ignoring them causes

**1. Never open a project CSV in Excel and save over it.** This is not a stylistic
preference. The existing damage in this project was caused exactly that way: clean UTF-8
went into Excel on a Mac and came back as `YaoundÈ` and `Deuxi√®me`. If a file must be
inspected in a spreadsheet, use Excel's Data → From Text/CSV import with UTF-8 chosen
explicitly, and do not save back. Read them in R instead.

**2. `source_citation` must stay byte-identical to `output/twatasha_todo.csv`.** It is the
join key back to `data/vector_extraction_data.csv`. It is deliberately excluded from
whitespace normalisation. Do not trim it, do not collapse its double spaces, do not strip
its `<b>`/`<i>` tags.

**3. Never edit the deliverables by hand.** They are generated. Record judgement calls in
`data/affiliation_decisions.csv` and re-run — see below. A hand edit is lost on the next
run and leaves no trace of why it was made. For **coordinates**, do not edit the decisions
file either: tick `data/coord_review.xlsx` and let `R/coord_review.R` write those rows.

**4. Do not decide ambiguous cases unilaterally.** The project owner has been explicit
about this. Typos, institution identity, and coordinate choices are his calls. Surface
them in the review lists; do not quietly resolve them.

**5. `data/vector_extraction_data.csv` is 223 MB.** Do not read it. Everything needed from
it is already in `output/twatasha_todo.csv`.

## Encoding traps

Two separate corruptions exist in the source spreadsheets, with different inverses. Both
are handled by `repair()` in the pipeline; this is here so the diagnosis is not lost.

| layer | signature | cause | inverse |
|---|---|---|---|
| A | `√`, `©`, `Ä`, `†` | UTF-8 bytes displayed through Mac Roman | mac-roman bytes → decode UTF-8 |
| B | `È` for é, `Ù` for ô | CP1252 bytes displayed through Mac Roman | mac-roman bytes → decode CP1252 |

They stack: `G√àn√àtique` → `GÈnÈtique` → `Génétique`.

In R:

```r
# layer A
raw <- iconv(s, from = "UTF-8", to = "macintosh", toRaw = TRUE)[[1]]
out <- rawToChar(raw); Encoding(out) <- "UTF-8"

# layer B
raw <- iconv(s, from = "UTF-8", to = "macintosh", toRaw = TRUE)[[1]]
out <- iconv(rawToChar(raw), from = "windows-1252", to = "UTF-8")
```

`data/unique_affiliations_Lat_Long.csv` is stored on disk in **Mac Roman**, not UTF-8.
Read it with `locale = locale(encoding = "macintosh")`.

A third corruption, not an encoding one: a case-insensitive find-and-replace of `us`,
`usa` and `uk` to `United States` / `United Kingdom` ran without word boundaries, giving
`funestUnited States`, `ManoUnited Kingdomis`, `SoUnited States` (Sousa). Standalone
expansions were deliberate and are kept; only mid-word ones are reversed.

A fourth: Excel's fill handle incremented the trailing page number of repeated citations
(`259-61 … 259-65` where the truth is `259-66`). Fixed by re-keying every citation to
`twatasha_todo.csv`, which repairs all citation damage at once.

## Recording decisions

`data/affiliation_decisions.csv` is the single place judgement calls live. Header:

```
decision_type,target,new_value,latitude,longitude,note,decided_on
```

| decision_type | target | new_value | lat/long | effect |
|---|---|---|---|---|
| `label_rename` | current affiliation_simple | replacement label | — | renames everywhere; renaming A to B merges them. Chains resolve (A→B, B→C gives A→C); loops are refused |
| `affiliation_relabel` | exact affiliation string | affiliation_simple to assign | — | moves one affiliation string onto a different label |
| `coordinate` | affiliation_simple | — | required | overrides the source files; sets `coord_status = decided` |
| `token_replacement` | broken token, e.g. `MUnited Stateseum` | corrected form, e.g. `Museum` | — | overrides the inferred us/uk case |
| `accept_as_is` | label or affiliation | — | — | marks `reviewed = TRUE` in the review lists; changes nothing |
| `note_only` | label or affiliation | — | — | records a note; marks reviewed |

Rules that matter:

- **Every decision must apply.** Anything that matches nothing is reported as `no_match`
  in `output/decisions_report.csv` and printed at the end of the run. A silent no-op is
  the failure mode to guard against; `verify_affiliations.py` fails the run if any
  decision did not apply.
- **`coordinate` targets the label as it stands after renames.** If a label is being
  renamed and given a coordinate, target the new name.
- The file is optional. Absent or header-only, the pipeline reproduces the shipped
  outputs byte-for-byte.
- `data/affiliation_decisions_EXAMPLE.csv` shows every type in use. It is illustrative —
  do not copy it into place wholesale.

## Running things

From the project root:

```bash
Rscript R/coord_review.R            # coordinate decisions, via data/coord_review.xlsx
python3 R/tidy_affiliations.py      # rebuild all outputs
python3 R/verify_affiliations.py    # 41 assertions; exits non-zero on failure
```

`pandas`, `xlrd` and `openpyxl` were installed on this machine on 2026-09-03 and the
Python steps run here. Verified 2026-09-04: a clean rebuild reproduces the reference
output exactly (1273 rows, 1002 lookup pairs, 398 labels, 1174 logged changes,
coord_status 262 ok / 88 missing / 29 conflict / 19 absent) and verify passes.

**The check count changes as work proceeds and that is correct.** With no decisions the
suite runs 36 checks; once `data/affiliation_decisions.csv` holds any decisions it runs
41, the extra five confirming those decisions landed. A rise from 36 to 41 is expected,
not a regression.

`R/coord_review.R` is the spreadsheet loop for coordinates: it builds
`data/coord_review.xlsx` (one row per candidate coordinate, an `accepted` column you fill
with yes/no), converts the answers into the `coordinate` rows of the decisions file, and
rebuilds the sheet preserving what you have already answered. It leaves every other
decision row alone. It refuses to accept two coordinates for one label. The sheet is xlsx
rather than csv precisely because rule 1 makes csv unsafe to open in Excel. Details in
`NEXT_STEPS.md` §1.

**Only six cells of the sheet are read back** (`R/coord_review.R:164`): `accepted` (A),
`affiliation_simple` (C), `latitude` (H), `longitude` (I), `your_note` (M), `decided_on`
(N). Everything else is display-only and regenerated each run. To supply your own
coordinate, type the numbers into H and I and put the link in M — `source_url` (Q) is
not read. A row whose label is not in the candidate list becomes a hand-entered
(`case = manual`) row, which is how you give a coordinate to a label the sheet does not
offer — an `ok`/`absent` label, or one created by a merge.

Three guards were added on 2026-09-04 after each failed in turn. All three exist because
a label can appear under two spellings that `join_key()` resolves to one:

- The "one yes per label" check groups on `join_key`, not label text
  (`R/coord_review.R:240`). `ICAPB UK` and `ICAPB United Kingdom` are one label; they
  cannot carry different coordinates. Same point spelt two ways is deduplicated instead,
  keeping the spelling the deliverables use.
- Candidate rows for labels no longer in the deliverables are dropped and counted
  (`R/coord_review.R:158`). Both source files are snapshots, so a merged-away label goes
  on generating rows forever. **Hand-typed rows are deliberately exempt** — an unknown
  label there is a typo worth surfacing. **This guard does not save a row you have
  already ticked**: once the label leaves the candidate list, `manual <- ans %>%
  filter(!k %in% cand$k, accepted == "yes")` reclassifies the ticked row to
  `case = manual`, which is exempt, so the dead `coordinate` decision is re-written on
  every run. Blanking column A on that row is the only fix — see the `label_rename`
  paragraph below. Cost a `41 checks, 2 failed` on 2026-09-04.
- A `coordinate` decision whose target is not a label at all is dropped and named
  (`R/coord_review.R:364`). It could only ever report `no_match`. Decisions for labels
  that exist but never reach the sheet are still preserved.

**A `label_rename` strands any `coordinate` decision targeting the old name.** The fix
belongs in the sheet — retarget or blank column A on that row — not in the CSV, because
the sheet is rewritten from on every run. Note `label_rename` also renames the label
inside `unique_entries`/`unique_affiliations_Lat_Long`, so merging two labels can pull
their source coordinates together into a new conflict; a `coordinate` decision overrides
it. `affiliation_relabel` does **not** touch those files — use it to split one label into
two (as `IHI Tanzania` was split into `IHI Ifakara` / `IHI Dar es Salaam`).

**Renames must name their final destination, not chain through a label that renames
created.** `A → B` then `B → C` resolves the data correctly, but the `B → C` row reports
`no_match` when no source row ever carried `B`, and verify fails the run.

The Python implementation is the tested reference. `R/tidy_affiliations.R` is a
transcription that has **never been executed** — R was unavailable where it was written.
It self-tests its encoding and regex assumptions before touching data, and checks parity
against `output/shipped/`. The parity check stands down once a decisions file exists,
since the outputs then legitimately differ.

Reading the legacy `.xls` needs `xlrd` in Python (`pip install xlrd`), or the script falls
back to LibreOffice if it is on PATH. `readxl` in R handles it natively.

## Two fixes already applied — do not undo them

**Coordinate decisions match on `join_key` when the exact label is absent.** Thirteen of
the 29 conflict labels carry the coordinate files' spelling (`CDC USA`, `UoE UK`,
`Ualbany U.S`, `Norte Dame US`, `Tulane University USA`, `UC Davis USA`, `UM U.S`,
`UVM USA`, `IC UK`, `ICAPB UK`, `Griffin Laboratory U.S`, `University of Wales UK`,
`Yale USA`) while deliverable 3 uses the version-3 spelling (`CDC United States`). A
`coordinate` decision written against the former is honoured by matching on `join_key`,
provided that resolves to exactly one label; `decisions_report.csv` records it as
"matched via join key to '…'". Without this every such decision reported `no_match`.
`review_coord_conflicts.csv` now also carries a `coord_file_label` column beside the
version-3 `affiliation_simple`.

**Verify tolerates an empty decisions file.** `df.apply(..., axis=1)` on an empty frame
returns a column-less Series which, used as a mask, drops every column — so a header-only
`affiliation_decisions.csv` used to crash verify with
`'DataFrame' object has no attribute 'decision_type'`. The filter is now guarded by
`if len(dec):`. Both fixes are in the Python and mirrored in `R/tidy_affiliations.R`.

## File map

```
data/
  twatasha_final_data/          the two source spreadsheets, authoritative
  affiliation_decisions.csv     judgement calls; edit this, not the outputs
                                (except coordinate rows — those come from the sheet)
  coord_review.xlsx             the coordinate sheet; tick `accepted`, generated+read by R/coord_review.R
  affiliation_decisions_EXAMPLE.csv
  unique_affiliations_Lat_Long.csv   round-1 coordinates, MAC ROMAN on disk
  Affiliation spreadsheet (version 2).csv   round 1, superseded
  unique_entries_tidy_20250203.*     identical to the Sep 2024 file; no edits were made
  vector_extraction_data.csv    223 MB, DO NOT READ. Everything needed from it is
                                already in output/twatasha_todo.csv
  *.geotiff, *.tif, *.zip       large rasters and archives, irrelevant here, do not read
R/
  check_coord_sanity.R          sweeps every coordinate against the country its
                                affiliation names; writes output/review_coord_sanity.csv
  tidy_affiliations.py          tested reference implementation
  verify_affiliations.py        assertions
  tidy_affiliations.R           transcription, unexecuted
  coord_review.R                the coordinate spreadsheet loop; runs, tested
  sources_to_check.R            produced output/twatasha_todo.csv
  unique_affils.R, reseach_locations.R   round-1 scripts, historical
output/
  affiliations_complete_*.csv   deliverable 1
  affiliation_lookup_*.csv      deliverable 2
  affiliation_simple_coords_*.csv  deliverable 3
  decisions_report.csv          did each decision apply?
  diff_report_*.csv             every changed cell; 1174 rows, read only with grep
  review_encoding_repairs.csv   411 rows; read only with grep
  review_simple_lumping.csv     133 rows with long pipe-joined cells; grep, do not cat
  review_coord_sanity.csv       24 coordinates that disagree with their country; nothing
                                in it has been acted on
  review_*.csv                  what still needs a human
  shipped/                      reference copies for the R parity check
AFFILIATION_CLEANING_README.md  what the pipeline did
aff_audit_plan.md               file lineage and full damage inventory
NEXT_STEPS.md                   current state and work queue
```

## Style

The project owner is an advanced R user and wants direct, unpadded communication. State
plainly when something is not known or not possible rather than producing an answer that
will not work. Give references. Australian English, `-ise` not `-ize`.
