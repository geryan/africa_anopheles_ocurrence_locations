# check_coord_sanity.R ---------------------------------------------------------
#
# Sanity-check every coordinate in deliverable 3 against the country its
# affiliation names, and record the suspects.  READ-ONLY except for the single
# file it writes, output/review_coord_sanity.csv.
#
#   Rscript R/check_coord_sanity.R
#
# It fixes nothing and proposes nothing.  Coordinate calls belong to the project
# owner and are made through data/coord_review.xlsx (see CLAUDE.md rule 3/4).
#
# Method
#   1. Keep the rows of output/final/affiliation_simple_coords_with_notes.csv that carry a
#      coordinate (coord_status ok or decided).
#   2. Expected country: parse trailing country token(s) out of
#      affiliation_simple, and independently out of that label's affiliation
#      strings in the lookup.  Both are recorded as evidence.  A label yielding
#      neither is reported in its own bucket, not dropped.
#   3. Actual country: maps::map.where(), offline, NA over sea.
#   4. The maps coastline is low resolution, so a raw name mismatch is not
#      enough.  For every disagreement the great-circle distance from the point
#      to the nearest vertex of the expected country's polygons is computed with
#      sf::st_distance (s2, so metres on the sphere) and only distances above
#      THRESHOLD_KM are flagged.  The distance is reported either way.
#   5. Secondary classes: zero coordinates, apparent lat/long transposition,
#      one coordinate shared by labels naming different countries, and
#      suspiciously round coordinates (informational).
#
# Offline throughout: no geocoding service is contacted.
# ------------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(countrycode)
  library(maps)
  library(sf)
})

THRESHOLD_KM <- 10   # tolerance for the low-resolution maps coastline

deliverable <- function(name) {
  f <- file.path("output", "final", name)
  if (!file.exists(f)) stop(f, " not found; run python3 R/tidy_affiliations.py first")
  f
}
coords_file <- deliverable("affiliation_simple_coords_with_notes.csv")
lookup_file <- deliverable("affiliation_lookup.csv")
out_file    <- "output/review_coord_sanity.csv"

message("coords: ", coords_file, "\nlookup: ", lookup_file)

# --- country matching ---------------------------------------------------------

# The set of ISO3 codes a piece of text matches, using countrycode's English
# name regexes (which carry the negative lookaheads that keep "Equatorial
# Guinea" out of "Guinea", etc.) plus the handful of aliases and label
# misspellings this corpus actually uses.  Returning the whole set, rather than
# one code, is what lets the caller reject an ambiguous candidate and shrink it.
cl <- countrycode::codelist[!is.na(countrycode::codelist$iso3c), ]
name_regex <- setNames(cl$country.name.en.regex, cl$iso3c)
name_regex <- name_regex[!is.na(name_regex)]

# Aliases used in this project's labels and affiliation strings.  Spelling
# variants only - no institution is being reassigned to a different country.
extra_regex <- c(
  USA = "\\bu\\.?\\s?s\\.?\\s?a?\\.?\\b|\\bunited\\s+states\\b",
  GBR = "\\bu\\.?\\s?k\\.?\\b|\\bunited\\s+kingdom\\b|\\bgreat\\s+britain\\b",
  NLD = "\\bnatherlands\\b|\\bnetherland\\b",
  ITA = "\\bitlay\\b",
  BFA = "\\bburina\\s+faso\\b|\\bburkina\\b",
  STP = "\\bprincipe\\b|\\bsao\\s+tome\\b",
  CIV = "\\bcote\\s?d.?\\s?ivoire\\b|\\bivory\\s+coast\\b",
  TZA = "\\btanzania\\b",
  COG = "\\brepublic\\s+of\\s+congo\\b|\\bcongo\\s+brazzaville\\b",
  GNQ = "\\bequatorial\\s+guinea\\b|\\bguinea\\s+ecuatorial\\b",
  GNB = "\\bguinea\\s?.?\\s?bissau\\b"
)

# The country dictionaries are unaccented, so "Benin" must be folded out of
# "Benin" before matching, likewise "Senegal", "Cote d'Ivoire".
fold <- function(x) {
  y <- iconv(x, "UTF-8", "ASCII//TRANSLIT")
  y <- ifelse(is.na(y), x, y)
  gsub("[`'^\"~]", "", y)
}

