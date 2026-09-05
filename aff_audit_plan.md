# Affiliation data: audit and plan

Working copy of the project inspected 2026-08-17. `vector_extraction_data.csv`, the
rasters and the zips were not opened.

---

## 1. What the files are and how they relate

```
data/vector_extraction_data.csv
      │  R/sources_to_check.R
      ▼
output/twatasha_todo.csv                    542 sources, 4 cols, UTF-8, CLEAN
      │                                     affiliation / affiliation_simple blank
      │
      ├─ ROUND 1 (manual, Excel) ───────────────────────────────────────────────
      │   data/Affiliation spreadsheet (version 2).csv     709 rows, 254 filled
      │        │  R/unique_affils.R
      │        ▼
      │   output/unique_affiliations_20240327.csv          191 unique pairs
      │        │  manual geocoding
      │        ▼
      │   data/unique_affiliations_Lat_Long.csv            180/191 with coords
      │        │  R/reseach_locations.R
      │        ▼
      │   output/research_locations_20240415.csv           105 distinct x/y
      │
      └─ ROUND 2 (manual, Excel) ───────────────────────────────────────────────
          data/Affiliation spreadsheet_version 3. 26 Sep. 2024.xlsx
              1273 rows; affiliation filled 1269, affiliation_simple 1265
              (data/ and data/twatasha_final_data/ copies are byte-identical)
              │
              ▼
          data/twatasha_final_data/unique_entries 26.sep.2024.xls
              510 rows, 507 unique (simple, affiliation) pairs, all coord cells filled
              (data/ copy differs in bytes but is identical cell-for-cell)
              │
              ▼
          data/unique_entries_tidy_20250203.xls  and  .csv
```

**`unique_entries_tidy_20250203` is identical to `unique_entries 26.sep.2024`, cell for
cell, in all 510 × 5 cells.** The February 2025 pass opened the file, re-saved the `.xls`
and exported a `.csv`; no content was changed. That answers "where did I get to" — nowhere
that survives in the file.

`Affiliation spreadsheet (version 2).csv` is a strict predecessor: 541 of its 542
citations resolve to `twatasha_todo.csv`, and v3 contains its 254 filled rows plus ~1015
more.

One source in `twatasha_todo.csv` never received an affiliation in either round:

> Diop, A., Molez, J.F., Konaté, L., Fontenille, D., Gaye, O., Diouf, M., Diagne, M. and
> Faye, O. (2002). *Role of Anopheles melas …*

`n` in v3 is intact — 0 mismatches against `twatasha_todo.csv` across 1262 resolvable rows.

---

## 2. Damage inventory

### 2.1 Character encoding — two distinct, separately reversible corruptions

| Layer | Signature | Transform applied | Inverse |
|---|---|---|---|
| A | `√`, `©`, `Ä`, `†` | UTF-8 bytes read as Mac Roman | `x |> encode(mac_roman) |> decode(utf-8)` |
| B | `È` for é, `Ù` for ô | CP1252/Latin-1 bytes read as Mac Roman | `x |> encode(mac_roman) |> decode(cp1252)` |

Worked example, both layers stacked in `unique_entries`:

```
G√àn√àtique  --A-->  GÈnÈtique  --B-->  Génétique
Contr√ôle    --A-->  ContrÙle    --B-->  Contrôle
```

Counts of affected cells:

| File / column | Layer A | Layer B |
|---|---|---|
| v3 `source_citation` | 399 rows | — |
| v3 `affiliation` | — | 16 cells |
| v3 `affiliation_simple` | — | 0 |
| v3 `affiliation - original` | — | 0 |
| `unique_entries` `affiliation` | 51 cells | included above |
| `unique_entries` `affiliation_simple` | 12 cells | included above |

`data/unique_affiliations_Lat_Long.csv` is stored on disk in Mac Roman, not UTF-8;
`read_csv()` without `locale(encoding = "macintosh")` will mangle it.

The `source_citation` damage does not need repairing by inference — every row can be
re-keyed against the clean `twatasha_todo.csv`.

### 2.2 Find-and-replace damage

A case-insensitive, non-whole-word replace of `us` → `United States`, `usa` →
`United States` and `uk` → `United Kingdom` was run over parts of the sheet.

```
Anopheles funestus            → Anopheles funestUnited States      (127×)
Manoukis, N.C.                → ManoUnited Kingdomis, N.C.
Sousa, C.A.                   → SoUnited States, C.A.
Emerging Infectious Diseases  → Emerging InfectioUnited States Diseases
Musée / Museum                → MUnited Stateseum
KNUST                         → KNUnited StatesT
Campus international          → CampUnited States international
Maladies Infectieuses         → Maladies InfectieUnited Stateses
```

Rows affected: `source_citation` 392, `affiliation` 171, `affiliation_simple` 240,
`affiliation - original` 6. It was not applied uniformly — row 1196 keeps
`… London, UK` in `affiliation` while its `affiliation_simple` reads
`LSHTM United Kingdom`.

