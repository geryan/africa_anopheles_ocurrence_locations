# NEXT_STEPS.md — what is left, in order

Read `CLAUDE.md` first for the working rules — particularly the one about never saving a
project CSV out of Excel.

This file runs top to bottom. **Steps 1 to 7 are done** and kept as the record of how each
was done. **Step 8, Gia's lake-region data, is answered and built; its closing runs are
left**, listed straight below. Everything after **Reference** is background.

---

## Where this is up to — 2026-09-17, 15:30

**You answered both step-8 sheets and the loop was run**; the last rebuild wrote the
deliverables at 15:30. Checked read-only afterwards, nothing run:

| | |
|---|---|
| `label_review.xlsx` | 255 rows, none open. Step 8's 51 pairs: 21 accepted (20 `label_rename` rows), 30 rejected |
| `coord_review.xlsx` | 241 rows, every label settled. 31 new `coordinate` rows: 22 of Gia's points as they stand, 6 conflicts the merges raised, `ILRAD Nairobi Kenya` on the ILRI point, your own points for `ICIPE Nairobi Kenya` and `MasenoU Maseno Kenya` |
| `data/affiliation_decisions.csv` | 312 decisions, all `applied` in `output/decisions_report.csv` |
| `output/final/affiliations_complete.csv` | 1640 rows, 746 papers |
| `output/final/affiliation_lookup.csv` | 1290 pairs |
| `output/final/affiliation_simple_coords.csv` | 327 labels — 168 `decided`, 156 `ok`, 3 `absent`, 0 `missing`, 0 `conflict`; none of Gia's points left unchecked |

**Closing runs — not done yet.** Verify has no recorded run on this build, and both sweeps
last ran at 12:33, before the merges and the new coordinates, so their "109 pairs" and
"0 flagged" are the old build's. Steps 1 and 2 say to re-run both after a batch of merges.

```bash
python3 R/verify_affiliations.py      # 49 checks expected
Rscript R/check_label_candidates.R
Rscript R/check_coord_sanity.R
Rscript R/label_review.R              # anything new reaches the sheet; the 21 rows should read applied
Rscript R/coord_review.R              # likewise; the 23 ticked lake rows should turn manual
python3 R/tidy_affiliations.py && python3 R/verify_affiliations.py   # if a decision changed
```

The rebuild should no longer print the `!! lake row 50117` notice, now that
`IHI Ifakara Tanzania` is merged into `IHI Ifakara`. `output/final/README.txt` still gives the
counts from before the answers (347 labels, 1298 pairs) and wants updating after these runs.

**Two of the answers, for you to confirm — facts, not recommendations:**

- `MTTI Kendu Bay Kenya` ("Mawego Technical Training Institute, Kendu Bay, Kenya") is
  `decided` at Gia's point as it stood, -4.0435, 39.6682, which is Mombasa. It is the only one
  of step 8's four far-from-town points left where it was.
- `KU Kenya` and `KenyattaU Nairobi Kenya` are merged into `JKUAT Kenya`, which now holds 10
  Kenyatta University affiliation strings (P.O. Box 43844, Nairobi) beside 5 for Jomo
  Kenyatta University of Agriculture and Technology. Kenyatta University (Kahawa, Nairobi)
  and JKUAT (Juja) are separate universities.

### Earlier on 2026-09-17 — before your answers

**Step 8 was open: Gia's lake-region data was in the deliverables, unreviewed.** Her 332 rows
sit under her own 39 labels. **51 label pairs** wait in `label_review.xlsx` and **39 labels**
in `coord_review.xlsx`: 37 of her points to check, and 2 labels of hers without a
coordinate. Answer the merges first. Step 8 has the loop.

The build is clean: **261 decisions, all applying**, and `verify` ends `49 checks, 0 failed`.
The three deliverables lost their `_20260817` stamp on 2026-09-17.