match_set <- function(x) {
  if (is.na(x) || !nzchar(trimws(x))) return(character(0))
  s <- tolower(fold(trimws(x)))
  hits <- names(name_regex)[vapply(name_regex, function(rx)
    grepl(rx, s, perl = TRUE, ignore.case = TRUE), logical(1))]
  extra <- names(extra_regex)[vapply(extra_regex, function(rx)
    grepl(rx, s, perl = TRUE, ignore.case = TRUE), logical(1))]
  unique(c(hits, extra))
}

# Candidate substrings of a label / affiliation string, longest first.  Trailing
# runs of words from the last comma-delimited field, then the last two fields,
# then the whole thing.  Longest-first stops "Equatorial Guinea" collapsing to
# "Guinea"; the exactly-one-match rule stops "IHRDC Tanzania" collapsing to
# "RDC" (DR Congo) and "Virginia Tech" to the Virgin Islands.
candidates <- function(x) {
  clean <- trimws(gsub("[[:space:],.;]+$", "", x))
  if (!nzchar(clean)) return(character(0))
  parts <- trimws(strsplit(clean, ",", fixed = TRUE)[[1]])
  parts <- parts[nzchar(parts)]
  if (!length(parts)) return(clean)
  last <- parts[length(parts)]
  toks <- strsplit(last, "\\s+")[[1]]
  n <- min(5L, length(toks))
  runs <- vapply(seq(n, 1L), function(k)
    paste(toks[(length(toks) - k + 1L):length(toks)], collapse = " "), character(1))
  two <- if (length(parts) >= 2)
    paste(parts[(length(parts) - 1L):length(parts)], collapse = ", ") else character(0)
  unique(c(runs, two, clean))
}

# One country for a string: the first candidate (longest first) that matches
# exactly one country.  The evidence text is then the shortest candidate giving
# that same single answer, so "Wits Unitversity South Africa" is reported as
# "South Africa" while "CREC Equatorial Guinea" is not shortened to "Guinea"
# (which resolves to a different country and is therefore rejected).
parse_country <- function(x) {
  if (is.na(x)) return(list(iso = NA_character_, text = NA_character_))
  cands <- candidates(x)
  for (cand in cands) {
    m <- match_set(cand)
    if (length(m) == 1L) {
      same <- Filter(function(c2) identical(match_set(c2), m), cands)
      return(list(iso = m, text = same[which.min(nchar(same))]))
    }
  }
  # Fall back to a whole-string scan: accept only if the string as a whole names
  # exactly one country.
  m <- match_set(x)
  if (length(m) == 1L) return(list(iso = m, text = trimws(x)))
  list(iso = NA_character_, text = NA_character_)
}

# Overseas territories: an institution in Saint-Denis de La Reunion whose
# affiliation says "France" is correctly placed, and must not be reported as
# 9,000 km wrong.  Point country is mapped to its sovereign before comparison.
sovereign_of <- c(
  REU = "FRA", MYT = "FRA", GLP = "FRA", MTQ = "FRA", GUF = "FRA",
  NCL = "FRA", PYF = "FRA", SPM = "FRA", WLF = "FRA", BLM = "FRA", MAF = "FRA",
  PRI = "USA", VIR = "USA", GUM = "USA", ASM = "USA", MNP = "USA",
  ABW = "NLD", CUW = "NLD", SXM = "NLD", BES = "NLD",
  GIB = "GBR", FLK = "GBR", BMU = "GBR", IMN = "GBR", JEY = "GBR", GGY = "GBR",
  SHN = "GBR", CYM = "GBR", TCA = "GBR", VGB = "GBR", MSR = "GBR", AIA = "GBR",
  HKG = "CHN", MAC = "CHN", GRL = "DNK", FRO = "DNK", ALA = "FIN", SJM = "NOR"
)
to_sovereign <- function(iso) ifelse(!is.na(iso) & iso %in% names(sovereign_of),
                                     sovereign_of[iso], iso)