Reversal is mechanical but the case is not recoverable from the string alone
(`us` / `US` / `usa` / `USA` all map to the same output), so the distinct broken tokens
need eyeballing. There are 12 distinct tokens in `affiliation`, 6 in `affiliation_simple`,
~55 in `source_citation` (irrelevant — those get re-keyed).

### 2.3 Excel fill-handle (drag-down) damage

Where one paper spans several rows the citation was dragged down and Excel treated the
trailing page number as a series and incremented it:

| Paper | v3 shows | true |
|---|---|---|
| Costantini et al. 2001, Med Vet Entomol 15(3) | 259-**61**, -**62**, -**63**, -**64**, -**65** | 259-**66** |
| Robert et al. 1998, J Med Entomol 35(6) | 948-**56**, -**57**, -**58** | 948-**55** |
| Antonio-Nkondjio et al. 2008, TRSTMH 102(4) | 352-**8** | 352-**9** |
| Cohuet et al. 2004, Insect Mol Biol 13(3) | 251-**7** | 251-**8** |
| Girod et al. 2006, J Med Entomol 43(5) | 1082-**6** | 1082-**7** |
| Ollomo et al. 1997, AJTMH 56(4) | 440-**4** | 440-**5** |
| Paskewitz et al. 1993, J Med Entomol 30(5) | 953-**6** | 953-**7** |
| Pennetier et al. 2008, Emerg Infect Dis 14(11) | 1707-**13** | 1707-**14** |

16 rows in v3, 3 rows in `Affiliation spreadsheet (version 2).csv`. `n` is not affected.
All are repaired by re-keying to `twatasha_todo.csv`.

### 2.4 Structural

- 11 rows in v3 have a blank `source_citation` (rows 109, 320–322, 457, 552–553, 555,
  1196–1198). Each sits directly under a row for the same paper — continuation rows for
  extra affiliations. Forward-fill is safe and was checked row by row.
- `ABSENT` is a sentinel: 55 rows in `affiliation`/`affiliation_simple`, 27 coordinate
  rows in `unique_entries`.
- One latitude carries a trailing comma: `43.684397,` (Campus international de
  Baillarguet, France).
- ~30 `affiliation_simple` cells hold the full affiliation text instead of a short label,
  e.g. `Danish Bilharziasis Laboratory, 1-D Jaergersborg Allé, Charlottenlund …`.
- Two leading-newline `affiliation` values (rows 552, 553); several trailing spaces
  (`MoH Sudan `, `SAP Italy `, `UofG Sudan `); two zero-width spaces (U+200B).

### 2.5 Coverage gaps

| Quantity | Count |
|---|---|
| distinct `affiliation_simple` in v3 | 406 |
| …with coordinates in `unique_entries` | 271 |
| **…with no coordinates at all** | **129** |
| distinct `affiliation` strings in v3 | 980 |
| unique (`affiliation`, `affiliation_simple`) pairs | 1007 |

---

## 3. Things needing your judgement (lists, not decisions)

### 3.1 One `affiliation` carrying two or more `affiliation_simple` labels — 30 cases

Two kinds mixed together. Obvious typos:

```
Wits Unitversity South Africa   vs  Wits University South Africa  vs  Wits Univeristy South Africa
UY1 Cameroon                    vs  UYI Cameroon
UoK Sudan                       vs  UofK Sudan
CNRFP Burina faso               vs  CNRFP Burkina Faso
MRC Gambia                      vs  MRC The Gambia
CREC                            vs  CREC Benin
```

And real judgement calls:

```
Laboratory of the Research Institute for Development, RU#016, Organization for the
fight against major endemic diseases in Central Africa …
        →  IRD Cameroon   |   OCEAC Cameroon

Department of Epidemiology of Parasitic Affections, National School of Medicine and
Pharmacy, Bamako, Mali
        →  MRTC Mali   |   ENMP Mali   |   <full text>

Institute of Research for Development, Antananarivo, Madagascar
        →  IRD Madagascar   |   RTI Madagascar

Center for Malaria and other Tropical Diseases / Institute of Hygiene and Tropical
Medicine, Lisbon
        →  CEMTROD Portugal   |   IHMT Portugal
```

Plus 5 groups differing only by case, trailing punctuation or whitespace:
`Centre Muraz Burkina Faso` / `Centre Muraz, Burkina Faso` / `Centre Muraz Burkina Faso.`;
`LIN-IRD France` / `LIN/IRD France`; `ORSTOM Sénégal` / `ORSTOM Sénégal.`;
`UB United States` / `UB United states`; `UVM United States` / `UVM United states`.

### 3.2 One `affiliation_simple` covering possibly-distinct places

Largest lumps: `SAP Italy` (45 distinct affiliation strings), `OCEAC Cameroon` (28),
`LSTM United Kingdom` (23), `CDC United States` (19), `IRD France` (19),
`UCAD Senegal` (17), `UC United States` (16).

