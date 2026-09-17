# Merge Gia's lake-region data into output/final, and drop the `_20260817` stamp

**Status, 2026-09-17 (eighth session): approved and built. Open only for the owner's
answers in the two sheets.** `NEXT_STEPS.md` step 8 is the record of what was built, the
numbers and the loop; read that, not this. This file is kept as the plan as approved.
Where the build departs from the text below:
- **B0 was dropped. `vector_extraction_data.csv` is never read**, no exception, and
  `output/lake_todo.csv` does not exist. Gia's file carries citation and n itself:
  `R/sources_to_check.R:35` is a `left_join` on (source_citation, n), so a paper of hers not
  on `twatasha_todo.csv` had already matched the extraction data on both. The guard "one
  lake citation altered by a byte" therefore cannot exist: nothing independent holds those
  bytes. Verify instead fails when the pipeline alters, loses or duplicates her rows.
- **B5 also offers every one of her `ok` points** as a `case = lake` row to check (yes =
  checked, the label becomes `decided`), at the owner's request, because nothing else would
  put her points in front of him.
- **`affiliation_relabel` does not move her rows.** One of her rows carries a string a
  2026-09-04 relabel sends to `IHI Ifakara`; it stays under `IHI Ifakara Tanzania` until
  merged, and every rebuild names it.
- **`coord_review.R` keeps a decision's recorded note** when its ticked row turns `manual`,
  or a checked point of hers loses `source: lake_region_source_counts.csv`.
- **Verify runs 49 checks, not 48**: a 43rd check was added on the way, for a bug in
  `absent_review.R` that had put 66 duplicate rows into deliverable 1 (1374 instead of
  1308). With that fixed, every expected figure below held.

## Context

`data/gia_final_data/` holds Gia's lake-region affiliations (the same shape as deliverable 1)
and their coordinates (the same shape as deliverable 3). They are to be merged into the
three deliverables. Some of Gia's papers, affiliations and institutions are already in the
existing set, so a merge is only applied once the owner approves it in a sheet, as with
every other judgement call. Separately, the three files in `output/final/` lose the
`_20260817` stamp.

**Decisions already taken (2026-09-17):**
- Matches are answered in **`label_review.xlsx`**.
- Gia's rows reach `output/final` on the **next rebuild**, each under its own label, and
  merge as they are approved.
- On papers already present, **only affiliations the paper does not already carry are
  added**.
- **`vector_extraction_data.csv` is read once** to write `output/lake_todo.csv`.

### What the new data holds (drives the design)

**The affiliations file**
- 338 rows, 211 papers, 274 distinct affiliation strings, 40 labels.
- It has a byte-order mark, Windows line endings, and 22 affiliations with line breaks
  inside them.
- `R/sources_to_check.R` built `twatasha_todo.csv` as the Africa sources that do **not**
  join this file on citation *and* n. So:
  - **204 papers are new.**
  - **7 are already in deliverable 1.** For 4 of them Gia's citation carries mojibake
    (`B√∏gh`, `Geissb√ºhler` ×2, `M√ºller`). For the other 3 the citation matches exactly,
    but Gia's n is lower than the Africa count (34 vs 57, 28 vs 64, 4 vs 8).
- Gia recorded **only the African affiliations** of each paper: all 40 of her labels are
  East African institutions. Of her 12 rows on those 7 papers, 6 repeat an affiliation
  already on that paper and 6 are new, e.g. MoH Nairobi for Bøgh 1998.
- **A partial find-and-replace of `Centre` → `IHI Ifakara Tanzania`** damaged 148
  affiliation cells ("International IHI Ifakara Tanzania of Insect Physiology…") and 22
  label cells (`Ifakara IHI Ifakara Tanzania Ifakara Tanzania`). `Centre` survives
  unreplaced in 17 rows and `Center` in 13. The label `IHI Ifakara Tanzania`, when it is
  the whole cell (2 rows), is genuine.
- One `30197Ð00100`: a Mac Roman en dash read as Latin-1.

**The counts file**
- 39 labels, with columns in the order `longitude, latitude`. Its `n` is rows per label and
  is not needed.
- It disagrees with the affiliations file in two places:
  - it has `ILRI Nairobi Kenya` where the rows say `ILRAD Nairobi Kenya`;
  - its `IHI Ifakara Tanzania` n = 24 is the 2 rows under that label plus the 22 under
    the damaged one.