# The other direction, and the reason this exists: folding a territory into its
# sovereign also hides a point that is in the sovereign but nowhere near the
# territory the affiliation actually names.  `IPG France` is
# "Pasteur Institute of Guyana, Cayenne, France" carrying a coordinate in Paris;
# expected FRA, point FRA, no flag, 7000 km wrong.  So when the text names a
# territory outright, that territory - not its sovereign - is what the
# coordinate is checked against.
#
# Curated, not exhaustive: names and principal cities specific enough that a
# match is not an accident.  "Saint-Denis" alone is not here, because most
# Saint-Denis addresses are the Paris suburb; bare "Guyana" is not here either,
# because that is a country in its own right.
territory_regex <- c(
  GUF = "\\bguyane\\b|\\bfrench\\s+guiana\\b|\\bcayenne\\b|\\bkourou\\b|\\bmatoury\\b",
  REU = "\\bla\\s+r[eé]union\\b|\\breunion\\b|\\bsainte?.clotilde\\b",
  GLP = "\\bguadeloupe\\b|\\bpointe.a.pitre\\b|\\bbasse.terre\\b",
  MTQ = "\\bmartinique\\b|\\bfort.de.france\\b",
  MYT = "\\bmayotte\\b|\\bmamoudzou\\b",
  NCL = "\\bnouvelle.cal[eé]donie\\b|\\bnew\\s+caledonia\\b|\\bnoum[eé]a\\b",
  PYF = "\\bpolyn[eé]sie\\b|\\bfrench\\s+polynesia\\b|\\bpapeete\\b|\\btahiti\\b",
  PRI = "\\bpuerto\\s+rico\\b",
  GUM = "\\bguam\\b",
  HKG = "\\bhong\\s+kong\\b",
  MAC = "\\bmaca[uo]\\b",
  GRL = "\\bgreenland\\b|\\bnuuk\\b"
)

# The territory a piece of text names, when it names exactly one.
territory_of <- function(x) {
  if (is.na(x) || !nzchar(trimws(x))) return(NA_character_)
  s <- tolower(fold(x))
  hits <- names(territory_regex)[vapply(territory_regex, function(rx)
    grepl(rx, s, perl = TRUE), logical(1))]
  if (length(hits) == 1L) hits else NA_character_
}

# --- data ---------------------------------------------------------------------

# Read as character so decimal places can be counted off the source text.
coords_raw <- read_csv(coords_file, col_types = cols(.default = col_character()))
lookup     <- read_csv(lookup_file, col_types = cols(
  affiliation_simple = col_character(), affiliation = col_character(),
  n_rows = col_double()))

# A label the owner has already looked at and signed off is not a suspect.
# `accept_as_is` and `note_only` are the decision types that mean exactly that,
# so a coordinate carrying one is skipped and counted.
signed_off <- character(0)
f_dec <- "data/affiliation_decisions.csv"
if (file.exists(f_dec)) {
  d <- read_csv(f_dec, col_types = cols(.default = col_character()), progress = FALSE)
  if ("decision_type" %in% names(d))
    signed_off <- unique(d$target[d$decision_type %in% c("accept_as_is", "note_only")])
  signed_off <- signed_off[!is.na(signed_off)]
}

co <- coords_raw %>%
  mutate(latitude_num = suppressWarnings(as.numeric(latitude)),
         longitude_num = suppressWarnings(as.numeric(longitude)),
         n_rows_num = suppressWarnings(as.numeric(n_rows))) %>%
  filter(!is.na(latitude_num), !is.na(longitude_num))

message(sprintf("%d rows in deliverable 3, %d carry a coordinate", nrow(coords_raw), nrow(co)))

# --- expected country ---------------------------------------------------------

lab_parsed <- lapply(co$affiliation_simple, parse_country)
co$country_label      <- vapply(lab_parsed, function(p) p$iso, character(1))
co$country_label_text <- vapply(lab_parsed, function(p) p$text, character(1))

# Affiliation strings: parse each, then take the plurality country per label.
aff <- lookup %>% filter(affiliation_simple %in% co$affiliation_simple)
aff_parsed <- lapply(aff$affiliation, parse_country)
aff$iso  <- vapply(aff_parsed, function(p) p$iso, character(1))
aff$text <- vapply(aff_parsed, function(p) p$text, character(1))

aff_summary <- aff %>%
  filter(!is.na(iso)) %>%
  count(affiliation_simple, iso, name = "n_aff") %>%
  arrange(affiliation_simple, desc(n_aff), iso) %>%
  group_by(affiliation_simple) %>%
  summarise(
    country_aff = first(iso),
    aff_tally = paste0(iso, "=", n_aff, collapse = "/"),
    .groups = "drop")

# A representative affiliation string per label: the most frequent, longest.
aff_excerpt <- aff %>%
  arrange(affiliation_simple, desc(n_rows), desc(nchar(affiliation))) %>%
  group_by(affiliation_simple) %>%
  summarise(affiliation_excerpt = first(affiliation), .groups = "drop")