`IRD France` for instance spans Montpellier campus, Faculté de Pharmacie, Centre of
Biology and Management of Populations, and an unqualified "Institute of Research for
Development, France". Whether those are one location is your call.

Also flagged: composite affiliations that name two institutions in two countries, e.g.
`Division of Parasitic Diseases, CDC, Atlanta, GA, USA, and Kenya Medical Research
Institute …` → `CDC United States`.

### 3.3 `affiliation_simple` with more than one coordinate pair — 25 cases

| Label | separation | comment |
|---|---|---|
| `Wits University South Africa` | 5825 km | **latitude sign error**: −26.1899 vs +26.1929 |
| `CIRAD France` | 393 km | Montpellier vs Poitiers-ish |
| `BRL Zimbabwe` | 365 km | Harare vs Chiredzi |
| `IHI Tanzania` | 323 km | Dar es Salaam vs Ifakara — both are real IHI sites |
| `LSTM United Kingdom` | 161 km | −2.9716 is Liverpool; −5.4080 is in the Irish Sea |
| `University of Wales UK` | 84 km | Lampeter vs Cardiff |
| `CDC USA`, `MoH Sudan`, `ORSTOM Senegal`, `IMPM Cameroon` | 2–7 km | different campuses/buildings |
| 15 others | ≤ 300 m | same building, different rounding |

Note also that `CDC USA` and `CDC United States` (and `Bacilligen U.S` /
`Bacilligen United States`, `Norte Dame US` / `Norte Dame United States`) are separate
labels created by the find-and-replace, not separate places.

---

## 4. Proposed plan

All steps as a single reproducible R script (`R/tidy_affiliations.R`) plus a Quarto-free
plain log, so nothing depends on re-running Excel.

**Step 1 — read.** Read `Affiliation spreadsheet_version 3 …xlsx` with `readxl`, keeping
all five columns as character. Read `twatasha_todo.csv` (UTF-8) and
`unique_entries 26.sep.2024.xls` (via `readxl`, which handles BIFF8 directly).

**Step 2 — repair encoding.** Apply layer A then layer B, gated on the signature character
sets rather than blanket-applied, so correct French text is not re-broken. Emit
`output/review_encoding_repairs.csv` (before → after, every changed cell) for spot-check.

**Step 3 — restore `source_citation`.** Forward-fill the 11 blanks, then match each row to
`twatasha_todo.csv`: exact match on the repaired string first, then on a canonical key that
neutralises the `us`/`uk` substitutions, then on a digit-stripped key to catch the
drag-down page numbers. Overwrite `source_citation` and `n` with the `twatasha_todo.csv`
values. Any row that fails all three stages is written to
`output/review_unmatched_sources.csv` rather than guessed at.

**Step 4 — reverse the find-and-replace in `affiliation`, `affiliation - original` and
`affiliation_simple`.** Only mid-word occurrences are touched. Every distinct token and its
proposed replacement goes to `output/review_us_uk_tokens.csv` **for your sign-off before
the substitution is baked in** — the case of the original (`us` / `US` / `usa` / `USA`) is
not recoverable from the string.

**Step 5 — whitespace normalisation.** Trim, collapse internal runs, strip U+200B and
leading newlines. This is the only silent change.

**Step 6 — deliverable 1.** `output/affiliations_complete_<date>.csv`, 1273 rows, UTF-8,
columns `source_citation, n, affiliation_original, affiliation, affiliation_simple`.

**Step 7 — deliverable 2.** `output/affiliation_lookup_<date>.csv` — distinct
(`affiliation`, `affiliation_simple`) pairs, ~1007 rows, sorted by `affiliation_simple`.

**Step 8 — deliverable 3.** `output/affiliation_simple_coords_<date>.csv` — one row per
distinct `affiliation_simple` (~406), with `latitude`, `longitude`, `note`,
`coord_source` (`unique_entries` / `unique_affiliations_Lat_Long` / `missing`) and
`coord_status` (`ok` / `conflict` / `absent` / `missing`). The 129 unmatched labels appear
with `NA` coordinates and `coord_status = "missing"` so you can work through them.

**Step 9 — review lists.** `review_simple_conflicts.csv` (§3.1),
`review_simple_lumping.csv` (§3.2), `review_coord_conflicts.csv` (§3.3),
`review_missing_coords.csv`, `review_unmatched_sources.csv`.

**Step 10 — verification.** Assertions run at the end and printed: row count preserved at
1273; `n` matches `twatasha_todo.csv` for every row; no `√`, `È`-as-é or mid-word
`United States`/`United Kingdom` survive anywhere; every `affiliation_simple` in
deliverable 2 appears exactly once in deliverable 3; every non-`ABSENT` coordinate parses
as a number and falls in a plausible range. Plus a spot re-read of 20 random cells against
the original xlsx.