**Overlap with existing labels**
- No lake label collides with an existing one on `label_key` or `join_key`, so nothing
  collapses silently.
- 13 lake affiliation strings already exist in deliverable 2 under an existing label: hard
  match evidence.
- **Coordinates alone:** 3 lake×existing pairs sit within 0.25 km and 18 within 2 km.
- A few lake points are nowhere near the town their label names:
  - `MasenoU Maseno Kenya` is 282 km from Maseno, in Nairobi;
  - `MTTI Kendu Bay Kenya` is in Mombasa;
  - `ICIPE Nairobi Kenya` is near Homa Bay, 274 km from Nairobi;
  - `NLRRI Tororo Uganda` is 173 km from Tororo.

  The sanity sweep only tests the country, so it will pass all four. Coordinate evidence
  for these labels has to be read against the text.

---

## Part A — remove `_20260817` from `output/final` (first, on its own)

**Writers and readers become fixed names:** `affiliations_complete.csv`,
`affiliation_lookup.csv`, `affiliation_simple_coords.csv`.
- `R/tidy_affiliations.py:472,481,588`. `diff_report_20260817.csv` is in `output/`, not
  `final/`, and stays as it is.
- `R/verify_affiliations.py:9-11`. `random.seed(20260817)` stays.
- `R/coord_review.R:50-51`, `R/absent_review.R:55`.
- `R/label_review.R:97-128`, `R/check_label_candidates.R:89-96`,
  `R/check_coord_sanity.R:42-49`: `newest()` and its `\d{8}` glob are replaced by the
  fixed path. The glob would otherwise find nothing.
- `R/tidy_affiliations.R` (never run): the writes lose the stamp. `STAMP` becomes the
  baseline stamp used only by `parity()`, because `output/parity_baseline/` is a frozen
  fixture and keeps its dated names.

**Test:** in a sandbox, the rebuild must reproduce the three dated files byte-for-byte
under the new names, and verify must end 42/0. Then the same on the real project: `cmp`
the new files against the old, then delete the three dated files. `output/` is gitignored,
so git is not involved.

**Docs:** filenames in `output/final/README.txt`, `CLAUDE.md` (the "stamp kept on purpose"
paragraph and the file map), `NEXT_STEPS.md` and `HANDOFF_PROMPT.txt`.

---

## Part B — the lake integration

### B0. `R/lake_sources.R` (new) → `output/lake_todo.csv`

- Mirrors `R/sources_to_check.R`: reads `vector_extraction_data.csv` with only
  `source_citation` and `anopheline_region_id`, filters to Africa, and counts n per
  citation.
- Writes `source_citation, n` for every Africa citation that is verbatim in Gia's file and
  not in `twatasha_todo.csv`. Expected: 204.
- Names every Gia citation it cannot place. Expected: the 4 mojibake citations, which
  resolve through `twatasha_todo.csv` instead.
- Names any n that differs from Gia's. Expected: none.
- Run once. **This is the one sanctioned read of the 223 MB file.** CLAUDE.md rule 6
  records the exception.

### B1. `R/tidy_affiliations.py` — rows

- **Load.** After `added_affiliations.csv`, append Gia's rows (`encoding='utf-8-sig'`) with
  `row_xlsx` 50001+ and no `affiliation_original`. They then go through the same repair,
  whitespace, collapse and decision steps as every other row.
- **Step 2b, lake rows only:**
  - replace `IHI Ifakara Tanzania` with `Centre` in `affiliation` and
    `affiliation_simple`, except where it is the whole cell;
  - replace `Ð` with `–`.
  - Each change goes to the diff log.
  - `output/review_lake_repairs.csv` shows each distinct reading in context (e.g.
    "International Centre of Insect", ×48) so the reversal can be skimmed. Which of
    Centre or Center a given paper printed cannot be recovered, as with the us/uk case.
- **Citations and n.**
  - A lake citation that is verbatim in `lake_todo.csv` is kept byte-identical (rule 3),
    judged on the **pre-repair** text.
  - Anything else resolves against `twatasha_todo.csv` with the existing
    `resolve()`: exact, then key, then digit-stripped key.
  - n always comes from the todo file the citation resolved to, never from Gia's file. So
    Besansky keeps 57, not 34.
  - Unresolved rows go to `review_unmatched_sources.csv` as a new issue type, and verify
    fails on them.