co <- co %>%
  left_join(aff_summary, by = "affiliation_simple") %>%
  left_join(aff_excerpt, by = "affiliation_simple")

# A territory named anywhere in the label or in any of its affiliation strings.
terr_by_label <- aff %>%
  mutate(terr = vapply(affiliation, territory_of, character(1))) %>%
  filter(!is.na(terr)) %>%
  count(affiliation_simple, terr, name = "n_terr") %>%
  arrange(affiliation_simple, desc(n_terr)) %>%
  group_by(affiliation_simple) %>%
  summarise(territory_aff = first(terr), .groups = "drop")

co <- co %>%
  left_join(terr_by_label, by = "affiliation_simple") %>%
  mutate(territory = ifelse(!is.na(vapply(affiliation_simple, territory_of, character(1))),
                            vapply(affiliation_simple, territory_of, character(1)),
                            territory_aff))

co <- co %>%
  mutate(
    expected_country = ifelse(!is.na(country_label), country_label, country_aff),
    expected_country_evidence = case_when(
      !is.na(country_label) & !is.na(country_aff) & country_label == country_aff ~
        sprintf("both: label \"%s\"; affiliations %s", country_label_text, aff_tally),
      !is.na(country_label) & !is.na(country_aff) & country_label != country_aff ~
        sprintf("label \"%s\" (used); affiliations disagree %s",
                country_label_text, aff_tally),
      !is.na(country_label) ~ sprintf("label only: \"%s\"", country_label_text),
      !is.na(country_aff)   ~ sprintf("affiliation only: %s", aff_tally),
      TRUE ~ NA_character_))

# The text names an overseas territory of the country expected: check against the
# territory, which is the whole point - Cayenne is France, and 7000 km from Paris.
co <- co %>%
  mutate(
    expected_is_territory = !is.na(territory) &
      (is.na(expected_country) | to_sovereign(territory) == expected_country |
       territory == expected_country),
    expected_country_evidence = ifelse(
      expected_is_territory & !identical(territory, expected_country),
      sprintf("%s; text names %s, checked against that",
              ifelse(is.na(expected_country_evidence), "", expected_country_evidence),
              territory),
      expected_country_evidence),
    expected_country = ifelse(expected_is_territory, territory, expected_country))

# --- actual country -----------------------------------------------------------

wm <- maps::map("world", fill = TRUE, plot = FALSE)
world <- sf::st_make_valid(sf::st_as_sf(wm))
world <- suppressWarnings(sf::st_set_crs(world, 4326))
world$map_name <- sub(":.*$", "", world$ID)

map_iso <- suppressWarnings(countrycode(world$map_name, "country.name", "iso3c",
                                        warn = FALSE))
manual_map_iso <- c("Canary Islands" = "ESP", "Madeira Islands" = "PRT",
                    "Azores" = "PRT", "Barbuda" = "ATG", "Grenadines" = "VCT",
                    "Saint Martin" = "MAF", "Bonaire" = "BES",
                    "Sint Eustatius" = "BES", "Saba" = "BES",
                    "Micronesia" = "FSM", "Kosovo" = "XKX",
                    "Ascension Island" = "SHN", "Heard Island" = "HMD",
                    "Chagos Archipelago" = "IOT")
fill <- is.na(map_iso) & world$map_name %in% names(manual_map_iso)
map_iso[fill] <- manual_map_iso[world$map_name[fill]]
world$iso3c <- map_iso

co$point_country_name <- maps::map.where("world", co$longitude_num, co$latitude_num)
co$point_country_name <- sub(":.*$", "", co$point_country_name)
co$point_country <- suppressWarnings(countrycode(co$point_country_name,
                                                 "country.name", "iso3c", warn = FALSE))
fill <- is.na(co$point_country) & co$point_country_name %in% names(manual_map_iso)
co$point_country[fill] <- manual_map_iso[co$point_country_name[fill]]

# Transposed reading of the same pair.
swap_ok <- abs(co$longitude_num) <= 90 & abs(co$latitude_num) <= 180
co$swap_country <- NA_character_
if (any(swap_ok)) {
  nm <- sub(":.*$", "", maps::map.where("world", co$latitude_num[swap_ok],
                                        co$longitude_num[swap_ok]))
  co$swap_country[swap_ok] <- suppressWarnings(
    countrycode(nm, "country.name", "iso3c", warn = FALSE))
}

