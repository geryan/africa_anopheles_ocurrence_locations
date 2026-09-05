# Proposed coordinates for the 88 missing affiliations

Produced 2026-08-18. **These are proposals, not decisions.** Nothing has been written into
the deliverables. To adopt them, copy `output/proposed_decisions_coords.csv` over
`data/affiliation_decisions.csv` and re-run the pipeline.

| file | what it is |
|---|---|
| `output/proposed_coords_missing88_20260818.csv` | the table you asked for: 88 rows, coordinate, source name, source URL, Google Maps link, OSM link, precision, confidence, notes |
| `output/proposed_decisions_coords.csv` | the same 88 as `coordinate` rows in decisions-file format, ready to drop in |

## Coverage and quality

All 88 were located. None came back not-found, but "found" spans a wide range and the
`precision` column is the thing to read:

| precision | n | meaning |
|---|---|---|
| `building` | 25 | a specific street address or building |
| `campus` | 39 | the right campus, not the right building — error typically 100–500 m |
| `city` | 19 | town or city centroid only; the institution could not be pinned |
| `org_hq` | 5 | a programme or ministry rather than a research site; coordinate is its headquarters |

Confidence: 53 high, 35 medium, 0 low. Every row carries a URL that was actually retrieved.

## Independent corroboration

Thirty of the 88 landed within 500 m of a coordinate already in the project for what is
obviously the same institution, without either being told about the other:

```
SSE Madagascar          2 m from  MOH Madagascar
Rothamsted Research UK 92 m from  IACR-Rothamsted United Kingdom
University, Keele UK  114 m from  Keele University United Kingdom
IPR Ivory Coast       167 m from  IPR Côte d'Ivoire
IP France             174 m from  IPF France
JHU United States     180 m from  BSPH United states
UCLA United States    190 m from  UC United States
CMDT Portugal         224 m from  CEMTROD Portugal
the 10 Bamako labels  271 m from  Faculty of Medicine, Pharmacy and Odonto-Stomatology…
```

That is a useful check on both the new coordinates and the existing ones. It is also a
list of merge candidates: `nearest_existing_label` and `nearest_existing_km` are in the
table so you can work through them.

## Labels that resolved to the same place

`same_coord_group` marks 29 labels falling into 10 groups within 1 km of each other:

1. `Blair and de Beers…Causeway` + `MOHCW Zimbabwe` — both the Blair laboratory, Harare
2. `Blue Nile Health Project Sudan` + `Blue Nile Research and Training Institute Sudan` — Wad Madani
3. `C/O.U.A.…Equatorial Guinea` + `EGMI Equatorial Guinea` — Bata
4. the three Danish Bilharziasis Laboratory spellings
5. **ten** Bamako labels — DEAP / ENMP / FMPOS / MRTC / University of Bamako / University of Mali, all the Point G campus
6. `Department of Medical Microbiology The Netherlands` + `RU The Netherlands` — Radboudumc
7. `INSPQ Ivory Coast` + `IPR Ivory Coast` — Institut Pierre Richet, Bouaké
8. `Institute of Cell, Animal and Population Biology…` + `University of Edinburgh United Kingdom` — Ashworth Laboratories, King's Buildings
9. `MC Italy` + `UNICAM Italy` — Polo di Bioscienze, Camerino
10. `UTHB United States` + `UTMB United States` — University of Texas Medical Branch, Galveston

Group 5 is the big one. Ten distinct `affiliation_simple` values, one campus.

## Findings that change other parts of the project

**Blair and de Beers is two places.** Blair Research Laboratory is in Harare (Causeway is a
central Harare district and the PO Box designation); the de Beers Research Laboratory,
established 1965, is a separate field station at Chiredzi, roughly 400 km south-east. This
is the explanation for the 365 km `BRL Zimbabwe` conflict in `review_coord_conflicts.csv` —
both coordinates are correct, for different sites. Only the Harare site is geocoded here.