- **Step 3b bound.** The placeholder drop's `row_xlsx < 90001` becomes `< 50001`, so lake
  rows are never treated as spreadsheet placeholders. Behaviour on version 3 is unchanged.
- **Step 3c, new.**
  - A lake row is dropped when its paper already carries the same affiliation (the
    `key()`-normalised text) from the spreadsheet or the additions.
  - All 12 lake rows on the 7 shared papers go to `output/review_lake_overlap.csv`, showing
    whether each was dropped or added, and which existing label carries the same text.
    Labels are written as they stand after collapse and renames.
  - `MAFS Dar es Salaam Tanzania` loses its only row this way.
- **`output/label_sources.csv`** (working file): `affiliation_simple, n_rows, n_rows_lake`,
  for the sweep and the sheet.

### B2. `R/tidy_affiliations.py` — coordinates

- **Loading.** The counts file becomes a third coordinate source,
  `lake_region_source_counts.csv`, read as `latitude`/`longitude` by name. It gets the same
  repair, squash, collapse and rename steps as `ue`/`ull`.
- **`absorb_lake()` runs after `ue` and `ull`:**
  - a key they left unresolved, absent or missing takes the lake point;
  - a key they resolved `ok` or `conflict` that also has a *different* lake point becomes a
    **conflict** listing both.
- **Why a conflict rather than a silent winner.** Whichever way a merge goes (keep the old
  label or keep Gia's), both points reach `coord_review.xlsx` and the owner picks one, as
  for two `ok` labels today. A `coordinate` decision still overrides.
- **Nothing existing moves.** No join-key collisions means all 308 current labels resolve
  exactly as now until something is merged.
- **`output/review_lake_counts.csv`** covers three cases: counts labels no row carries
  (`ILRI…`, `MAFS…`), lake labels with rows but no coordinate (`ILRAD…`,
  `Ifakara Centre Ifakara Tanzania`), and Gia's n versus her rows.

### B3. `R/check_label_candidates.R` — matches that cross the two datasets

- **Scope.** It reads `output/label_sources.csv`; without that file it behaves exactly as
  now. The new evidence applies only to pairs where one label carries lake rows and the
  other carries non-lake rows. Gia's own deliberate city splits (`NIMR Tanga` /
  `NIMR Amani`) are not raised on this new evidence alone.
- **`same_acronym`:** the same leading institution token, in the same country. E.g.
  `KEMRI Nairobi Kenya`–`KEMRI Kenya`/`KEMRI-Kilifi`, `UoN Nairobi Kenya`–`UoN Kenya`,
  `IHI Ifakara Tanzania`–`IHI Ifakara`. `MoH Nairobi Kenya`–`MoH Burundi` is dropped by the
  existing country rule.
- **`near_point` (≤ 2 km) is kept on its own** for these pairs; the "potential coordinates
  suggest a match" case.
- **`shared_affiliation`** also comes from the dropped rows in
  `review_lake_overlap.csv`, so a match like `MAFS`/`MAFC` is not lost with its row.
- **Standard evidence** covers lake labels like any other: `same_point` for
  `KCMC`/`JMP Moshi`, `acronym` for `MU Kenya`/`MasenoU`.
- **Old↔old pairs cannot gain evidence**, only lose `shared_phrase` where a phrase becomes
  common. Answers are keyed by pair and `label_review.R` keeps answered rows, so nothing
  already answered is lost.

### B4. `R/label_review.R`

- **A new last column, `lake`**, shows which side carries Gia's rows (`a`, `b`, `both`).
  Columns A–X keep their letters, so the read-back cells A, C, R and S are unchanged.
- **A misleading warning is corrected.** When the label being merged away is `decided` and
  the survivor is not, the patch retargets the owner's coordinate onto the survivor. The
  warning therefore says that coordinate follows the merge and the survivor's own point is
  discarded. It currently says "discards a coordinate you chose", which is wrong in that
  case. This is the common case here: Gia's labels are `ok`, and many of their old
  counterparts are `decided`.

### B5. `R/coord_review.R` — Gia's coordinates for labels her rows don't use

