# NEXT_STEPS.md — what is left, in order

Read `CLAUDE.md` first for the working rules — particularly the one about never saving a
project CSV out of Excel.

This file runs top to bottom. Steps 1 to 4 are the remaining work, in the order worth doing
it. Everything after **Reference** is background you do not need in order to finish.

---

## Where this is up to — 2026-09-10: finished

Every step is done. The build is clean — **233 decisions, all applying**, and `verify` ends
`41 checks, 0 failed`.

| | |
|---|---|
| deliverable 1 `affiliations_complete_*.csv` | 1278 rows — 1273 from the spreadsheet, 5 added |
| deliverable 2 `affiliation_lookup_*.csv` | 986 pairs |
| deliverable 3 `affiliation_simple_coords_*.csv` | 298 labels — 169 `ok`, 116 `decided`, 13 `absent` |

Nothing is `missing` and nothing is in `conflict`. The 13 `absent` are the round-1 source
file's own `ABSENT`. All 542 `twatasha_todo.csv` sources are represented;
`review_unmatched_sources.csv` is empty.

| step | | |
|---|---|---|
| — | environment | **done** 2026-09-03 |
| — | coordinates: every label settled | **done** 2026-09-07 |
| **1** | merge duplicate labels | **done** — 124 merges applied, 70 pairs rejected, none open |
| **2** | check the coordinates already there | **done** — 285 checked, 0 flagged, 2 signed off |
| **3** | spot-checks | **done** — reviewed, nothing changed |
| **4** | the paper version 3 never covered | **done** — 5 affiliations added, coordinate settled |

**The review files that are still not empty are records, not work:**

| file | rows | why it is not open work |
|---|---|---|
| `review_simple_conflicts.csv` | 2 | `IRD France` / `MIVEGEC / CIRAD / LIN Montpellier` and `IRD Cameroon` / `ORSTOM/ OCEAC Cameroon` — both pairs deliberately rejected in `label_review.xlsx` |
| `review_label_duplicates.csv` | 55 | every pair is answered in the sheet: 124 applied, 70 rejected, 0 open |
| `review_label_lumping.csv` | 84 | the granularity question, deliberately not pursued |
| `review_simple_lumping.csv` | 124 | the same question, older form |
| `review_us_uk_tokens.csv` | 21 | reviewed 2026-09-10, all 21 expansions correct |
| `review_labels_collapsed.csv` | 8 | reviewed 2026-09-10, left as they are |
| `review_coord_conflicts.csv` | 38 | raw conflicts in the source files, every one resolved by a `coordinate` decision |
| `review_coord_sanity.csv` | 0 | sweep flags nothing |

The steps below are kept as the record of how each was done, and because the loops still
work if a label or coordinate ever needs revisiting.

---

## Step 1 — merge duplicate labels

Some `affiliation_simple` values are the same place under different spellings. This is a
spreadsheet, exactly like coordinates were. **You never hand-write a decision line.**

```bash
Rscript R/label_review.R          # builds data/label_review.xlsx
# open it in Excel, put yes/no in column A, save
Rscript R/label_review.R          # answers -> data/affiliation_decisions.csv
Rscript R/coord_review.R          # re-emit the coordinate rows
python3 R/tidy_affiliations.py && python3 R/verify_affiliations.py
```

200 rows, one per candidate pair — two labels that may be one place — open first and
worst-first. 153 open, 47 already applied. **Two columns are yours:**

| column | |
|---|---|
| **A `accepted`** | `yes`, `no`, or blank. `y` / `x` / `1` also read as yes |
| **C `keep`** | the label that survives. Filled in with a guess — retype it to change the answer |
| **F `group`** | the cluster this pair belongs to. Not editable; see below |
| **Q `warning`** | read this before you tick. See below |

`keep` does **not** have to be one of the two labels on the row. Name any label and both of
the row's labels merge into it, so *"these three are one place, keep the third"* is one yes
on one row. Ticking several rows that share a label merges the whole group.

Only four cells are read back: `accepted` (A), `keep` (C), `your_note` (R) and
`decided_on` (S). Everything else is evidence and is regenerated every run — row counts,
`coord_status` and coordinate for each side, the distance between them, the evidence that
raised the pair, the first 500 characters of each label's affiliation strings, and a Google
Maps link for each coordinate in U and V.

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

Column O is for the second case. It fires on any row, ticked or not, and says:

| it says | meaning |
|---|---|
| `N km apart` | the two coordinates are more than 5 km apart |
| `discards a coordinate you chose` | the label being merged away is `decided` — you are throwing away your own answer, not an unexamined source value |
| `the discarded point is sanity-flagged` | the point being dropped is one of the 24 in `review_coord_sanity.csv`. This is the comfortable case: the merge takes the bad coordinate away with the label |
| `KEEPS a sanity-flagged point` | the survivor's coordinate is one of the 24. Think about this one |

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
- **It repairs the coordinate sheet.** All 91 labels in `coord_review.xlsx` carry a
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

**`output/review_label_duplicates.csv` — 153 pairs**, 53 of them at `strength >= 4`. Each
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

**`output/review_label_lumping.csv` — 86 labels.** Nothing here is in the sheet; it is a
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