**MRC Sierra Leone: the address in the project note is wrong for these papers.** The note
reads "5 Frazier Davis Drive, Freetown". OpenAlex's record for PMID 7944670 (Barnish et al.,
*Ann Trop Med Parasitol* 1994) gives the verbatim affiliation "Medical Research Council
Laboratory, P.O. Box 81, **Bo**, Sierra Leone". Frazer Davies Drive is a real Freetown
street, but it is ~230 km from Bo and matches no affiliation in this corpus. Recommend
retiring it. Bo town is the coordinate given.

**`UTHB` is a typo for `UTMB`.** Both affiliation strings are verbatim identical: "Department
of Pathology and Center for Tropical Diseases, University of Texas Medical Branch, Galveston".

**`INSPQ Ivory Coast` is Ivorian, not Québécois.** The acronym normally means Institut
national de santé publique du Québec. This one is the Institut National de Santé Publique of
Côte d'Ivoire, which absorbed the Institut Pierre Richet at Bouaké after OCCGE dissolved.
Never merge it with a Quebec affiliation.

**`RTI Madagascar` is mislabelled.** The affiliation reads "Institute of Research for
Development", which is the English rendering of Institut de Recherche pour le Développement
(IRD, formerly ORSTOM) — not RTI International. This confirms the existing project note
"need to check for translation". It is also a merge candidate with `IRD Madagascar`.

**`CREC Equatorial Guinea` is CRCE, and unrelated to CREC Cotonou.** It is the Centro de
Referencia para el Control de Endemias, the Equatorial Guinea field laboratory of Spain's
Centro Nacional de Medicina Tropical (ISCIII). It has had both Malabo and Bata sites; Malabo
was chosen on an era-matched PubMed record (PMID 16784527). Confirm against the paper.

**`FMSP Cameroon` may be anachronistic.** The Faculté de Médecine et des Sciences
Pharmaceutiques at Douala was decreed in 1993 but only began teaching in 2006–07. If the
source paper predates that, the affiliation points somewhere else. The Université de Douala
main campus is noted in the row as the alternative.

## Two bad published coordinates found along the way

Worth knowing in case either was ever used elsewhere in this project:

- English Wikipedia gives **Queen Elizabeth Central Hospital, Blantyre** as `15.803 N,
  35.017 W` — wrong hemisphere on both axes.
- English Wikipedia's infobox for Sudan's **National Centre for Research** plots ~11 km south
  of the University of Khartoum despite naming a central-Khartoum street.
- GeoNames' "Università di Camerino" is at Ascoli Piceno, ~55 km from Camerino. GeoNames'
  "Jimma University" is the Agricultural Campus, ~2.6 km from the health campus used here.

## A residual find-and-replace bug

Two affiliation strings contain `United States.A.` — that is `U.S.A.` with `US` expanded.
The mid-word reversal did not catch it because the `.` on either side is not a word
character, so it reads as a standalone expansion. Affected labels: `Bacilligen United States`
and `ND United States`. Add `token_replacement` rows if you want them fixed:

```
token_replacement,United States.A.,U.S.A.,,,,2026-08-18
```

## Method and its limits

Nine research agents, ten institutions each, each required to cite a URL it actually
retrieved and to return not-found rather than guess. Coordinates came from institutions'
own sites, the Danish national address register, DBpedia's mirror of Wikipedia infoboxes,
OpenStreetMap via Mapcarta, GeoNames, OpenAlex, ROR, api.postcodes.io and the US Census
geocoder. Nominatim, Overpass, Wikidata and the Wikipedia API were unreachable from this
environment.

The honest limits: 19 of the 88 are city centroids and should not be treated as institution
locations. `campus` rows are good to a few hundred metres, not to the building. Several
entries involve an institution that has moved or been renamed, and the coordinate is the
present-day site, which may not be where the work in a 1980s paper was done — the `notes`
column says so where it applies. Nothing here has been verified against the source papers.
