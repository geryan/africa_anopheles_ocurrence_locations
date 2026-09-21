# CLAUDE.md — africa_anopheles_ocurrence_locations_cc

Context for Claude Code working in this repository. **`NEXT_STEPS.md` is the record of the
work**: it runs top to bottom, **steps 1 to 9 are all done**, and everything after its
Reference heading is background. There is no open work — see below.

## Where this is up to — 2026-09-21: everything is answered; the deliverables are final

**There is no open work.** Every sheet is fully answered, both coordinate sweeps flag
nothing, the label sweep has no open pair, and `python3 R/verify_affiliations.py` ends
**50 checks, 0 failed**. `NEXT_STEPS.md` steps 1 to 9 are all done and are kept as the
record of how each was done.

| | |
|---|---|
| `output/final/affiliations_complete.csv` | 1640 rows, 746 papers |
| `output/final/affiliation_lookup.csv` | 1289 pairs |
| `output/final/affiliation_simple_coords.csv` | 327 labels — **183 `decided`, 141 `ok`, 3 `absent`, 0 `missing`, 0 `conflict`** |
| `data/affiliation_decisions.csv` | **345 decisions, all `applied`**: 183 `coordinate`, 133 `label_rename`, 16 `accept_as_is`, 10 `affiliation_relabel`, 3 `lake_relabel` |
| `data/label_review.xlsx` | 265 pairs: 150 applied, 115 rejected, none open |
| `data/coord_review.xlsx` | 256 rows over 183 labels, every one settled |
| `R/check_coord_sanity.R` | 324 checked, **0 flagged**, 5 signed off |
| `R/check_coord_place.R` | 324 checked, **0 flagged**, 9 signed off, 74 untestable |
| `R/check_label_candidates.R` | 77 pairs, every one answered |

**No `ok` coordinate comes from Gia's counts file.** Each of her points was either
confirmed by hand, which made it `decided`, or replaced when her label was merged.

### What was built in the last three days, and why

- **`R/check_coord_place.R` and `R/place_lookup.R`** (2026-09-18) — the town check, the
  half `check_coord_sanity.R` never had. It exists because `MTTI Kendu Bay Kenya` was
  ticked at a point in Mombasa, 693 km from Kendu Bay, and nothing showed it: the country
  sweep passed it, and the fact was written in `NEXT_STEPS.md` rather than in the sheet the
  answer was typed into. Step 9 of `NEXT_STEPS.md` has the detail.
- **`place_check`, column S of `coord_review.xlsx`** — every row that carries a coordinate
  now says, in words, what town the point is in and how far that is from the town its text
  names. This is the part that matters: a flag nobody sees while ticking is not a flag.
- **`checked` in column A**, and the status `FLAGGED - not in the town the text names`,
  which sorts those rows to the top. A flagged row usually arrives carrying the `yes` it was
  given before the sweep existed, so a bare `yes` cannot mean "checked against the town";
  `checked` keeps the coordinate and appends the `accept_as_is` that silences the sweep.
- **`lake_relabel`** (2026-09-18) — a decision type that moves an affiliation string onto
  another label for **every** row carrying it, Gia's included. `affiliation_relabel` leaves
  hers alone by design, and that guard stays.

### The last few judgement calls, for the record

- **`KU Kenya` and `KenyattaU Nairobi Kenya` were wrongly merged into `JKUAT Kenya`** on
  2026-09-17 and the merge was undone on 2026-09-18. Kenyatta University (Kahawa) and JKUAT
  (Juja) are separate universities 13 km apart. Undoing it left seven rows of JKUAT text
  under the Kenyatta label, all of them Gia's, which nothing could move — that is why
  `lake_relabel` exists. `JKUAT Kenya` is now 10 rows at Juja, `KenyattaU Nairobi Kenya`
  12 rows at Kahawa on the owner's own point.
- **`MoH Nigeria` was split** into `FMoH Abuja Nigeria` (1 row) and `FMoH Lagos Nigeria`
  (2 rows), 529 km apart under one label. `MOH Abuja, Nigeria` is the *State* ministry and a
  different body; `MoH Abuja Nigeria` was refused as a name because `join_key()` collapses it
  onto that label.
- **`ORSTOM France` was merged into `MIVEGEC / CIRAD / LIN Montpellier`**, not into
  `IRD France`: its one string is the Laboratoire de Lutte contre les Insectes Nuisibles, and
  21 of the Montpellier label's rows are that laboratory. Two LIN strings were moved off
  `IRD France` at the same time, which is why deliverable 2 went from 1290 pairs to 1289 —
  one string had been under two labels.
- **`Campus international de Baillarguet France` was merged into `CIRAD-EMVT France`.** The
  pair was only raised once `CIRAD-EMVT France`'s coordinate was corrected on 2026-09-21;
  it had been 397 km away near Poitiers, and the earlier decision to keep the two apart was
  made while it was.
- **Two affiliation strings deliberately sit under two labels each** and are left that way:
  the KEMRI / USAMRD-A Nairobi string (7 rows) and the IRD / OCEAC Yaoundé string (2 rows).
  Each names two institutions, so no single label is right. They are the two rows of
  `output/review_simple_conflicts.csv`.

Counts further down this file are from before 2026-09-21 unless dated otherwise.
### Earlier on 2026-09-17 — step 8 built, before the answers

**Step 8 was then open.** Gia's lake-region data (`data/gia_final_data/`) is in all three
deliverables, each of her 332 rows under her own label, and **nothing of hers is matched or
checked yet**. The owner answers in the two sheets: **51 pairs in `label_review.xlsx`** (37
of her labels against existing ones, 14 of hers against each other; column Y `lake` says
which side is hers) and **39 labels in `coord_review.xlsx`** (37 of her points as
`case = lake` rows, where yes means checked and the label becomes `decided`;
`ILRAD Nairobi Kenya` offered the point her counts file gives `ILRI Nairobi Kenya`;
`Ifakara Centre Ifakara Tanzania` with no candidate). **Merges first**: a merge decides which
coordinate survives. The loop, the numbers, how her rows are handled and the facts to put in
front of the owner are step 8 of `NEXT_STEPS.md`.