# --- distance to the expected country ----------------------------------------

co$point_sov    <- to_sovereign(co$point_country)
co$expected_sov <- to_sovereign(co$expected_country)
# Territory-specific expectations are compared exactly; everything else folds
# into the sovereign, so an institute in Saint-Denis whose affiliation says
# "France" is not reported as 9,000 km wrong.
co$country_ok   <- !is.na(co$expected_country) & !is.na(co$point_country) &
  ifelse(co$expected_is_territory,
         co$point_country == co$expected_country,
         co$point_sov == co$expected_sov)

dist_to_country <- function(lon, lat, iso) {
  if (is.na(iso)) return(NA_real_)
  polys <- world[!is.na(world$iso3c) & world$iso3c == iso, ]
  if (!nrow(polys)) return(NA_real_)
  pt <- sf::st_sfc(sf::st_point(c(lon, lat)), crs = 4326)
  as.numeric(min(sf::st_distance(pt, polys))) / 1000
}

co$distance_km_to_expected <- NA_real_
need <- !is.na(co$expected_country) & !co$country_ok
for (i in which(need)) {
  co$distance_km_to_expected[i] <- dist_to_country(
    co$longitude_num[i], co$latitude_num[i], co$expected_country[i])
}
co$distance_km_to_expected[!need & !is.na(co$expected_country)] <- 0

# --- flags --------------------------------------------------------------------

dec_places <- function(s) {
  s <- sub("^[+-]", "", trimws(s))
  ifelse(grepl("\\.", s), nchar(sub("^[^.]*\\.", "", sub("0+$", "", s))), 0L)
}

co <- co %>%
  mutate(
    f_zero = latitude_num == 0 | longitude_num == 0,
    f_sea  = is.na(point_country) & !is.na(expected_country) &
      !is.na(distance_km_to_expected) & distance_km_to_expected > THRESHOLD_KM,
    f_mismatch = !is.na(point_country) & !country_ok & !is.na(expected_country) &
      !is.na(distance_km_to_expected) & distance_km_to_expected > THRESHOLD_KM,
    f_swap = !country_ok & !is.na(expected_country) & !is.na(swap_country) &
      to_sovereign(swap_country) == expected_sov,
    f_round = dec_places(latitude) < 2 & dec_places(longitude) < 2,
    f_noexp = is.na(expected_country))

# --- a repair that would put the point in the expected country ----------------
#
# Four of the error classes are arithmetic: a sign dropped, a leading digit
# lost, the pair written the wrong way round.  Each candidate transformation is
# tested by the same measure as the original - does it land inside the expected
# country - and only one that does is proposed.  This is evidence, not a fix:
# coord_review.xlsx offers it as a candidate row and the owner ticks or ignores
# it (CLAUDE.md rule 4).
repairs_for <- function(lat, lon, iso) {
  drop_digit <- function(v) if (abs(v) < 10) sign(v) * (abs(v) + 10) else NA_real_
  cands <- list(
    list("latitude sign flipped",      -lat,  lon),
    list("longitude sign flipped",      lat, -lon),
    list("both signs flipped",         -lat, -lon),
    list("latitude and longitude transposed", lon, lat),
    list("leading 1 lost from latitude",  drop_digit(lat), lon),
    list("leading 1 lost from longitude", lat, drop_digit(lon)))
  for (cd in cands) {
    la <- cd[[2]]; lo <- cd[[3]]
    if (is.na(la) || is.na(lo)) next
    if (abs(la) > 90 || abs(lo) > 180) next
    d <- dist_to_country(lo, la, iso)
    if (!is.na(d) && d <= THRESHOLD_KM)
      return(list(type = cd[[1]], lat = la, lon = lo, km = d))
  }
  NULL
}

# One coordinate under two or more labels naming different countries.
co$coord_key <- paste(co$latitude, co$longitude)
shared <- co %>%
  group_by(coord_key) %>%
  summarise(n_lab = n_distinct(affiliation_simple),
            n_country = n_distinct(expected_country[!is.na(expected_country)]),
            countries = paste(sort(unique(expected_country[!is.na(expected_country)])),
                              collapse = "/"),
            .groups = "drop") %>%
  filter(n_lab >= 2, n_country >= 2)
co$f_shared <- co$coord_key %in% shared$coord_key
co <- co %>% left_join(shared %>% select(coord_key, shared_countries = countries),
                       by = "coord_key")