- **`output/review_simple_conflicts.csv`, 18 rows** — one affiliation string carrying two
  or more labels. Spelling variants still open: `Wits Unitversity` / `Wits Univeristy` /
  `Wits University` (4 of the 18 rows), `UY1` / `UYI Cameroon`, `UoK` / `UofK Sudan`,
  `CNRFP Burina faso` / `CNRFP Burkina Faso`, `MRC Gambia` / `MRC The Gambia` /
  `MRC Laboratories, Fajara`, `DBL Denmark` / `Danish Bilharziasis Laboratory`,
  `LNSP Bissau` / `NPHL Guinea Bissau`. Four more are a short label sitting beside the
  long-form label for the same string — cosmetic, not a pipeline fault. The rest are real
  questions of institution identity: `IRD Cameroon` vs `OCEAC Cameroon` and vs `Malaria
  Research Laboratory Cameroon`, `IRD Madagascar` vs `RTI Madagascar`, `IRD France` vs
  `MIVEGEC / CIRAD / LIN Montpellier`.
- **`output/review_simple_lumping.csv`, 135 rows** — how many distinct affiliation strings
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

## Step 2 — check the coordinates already there

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

**15 of 284 are flagged** at 2026-09-10, all of them `coord_status = ok` — never one of
your 99 `decided` coordinates. A further 20 disagree with `maps` but sit inside the 10 km
coastal tolerance and are not flagged.

### What you see, and what to put in column A

Each suspect gets one row carrying **the coordinate as it stands**, so ticking it means
*checked, this is right*. `geocoder_notes` says what is wrong with it — which country the
point is in, which country was expected, how far outside it sits.

Where the error is arithmetic, a **second row** carries the repair, and it is only offered
when the repaired point actually lands inside the expected country. Four of the 15 have
one:

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
but disagrees with the label's country will come back every run. Two of the 15 are like
that:

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

The sweep is read-only and idempotent, and globs the newest dated deliverable. Re-run it
after any batch of merges, then re-run `coord_review.R` to refresh the open rows.

---

## Step 3 — spot-checks, low effort, worth doing once

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

## After every change — rebuild and read the output

```bash
python3 R/tidy_affiliations.py      # rebuild all three deliverables
python3 R/verify_affiliations.py    # assertions; exits non-zero on failure
```

The rebuild prints `N decisions applied`, or shouts `!! N decision(s) did NOT apply` and
names them. **A decision that did not apply is almost always a mistyped target**;
`output/decisions_report.csv` says which. `verify` fails the run on any of them, which is
the guard against a silent no-op.

`verify` runs 36 checks with an empty decisions file and 41 once it holds anything. The
extra five confirm your decisions landed. A rise from 36 to 41 is expected, not a
regression.

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
| `accept_as_is` | you, in the CSV | marks `reviewed = TRUE`; changes nothing |
| `note_only` | you, in the CSV | records a note; marks reviewed |

The two scripts each rewrite their own decision type and pass every other row through
untouched. The file is optional: absent or header-only, the pipeline reproduces the shipped
outputs byte-for-byte. `data/affiliation_decisions_EXAMPLE.csv` shows every type in use and
is illustrative — do not copy it into place.

### The coordinate loop — finished, kept for when a merge needs it

```bash
Rscript R/coord_review.R          # build/refresh data/coord_review.xlsx
# open the sheet, fill column A with yes/no, save
Rscript R/coord_review.R          # answers -> data/affiliation_decisions.csv
```

All 91 labels in it are settled. One row per *candidate* coordinate; a label with two
competing coordinates gets a row each, and two yeses for one label is an error that stops
the script rather than letting it pick for you.

Only six cells are read back: `accepted` (A), `affiliation_simple` (C), `latitude` (H),
`longitude` (I), `your_note` (M), `decided_on` (N). To supply your own coordinate, type the
numbers into H and I and put the link in M.

**A label the sheet does not offer** — one created by a merge, or an `ok` / `absent` label
— has no row, so there is nothing to tick. Type the label into column C with your
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

**Do not run the old bulk-adopt path**, `cp output/proposed_decisions_coords.csv
data/affiliation_decisions.csv`. It was tested once against an empty decisions file, but it
overwrites `data/affiliation_decisions.csv` and would destroy the 139 decisions in place.

### The review files at a glance

| file | rows | what it is | answer goes |
|---|---|---|---|
| `review_label_duplicates.csv` | 153 | two labels that may be one place | `label_review.xlsx` |
| `review_label_lumping.csv` | 86 | one label that may be several places | `label_review.xlsx` or the CSV |
| `review_simple_conflicts.csv` | 18 | one string carrying two labels | `label_review.xlsx` |
| `review_simple_lumping.csv` | 135 | strings per label | `label_review.xlsx` or the CSV |
| `review_coord_sanity.csv` | 24 | coordinate outside its country | `coord_review.xlsx` |
| `review_us_uk_tokens.csv` | 21 | inferred us/uk expansions | `token_replacement` |
| `review_encoding_repairs.csv` | 411 | every encoding repair made | nothing, unless wrong |
| `review_labels_collapsed.csv` | 8 | formatting-only label merges | nothing, unless wrong |
| `review_unmatched_sources.csv` | 1 | paper with no affiliation | step 4 |
| `decisions_report.csv` | 139 | did each decision apply? | read after every rebuild |

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
  self-test or parity check fails, the shipped CSVs in `output/shipped/` are the trusted
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