**The build is clean.** `data/affiliation_decisions.csv` holds **261 decisions, all
applying**, and verify ends `49 checks, 0 failed`. Deliverable 1 is **1640 rows** (1273
spreadsheet rows + 94 from `data/added_affiliations.csv` − 59 `ABSENT` placeholders + 332 of
Gia's 338, the other 6 already on their paper), 746 papers; deliverable 2 is 1298 pairs;
deliverable 3 is **347 labels: 205 ok (37 of them Gia's, unchecked), 137 decided, 3 absent,
2 missing (both Gia's), 0 conflict**. The sanity sweep checks **342 and flags 0**, and tests
only the country, so it says nothing about whether her points are in the right town:
`MasenoU Maseno Kenya` sits in Nairobi and passes. The label sweep raises 109 pairs; the 58
from before step 8 are all answered. All 542 `twatasha_todo.csv` sources and all 211 of
Gia's papers are represented.

**Three other changes on 2026-09-17:**
- **The deliverables have fixed names**: `output/final/affiliations_complete.csv`,
  `affiliation_lookup.csv`, `affiliation_simple_coords.csv`. The `_20260817` stamp is gone
  and every script reads the fixed name. `output/diff_report_20260817.csv` and
  `output/parity_baseline/` keep their dates.
- **`R/absent_review.R` no longer duplicates rows.** It judged which rows of the additions
  file were its own from the papers deliverable 1 still showed as `ABSENT`, so after a
  rebuild dropped a supplied paper's placeholders it kept that paper's rows as someone
  else's and wrote them again: 66 duplicates per run. Deliverable 1 held 1374 rows, not
  1308, and the extra row flipped the formatting-only collapse to `MOH Nigeria`. Verify
  passed it because its count came from the same file. The script now owns every paper in
  its sheet; verify's 43rd check compares the additions file with the sheet itself.
- **`data/vector_extraction_data.csv` is still never read.** The lake plan proposed one read
  to get citation and n for Gia's new papers; the owner vetoed it. Her file already carries
  both, and `R/sources_to_check.R:35` built the todo list with a `left_join` on
  (source_citation, n), so a paper of hers not on that list had matched on both.

### Before step 8 — steps 6 and 7, answered 2026-09-16

**Step 6.** The 12 labels whose coordinate the round-1 source recorded as `ABSENT` were
invisible to every sheet and sweep until the loop was built on 2026-09-15; the owner answered
all 12 on 2026-09-16 — **10 given a coordinate, 2 left `absent`** with an `accept_as_is`
sign-off each (`LRP Cameroon`, "can't be found; country level too coarse to usefully
assign", 20 records; `Mission for the Prevention and Fight against Vector Endemics, Réunion,
France`, "Reunion too coarse to assign locale", 68 records). See **The absent coordinates**
below and step 6 of `NEXT_STEPS.md`.

**Step 7.** The new coordinates made `R/check_label_candidates.R` raise two pairs, both
answered in `label_review.xlsx` on 2026-09-16: `Centro Hispano-Guineano de Enfermedades
Tropicales, Malabo, Equatorial Guinea` / `CREC Equatorial Guinea` (0.14 km apart)
**rejected**, and `DRASS France` / `Vector Control Service, Regional Directorate of Health
and Social Affairs, Saint-Denis de La Réunion, France` **merged into the new label
`DRASS Reunion`** (2 rows, 80 records, -20.9006092, 55.4874248 — DRASS's own point, which the
merge kept). `National Center for the Fight against Malaria, Ouagadougou, Burkina Faso`
(12.3642904, -1.5050645) and `CNRFP Burkina Faso` (12.349733, -1.4903285) are 2.3 km apart,
the sweep does not raise them, and they are deliberately left as two labels.

### The absent coordinates — step 6, loop built 2026-09-15, answered 2026-09-16

Deliverable 3 had **13 labels with `coord_status = absent`**. One is the label `ABSENT`
itself — 23 papers whose affiliation could not be found in step 5 — and it stays as it is:
no affiliation, so no coordinate. **The other 12 were real institutions, each naming a
place, each carrying one row of deliverable 1 and between 4 and 68 occurrence records — 337
altogether.** `absent` meant only that the round-1 coordinate file said `ABSENT`; it did not
mean no coordinate exists, and 10 of the 12 now have one. Several are city centroids, said
so in the note.

Why nothing showed them before 2026-09-15:

- `coord_review.xlsx` never offered them. Its catch-all `needs a coordinate` rows were built
  from `coord_status == "missing"` only, and these are `absent`. Fixed — see below.
- `R/check_coord_sanity.R` sweeps coordinate-bearing labels, so a label with no coordinate
  is invisible to it. **The sweep reading `0 flagged` says nothing about these 12** until
  each has a coordinate.
- `review_missing_coords.csv` and the 88 researched proposals predate them: none of the 12
  is in `output/proposed_coords_missing88_20260818.csv`, so every one needs looking up.

**The loop is built** (2026-09-15, tested end to end on a sandbox copy first). The orphan
filter, `R/coord_review.R:241`, takes `absent` as well as `missing`. It leaves out the label
`ABSENT`, and any label signed off with `accept_as_is` or `note_only`, which is how a label
is left without a coordinate on purpose; the script names each one it leaves out. All 12 are
in deliverable 2, so the merged-away guard (`:277`) keeps them. A `coordinate` decision
settles one as it does any other label: `tidy_affiliations.py` gives these 12 `absent` at
line 519, from the ABSENT cells of their source rows (line 557 does it only for the label
`ABSENT`), and applies decisions after both, at line 580, so the status becomes `decided`.
No pipeline change was needed.

**A label that is staying without a coordinate is signed off in the sheet** (2026-09-16):
`absent` in column A of its row, with the reason in `your_note` (M), appends an
`accept_as_is` decision for it (`R/coord_review.R:386` reads the answer, `:601` writes the
row). From the next run on the label is no longer offered, and every run names it. The
sign-off rows are **appended and never rewritten** — a sign-off already in the file, like
the five hand-written ones, passes through untouched — so blanking column A does not undo
one; that means taking the line out of the file deliberately. `no` in column A does not
sign a label off: there is no coordinate on the row to reject, and the run names it under
`!!`. The 12 labels, what each was answered, and the pairs they raised are under **steps 6
and 7 of `NEXT_STEPS.md`**.

**Step 5 was done on 2026-09-11.** It was added after steps 1 to 4 were finished, to go back
over every affiliation the source recorded as `ABSENT`. All 58 papers are answered in
`data/absent_review.xlsx` (89 rows): 35 now have real affiliations, and 23 were confirmed
`ABSENT` — so deliverable 1 still has 23 `ABSENT` rows, each one typed deliberately. It
created 11 new labels, every one given a coordinate in `coord_review.xlsx`. One label typed
in the sheet, `MOH Nigeria`, was folded into the existing `MoH Nigeria` by the
formatting-only collapse; it is the ninth row of `review_labels_collapsed.csv`.

**A pipeline bug was found and fixed the same day.** `tidy_affiliations.py` dropped the
replaced placeholders by matching the spreadsheet's raw citation text at load, before the
re-key, so every placeholder whose citation the spreadsheet had damaged survived beside its
replacement — 23 rows over 22 papers. Verify computed its expectation the same way and
agreed. The drop now runs after the re-key (step 3b), verify derives the match
independently, and a 42nd check asserts the invariant directly. See **Replacing an
affiliation the source recorded as ABSENT** below.

Before step 8 all three sheets were fully answered: `absent_review.xlsx` 89 rows,
`coord_review.xlsx` 137 labels settled and 2 signed off as staying without a coordinate,
`label_review.xlsx` 125 merges applied and 76 pairs rejected with none open
— the five pairs step-5 labels raised were all rejected on 2026-09-11. Step 8 opened 51
pairs and 39 coordinate labels. **The coordinate sanity sweep checks 342 and flags 0.** Five coordinate-bearing labels are signed off by
`accept_as_is` (two more labels carry one for staying without a coordinate at all, from
step 6):
`SIPPE CAS United States`, whose Shanghai coordinate is right and whose label is the
problem, and four whose affiliations name no country for the sweep to test —
`One World Development Group, Florida`, and from step 5 `Illinois NHS` (Champaign), `UQ`
(St Lucia, Brisbane) and `University of Copenhagen`.

**`label_review.R` no longer re-dates renames** (fixed 2026-09-11). It stamped the run date
on every rename whose sheet `decided_on` cell is blank — 73 applied rows — so on each run
those renames took that run's date, and the date recorded for them was only ever the last
run's. Unlike `coord_review.R` and `absent_review.R`, it never wrote the stamped date back
to its sheet. It now keeps the date already recorded for the same rename; tested on a
sandbox copy, a run with nothing changed reproduces its input exactly. The 67 renames the
2026-09-11 run re-dated had read 2026-09-10 before it, which was itself a re-stamp; their
true dates, between 2026-09-07 and 2026-09-10, are not recoverable from the project files.
**They are left as they are, on the owner's instruction: the dates are immaterial as long as
the decisions themselves are recorded correctly.** Do not raise them again.

Outside step 8, what is left is not work (counts at 2026-09-17, which include Gia's labels):
`review_simple_lumping.csv` (157) and `review_label_lumping.csv` (101) are the
how-coarse-should-a-label-be question, deliberately not pursued; `review_simple_conflicts.csv`
(10) is two pairs rejected in `label_review.xlsx` plus 8 strings Gia's rows share with an
existing label, all open pairs of step 8; `review_us_uk_tokens.csv` (21) and the first eight
rows of `review_labels_collapsed.csv` were reviewed on 2026-09-10 and left as they are.
`review_label_duplicates.csv` (109) holds the 58 pairs answered before step 8 and 51 open
ones from it; the 58 include the five step-5 pairs, all
rejected: `MOH Abuja, Nigeria` / `MOH Lafia, Nigeria` (a shared phrase, 128 km apart) and
four acronym collisions — `University of Copenhagen` against `UC United States`,
`UC Davis United States` and `UoC Greece`, and `University of Liverpool` against
`UoL United Kingdom`.

**The deliverables live in `output/final/`** (2026-09-10), with a README that says what
each file and column is, what was done, and what the known limits are. Everything else in
`output/` is working files. `output/shipped/` was renamed **`output/parity_baseline/`** and
carries its own README saying it is a pre-decisions test fixture, not a product — the old
name had already caused one near-miss. The three files carried a `_20260817` stamp, kept so
anything downstream would still resolve, until 2026-09-17, when the owner had it dropped:
they are `affiliations_complete.csv`, `affiliation_lookup.csv` and
`affiliation_simple_coords.csv`, and the dated copies were deleted after a byte-for-byte `cmp`.

### The label sweep — new 2026-09-07, done

`R/check_label_candidates.R` sweeps the whole label list for the two faults the sheet
cannot show, and writes `output/review_label_duplicates.csv` (two labels that may be one
place, strongest first — 153 pairs on 2026-09-07, 58 before step 8 and every one answered in
`label_review.xlsx`, 109 at 2026-09-17) and `output/review_label_lumping.csv` (one label that
may be several places — 86 then, 101 at 2026-09-17, the granularity question, deliberately
not pursued). Since step 8 it also reads `output/label_sources.csv`, and fires three extra
kinds of evidence — `same_acronym`, `shared_affiliation` from Gia's dropped rows, and
`near_point` on its own — only for a pair with Gia's rows on one side and other rows on the
other; step 8 of `NEXT_STEPS.md` has the detail.
Read-only, idempotent, ~7 s; re-run after any batch of merges. Written up under step 1 of
`NEXT_STEPS.md`, which lists the evidence types and the known false positives.

`R/label_review.R` is the spreadsheet loop that acts on it: `data/label_review.xlsx`,
254 rows at 2026-09-17, column A `accepted` and column C `keep` (which may name any label,
not just one of the two on the row); `warning` is column Q, the two maps links W and X, and
`lake` (which side carries Gia's rows) Y. **`keep` can also create a label that does not exist yet, written
`new: DRASS Reunion`** (added 2026-09-16, `R/label_review.R:248`): both of the row's labels
then merge into a new label of that name. The marker is required, because an unmarked
unknown name is far more often a typo — that is refused, naming it — and a `new:` name that
`join_key()` resolves to an existing label is refused too, since two labels sharing a key
make every `coordinate` decision for either of them ambiguous. It resolves merge groups before writing, so every `label_rename`
it emits names the final survivor directly, and it patches `data/coord_review.xlsx` so no
coordinate decision is stranded. Its first run on 2026-09-07 was lossless — the same 139
decisions, with four chained renames normalised to their final destination.

The sweep is deliberately wider than `review_simple_conflicts.csv`, which only sees labels
sharing an affiliation string: it also matches on institution phrases, acronym
expansions in three forms (so `UoN` finds "University of Nairobi"), domain-style
contractions (`uonbi`), spelling distance and coordinate proximity. A pair resting only on soft
evidence is dropped unless both labels name the same country; hard evidence — a shared
string or one coordinate — is kept regardless.

The coordinate loop, should a label need one again, is `Rscript R/coord_review.R` → owner ticks column A in Excel → same command again →
`python3 R/tidy_affiliations.py && python3 R/verify_affiliations.py`.

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
polygon with a **10 km** coastal tolerance. **17 of 289 flagged** on its first run into
`output/review_coord_sanity.csv`, worst-first, one Google Maps link per row. Idempotent;
reads `output/final/affiliation_simple_coords.csv`, so re-run it after any batch of merges. On 2026-09-10
it flagged 15 of 284, all `coord_status = ok` rows, none of the owner's `decided` ones, and
all 15 were settled that day — 13 given a corrected coordinate, 2 signed off with
`accept_as_is`. After step 5 on 2026-09-11 it flagged 3 of 296, all `no_expected_country` —
new labels it cannot test, not wrong coordinates — and with those signed off too it flags
0 of 296. After step 8 it checks 342 and flags 0, 37 of them Gia's points, which is why
`coord_review.R` offers every one of hers as a row to check. It is written up as **step 2 of
`NEXT_STEPS.md`**.

**Its suspects reach the owner through `coord_review.xlsx`, not the CSV** (2026-09-10).
`coord_review.R` reads `review_coord_sanity.csv` as a third candidate source and emits, per
suspect, a `case = sanity` row carrying the coordinate as it stands — ticking that means
"checked, this is right" — plus a second row carrying an arithmetic repair whenever the
sweep finds one that lands inside the expected country. Four of the 15 have one. Without
this an `ok` label could never be re-opened, because only `missing` and `conflict` labels
ever reach the sheet.

**The sweep honours `accept_as_is` and `note_only`**: a label carrying either is not
flagged, and the count is reported. That is how a coordinate that is genuinely right but
disagrees with its label's country — `SIPPE CAS United States` is Shanghai, `One World
Development Group, Florida` names no country — is silenced for good.

**Overseas territories are checked against the territory, not the sovereign**, whenever the
text names one (added 2026-09-08). Folding `GUF` into `FRA` had hidden `IPG France` —
"Pasteur Institute of Guyana, Cayenne, France" with a coordinate in Paris, 7068 km out. The
fold still applies in the other direction, so an affiliation saying "France" whose point is
in Réunion is not reported as wrong.

Error classes it found: latitude sign flipped for southern-hemisphere cities (Wits,
Antananarivo), a leading digit lost from latitude (`RIHS Burkina Faso`, Dakar, `SU
Yemen`), longitude sign flipped (`INSERM France`), and a coordinate copied verbatim from
an adjacent unrelated label (`UNHCR Sudan` = Umeå; Rothamsted = Bamako). None of the
owner's `decided` rows was flagged in either sweep. Every one has since been settled.

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

1. every (paper, affiliation, affiliation_simple) row — `output/final/affiliations_complete.csv`
2. affiliation → affiliation_simple lookup — `output/final/affiliation_lookup.csv`
3. affiliation_simple → latitude/longitude — `output/final/affiliation_simple_coords.csv`

`affiliation_simple` is a short label (`IRD France`, `MRTC Mali`) that unifies the many
long-form strings denoting one place. It is the join key for coordinates.

## Working rules, in order of how much damage ignoring them causes

**1. Never open a project CSV in Excel and save over it.** This is not a stylistic
preference. The existing damage in this project was caused exactly that way: clean UTF-8
went into Excel on a Mac and came back as `YaoundÈ` and `Deuxi√®me`. If a file must be
inspected in a spreadsheet, use Excel's Data → From Text/CSV import with UTF-8 chosen
explicitly, and do not save back. Read them in R instead.

**1b. Save and CLOSE the sheet before running its script.** Every one of the four
`*_review.R` scripts rewrites its own `.xlsx` on each run. If the sheet is still open in
Excel, the script reads the version on disk — without whatever is unsaved — and then
overwrites the file with its own. The edit is gone, silently, and the only sign is that the
answer never appears. This happened on 2026-09-10 with a coordinate for `SNLAP Senegal`.
Order is always: type → save → close → run.

**2. NEVER overwrite `data/affiliation_decisions.csv`. Only add to it.** It is the record
of every change made since the automated repair, and nothing else holds that record.
Hand-written decisions are appended as new lines. Nothing ever replaces the file — no `cp`
over it, no writing it afresh from a proposals file, no bulk "adopt these" step, whatever
an older note says: `GEOCODING_NOTES.md` once said to copy
`output/proposed_decisions_coords.csv` over it, which would have destroyed every decision
in it. The only rows ever rewritten are the two sheet-owned types — `R/coord_review.R`
regenerates the `coordinate` rows and `R/label_review.R` the `label_rename` rows from their
sheets, and each passes every other row through untouched (rule 4).

**3. `source_citation` must stay byte-identical to `output/twatasha_todo.csv`** — or, for
the 204 of Gia's papers not on that list, to her file as delivered. It is the join key back
to `data/vector_extraction_data.csv`. It is deliberately excluded from whitespace
normalisation and, for Gia's rows, from encoding repair: one of hers keeps
`Geissb√ºhler`, because that is the text it matched. Do not trim it, do not collapse its
double spaces, do not strip its `<b>`/`<i>` tags.

**4. Never edit the deliverables by hand.** They are generated. Record judgement calls in
`data/affiliation_decisions.csv` and re-run — see below. A hand edit is lost on the next
run and leaves no trace of why it was made. A row that version 3 never had at all cannot be fixed by any
decision — add it to `data/added_affiliations.csv` instead (see below). Two decision types
are not hand-written in the decisions file either, because a spreadsheet owns them: **`coordinate`** rows come from
`data/coord_review.xlsx` via `R/coord_review.R`, and **`label_rename`** rows from
`data/label_review.xlsx` via `R/label_review.R`. Each script rewrites its own decision type
and passes every other row through untouched. `R/coord_review.R` also **appends** an
`accept_as_is` row for a label answered `absent` in the sheet; those it never rewrites, so
every sign-off already in the file stays exactly as it is.

**5. Do not decide ambiguous cases unilaterally.** The project owner has been explicit
about this. Typos, institution identity, and coordinate choices are his calls. Surface
them in the review lists; do not quietly resolve them.

**6. `data/vector_extraction_data.csv` is 223 MB.** Do not read it — not once, not in a
sandbox, not by symlink. Everything needed from it is already in `output/twatasha_todo.csv`
and, for Gia's papers, in her own file. On 2026-09-17 a plan proposed a single sanctioned
read for her citations and n; the owner refused it.

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

`data/affiliation_decisions.csv` is the single place judgement calls live, and the record of
every change: add to it, never overwrite it (rule 2). Header:

```
decision_type,target,new_value,latitude,longitude,note,decided_on
```

| decision_type | target | new_value | lat/long | effect |
|---|---|---|---|---|
| `label_rename` | current affiliation_simple | replacement label | — | renames everywhere; renaming A to B merges them. Chains resolve (A→B, B→C gives A→C); loops are refused. **Written by `R/label_review.R` from the sheet — do not hand-edit these rows** |
| `affiliation_relabel` | exact affiliation string | affiliation_simple to assign | — | moves one affiliation string onto a different label; **leaves Gia's rows alone** |
| `lake_relabel` | exact affiliation string | affiliation_simple to assign | — | the same, but moves **every** row carrying that string, Gia's included. The only way to move rows of hers off one of her labels short of merging the whole label |
| `coordinate` | affiliation_simple | — | required | overrides the source files; sets `coord_status = decided` |
| `token_replacement` | broken token, e.g. `MUnited Stateseum` | corrected form, e.g. `Museum` | — | overrides the inferred us/uk case |
| `accept_as_is` | label or affiliation | — | — | marks `reviewed = TRUE` in the review lists; changes nothing. For a label with no coordinate, **written by `R/coord_review.R` from `absent` in column A** — appended, never rewritten |
| `note_only` | label or affiliation | — | — | records a note; marks reviewed |

Rules that matter:

- **Every decision must apply.** Anything that matches nothing is reported as `no_match`
  in `output/decisions_report.csv` and printed at the end of the run. A silent no-op is
  the failure mode to guard against; `verify_affiliations.py` fails the run if any
  decision did not apply.
- **`coordinate` targets the label as it stands after renames.** If a label is being
  renamed and given a coordinate, target the new name.
- The file is optional. Absent or header-only, the pipeline reproduces the baseline
  outputs byte-for-byte.
- `data/affiliation_decisions_EXAMPLE.csv` shows every type in use. It is illustrative —
  do not copy it into place wholesale.

## Replacing an affiliation the source recorded as ABSENT

59 rows of deliverable 1 carry `affiliation = ABSENT`, over 58 papers: whoever entered
them could not find an affiliation. `R/absent_review.R` is the loop.

```bash
Rscript R/absent_review.R          # builds data/absent_review.xlsx, one row per ABSENT row
# type the affiliation (A) and its label (B), save
Rscript R/absent_review.R          # answers -> data/added_affiliations.csv
python3 R/tidy_affiliations.py && python3 R/verify_affiliations.py
```

One paper with several affiliations: copy the row, paste it below, change the affiliation.
Any row carrying a citation and an affiliation is read, so the sheet does not cap how many
a paper can have. An existing `affiliation_simple` folds the paper into that label; a new
one creates a label, which then wants a coordinate and appears in `coord_review.xlsx` as a
`needs a coordinate` row on the next run — the script names any new label it sees.

**The ABSENT row itself is dropped by `tidy_affiliations.py`.** Any citation the additions
file supplies has its ABSENT (or empty) rows removed, so the paper ends up with what was
entered and nothing else. A paper that has real affiliations *as well as* a placeholder —
there are three — keeps the real ones.

**The drop matches on the re-keyed citation** (step 3b of `tidy_affiliations.py`, after the
forward-fill and the re-key to `twatasha_todo.csv`). Until 2026-09-11 it ran at load on the
spreadsheet's raw citation text, which the spreadsheet had damaged for many papers —
mojibake, `SoUnited States`, drag-down page numbers — while the additions file carries the
clean form. 23 of the 59 placeholders survived beside their replacements, and verify, which
computed its expectation the same raw way, agreed with the pipeline. Verify now resolves
every spreadsheet row to its paper with its own key — ASCII letters and digits only, us/uk
neutralised, digits dropped as an unambiguous fallback — which resolves all 1273 rows and
matches the deliverable's citation on every surviving one. It also asserts the invariant
directly: **no supplied paper keeps an `ABSENT` or empty row except those typed into the
additions file.** That is the 42nd check, and it runs only when the additions file holds
rows.

Two assertions had to be taught about removal: the deliverable-1 row count is
`1273 + added - replaced`, and the 20-random-row drift check compares against the rows that
survived rather than by raw position, since a removed row shifts everything after it. The
todo-coverage check was rewritten to assert the invariant (every todo source represented)
rather than arithmetic on 541, because a supplied citation may be one that already had a
row or a wholly new one.

**The script owns every paper in its sheet** (fixed 2026-09-17, `R/absent_review.R:153`).
It used to own only the papers deliverable 1 still showed as `ABSENT`. After a rebuild had
dropped a supplied paper's placeholders, that paper's rows in `added_affiliations.csv` were
kept as someone else's and written again from the sheet: 66 duplicate rows per run, which
reached deliverable 1 on 2026-09-16 (1374 rows instead of 1308) and passed verify, whose row
count takes `added` from that same file. Now a paper listed in the sheet is the sheet's
whether or not it still reads as `ABSENT`, so blanking an answer undoes it (the placeholder
comes back on the next rebuild), and `n` and the search link are filled from the citation
rather than lost. Verify's **43rd check** compares the additions file with the sheet: every
answer as many times as `absent_review.xlsx` holds it, no more, no fewer.

## When a change moves a count, teach verify — do not loosen it

`verify_affiliations.py` asserts against constants taken from the source spreadsheet: 1273
rows, 541 of 542 sources covered, non-null counts per column. Three changes in September
2026 moved those numbers legitimately — appending rows from `added_affiliations.csv`,
dropping replaced `ABSENT` placeholders, and re-keying coverage. Each time the assertion
was rewritten to compute the new expectation from the same inputs, never deleted or
relaxed:

- the row count is `1273 + added - replaced`, both recomputed in verify from the additions
  file and the spreadsheet rather than taken on trust;
- coverage asserts the invariant — every `twatasha_todo.csv` source is represented — because
  arithmetic on 541 cannot tell a wholly new citation from one that already had an `ABSENT`
  row;
- the 20-random-row drift check compares against the rows that **survived**, in order,
  because a dropped row shifts every position after it and made 11 untouched rows look
  drifted;
- Gia's rows (2026-09-17): the row count adds hers less those already on their paper, which
  verify works out itself — her citations through its own `_paper()`, her affiliations
  under its own `canon()` with its own reversal of the two repairs — against the
  deliverable's first `1273 + added − replaced` rows. Citations and n may come from her file
  for her 204 new papers; the mojibake check exempts exactly those citations; the relabel
  check looks only at non-lake rows. Six checks are new, each made to fail in a sandbox by
  the fault it guards: every paper of hers represented, her rows once each as a multiset,
  no `IHI Ifakara Tanzania` inside a longer cell, no `Ð`, her points verbatim on live
  undecided labels, and 20 random rows of hers unchanged.

**An expectation recomputed with the pipeline's own logic inherits the pipeline's bugs.**
On 2026-09-11 verify passed a build in which 23 replaced placeholders had survived, because
it chose the rows to expect dropped exactly the way `tidy_affiliations.py` chose the rows to
drop. Derive the expectation independently, and where an invariant can be stated directly —
"no supplied paper keeps a placeholder" — assert that as well as the count.

**A count taken from an input inherits that input's faults.** On 2026-09-17 deliverable 1
held 66 duplicate rows and verify passed, because `1273 + added − replaced` took `added` from
the additions file, which `absent_review.R` had filled with the duplicates. Where an input is
itself generated, check it against what generated it: the 43rd check compares that file with
`absent_review.xlsx`.

If a change makes verify fail, the question is which assertion is now wrong about the
world, not how to make the red go away.

## Adding a paper version 3 never covered

`data/added_affiliations.csv` — `source_citation, affiliation, affiliation_simple, note,
added_on`. Rows here are appended to the version 3 frame as it loads, before anything else
runs, so they go through encoding repair, the `n` re-key, labelling, decisions and the
coordinate loop exactly like a spreadsheet row. `row_xlsx` from **90001** up marks a row as
coming from this file.

Why not type it into the spreadsheet: `Affiliation spreadsheet_version 3. 26 Sep. 2024.xlsx`
stays the artefact it was delivered as, and every hand-entered row stays visible and
reversible in one place.

`source_citation` must be byte-identical to the `twatasha_todo.csv` value — copy it from
`output/review_unmatched_sources.csv`, which is where the uncovered papers are listed.
Leave `n` out; it is re-keyed from `twatasha_todo.csv` like every other row.

Two assertions in `verify_affiliations.py` count off the spreadsheet and now allow for these
rows: the deliverable-1 row count (1273 + added) and the todo-source coverage (541 + added
of 542). Adding a row without teaching verify about it fails the run, which is the intended
behaviour.

Added 2026-09-10: the five affiliations of Diop et al. 2002, the one paper
`review_unmatched_sources.csv` had been reporting since August. That file is now empty and
every one of the 542 todo sources is represented.

## Running things

From the project root:

```bash
Rscript R/absent_review.R           # affiliations recorded ABSENT, via data/absent_review.xlsx
Rscript R/label_review.R            # label merges, via data/label_review.xlsx
Rscript R/coord_review.R            # coordinate decisions, via data/coord_review.xlsx
python3 R/tidy_affiliations.py      # rebuild all outputs
python3 R/verify_affiliations.py    # 50 assertions; exits non-zero on failure
```

Run `label_review.R` before `coord_review.R`: a merge patches the coordinate sheet, and
`coord_review.R` is what turns that patch back into decisions.

`pandas`, `xlrd` and `openpyxl` were installed on this machine on 2026-09-03 and the
Python steps run here. Verified 2026-09-04: a clean rebuild reproduces the reference
output exactly (1273 rows, 1002 lookup pairs, 398 labels, 1174 logged changes,
coord_status 262 ok / 88 missing / 29 conflict / 19 absent) and verify passes.

**The check count changes as work proceeds and that is correct.** With no decisions the
suite runs 36 checks; once `data/affiliation_decisions.csv` holds any decisions it runs
41, the extra five confirming those decisions landed; once `data/added_affiliations.csv`
holds rows it runs 43, the two extra confirming every replaced placeholder is gone and that
the file holds each `absent_review.xlsx` answer as often as the sheet does; once
`data/gia_final_data/` is present it runs 49, six more for Gia's rows; and 50 once the
decisions file holds a `lake_relabel`, the extra one asserting that every row carrying that
string — Gia's included, so it is checked against the whole of deliverable 1 — sits under the
label the decision names. A rise from 36 to 41 to 43 to 49 to 50 is expected, not a
regression.

`R/coord_review.R` is the spreadsheet loop for coordinates: it builds
`data/coord_review.xlsx` (one row per candidate coordinate, an `accepted` column you fill
with yes/no/absent), converts the answers into the `coordinate` rows of the decisions file
— and appends an `accept_as_is` row for each label answered `absent` — then rebuilds the
sheet preserving what you have already answered. It leaves every other
decision row alone. It refuses to accept two coordinates for one label. The sheet is xlsx
rather than csv precisely because rule 1 makes csv unsafe to open in Excel. Details in
**The coordinate loop** under Reference in `NEXT_STEPS.md`.

**Only six cells of the sheet are read back as answers** (`R/coord_review.R:306`):
`accepted` (A — `yes`, `no`, `absent` or blank), `affiliation_simple` (C), `latitude` (H),
`longitude` (I), `your_note` (M), `decided_on` (N). `case` (G) is read too, only to tell a typed row from a generated one when
reporting what was not kept. Everything else is display-only and regenerated each run. To
supply your own coordinate, type the numbers into H and I and put the link in M —
`source_url` (Q) is not read. A row whose label is not in the candidate list becomes a
hand-entered (`case = manual`) row, which is how you give a coordinate to a label the sheet
does not offer — an `ok` label, or one created by a merge.

Three guards were added on 2026-09-04 after each failed in turn. All three exist because
a label can appear under two spellings that `join_key()` resolves to one:

- The "one yes per label" check groups on `join_key`, not label text
  (`R/coord_review.R:475`). `ICAPB UK` and `ICAPB United Kingdom` are one label; they
  cannot carry different coordinates. Same point spelt two ways is deduplicated instead,
  keeping the spelling the deliverables use.
- Candidate rows for labels no longer in the deliverables are dropped and counted
  (`R/coord_review.R:277`). Both source files are snapshots, so a merged-away label goes
  on generating rows forever. **Hand-typed rows are deliberately exempt** — an unknown
  label there is a typo worth surfacing. **This guard does not save a row you have
  already ticked**: once the label leaves the candidate list, `manual <- ans %>%
  filter(!k %in% cand$k, accepted == "yes")` reclassifies the ticked row to
  `case = manual`, which is exempt, so the dead `coordinate` decision is re-written on
  every run. Blanking column A on that row is the only fix — see the `label_rename`
  paragraph below. Cost a `41 checks, 2 failed` on 2026-09-04.
- A `coordinate` decision whose target is not a label at all is dropped and named
  (`R/coord_review.R:571`). It could only ever report `no_match`. Decisions for labels
  that exist but never reach the sheet are still preserved. **So is a decision whose label
  a `label_rename` in the same file is about to take away** (added 2026-09-16): the
  deliverables still list it, so the older rule kept it, the rename then removed the label
  in the rebuild, and the build ended `42 checks, 2 failed` — clearing only on a second
  run. Found merging `DRASS France` into `DRASS Reunion`.

Two more were added on 2026-09-15 with the `absent` rows, because typed input used to vanish
without a word when the sheet was rewritten:

- Anything in H or I that is not a plain number — `14,7`, or both numbers pasted into one
  cell — stops the run before anything is written (`R/coord_review.R:328`), so the sheet on
  disk keeps what was typed. A U+2212 minus sign copied from a web page is read as `-`.
- A coordinate typed without `yes` in A, and an answer or note on a row with no coordinate,
  are named under `!!` at the end of the run (`R/coord_review.R:432`). The sheet cannot hold
  either: a hand-typed coordinate is kept only while ticked, and a label staying without a
  coordinate is signed off with `absent` in A, not `no`.

Added 2026-09-17 for Gia's data (step 8 of `NEXT_STEPS.md`), while
`data/gia_final_data/` exists:

- **`case = lake` rows.** Every label whose coordinate came from her counts file
  (`coord_source = lake_region_source_counts`) and is still `ok` gets a row carrying that
  point: yes means checked, and the label becomes `decided`. Without these her points would
  never reach the sheet, and the sanity sweep, testing only the country, passes a point in
  the wrong town. A point of hers that no label uses is offered to every label without a
  coordinate whose name ends in the same two words (`ILRI Nairobi Kenya`'s point to
  `ILRAD Nairobi Kenya`); one offered to no label is named on every run (`MAFS`).
- **A ticked row that turns `manual` keeps its recorded note.** Once its source stops
  offering it, a ticked sanity or lake row comes back as `case = manual`, which has no source,
  and its decision used to be rewritten without the provenance recorded when it was ticked.
  The note already in the decisions file for the same label and coordinate is kept unless
  the note typed in M has changed.

**A `label_rename` strands any `coordinate` decision targeting the old name.** The fix
belongs in the sheet — retarget or blank column A on that row — not in the CSV, because
the sheet is rewritten from on every run. Note `label_rename` also renames the label
inside `unique_entries`/`unique_affiliations_Lat_Long`, so merging two labels can pull
their source coordinates together into a new conflict; a `coordinate` decision overrides
it. `affiliation_relabel` does **not** touch those files — use it to split one label into
two (as `IHI Tanzania` was split into `IHI Ifakara` / `IHI Dar es Salaam`). **It does not move
Gia's rows either** (2026-09-17): her rows keep her labels until merged in
`label_review.xlsx`, and a rebuild names any row of hers carrying a relabelled string (one:
"Ifakara Health Institute, Mlabani Passage, Ifakara, Tanzania", under
`IHI Ifakara Tanzania`).

**`lake_relabel` is how her rows are moved deliberately** (added 2026-09-18,
`tidy_affiliations.py` immediately after the `affiliation_relabel` block). Same target and
new_value, no exemption: every row carrying the string moves, hers included, and the run
reports how many of them were hers. The guard on `affiliation_relabel` stays and is not to be
worked around — a relabel written for spreadsheet rows is not an approval of a match with
hers. It was added because undoing the `KU Kenya` / `KenyattaU Nairobi Kenya` merge into
`JKUAT Kenya` left seven rows of "Jomo Kenyatta University of Agriculture and Technology"
text under `KenyattaU Nairobi Kenya`, all of them Gia's, that no decision type could reach:
`affiliation_relabel` skips her rows and a `label_rename` would take the whole label back.

**Renames must name their final destination, not chain through a label that renames
created.** `A → B` then `B → C` resolves the data correctly, but the `B → C` row reports
`no_match` when no source row ever carried `B`, and verify fails the run.

**The pipeline is Python.** `R/tidy_affiliations.py` builds the deliverables and
`R/verify_affiliations.py` checks them; there is no other implementation. An R transcription,
`R/tidy_affiliations.R`, existed but was **never executed** — R was unavailable where it was
written — and it fell steadily behind: it never mirrored the placeholder drop of step 3b,
anything for Gia's lake-region rows, or `lake_relabel`. It was deleted on 2026-09-21. The R
scripts that remain are the four review loops and the three sweeps, all of which run.

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
`if len(dec):`.

## File map

```
data/
  twatasha_final_data/          the two source spreadsheets, authoritative
  affiliation_decisions.csv     judgement calls, the record of every change; add to
                                it, NEVER overwrite it (rule 2), and never edit the
                                outputs instead. coordinate and label_rename rows
                                come from the two sheets
  added_affiliations.csv        rows version 3 never had, and replacements for rows it
                                recorded as ABSENT; appended to v3 at load, row_xlsx
                                90001+. Written by R/absent_review.R for ABSENT papers;
                                other rows (Diop et al. 2002) are passed through
  absent_review.xlsx            the ABSENT sheet; type the affiliation and its label,
                                generated+read by R/absent_review.R
  coord_review.xlsx             the coordinate sheet; tick `accepted`, generated+read by R/coord_review.R
  label_review.xlsx             the label-merge sheet; tick `accepted` (A), set
                                `keep` (C), read `warning` (Q) before ticking; `lake`
                                (Y) says which side is Gia's; generated+read by
                                R/label_review.R
  gia_final_data/               Gia's lake-region affiliations (rows, 338) and
                                coordinates (counts, 39 labels), as delivered; read by
                                tidy_affiliations.py, verify, and coord_review.R
  affiliation_decisions_EXAMPLE.csv
  unique_affiliations_Lat_Long.csv   round-1 coordinates, MAC ROMAN on disk
  Affiliation spreadsheet (version 2).csv   round 1, superseded
  unique_entries_tidy_20250203.*     identical to the Sep 2024 file; no edits were made
  vector_extraction_data.csv    223 MB, DO NOT READ, not even once (rule 6).
                                Everything needed from it is already in
                                output/twatasha_todo.csv and Gia's file
  *.geotiff, *.tif, *.zip       large rasters and archives, irrelevant here, do not read
R/
  check_coord_sanity.R          sweeps every coordinate against the country its
                                affiliation names; writes output/review_coord_sanity.csv
  check_coord_place.R           sweeps every coordinate against the TOWN its
                                affiliation names; writes output/review_coord_place.csv
  place_lookup.R                the gazetteer (maps::world.cities) and the two-way
                                place comparison; sourced by check_coord_place.R and
                                coord_review.R, defines functions only
  check_label_candidates.R      sweeps the label list for duplicates and lumps; writes
                                output/review_label_duplicates.csv and
                                output/review_label_lumping.csv
  tidy_affiliations.py          tested reference implementation
  verify_affiliations.py        assertions
  coord_review.R                the coordinate spreadsheet loop; runs, tested
  label_review.R                the label-merge spreadsheet loop; owns every
                                label_rename row and patches coord_review.xlsx
  absent_review.R               the ABSENT-affiliation loop; turns data/absent_review.xlsx
                                into the rows of data/added_affiliations.csv
  sources_to_check.R            produced output/twatasha_todo.csv
  unique_affils.R, reseach_locations.R   round-1 scripts, historical
output/
  final/                        THE THREE DELIVERABLES, and nothing else. Has its
                                own README.txt. Everything below is working files
    affiliations_complete.csv        deliverable 1 (no date stamp since 2026-09-17)
    affiliation_lookup.csv           deliverable 2
    affiliation_simple_coords.csv    deliverable 3
  decisions_report.csv          did each decision apply?
  diff_report_20260817.csv      every changed cell; 1880 rows, read only with grep
  review_encoding_repairs.csv   411 rows; read only with grep
  review_simple_lumping.csv     157 rows with long pipe-joined cells; grep, do not cat
  review_coord_sanity.csv       coordinates that disagree with their country; empty
                                at 2026-09-21, 5 labels signed off with accept_as_is
  review_coord_place.csv        coordinates that are not in the town their text
                                names; empty at 2026-09-21, 9 labels signed off,
                                74 the gazetteer cannot test
  review_label_duplicates.csv   77 label pairs that may be one place, every one
                                answered in label_review.xlsx
  review_label_lumping.csv      95 labels that may be several places; deliberately
                                not pursued
  review_lake_repairs.csv       every reading the Centre and Ð repairs to Gia's rows
                                produced, with counts
  review_lake_overlap.csv       Gia's 12 rows on the 7 papers already present:
                                dropped or added, and the existing label
  review_lake_counts.csv        her unused points, her labels without a coordinate,
                                her n against her rows
  label_sources.csv             rows per label and how many are Gia's; read by the
                                label sweep and label_review.R
  review_*.csv                  what still needs a human
  parity_baseline/              a frozen 2026-08-17 build made with NO decisions.
                                Built for the R parity check, which no longer
                                exists; kept as the only picture of the corpus
                                before any judgement call. NOT a deliverable; it
                                still shows 88 missing / 29 conflict. Called
                                shipped/ until 2026-09-10, a name that read as
                                "the files we shipped" and caused exactly the
                                confusion you would expect. Has its own README.txt
AFFILIATION_CLEANING_README.md  what the pipeline did
aff_audit_plan.md               file lineage and full damage inventory
NEXT_STEPS.md                   the work queue; linear, steps 1-8 then reference
LAKE_MERGE_PLAN.md              the approved plan for step 8, with the owner's changes;
                                NEXT_STEPS.md step 8 is the record of what was built
```

## Style

The project owner is an advanced R user and wants direct, unpadded communication. State
plainly when something is not known or not possible rather than producing an answer that
will not work. Give references. Australian English, `-ise` not `-ize`.