flag_of <- function(r) {
  f <- c(
    if (isTRUE(r$f_zero))   "zero_coordinate",
    if (isTRUE(r$f_sea))    "point_in_sea",
    if (isTRUE(r$f_mismatch)) "country_mismatch",
    if (isTRUE(r$f_swap))   "possible_transposition",
    if (isTRUE(r$f_shared)) "shared_coordinate_different_countries",
    if (isTRUE(r$f_round))  "round_coordinate",
    if (isTRUE(r$f_noexp))  "no_expected_country")
  paste(f, collapse = "; ")
}
co$flag_type <- vapply(seq_len(nrow(co)), function(i) flag_of(co[i, ]), character(1))

co$repair_type <- NA_character_
co$repair_latitude <- NA_real_
co$repair_longitude <- NA_real_
for (i in which(nzchar(co$flag_type) & !is.na(co$expected_country) &
                !is.na(co$distance_km_to_expected) &
                co$distance_km_to_expected > THRESHOLD_KM)) {
  r <- repairs_for(co$latitude_num[i], co$longitude_num[i], co$expected_country[i])
  if (!is.null(r)) {
    co$repair_type[i]      <- r$type
    co$repair_latitude[i]  <- r$lat
    co$repair_longitude[i] <- r$lon
  }
}

trunc_at <- function(x, n = 120) {
  x <- gsub("[[:space:]]+", " ", x)
  ifelse(is.na(x), NA_character_,
         ifelse(nchar(x) > n, paste0(substr(x, 1, n - 1), "…"), x))
}

if (length(signed_off)) {
  hit <- co$affiliation_simple %in% signed_off & nzchar(co$flag_type)
  if (any(hit)) {
    message(sprintf("signed off with accept_as_is/note_only, not flagged: %d", sum(hit)))
    message(paste0("    ", co$affiliation_simple[hit], collapse = "\n"))
    co$flag_type[hit] <- ""
  }
}

out <- co %>%
  filter(nzchar(flag_type)) %>%
  transmute(
    affiliation_simple,
    latitude = latitude_num,
    longitude = longitude_num,
    coord_status,
    coord_source,
    n_rows = n_rows_num,
    expected_country,
    expected_country_evidence,
    point_country,
    point_country_name,
    distance_km_to_expected = round(distance_km_to_expected, 2),
    flag_type,
    repair_type,
    repair_latitude,
    repair_longitude,
    shared_coordinate_countries = shared_countries,
    affiliation_excerpt = trunc_at(affiliation_excerpt),
    google_maps = sprintf("https://www.google.com/maps/search/?api=1&query=%s,%s",
                          latitude, longitude)) %>%
  arrange(desc(!is.na(distance_km_to_expected)), desc(distance_km_to_expected),
          affiliation_simple)

dir.create(dirname(out_file), showWarnings = FALSE, recursive = TRUE)
readr::write_csv(out, out_file, na = "")

# --- summary ------------------------------------------------------------------

message(sprintf("checked %d, flagged %d", nrow(co), nrow(out)))
message("threshold = ", THRESHOLD_KM, " km")
tab <- sort(table(unlist(strsplit(out$flag_type, "; "))), decreasing = TRUE)
for (i in seq_along(tab)) message(sprintf("  %-40s %d", names(tab)[i], tab[i]))
near <- co %>% filter(!country_ok, !is.na(expected_country),
                      !is.na(distance_km_to_expected),
                      distance_km_to_expected > 0,
                      distance_km_to_expected <= THRESHOLD_KM)
message(sprintf("disagreed with maps but within %d km (not flagged): %d",
                THRESHOLD_KM, nrow(near)))
if (nrow(near)) for (i in seq_len(nrow(near)))
  message(sprintf("    %-55s %5.1f km", near$affiliation_simple[i],
                  near$distance_km_to_expected[i]))
message(sprintf("no expected country at all: %d", sum(co$f_noexp)))
ot <- co %>% filter(!is.na(point_country), !is.na(expected_country),
                    point_country != expected_country, country_ok)
if (nrow(ot)) {
  message("resolved via overseas-territory equivalence (not flagged):")
  for (i in seq_len(nrow(ot)))
    message(sprintf("    %-55s %s in %s", ot$affiliation_simple[i],
                    ot$expected_country[i], ot$point_country[i]))
}
message("written: ", out_file)