| | |
|---|---|
| `output/final/affiliations_complete.csv` | 1640 rows — 1273 from the spreadsheet, 94 added, 59 `ABSENT` placeholders replaced, 332 of Gia's; 746 papers |
| `output/final/affiliation_lookup.csv` | 1298 pairs |
| `output/final/affiliation_simple_coords.csv` | 347 labels — 205 `ok` (37 of them Gia's, unchecked), 137 `decided`, 3 `absent`, 2 `missing` |

**A bug found on the way, fixed 2026-09-17.** `R/absent_review.R` wrote the 66 non-ABSENT
answers again on every run, so the deliverable held 1374 rows rather than 1308, and the
extra row had flipped `MoH Nigeria` to `MOH Nigeria` in the formatting-only collapse. Verify
passed it, because it took its expected count from the same additions file. Step 5 has the
detail; verify's 43rd check now compares the additions file with the sheet.

**Step 5 was added after steps 1 to 4 were finished**, to go back over every affiliation the
source could not find, and was done on 2026-09-11: 35 of the 58 papers now have real
affiliations and 23 are confirmed `ABSENT`. It also exposed a pipeline bug, fixed the same
day — see step 5.

**Before step 8 every sheet was answered and nothing was flagged**, but that only covers
labels that have a coordinate. The sanity sweep checks 342 coordinates and flags 0, with five
labels signed off by `accept_as_is` — three of them step-5 labels whose affiliations name no
country (`Illinois NHS`, `UQ`, `University of Copenhagen`). 37 of the 342 are Gia's, and
the sweep tests only the country, so its `0 flagged` says nothing about whether her points
are in the right town. The five label pairs step-5 labels raised were all rejected in
`label_review.xlsx`. The 12 labels of step 6 had no coordinate, so no sweep could say
anything about them; the 10 that now have one are swept and none is flagged.

**The three deliverables are in `output/final/`, with a README.txt that documents every
column, what was done and the known limits.** Everything else in `output/` is working
files. `output/parity_baseline/` (called `shipped/` until 2026-09-10) is a frozen
pre-decisions build kept only for the R parity check — it still shows 88 missing and 29
conflict, and its own README says so.

Nothing is in `conflict`. The 2 `missing` are Gia's `ILRAD Nairobi Kenya` and
`Ifakara Centre Ifakara Tanzania`, both open in `coord_review.xlsx`. The 3 `absent` are
the label `ABSENT` itself, which is final, and the two labels step 6 signed off. All 542
`twatasha_todo.csv` sources and all 211 of Gia's papers are represented;
`review_unmatched_sources.csv` is empty.

| step | | |
|---|---|---|
| — | environment | **done** 2026-09-03 |
| — | coordinates: every label settled | **done** 2026-09-07 |
| **1** | merge duplicate labels | **done** — 125 merges applied, 76 pairs rejected, none open before step 8 |
| **2** | check the coordinates already there | **done** — 342 checked at 2026-09-17, 0 flagged, 5 signed off |
| **3** | spot-checks | **done** — reviewed, nothing changed |
| **4** | the paper version 3 never covered | **done** — 5 affiliations added, coordinate settled |
| **5** | affiliations the source recorded as ABSENT | **done** 2026-09-11 — 35 papers given affiliations, 23 confirmed `ABSENT`, 11 new labels with coordinates |
| **6** | coordinates the source recorded as ABSENT | **done** 2026-09-16 — loop built 2026-09-15, all 12 answered: 10 coordinates, 2 left `absent` and signed off |
| **7** | two label pairs the new coordinates raised | **done** 2026-09-16 — `Centro Hispano-Guineano` / `CREC Equatorial Guinea` rejected; `DRASS France` + the Saint-Denis `Vector Control Service` label merged into the new label `DRASS Reunion` |
| **8** | Gia's lake-region data | **built and answered** 2026-09-17 — 20 merges, 30 pairs rejected, 31 coordinates, rebuilt 15:30; verify, both sweeps and a last pass of the two sheet scripts still to run (top of this section) |

**Step 8's open work is in the two sheets.** The review files below were records, not work,
before step 8; the counts are as at 2026-09-17, after it:

| file | rows | what it is now |
|---|---|---|
| `review_simple_conflicts.csv` | 10 | 2 pairs rejected before step 8 (`IRD France` / `MIVEGEC / CIRAD / LIN Montpellier`, `IRD Cameroon` / `ORSTOM/ OCEAC Cameroon`); the other 8 are strings Gia's rows share with an existing label, all raised as open pairs in `label_review.xlsx` |
| `review_label_duplicates.csv` | 109 | the 58 earlier pairs, all answered, and 51 raised by Gia's labels, all open |
| `review_label_lumping.csv` | 101 | the granularity question, deliberately not pursued |
| `review_simple_lumping.csv` | 157 | the same question, older form |
| `review_us_uk_tokens.csv` | 21 | reviewed 2026-09-10, all 21 expansions correct |
| `review_labels_collapsed.csv` | 9 | the first 8 reviewed 2026-09-10; the ninth, `MOH Nigeria` → `MoH Nigeria`, came from step 5 |
| `review_coord_conflicts.csv` | 38 | raw conflicts in the source files, every one resolved by a `coordinate` decision |
| `review_coord_sanity.csv` | 0 | sweep flags nothing; 5 labels signed off with `accept_as_is` |

The steps below are kept as the record of how each was done, and because the loops still
work if a label or coordinate ever needs revisiting.

---

## Step 1 — merge duplicate labels — done

Some `affiliation_simple` values are the same place under different spellings. This is a
spreadsheet, exactly like coordinates were. **You never hand-write a decision line.**

```bash
Rscript R/label_review.R          # builds data/label_review.xlsx
# open it in Excel, put yes/no in column A, save
Rscript R/label_review.R          # answers -> data/affiliation_decisions.csv
Rscript R/coord_review.R          # re-emit the coordinate rows
python3 R/tidy_affiliations.py && python3 R/verify_affiliations.py
```

One row per candidate pair — two labels that may be one place — open first and
worst-first. 200 rows on 2026-09-07, 153 of them open; 254 at 2026-09-17, 51 open, all
raised by Gia's labels (step 8). **Two columns are yours:**

| column | |
|---|---|
| **A `accepted`** | `yes`, `no`, or blank. `y` / `x` / `1` also read as yes |
| **C `keep`** | the label that survives. Filled in with a guess — retype it to change the answer. `new: <name>` creates a label of that name and merges the row into it |
| **F `group`** | the cluster this pair belongs to. Not editable; see below |
| **Q `warning`** | read this before you tick. See below |

`keep` does **not** have to be one of the two labels on the row. Name any label and both of
the row's labels merge into it, so *"these three are one place, keep the third"* is one yes
on one row. Ticking several rows that share a label merges the whole group.

Only four cells are read back: `accepted` (A), `keep` (C), `your_note` (R) and
`decided_on` (S). Everything else is evidence and is regenerated every run — row counts,
`coord_status` and coordinate for each side, the distance between them, the evidence that
raised the pair, the first 500 characters of each label's affiliation strings, and a Google
Maps link for each coordinate in W and X. Column Y `lake` (added 2026-09-17) says which side
carries Gia's rows: `a`, `b` or `both`.

### Rows are grouped into clusters, not listed one by one

Every pair that shares a label with another pair is in the same cluster, and the whole
cluster sits together in the sheet under one `group` name — the cluster's busiest label,
with `group_n` giving how many labels are in it. So a family of five spellings is decided
once, looking at all of it, instead of being re-prosecuted five times in five places.

Clusters with unanswered rows come first, then by the strongest evidence in the cluster,
then by size. Within a cluster the open rows come first. 63 clusters at 2026-09-08; the
largest are `OCEAC Cameroon` (26 labels — the IRD / ORSTOM / OCEAC / Centre Muraz /
Montpellier family) and `UC United States` (12 — the `UA` / `UOA` / `UvA` acronym
collisions, most of which are dismissible in one pass).

Every edge counts towards a cluster, weak ones included. That is deliberate: the point is
to see everything that might touch the label in hand at once, and dismissing a weak edge is
cheap when you are already looking at the family.

### The `warning` column — what a merge does to the coordinates

**A merge keeps the survivor's coordinate and throws the other one away.** Whether you ever
see that depends on a distinction worth knowing:

- **Both labels `ok`** — the rename also renames them inside the coordinate source files, so
  both points land on the survivor and it becomes a `conflict`. Two rows appear in
  `coord_review.xlsx` and you pick one. Visible, and it is why merging raises new
  coordinate work.
- **Either label `decided`** — the `coordinate` decision overrides the source files, so no
  conflict is raised and the other point is discarded silently.

Column Q is for the second case. It fires on any row, ticked or not, and says:

| it says | meaning |
|---|---|
| `N km apart` | the two coordinates are more than 5 km apart |
| `discards a coordinate you chose` | both labels are `decided` — the survivor keeps its own, and you are throwing away your other answer, not an unexamined source value |
| `the coordinate you chose follows the merge; the survivor's own point is discarded` | the label being merged away is `decided` and the survivor is `ok`: the script retargets your coordinate onto the survivor (below), so it is the survivor's source point that goes. Until 2026-09-17 this case wrongly read `discards a coordinate you chose` |
| `the discarded point is sanity-flagged` | the point being dropped is one in `review_coord_sanity.csv` (none at 2026-09-17). This is the comfortable case: the merge takes the bad coordinate away with the label |
| `KEEPS a sanity-flagged point` | the point that survives is one in `review_coord_sanity.csv`. Think about this one |

Every run also prints the warnings for merges you have accepted but not yet built, worst
first, with a maps link to the point being discarded. `Rothamsted Research` is the worked
case: its long-form label carried **12.6111, −8.1603 — Bamako**, 4415 km from Harpenden, and
because `RRes United Kingdom` was `decided` the merge would have dropped it without a word.
The warning says `4415 km apart; the discarded point is sanity-flagged`, which is exactly
the reassurance you want before ticking.

### Worked example

You decide `Wits Unitversity`, `Wits Univeristy` and `Wits University South Africa` are one
place. Row numbers move when the sheet is rebuilt; these are as it stands.

1. **Row 16**, `Wits Unitversity South Africa` vs `Wits University South Africa`. Column C
   already reads `Wits University South Africa`. Put `yes` in A.
2. **Row 6**, `Wits Unitversity South Africa` vs `Wits Univeristy South Africa`. Put `yes`
   in A and retype C to `Wits University South Africa`.
3. Save, run the four commands above.

Two `label_rename` lines are written for you, 19 rows move onto `Wits University South
Africa`, which then covers 35. Both misspellings carry latitude **+26.19** — which step 2
flags as 5378 km out — and they leave with the labels, so two of that step's 24 clear at
the same time. Row 54 is the third pairing and needs nothing; the group resolves from any
two.

### What the script does that hand-editing did not

- **It resolves the group before writing.** Every `label_rename` it emits names the final
  survivor directly, so a rename can never chain through a label that an earlier rename
  created. That trap reports `no_match` and fails verify; through the sheet it cannot
  happen.
- **It repairs the coordinate sheet.** Every settled label in `coord_review.xlsx` carries a
  `coordinate` decision, and merging a label away orphans it. Each run patches
  `data/coord_review.xlsx` and prints what it did: if the survivor has no coordinate of its
  own the merged label's row is **retargeted** to it, so the coordinate you already chose
  follows the merge; if both have one, the survivor keeps its own and the merged label's
  row is **blanked** in column A. That is why `Rscript R/coord_review.R` is in the
  sequence — it turns the patched sheet back into decisions.
- **It owns every `label_rename` row** of `data/affiliation_decisions.csv` and passes every
  other decision type through untouched.

### Where the candidates come from

`Rscript R/check_label_candidates.R` (~7 s, read-only) sweeps the whole label list and
writes the two files the sheet is built from. Re-run it after a batch of merges.

**`output/review_label_duplicates.csv` — 153 pairs when it first ran on 2026-09-07**, 53 of them
at `strength >= 4`; 109 at 2026-09-17. Each
pair carries the evidence that raised it, usually several:

| evidence | |
|---|---|
| `shared_affiliation` | the two labels share an affiliation string verbatim |
| `shared_phrase` | their strings share an institution phrase found under at most 3 labels |
| `shared_phrase_only2` | the same, where the phrase is under exactly these two labels — the strongest form |
| `acronym` | one label's acronym is an abbreviation of an institution written out under the other. Three forms are generated, because `UoN` / `UoK` / `UofK` take their `o` from the "of" that plain initials throw away |
| `contraction` | a contraction rather than an initialism — word initials plus a fragment of the last word, the shape a domain name takes: `uonbi` for University of Nairobi. Fires on 4 pairs in the whole corpus |
| `same_point` | coordinates within 250 m |
| `near_point` | within 2 km; never reported alone, since two unrelated institutes in one city are near each other |

A pair resting only on soft evidence is dropped unless both labels name the same country.
Hard evidence — a shared string, or one coordinate — is kept whatever the countries say,
which is what keeps `Wits Unitversity` / `Wits University` in the list despite the 5825 km
between them.

Known false positives, so you can dismiss them fast: the five `IRD <country>` labels all
match `MIVEGEC / CIRAD / LIN Montpellier` on the acronym alone; `UI Nigeria` picks up
`Unilorin Nigeria` on colliding initials; `IC United Kingdom` picks up Edinburgh's
"Institute of Cell, Animal and Population Biology"; `U Nijmegen` picks up `UoN Kenya`.

### The other half of the same problem — one label, several places

**`output/review_label_lumping.csv` — 86 labels on 2026-09-07, 101 at 2026-09-17.** Nothing here is in the sheet; it is a
reading list, and the fix is either a `label_rename` (if two labels should be one) or an
`affiliation_relabel` (if one label should be two, as `IHI Tanzania` was split into
`IHI Ifakara` and `IHI Dar es Salaam`).

| flag | |
|---|---|
| `multi_country` | the label's strings name two or more countries — 9 labels |
| `composite_string` | one single string names two or more, e.g. CDC Atlanta *and* KEMRI Kisumu |
| `multi_place` | two or more distinct cities. The city is the last comma field that is not a country, an institution, a department or an address |
| `multi_institution` | two or more institution phrases, neither nested in the other; reported alone only at three or more, since two departments of one campus is normal here |

The nine `multi_country` labels are the ones a single coordinate cannot honestly serve:

```
IPF France        FRA; MDG; SEN    3 rows     SAP Italy      BFA; ITA   58 rows
CDC United States KEN; USA        20 rows     KEMRI Kenya    KEN; USA    3 rows
AAU Ethiopia      ETH; NGA         7 rows     CIRMF Gabon    FRA; GAB    5 rows
SIPPE CAS US      CHN; USA         1 row      CSRS CIV       CHE; CIV    4 rows
ISCIII Spain      ESP; GNQ        11 rows
```

Then the two-city cases: `IRD France` (Montpellier and Paris), `UC United States` (Davis,
Irvine, Los Angeles, Riverside), `IRD Burkina Faso` (Ouagadougou and Bobo-Dioulasso),
`SAMRC South Africa` (Durban, Congella, Johannesburg), `NIAID United States` (Bethesda and
Rockville), `MRC The Gambia` (Banjul and Fajara), `NICD South Africa` (Johannesburg and
Sandringham), `IHMT Portugal` (Lisboa and Lisbon — one city, two spellings).

US place names that are also country names (Georgia, Indiana, Norfolk) are suppressed when
the label also says USA, and overseas territories fold into their sovereign, so Réunion
does not read as a second country against France.

### The two older lists, superseded but still accurate

Both are regenerated on every rebuild, and every row in them is also a row in
`label_review.xlsx`. Read them for the reasoning; put the answer in the sheet.

- **`output/review_simple_conflicts.csv`, 18 rows on 2026-09-07** (10 at 2026-09-17) — one affiliation string carrying two
  or more labels. Spelling variants still open: `Wits Unitversity` / `Wits Univeristy` /
  `Wits University` (4 of the 18 rows), `UY1` / `UYI Cameroon`, `UoK` / `UofK Sudan`,
  `CNRFP Burina faso` / `CNRFP Burkina Faso`, `MRC Gambia` / `MRC The Gambia` /
  `MRC Laboratories, Fajara`, `DBL Denmark` / `Danish Bilharziasis Laboratory`,
  `LNSP Bissau` / `NPHL Guinea Bissau`. Four more are a short label sitting beside the
  long-form label for the same string — cosmetic, not a pipeline fault. The rest are real
  questions of institution identity: `IRD Cameroon` vs `OCEAC Cameroon` and vs `Malaria
  Research Laboratory Cameroon`, `IRD Madagascar` vs `RTI Madagascar`, `IRD France` vs
  `MIVEGEC / CIRAD / LIN Montpellier`.
- **`output/review_simple_lumping.csv`, 135 rows on 2026-09-07** (157 at 2026-09-17) — how many distinct affiliation strings
  each label covers. 133 at 2026-08-17; merging labels makes the lumps bigger, not smaller.
  Largest: `SAP Italy` (45), `OCEAC Cameroon` (28), `LSTM United Kingdom` (23),
  `UB / USTTB Mali` (23), `MIVEGEC / CIRAD / LIN Montpellier` (21), `CDC United States`
  (19), `IRD France` (19), `UCAD Senegal` (17).

### Two things that stay hand-written

`affiliation_relabel` and `accept_as_is` are not in any sheet. Add them to
`data/affiliation_decisions.csv` in **RStudio, never Excel**:

```
affiliation_relabel,Department of Zoology…,IHI Ifakara,,,split; different site,2026-09-03
accept_as_is,IRD France,,,,checked; one site,2026-09-03
```

`accept_as_is` marks a label as checked without changing anything — the review lists then
show `reviewed = TRUE` and it stops demanding attention.

---

## Step 2 — check the coordinates already there — done 2026-09-10

The coordinate sheet only ever showed you `missing` and `conflict` labels. It never showed
the `ok` ones, which came out of the source files unexamined. This step sweeps those, and
**the answers go into `coord_review.xlsx` exactly like every other coordinate** — the
suspects are injected into that sheet as `case = sanity` rows with status `open`.

```bash
Rscript R/check_coord_sanity.R    # find the suspects -> output/review_coord_sanity.csv
Rscript R/coord_review.R          # put them in data/coord_review.xlsx as open rows
# open the sheet, put yes/no in column A, save
Rscript R/coord_review.R          # answers -> data/affiliation_decisions.csv
python3 R/tidy_affiliations.py && python3 R/verify_affiliations.py
```

**When this step finished the sweep flagged 0 of 285**; after step 5 it flagged 3 of 296,
all new labels naming no country it can test, and with those signed off it flags 0 of 296.
It found 15 suspects on 2026-09-10, all of them
`coord_status = ok` — never one of the 116 coordinates you had chosen — and all 15 were
settled: 13 given a corrected coordinate, 2 signed off with `accept_as_is` because they are
right and simply cannot pass a country test. A further 20 coordinates disagree with `maps`
but sit inside the 10 km coastal tolerance and are not flagged.

The rest of this step is the record of how it was done, and the loop still works if a
coordinate ever needs re-opening — which is the only way an `ok` label can be, since one
never reaches the sheet otherwise.

### What you see, and what to put in column A

Each suspect gets one row carrying **the coordinate as it stands**, so ticking it means
*checked, this is right*. `geocoder_notes` says what is wrong with it — which country the
point is in, which country was expected, how far outside it sits.

Where the error is arithmetic, a **second row** carries the repair, and it is only offered
when the repaired point actually lands inside the expected country. Four of the 15 had one:

```
SU Yemen             5.3674, 44.1804   leading 1 lost from latitude  -> 15.3674, 44.1804
INSERM France       48.8266, -2.5124   longitude sign flipped        -> 48.8266,  2.5124
CVI Nigeria          6.9158, -6.9063   longitude sign flipped        ->  6.9158,  6.9063
…SAIMR, Johannesburg 33.9417, 18.4629  latitude sign flipped         -> -33.9417, 18.4629
```

So, per label, one of four answers:

| you think | what you do |
|---|---|
| the coordinate is right | `yes` on the "as it stands" row |
| the repair is right | `yes` on the repair row |
| both are wrong and you know the right one | type your numbers into `latitude` (H) and `longitude` (I) on either row, link in `your_note` (M), `yes` in A |
| both are wrong and you do not know yet | `no` on every row for that label. Status becomes `rejected - needs a new coordinate` and it stays in front of you |

The usual rule applies: one `yes` per label, and the script stops rather than pick for you.

### When the coordinate is right but keeps being flagged

The sweep tests geography, not status, so a coordinate that is genuinely where it should be
but disagrees with the label's country comes back every run. Two of the 15 were like that,
and both now carry an `accept_as_is` decision, which the sweep honours:

- **`SIPPE CAS United States`** — the point is Shanghai and correct. The affiliation is
  `Shanghai Institute of Plant Physiology and Ecology, Shanghai, China Indiana University,
  United States of America`, one string naming two institutions in two countries, so the
  label says United States. A label problem, not a coordinate one.
- **`One World Development Group, Florida`** — Gainesville, and fine. Flagged only because
  "Florida" is not a country the parser knows.

To silence one for good, give it an `accept_as_is` line in `data/affiliation_decisions.csv`
(hand-written, RStudio):

```
accept_as_is,SIPPE CAS United States,,,,coordinate is Shanghai and correct; the label is the problem,2026-09-10
```

The sweep honours `accept_as_is` and `note_only` and says how many it skipped.

A third, **`UMU Sweden`**, is correct and needs nothing: it is only listed because
`UNHCR Sudan` carries the identical point. Fix that and this clears.

### The rest of the 15

Seven need a coordinate looked up. The affiliation says where each belongs:

```
IRD Cameroon        17 rows  Yaoundé            442 km out, currently in Nigeria
MoH Cameroon         5 rows  Yaoundé            624 km out, currently in Nigeria
ISCII Equatorial Guinea 2    Bata              4269 km out, currently Madrid
IPG France           1 row   Cayenne, Guyane   7068 km out, currently Institut Pasteur Paris
INSP Guinea          1 row   Conakry           4181 km out, currently Paris
UNHCR Sudan          1 row   Khartoum          5455 km out, currently Umeå
Parasitology Dept…Dakar  1   Dakar             restoring the dropped leading 1 still leaves
                                               67 km, in the Atlantic - longitude is wrong too
```

And one is a geocoder trap rather than an arithmetic error: **`CIRAD Benin`** at
6.4039, 5.6169 is 7.8 km from **Benin City, Nigeria** and 357 km from Cotonou. "Benin" was
resolved to the Nigerian city, not the country.

### The error classes the sweep knows

- latitude sign flipped for southern-hemisphere cities
- a leading digit lost from latitude
- longitude sign flipped
- a coordinate copied verbatim from an adjacent unrelated label (`UNHCR Sudan` = Umeå)
- the sovereign's capital instead of the overseas territory the affiliation names —
  `IPG France` is "Pasteur Institute of Guyana, Cayenne, France" carrying a coordinate in
  Paris

That last class was invisible until 2026-09-08. Folding an overseas territory into its
sovereign is what stops an institute in Saint-Denis de La Réunion reading as 9,000 km
wrong, but it also hid a point that is in France and nowhere near Cayenne. The sweep now
carries a curated list of territory names and principal cities — Guyane / Cayenne / Kourou,
Réunion, Guadeloupe, Martinique, Mayotte, New Caledonia, French Polynesia, Puerto Rico,
Guam, Hong Kong, Macau, Greenland — and when the text names one of them, the coordinate is
checked against **that territory** rather than its sovereign. `Saint-Denis` on its own and
bare `Guyana` are deliberately not in the list: most Saint-Denis addresses are the Paris
suburb, and Guyana is a country in its own right.

**Its blind spot is right country, wrong place.** The `LIN` labels sat 98 km from
Montpellier and passed it clean. `One World Development Group, Florida` names no country at
all and cannot be tested.

The sweep is read-only and idempotent, and reads `output/final/affiliation_simple_coords.csv`. Re-run it
after any batch of merges, then re-run `coord_review.R` to refresh the open rows.

---

## Step 3 — spot-checks — done

- **`output/review_us_uk_tokens.csv`, 21 rows.** The case of the original (`us` / `US` /
  `usa`) is not recoverable from the string and was inferred. `Museum`, `Campus`, `KNUST`,
  `USTTB`, `Skukuza`, `Infectieuses` all look right, but confirm.
- **`output/review_encoding_repairs.csv`, 411 rows.** Skim for anything that looks worse
  after repair than before. Grep it; do not `cat` it.
- **`output/review_labels_collapsed.csv`, 8 rows.** In particular `ORSTOM Sénégal` →
  `ORSTOM Senegal` was chosen by frequency (12 rows against 1), not by correctness.

---

## Step 4 — a paper version 3 never covered — done 2026-09-10

`output/review_unmatched_sources.csv` had one row since August: Diop et al. 2002, *Role of
Anopheles melas … in a mangrove swamp in Saloum (Senegal)*, Parasite 9(3):239-46. Its
`row_xlsx` was empty, which is the point — the paper is in `twatasha_todo.csv` but is not in
the version 3 spreadsheet at all. No decision type can fix that: they all modify rows that
exist.

**`data/added_affiliations.csv`** is the mechanism.

```
source_citation, affiliation, affiliation_simple, note, added_on
```

Rows here are appended to the version 3 frame as it loads, before anything else runs, so
they go through encoding repair, the `n` re-key, labelling, decisions and the coordinate
loop exactly like a spreadsheet row. `row_xlsx` from **90001** up marks a row as coming
from this file rather than a spreadsheet row, which keeps the change log honest. The source
spreadsheet is not touched, so it stays the artefact it was delivered as.

`source_citation` must be byte-identical to the `twatasha_todo.csv` value — copy it from
`review_unmatched_sources.csv`. Leave `n` out of it; it is re-keyed from
`twatasha_todo.csv` like every other row.

Two assertions in `verify_affiliations.py` count off the spreadsheet and were taught about
these rows: the deliverable-1 row count is now `1273 + added`, and the coverage check is
`541 + added of 542`. Adding a row without teaching verify fails the run, which is what you
want.

The five affiliations of Diop et al. 2002 went in on 2026-09-10, `n = 105` picked up
automatically from the todo file:

```
Laboratoire de Paludologie, IRD, BP 1386, Dakar                      -> IRD Senegal
Département de Biologie Animale, FST, Université C.A. Diop           -> UCAD Senegal
Laboratoire de Zoologie Médicale, IRD, BP 1386, Dakar                -> IRD Senegal
Service National de Lutte Anti-Parasitaire, BP-SLAP, Thiès           -> SNLAP Senegal  (new)
Service de Parasitologie, Faculté de Médecine et de Pharmacie, UCAD  -> UCAD Senegal
```

The labels are editable in that file if any is wrong — change the cell and rebuild.
`review_unmatched_sources.csv` is now empty and all 542 todo sources are represented.

---

## Step 5 — affiliations the source recorded as ABSENT — done 2026-09-11

All 58 papers answered, 89 rows in the sheet: 35 papers now have real affiliations and 23
are confirmed `ABSENT`, which is why deliverable 1 still has 23 `ABSENT` rows.

**The first build after it was wrong, and verify passed it.** 23 of the 59 placeholders —
over 22 papers — survived beside the affiliations that replaced them, because the drop
matched the spreadsheet's raw citation text before the re-key, and verify worked out its
expectation the same way. Fixed 2026-09-11: the drop now runs after the re-key, and verify
matches citations independently and asserts directly that no supplied paper keeps a
placeholder (the 42nd check). Details in `CLAUDE.md`, under **Replacing an affiliation the
source recorded as ABSENT**.

**A second bug, found 2026-09-17, and verify passed that one too.** `R/absent_review.R`
decided which rows of `added_affiliations.csv` belonged to its sheet from the papers
deliverable 1 still showed as `ABSENT`. Once a rebuild had dropped a supplied paper's
placeholders, that paper no longer qualified, so its rows were kept as someone else's *and*
written again from the sheet: 66 duplicate rows per run, for the 35 papers given real
affiliations (the 23 still `ABSENT` kept qualifying). One run on 2026-09-16 put them in the
deliverable — 1374 rows, not 1308 — and the extra `MOH Nigeria` row won the formatting-only
collapse against `MoH Nigeria`. The script now treats every paper in its sheet as its own
(`R/absent_review.R:153`), so blanking an answer also undoes it now, and it fills `n` and
the search link from the citation, which the 66 answered rows had lost. Verify's 43rd check
compares the additions file with the sheet directly: each answer as many times as the sheet
holds it. Tested on a sandbox copy first: the current file failed the check (66 extra rows
over 35 papers), the fixed script took it to 94 rows, a second run changed nothing, and
the rebuild was the old deliverable minus exactly the 66 earlier copies.

How it was done, for the record:

59 rows of deliverable 1 carry `affiliation = ABSENT`, over 58 papers — whoever entered
them could not find an affiliation. 55 of those papers are ABSENT and nothing else; three
have real affiliations alongside a placeholder.

```bash
Rscript R/absent_review.R          # builds data/absent_review.xlsx
# open it, type the affiliation and its label, save
Rscript R/absent_review.R          # answers -> data/added_affiliations.csv
python3 R/tidy_affiliations.py && python3 R/verify_affiliations.py
```

One row per ABSENT row, open ones first. **Two columns are yours:**

| column | |
|---|---|
| **A `affiliation`** | the affiliation as published. Leave blank to skip the paper for now |
| **B `affiliation_simple`** | the short label |

The rest is context: `source_citation`, `n` (occurrence records for the paper),
`other_labels_on_this_paper` for the three mixed cases, and **`find_the_paper`**, a Google
Scholar search link built from the title so you can pull the paper up in one click.

**One paper, several affiliations:** copy the whole row, paste it below, change the
affiliation. Any row carrying a citation and an affiliation is read, so nothing caps how
many a paper can have. Do not retype the citation — copy it, or the run stops and tells you
which one does not match.

**The label decides what happens next.** An existing `affiliation_simple` folds the paper
into that label and it inherits that label's coordinate. A new one creates a new label,
which then wants a coordinate: it appears in `coord_review.xlsx` as a `needs a coordinate`
row on the next run, and `absent_review.R` names every new label it sees as it writes.

**The ABSENT row is dropped for you.** Once a paper has real affiliations in
`added_affiliations.csv`, `tidy_affiliations.py` removes that paper's ABSENT placeholders —
otherwise the paper would read as both known and unknown. The three papers that have real
affiliations as well as a placeholder keep the real ones.

Nothing is written by hand: the sheet owns the rows of `data/added_affiliations.csv` whose
citation is one of the 58 papers, and passes every other row through, which is why the five
Diop et al. 2002 affiliations from step 4 sit in the same file untouched.

Verify was taught about row removal rather than loosened — the deliverable-1 count is
`1273 + added - replaced`, the drift check compares against surviving rows rather than raw
positions, and the coverage check now asserts that every todo source is represented instead
of counting from 541.

---

## Step 6 — coordinates the source recorded as ABSENT — done 2026-09-16

**All 12 are answered: 10 given a coordinate, 2 left `absent` and signed off.** Several of
the 10 are city centroids and say so in their note. The two sign-offs are `LRP Cameroon`
(20 records, "can't be found; country level too coarse to usefully assign") and `Mission
for the Prevention and Fight against Vector Endemics, Réunion, France` (68 records,
"Reunion too coarse to assign locale"). Deliverable 3 was then 169 `ok`, 137 `decided`,
3 `absent` and the sanity sweep checked 306, flagging 0; the step-7 merge took it to 308
labels, 168 `ok`, and 305 swept. What the new coordinates raised is a
label question — step 7.

Deliverable 3 has **13 labels with `coord_status = absent`**. One is the label `ABSENT`
itself — the 23 papers step 5 confirmed have no findable affiliation — and it stays as it
is: no affiliation, so no coordinate. **The other 12 are real institutions.** Each names a
place, each carries one row of deliverable 1, and between them they carry **337 occurrence
records**.

`absent` means only that the round-1 coordinate file had `ABSENT` in its latitude and
longitude cells. It does not mean no coordinate exists. Nobody has been through them.

| label | records | the place its affiliation names |
|---|---|---|
| `Mission for the Prevention and Fight against Vector Endemics, Réunion, France` | 68 | Réunion — the affiliation text itself says only "France" |
| `DRASS France` | 64 | "Regional Directorate of Health and Social Affairs, Vector Control Service, Saint-Denis de La Réunion" |
| `Department of Parasitology-Medical and Molecular Mycology, Faculty of Medicine of Grenoble, La Tronche, France` | 56 | La Tronche, Grenoble |
| `Division of Environmental Hygiene and Sanitation, N'Djamena Chad` | 34 | N'Djamena |
| `Medical Entomology Department, French Cooperation Mission, Kinshasa, Zaire.` | 32 | Kinshasa, then Zaire, now DR Congo |
| `Laboratoire de Biologie des Invertébrés, I.N.R.A., Antibes, France` | 24 | Antibes |
| `LRP Cameroon` | 20 | "Laboratoire de Recherche sur le Paludisme, Cameroon" — **names no city**; this one needs the paper |
| `BMC-series Journals, BioMed Central, Middlesex House, Cleveland Street, London, UK` | 12 | London — but this is the **publisher's** address, not a research centre |
| `Centro Hispano-Guineano de Enfermedades Tropicales, Malabo, Equatorial Guinea` | 12 | Malabo |
| `Project CIBP/MEAVSB, Garoua, Cameroon` | 6 | Garoua |
| `Laboratory of Bio-Pedology, Dakar, Senegal` | 5 | Dakar |
| `National Center for the Fight against Malaria, Ouagadougou, Burkina Faso` | 4 | Ouagadougou |

### Why none of this ever reached a sheet

- **`coord_review.xlsx` never offered them.** Its catch-all `needs a coordinate` rows were
  built from `coord_status == "missing"` only, and these are `absent`. Fixed 2026-09-15.
- **The sanity sweep cannot see them.** `R/check_coord_sanity.R` sweeps coordinate-bearing
  labels, so a label with no coordinate is invisible to it. Its `0 flagged` says nothing
  about these 12 until each has a coordinate.
- **The 88 researched proposals predate them.** None of the 12 is in
  `output/proposed_coords_missing88_20260818.csv`, so every one needs looking up.

### The loop — built 2026-09-15

Tested end to end on a sandbox copy before it touched the real sheet: the rows appear, a
typed coordinate becomes a `coordinate` decision, the rebuild marks the label `decided`,
verify passes, the next run drops the row, and the sweep then checks the label.

1. The orphan filter, `R/coord_review.R:241`, takes `absent` as well as `missing`. It leaves
   out the label `ABSENT` itself, and any label signed off with `accept_as_is` or
   `note_only`, naming each one it leaves out on every run. The 12 arrive as open
   `needs a coordinate` rows with empty `latitude`/`longitude`; `geocoder_notes` says the
   round-1 file recorded ABSENT.
2. The merged-away guard (`R/coord_review.R:277`) keeps them: all 12 are in deliverable 2
   under their exact label, and no two labels share a `join_key`. Run on the same inputs,
   the committed script and the edited one write a byte-identical decisions file, and their
   sheets differ only by the 12 rows.
3. No pipeline change was needed. `tidy_affiliations.py` gives these 12 `absent` at line
   519, from the ABSENT cells of their source rows (line 557 does it only for the label
   `ABSENT`), and applies `coordinate` decisions after both, at line 580, so a decision
   wins and the label becomes `decided`. Confirmed in the sandbox.
4. Typed input the sheet cannot keep is no longer lost without a word. Anything in H or I
   that is not a number (`14,7`, both numbers in one cell) stops the run with nothing
   written; a U+2212 minus sign is read as `-`. A coordinate typed without `yes`, or an
   answer or note on a row with no coordinate, is named under `!!` at the end of the run.
5. **`absent` in column A signs a label off** (added 2026-09-16, when the question came up
   with five of the 12 answered): the run appends an `accept_as_is` decision carrying the
   reason from `your_note`, and the label stops being offered. Sign-offs are appended,
   never rewritten, so the five hand-written ones — and any of these — stay as they are;
   undoing one means taking the line out of the file deliberately. `absent` on a row that
   carries a coordinate stops the run, as does a label typed into C that is not in the
   deliverables (named, not written).

First real run, 2026-09-15: 192 rows over 139 labels, **12 open**, 127 settled. The
decisions file kept the same 247 rows; the coordinate rows moved to the end of the file,
which the committed script does too.

```bash
Rscript R/coord_review.R          # the 12 appear as open rows
# type latitude (H), longitude (I), the link in your_note (M), yes in A; save; close
Rscript R/coord_review.R          # answers -> data/affiliation_decisions.csv
python3 R/tidy_affiliations.py && python3 R/verify_affiliations.py
Rscript R/check_coord_sanity.R    # now that they have coordinates, they get swept too
```

### Three answers are possible per label, and they are the owner's

- **A coordinate**, typed into the sheet as above.
- **A merge**, if the institution already has a label — that is `label_review.xlsx`, not the
  coordinate sheet, and it is worth settling before geocoding anything.
- **Left `absent`**: put `absent` in column A of its row, with the reason in `your_note`
  (M). The run appends an `accept_as_is` decision for that label, and from the next run on
  it is no longer offered — each run names it instead. `no` does not do this: there is no
  coordinate on the row to reject, and the run names it under `!!`. Sign-offs are appended
  and never rewritten, so undoing one means taking the line out of the file deliberately.
  The `BMC-series Journals` row is the obvious candidate: it is BioMed Central's own
  address in London, not a place any fieldwork was done.

### Three things to check before geocoding, none of them decided

- **`DRASS France` and the label `Vector Control Service, Regional Directorate of Health and
  Social Affairs, Saint-Denis de La Réunion, France`** (`ok`, 1 row, −20.8828812, 55.4579987)
  are the same words in a different order. The second already has a Réunion coordinate.
- **`Mission for the Prevention and Fight against Vector Endemics, Réunion, France`** is
  Réunion vector control too, and may or may not be that same service under another name.
- **`National Center for the Fight against Malaria, Ouagadougou, Burkina Faso`** against
  **`CNRFP Burkina Faso`** (`decided`, 15 rows, 12.349733, −1.4903285, Ouagadougou). On
  2026-09-11 the label `National Center for the Fight against Malaria Burkina Faso` — the
  same name without "Ouagadougou" — was merged into `CNRFP Burkina Faso`, so there is a
  precedent, but the French names differ: *lutte contre le paludisme* is a control
  programme, *recherche et de formation sur le paludisme* is the research centre.
  `check_label_candidates.R` does not raise this pair.
- A trap, not a candidate: `Department of Parasitology-Medical and Molecular Mycology …
  Grenoble` and `Department of Parasitology-Mycology, Faculty of Medicine, University of
  Health Sciences, Libreville, Gabon` have nearly the same name and are 5,000 km apart. Do
  not merge them.

---

## Step 7 — two label pairs the step-6 coordinates raised — done 2026-09-16

**Both are answered.** The `CREC` pair was rejected; `DRASS France` and the Saint-Denis
`Vector Control Service` label were **merged into a new label, `DRASS Reunion`** — 2 rows,
80 records, `decided` at -20.9006092, 55.4874248, which is DRASS's own point and the one
the merge kept. The sweep is back to 58 pairs, all answered. What was in front of the
decision:

| label | rows | records | coordinate | status |
|---|---|---|---|---|
| `Centro Hispano-Guineano de Enfermedades Tropicales, Malabo, Equatorial Guinea` | 1 | 12 | 3.7552718, 8.7828719 | `decided` |
| `CREC Equatorial Guinea` | 1 | 1 | 3.7555560, 8.7816670 | `decided` |

0.14 km apart, which the sweep calls `same_point`.

| label | rows | records | coordinate | status |
|---|---|---|---|---|
| `DRASS France` | 1 | 64 | -20.9006092, 55.4874248 | `decided` |
| `Vector Control Service, Regional Directorate of Health and Social Affairs, Saint-Denis de La Réunion, France` | 1 | 16 | -20.8828812, 55.4579987 | `ok` |

3.64 km apart, sharing the phrase "vector control service".

A third pair the sweep still does **not** raise, flagged before the geocoding and unchanged
by it: `National Center for the Fight against Malaria, Ouagadougou, Burkina Faso` (1 row, 4
records, 12.3642904, -1.5050645) and `CNRFP Burkina Faso` (15 rows, 822 records, 12.349733,
-1.4903285) are 2.3 km apart. *Lutte contre le paludisme* is a control programme and
*recherche et de formation sur le paludisme* is the research centre, so the French names
differ; the same name without "Ouagadougou" was merged into `CNRFP Burkina Faso` on
2026-09-11.

### Creating a label that does not exist yet — added 2026-09-16

`keep` (C) refuses a name that is not already a label, because an unknown name there is far
more often a typo, and a typo would rename real labels into something nobody meant. To
create one deliberately, write it **`new: DRASS Reunion`**: both of the row's labels merge
into a new label of that name, the run says `new label created by this run`, and the prefix
is stripped from the sheet afterwards. A `new:` name that `join_key()` resolves to an
existing label is refused — two labels sharing a key make every `coordinate` decision for
either of them ambiguous. Before this the only way was a hand-written `label_rename`, which
is how `MIVEGEC / CIRAD / LIN Montpellier` was made in September.

**A merge takes the coordinate decision with it, in one pass.** `label_review.R` retargets
the ticked row in `coord_review.xlsx` (`DRASS France` → `DRASS Reunion`), and
`coord_review.R` rewrites the decision to the new name. The old decision used to survive
beside the new one — the deliverables are a snapshot from before the rename, so the guard
read the label as still live — and the build ended `42 checks, 2 failed`, clearing only on a
second run. A coordinate decision whose label a `label_rename` in the same file is about to
take away is now dropped in the same pass.

```bash
Rscript R/label_review.R          # the pairs appear in data/label_review.xlsx
# tick A, set keep (C), read the warning column, save, close
Rscript R/label_review.R          # answers -> data/affiliation_decisions.csv
Rscript R/coord_review.R          # re-emit the coordinate rows
python3 R/tidy_affiliations.py && python3 R/verify_affiliations.py
```

A merge keeps the survivor's coordinate and drops the other, and renames the label inside
the coordinate source files too — the `warning` column in the sheet says what each one
does. Step 1 has the detail.

---

## Step 8 — Gia's lake-region data — built and answered 2026-09-17; closing runs left

**Answered 2026-09-17**: 21 of the 51 pairs accepted (20 renames), 30 rejected, 31
coordinate decisions, rebuilt at 15:30. The closing runs, and two answers to confirm, are at
the top of **Where this is up to**. The rest of this step is the record of how it was built.

`data/gia_final_data/` holds Gia's lake-region affiliations
(`lake_region_source_affiliations_africa.csv`, the shape of deliverable 1: 338 rows, 211
papers, 40 labels) and her coordinates (`lake_region_source_counts.csv`, the shape of
deliverable 3: 39 labels). **They are in the deliverables, each row under her own label.
Nothing of hers is matched with an existing label, and none of her coordinates is checked.
That is yours, in the two sheets:**

| sheet | open | what |
|---|---|---|
| `label_review.xlsx` | 51 pairs | 37 set one of her labels against an existing one, 14 are two of hers raised on ordinary evidence. Column Y `lake` says which side is hers |
| `coord_review.xlsx` | 39 labels | 37 of her points as they stand (`case = lake`: yes means checked, and the label becomes `decided`); `ILRAD Nairobi Kenya` offered the point her counts file gives `ILRI Nairobi Kenya`; `Ifakara Centre Ifakara Tanzania` with no candidate at all |

**`no` on one of her points does not remove it.** The label stays `ok` with her point in the
deliverable, marked `rejected - needs a new coordinate`, and stays in front of you until you
tick a coordinate or type your own into H and I with `yes`, as for a sanity suspect in step 2.
Nothing in either sheet can take a coordinate away from a label that has one: `absent` on a
row that carries a coordinate stops the run, and clearing H and I first only appends an
`accept_as_is`, which leaves the point where it is. If one of her labels should end up with no
coordinate at all, that needs building.

**Answer the merges first.** A merge decides which coordinate survives, so a point of hers
checked before its label is merged into a `decided` one is thrown away by the merge.

```bash
# label_review.xlsx: yes/no in A, keep in C, read the warning in Q; save; close
Rscript R/label_review.R          # answers -> label_rename rows; patches coord_review.xlsx
Rscript R/coord_review.R
python3 R/tidy_affiliations.py && python3 R/verify_affiliations.py
Rscript R/coord_review.R          # second pass: merged labels' rows go, new conflicts appear
# coord_review.xlsx: yes/no in A (or your own numbers in H and I); save; close
Rscript R/coord_review.R
python3 R/tidy_affiliations.py && python3 R/verify_affiliations.py
```

A merge of an `ok` label into one of hers with a different point makes a `conflict`: both
points appear in `coord_review.xlsx` and you pick one, as for any conflict. Tested on a
sandbox copy with `UVRI Uganda` into `UVRI Entebbe Uganda`, 0.28 km apart.

### What to know before answering — facts, not recommendations

- Some of her points are nowhere near the town their label names, and the sanity sweep, which
  tests only the country, passes them: `MasenoU Maseno Kenya` is in Nairobi (276 km from
  `MU Kenya`'s point), `MTTI Kendu Bay Kenya` is in Mombasa, `ICIPE Nairobi Kenya` is near
  Homa Bay (32 km from `ICIPE Kenya`), and `NLRRI Tororo Uganda` is 173 km from Tororo, 0.26 km
  from `NaLIRRI Uganda`. Read coordinate evidence for these pairs against the text.
- `KEMRI Kenya` and `KEMRI Nairobi Kenya` are 112 km apart.
- One of her rows carries exactly the string a 2026-09-04 `affiliation_relabel` sends to
  `IHI Ifakara` ("Ifakara Health Institute, Mlabani Passage, Ifakara, Tanzania"). A relabel
  written for spreadsheet rows does not move hers, so the row stays under
  `IHI Ifakara Tanzania`, every rebuild names it, and the pair is open in the sheet with
  `shared_affiliation` evidence. Merge them and the message stops.
- `Ifakara Centre Ifakara Tanzania` is the label the `Centre` find-and-replace damaged: 22
  rows in her file, 21 in the deliverable (one repeated an existing row on Fillinger et al.).
  Her counts file gave `IHI Ifakara Tanzania` n = 24, which is that label's 2 rows plus these
  22. It has no coordinate of its own.
- Three rows of hers on papers already present are the same institution as an existing row,
  worded differently, and were added, because only the same text is dropped: NLRRI on Ramphul
  et al. 2009, ICIPE Mbita on Scholte et al., the Ifakara centre on Geissbühler et al.
  `output/review_lake_overlap.csv` lists all 12 rows on the 7 shared papers.
- Her point for `MAFS Dar es Salaam Tanzania` is unused: its only row repeated an existing
  one on Fillinger et al. and was dropped, and no label without a coordinate ends in the same
  words. `coord_review.R` names it on every run.

### How her rows are handled

**Rows** (`R/tidy_affiliations.py`). Loaded after the additions, `row_xlsx` 50001 up, through
the same repair, whitespace, collapse and decision steps as every other row.
- **Citations.** A citation of hers on `twatasha_todo.csv` resolves to it with the existing
  resolver, and n comes from the todo file: 7 papers, 3 exact (Besansky's n becomes 57, not
  her 34) and 4 through the mojibake key. The other 204 are new: citation byte-identical as
  she delivered it, n from her file. **`vector_extraction_data.csv` is not read**:
  `R/sources_to_check.R:35` built the todo list with a `left_join` on (source_citation, n), so
  a paper of hers not on it had already matched the occurrence records on both. One of the
  204, a Geissbühler et al. paper, keeps `Geissb√ºhler` because that is the text it matched.
- **Two repairs, her rows only, logged.** `IHI Ifakara Tanzania` inside a longer cell becomes
  `Centre` again: 148 affiliations, 22 labels. As a whole cell it is a genuine label and is
  left. One `Ð` becomes `–`. `output/review_lake_repairs.csv` lists every reading in context
  ("International Centre of Insect", ×26). Centre or Center cannot be recovered.
- **Papers already present.** A row of hers is dropped when its paper already carries the
  same affiliation under `key()`: 6 dropped, 6 added.
- **Coordinates.** Her counts file (longitude, then latitude, read by name) is a third source,
  after the two original files. A label they left without a coordinate takes her point; a
  label they resolved that has a different point of hers becomes a `conflict`. Until a merge
  shares a label, no key is shared, so nothing existing moved: all 308 earlier rows of
  deliverable 3 and the first 1308 rows of deliverable 1 were byte-identical.
  `output/review_lake_counts.csv` names her unused points (`ILRI`, `MAFS`), her labels without
  a coordinate, and the n = 24 above.
- **Without `data/gia_final_data/`** the build is byte-identical to the one before step 8,
  and verify runs 43 checks.
- `output/label_sources.csv` counts rows per label and how many are hers, for the sweep and
  the sheet.

**The label sweep** (`R/check_label_candidates.R`) adds three kinds of evidence, only for a
pair with her rows on one side and other rows on the other: `same_acronym` (the same leading
acronym, dropped when the two name different countries), `shared_affiliation` also from her
dropped rows, and `near_point` allowed on its own. 109 pairs: the 58 earlier ones unchanged
except `IHI Dar es Salaam` / `IHI Ifakara`, whose phrase is now under three labels
(`shared_phrase_only2` became `shared_phrase`; the pair was already answered); 37 of hers
against existing labels, 12 of them raised only by the new evidence; 14 of hers against each
other.

**`R/label_review.R`** has column Y `lake`, and its warning is corrected. When the label
merged away is `decided` and the survivor is `ok`, section 7 retargets your coordinate onto
the survivor, so the warning now says `the coordinate you chose follows the merge; the
survivor's own point is discarded`. It used to say `discards a coordinate you chose`. Ten rows
carry the corrected wording: nine already answered, and the open pair of the long-form Kisumu
label with `KEMRI Kisumu Kenya`. The run's map link now points at the point actually discarded.

**`R/coord_review.R`** builds the `case = lake` rows above, and a ticked row that later turns
`manual` keeps the note already on record. Without that, a checked point of hers lost
`source: lake_region_source_counts.csv` on the second pass.

**`R/verify_affiliations.py`: 49 checks.** Changed, computed independently of tidy: the row
count (`1273 + added − replaced + lake − already on their paper`), citations verbatim in the
todo list or her own file, n, the mojibake check exempting her 204 citations as delivered, the
relabel check on non-lake rows, the non-null counts. New: every paper of hers represented;
her rows once each, less those already on their paper (as a multiset, so a lost row and a
duplicate both fail); no `IHI Ifakara Tanzania` left inside a longer cell; no `Ð`; her points
verbatim on every live, undecided label; 20 random rows of hers unchanged apart from the
repairs. Each was made to fail in a sandbox by the fault it guards against. **What verify
cannot see: a citation Gia herself mistyped among the 204.** Nothing independent holds those
bytes without reading the extraction data.

### Tested before it touched the project

On sandbox copies, in the order the real run used: rebuild, both sweeps, `label_review.R`,
`coord_review.R`. Then five answers typed in with openpyxl, in two batches, each followed by
the loop twice, verify 49/0 every time: her `IHI Ifakara Tanzania` into the `decided`
`IHI Ifakara` (6 rows, your coordinate kept); `UVRI Uganda` into her `UVRI Entebbe Uganda` (a
conflict, then one point ticked); her `KEMRI Kisumu Kenya` kept over the `decided` long-form
Kisumu label (the corrected warning, your coordinate followed the merge); the `ILRI` point
ticked for `ILRAD`; one of her points ticked as checked. With no answers, `label_review.R` then
`coord_review.R` leave the decisions file with the same 261 rows; only the order of the two
`DRASS Reunion` renames changes, which the committed script did too.

**The deliverables also lost their `_20260817` stamp** on 2026-09-17, first and on its own:
the sandbox rebuild was byte-identical under the new names, old and new R scripts wrote
identical outputs, and the dated files were deleted after `cmp` on the project.

---

## After every change — rebuild and read the output

**Save and close the sheet before running its script.** Each `*_review.R` rewrites its own
xlsx every run; if Excel still has it open, the script reads the on-disk version without
your unsaved edit and then overwrites the file. The edit vanishes with no error. Type →
save → close → run.


```bash
python3 R/tidy_affiliations.py      # rebuild all three deliverables
python3 R/verify_affiliations.py    # assertions; exits non-zero on failure
```

The rebuild prints `N decisions applied`, or shouts `!! N decision(s) did NOT apply` and
names them. **A decision that did not apply is almost always a mistyped target**;
`output/decisions_report.csv` says which. `verify` fails the run on any of them, which is
the guard against a silent no-op.

`verify` runs 36 checks with an empty decisions file, 41 once it holds anything, 43 once
`data/added_affiliations.csv` holds rows, and 49 once `data/gia_final_data/` is present. The
extra five confirm your decisions landed; the 42nd confirms every replaced placeholder is
gone; the 43rd that the additions file holds each `absent_review.xlsx` answer as often as the
sheet does; the last six check Gia's rows (step 8). A rise from 36 to 41 to 43 to 49 is
expected, not a regression.

---

## Reference

### The decision types, and who writes them

`data/affiliation_decisions.csv` — header
`decision_type,target,new_value,latitude,longitude,note,decided_on`.

| decision_type | written by | effect |
|---|---|---|
| `label_rename` | **`R/label_review.R`**, from `data/label_review.xlsx` | renames everywhere; renaming A to B merges them |
| `coordinate` | **`R/coord_review.R`**, from `data/coord_review.xlsx` | overrides the source files; sets `coord_status = decided` |
| `affiliation_relabel` | you, in the CSV | moves one affiliation string onto a different label |
| `token_replacement` | you, in the CSV | overrides an inferred us/uk expansion |
| `accept_as_is` | you, in the CSV; or **`R/coord_review.R`**, appended from `absent` in column A of `coord_review.xlsx` | marks `reviewed = TRUE`; changes nothing. For a label with no coordinate it is the sign-off that keeps it that way |
| `note_only` | you, in the CSV | records a note; marks reviewed |

The two scripts each rewrite their own decision type and pass every other row through
untouched. The file is optional: absent or header-only, the pipeline reproduces the baseline
outputs byte-for-byte. `data/affiliation_decisions_EXAMPLE.csv` shows every type in use and
is illustrative — do not copy it into place.

### The coordinate loop — finished, kept for when a merge needs it

```bash
Rscript R/coord_review.R          # build/refresh data/coord_review.xlsx
# open the sheet, fill column A with yes/no, save
Rscript R/coord_review.R          # answers -> data/affiliation_decisions.csv
```

At 2026-09-17 it holds 176 labels: 137 settled, and 39 open from Gia's data (step 8). One
row per *candidate* coordinate; a label with two
competing coordinates gets a row each, and two yeses for one label is an error that stops
the script rather than letting it pick for you.

Only six cells are read back: `accepted` (A — `yes`, `no`, `absent` or blank),
`affiliation_simple` (C), `latitude` (H), `longitude` (I), `your_note` (M), `decided_on`
(N). To supply your own coordinate, type the numbers into H and I and put the link in M.
To leave a label without one, put `absent` in A and the reason in M.

**A label the sheet does not offer** — one created by a merge, an `ok` label, or an
`absent` one already signed off — has no row, so there is nothing to tick. (Unsigned
`absent` labels have been offered since 2026-09-15.) Type the label into column C with your
coordinates in H and I and `yes` in A; it becomes a `case = manual` row. `U Nijmegen` was
settled this way on 2026-09-07.

**Blanking column A is the only way to kill a coordinate decision; deleting it from the CSV
is not.** A ticked row whose label has left the candidate list is reclassified to
`case = manual`, which is exempt from the merged-away guard, so the dead decision is
written straight back on the next run. This cost a `41 checks, 2 failed` on 2026-09-04
(`CIRAD France`, `MIVEGEC France`); cleared 2026-09-07.

The sheet is `.xlsx`, not `.csv`, deliberately. Excel round-trips xlsx as UTF-8 without
touching the accents, so `coord_review.xlsx` and `label_review.xlsx` are the only two
project files it is safe to open and save. Verified on `São Tomé`, `Côte d'Ivoire`, `Allé`.
Rule 1 in `CLAUDE.md` still applies to every CSV.

**Never overwrite `data/affiliation_decisions.csv` — only add to it.** It is the record of
every change (rule 2 in `CLAUDE.md`). So never run the old bulk-adopt path,
`cp output/proposed_decisions_coords.csv data/affiliation_decisions.csv`, which
`GEOCODING_NOTES.md` used to recommend: it would replace every decision in the file with 88
proposals.

### The review files at a glance — counts at 2026-09-17

| file | rows | what it is | answer goes |
|---|---|---|---|
| `review_label_duplicates.csv` | 109 | two labels that may be one place | `label_review.xlsx` |
| `review_label_lumping.csv` | 101 | one label that may be several places | `label_review.xlsx` or the CSV |
| `review_simple_conflicts.csv` | 10 | one string carrying two labels | `label_review.xlsx` |
| `review_simple_lumping.csv` | 157 | strings per label | `label_review.xlsx` or the CSV |
| `review_lake_repairs.csv` | 62 | every reading the `Centre` and `Ð` repairs to Gia's rows produced | nothing, unless wrong |
| `review_lake_overlap.csv` | 12 | Gia's rows on the 7 papers already present: dropped or added | `label_review.xlsx`, where it matters |
| `review_lake_counts.csv` | 6 | her unused points, her labels without a coordinate, her n against her rows | `coord_review.xlsx` |
| `review_coord_sanity.csv` | 0 | coordinate outside its country, or no country to test | `coord_review.xlsx`, or `accept_as_is` |
| `review_us_uk_tokens.csv` | 21 | inferred us/uk expansions | `token_replacement` |
| `review_encoding_repairs.csv` | 411 | every encoding repair made | nothing, unless wrong |
| `review_labels_collapsed.csv` | 9 | formatting-only label merges | nothing, unless wrong |
| `review_unmatched_sources.csv` | 0 | paper with no affiliation | `added_affiliations.csv` (step 4) |
| `decisions_report.csv` | 261 | did each decision apply? | read after every rebuild |

`review_simple_lumping.csv` has long pipe-joined cells and `review_encoding_repairs.csv` is
411 rows — grep them, do not `cat` them.

### Not tasks

`aff_audit_plan.md`, `AFFILIATION_CLEANING_README.md` and `GEOCODING_NOTES.md` are the
record of how the data got into this state. `review_missing_coords.csv` and
`proposed_decisions_coords.csv` are superseded by the sheets. `R/tidy_affiliations.R` has
never been run — use the Python.

---

## Notes worth keeping

### Decisions already made — do not undo

- **Group 3 of the `same_coord_group` list was deliberately kept separate.**
  `C/O.U.A., Zona Sanitaria s/n, Equatorial Guinea` and `EGMI Equatorial Guinea` are not
  known to be the same place. Do not re-merge them. The other nine groups are resolved,
  including the ten Bamako labels that are now `UB / USTTB Mali`.
- **`BRL Zimbabwe`'s 365 km coordinate spread is not an error.** Blair Research Laboratory
  is in Harare; the de Beers Research Laboratory is a separate field station at Chiredzi.
  Two sites, two correct coordinates, one label.
- **Standalone `US` → `United States` expansions were kept**, per instruction; only
  mid-word damage was reversed. The side effect is that `CDC USA` and `CDC United States`
  remain distinct spellings across files. The coordinate lookup treats them as one label
  by `join_key`; the deliverables do not merge them.
- **No typo was corrected automatically** beyond pure formatting — case, trailing
  punctuation, accents, one stray comma.

### Still wrong, not yet fixed

- **`United States.A.`** is `U.S.A.` with `US` expanded. The mid-word reversal missed it
  because the surrounding full stops are not word characters. Live at 2026-09-07 in 5
  affiliation strings, under `Bacilligen United States`, `ND United States`, `Norte Dame
  United States`, `UC United States` and `WRAIR United States`. The damage is in the
  affiliation text, not the labels. A `token_replacement` row was the proposed fix; it has
  not been tried.
- **The MRC Sierra Leone address in the project note is wrong.** "5 Frazier Davis Drive,
  Freetown" matches no affiliation in the corpus; the papers say P.O. Box 81, **Bo**.
- **About 30 `affiliation_simple` values are full affiliation text**, e.g. `Blair and de
  Beers Research Laboratories, P.O. Box 8105. Causeway. Zimbabwe`. They work as labels but
  are ugly. `label_review.xlsx` will let you rename them: they appear as one side of a
  pair, and `keep` takes whatever short label you type.

### Known soft spots

- `R/tidy_affiliations.R` has never been run. Treat its first execution as a test; if its
  self-test or parity check fails, the baseline CSVs in `output/parity_baseline/` are the trusted
  artefacts. R 4.6.1 is installed with `readxl`, `readr`, `dplyr`, `stringi`, `writexl`,
  `tidyr` and `countrycode`; `openxlsx` is absent.
- `pandas`, `xlrd` and `openpyxl` were installed 2026-09-03 and both Python steps run on
  this machine. Between 2026-08-24 and then they could not, which is why the R
  transcription exists.
- The `n` column was carried through from `twatasha_todo.csv` unchanged and is the count of
  occurrence records per paper, not per affiliation. Do not sum it across the affiliation
  rows of one paper.

### What the automated repair did — 2026-08-17

Logged cell by cell in `output/diff_report_20260817.csv`.

| | cells |
|---|---|
| encoding (two stacked corruptions) | 411 |
| `source_citation` re-keyed to `twatasha_todo.csv` | 396 |
| whitespace | 270 |
| mid-word `United States` / `United Kingdom` reversed | 62 |
| `n` re-keyed | 11 |
| blank continuation rows forward-filled | 11 |
| formatting-only duplicate labels collapsed | 13 |

Everything since has been a judgement call, recorded in `data/affiliation_decisions.csv`.
Nothing was decided unilaterally.