A counts coordinate that no row's label uses is offered as a candidate row. It goes to
every coordinate-less label ending in the same two place words (`… Nairobi Kenya`), with a
note saying where it came from. So `ILRI Nairobi Kenya`'s point is offered to
`ILRAD Nairobi Kenya`. A coordinate offered to no label is named in the run output
(expected: `MAFS…`).

### B6. `R/verify_affiliations.py` — teach, don't loosen (42 → 48 checks)

**Expectations derived independently of tidy:** verify's own `_paper()`, its own `canon()`
with its own Centre reversal, and `lake_todo.csv` rather than Gia's file.

**Changed checks**
- Row count becomes `1273 + added − replaced + lake − lake duplicates`.
- Citations must be verbatim in `twatasha_todo.csv` **or** `lake_todo.csv`.
- n must agree with whichever of the two holds the citation.
- The non-null counts include the lake rows that were kept.

**New checks (only when the lake file exists)**
1. Every `lake_todo.csv` source is represented.
2. No (paper, affiliation) appears in deliverable 1 more often than in the spreadsheet and
   additions, plus once for a lake row no other source has.
3. No `IHI Ifakara Tanzania` is left embedded in `affiliation` or `affiliation_simple`.
4. No `Ð` is left.
5. Every lake coordinate whose label is live, not renamed, not decided and not in conflict
   landed verbatim.
6. 20 random kept lake rows are unchanged apart from the known repairs.

### B7. Docs

- **`NEXT_STEPS.md`:** a new step 8 with the loop and the numbers.
- **`CLAUDE.md`:**
  - current state and the file map;
  - the rule 6 exception;
  - check count 48;
  - `warning` is column Q, not O;
  - the R transcription does not mirror the lake step (nor did it the placeholder drop).
- **`output/final/README.txt`:** row, pair and label counts; Gia's provenance; two known
  limits: Gia's papers carry only their African affiliations, and her coordinates are
  checked for country only.

---

## Order of work, and verification

1. **Sandbox** (the 3.8 MB recipe in memory, plus `data/gia_final_data` and a **symlink**
   to `vector_extraction_data.csv`, so nothing big is copied). For every step, report what
   it showed.
   - **Part A:** byte-identical outputs under the new names; 42/0; each R script runs on
     the new paths, and its decisions file and review CSVs are unchanged.
   - **`lake_sources.R`:** 204 papers, 4 names resolving through `twatasha_todo.csv`, n
     mismatches 0.
   - **Rebuild with no new decisions:**
     - the first 1308 rows of deliverable 1 are identical and in order;
     - all 308 existing deliverable 3 rows are byte-identical;
     - 1640 rows (1308 + 338 − 6), 746 papers, 347 labels (205 `ok`, 137 `decided`, 3
       `absent`, 2 `missing`);
     - 170 Centre reversals and 1 `Ð`;
     - 6 rows dropped, 6 added;
     - verify 48/0.
   - **Guards bite:**
     - one lake citation altered by a byte: verify fails and the row is listed as
       unmatched;
     - the lake file removed: the Part A outputs return byte-for-byte.
   - **Sweep:** list the new pairs by evidence type, and every old↔old pair whose evidence
     changed.
   - **Answers simulated with openpyxl** in the sandbox sheets:
     - a lake label merged into a `decided` old label;
     - an `ok` old label merged into a lake label with a different point, which must
       become a conflict with two open rows in `coord_review.xlsx`, one ticked;
     - `keep` a lake label over a `decided` old one, with the corrected warning;
     - tick the `ILRI` candidate for `ILRAD`.

     After each: `label_review.R` → `coord_review.R` → rebuild → verify 48/0.
2. **Real project**, each `*_review.R` gated on `data/~$<sheet>.xlsx` (stop if present):
   1. Part A;
   2. `lake_sources.R`;
   3. `tidy` + `verify`;
   4. `check_label_candidates.R`, then `check_coord_sanity.R`;
   5. `label_review.R`, then `coord_review.R`.
3. **Report:** the counts, how many open rows each sheet gained, and the largest new
   clusters. Then the owner answers in the sheets: type, save, close, run.

**Not done:** no merge, coordinate or label is decided on the owner's behalf. The existing
lumping question stays unpursued. The R transcription is not extended.
