# check_label_candidates.R -----------------------------------------------------
#
# Sweep the current affiliation_simple list for two opposite faults the
# spreadsheet cannot show, and record the suspects.  READ-ONLY except for the
# two files it writes:
#
#   output/review_label_duplicates.csv   two labels that may be one place
#   output/review_label_lumping.csv      one label that may be several places
#
#   Rscript R/check_label_candidates.R
#
# It fixes nothing and proposes nothing.  Institution identity is the project
# owner's call (CLAUDE.md rule 4); this only puts the pairs in front of him.
#
# Why it exists: review_simple_conflicts.csv only sees labels that share an
# affiliation *string*, and review_simple_lumping.csv only counts how many
# strings a label covers.  Neither notices that two labels with no string in
# common are the same institute, or that one label's strings name two countries.
#
# Method, duplicates.  Every unordered pair of labels is scored on independent
# evidence, and a pair is reported if any of it fires:
#   shared_affiliation  the two labels share an affiliation string verbatim
#                       (this is review_simple_conflicts.csv, repeated here so
#                       one file holds every duplicate signal)
#   shared_phrase       their affiliation strings share a distinctive
#                       institution phrase - one occurring under at most
#                       MAX_PHRASE_LABELS labels, so "department of medical
#                       entomology" is not treated as identity.  Reported as
#                       shared_phrase_only2, and ranked a point higher, when the
#                       phrase is under exactly these two labels and nothing
#                       else
#   acronym             one label's leading acronym is an abbreviation of an
#                       institution phrase written out under the other, in any
#                       of the three forms `abbrevs_of` generates
#   contraction         one label is a contraction of such a phrase rather than
#                       its initials, the shape a domain name takes: `uonbi`
#                       for "University of Nairobi"
#   label_text          the labels differ only in spelling, once the country
#                       is set aside, and name the same country.  Relative edit
#                       distance, so `cdc`/`ctd` is not a candidate while
#                       `wits unitversity`/`wits univeristy` is
#   same_point          their coordinates are within SAME_POINT_KM
#   near_point          within NEAR_POINT_KM, reported only alongside some text
#                       evidence, because two unrelated institutes in one city
#                       are near each other and are not duplicates
#
# A pair whose only evidence is soft - phrase, acronym or spelling - is dropped
# unless the two labels name the same country (or one names none).  Hard
# evidence, a shared affiliation string or one coordinate, is kept whatever the
# countries say: `Wits Unitversity` and `Wits University` sit 5825 km apart
# because one latitude has the wrong sign, and that pair must still be reported.
#
# Method, lumping.  Per label, over its affiliation strings:
#   multi_country       the strings name two or more different countries
#   composite_string    one single string names two or more countries, e.g.
#                       "... CDC, Atlanta, GA, USA, and Kenya Medical Research
#                       Institute ..."
#   multi_institution   two or more distinct institution phrases that are not
#                       one nested inside the other
#   multi_place         two or more distinct place fields.  The place is the
#                       last comma field that is neither a country, nor an
#                       institution, nor a street address or box number, which
#                       makes it a city proxy: `IHI Tanzania` covering both
#                       Ifakara and Dar es Salaam is the case this finds.
#
# Only labels naming two countries, two cities, or three or more institutions
# are reported.  A label covering two institution phrases on one campus is the
# ordinary state of this corpus and is already counted in
# review_simple_lumping.csv.
#
# Offline throughout: no geocoding service is contacted.
# ------------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tidyr)
  library(countrycode)
})

SAME_POINT_KM       <- 0.25   # closer than this is one site, not two
NEAR_POINT_KM       <- 2.0    # same neighbourhood; needs text evidence too
MAX_PHRASE_LABELS   <- 3L     # a phrase under more labels than this is generic
MIN_PHRASE_CHARS    <- 14L    # and a short phrase is not identity either
MAX_REL_EDIT        <- 0.25   # spelling distance as a fraction of label length
MIN_CORE_CHARS      <- 4L     # below this, edit distance is meaningless
MIN_HEADS_ALONE     <- 3L     # institutions needed to report a label on that alone

# Newest dated deliverable, so this still runs after a rebuild re-stamps them.
newest <- function(pattern) {
  f <- list.files("output", pattern = pattern, full.names = TRUE)
  if (!length(f)) stop("no file matching ", pattern, " in output/")
  sort(f, decreasing = TRUE)[1]
}
coords_file <- newest("^affiliation_simple_coords_\\d{8}\\.csv$")
lookup_file <- newest("^affiliation_lookup_\\d{8}\\.csv$")

message("coords: ", coords_file, "\nlookup: ", lookup_file)

# --- country matching, as in check_coord_sanity.R ------------------------------

cl <- countrycode::codelist[!is.na(countrycode::codelist$iso3c), ]
name_regex <- setNames(cl$country.name.en.regex, cl$iso3c)
name_regex <- name_regex[!is.na(name_regex)]

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
  GNB = "\\bguinea\\s?.?\\s?bissau\\b",
  # Truncations and misspellings that appear as trailing fields in this corpus
  # and would otherwise be read as city names.
  CMR = "\\bcameroun\\b",
  SEN = "\\bseneg\\b",
  MDG = "\\bmadegascar\\b"
)

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

# One country for a string, longest candidate first; NA when nothing resolves to
# exactly one country.  Memoised - the same strings are asked for repeatedly.
.country_cache <- new.env(parent = emptyenv())
country_of <- function(x) {
  if (is.na(x) || !nzchar(trimws(x))) return(NA_character_)
  key <- x
  if (!is.null(hit <- .country_cache[[key]])) return(hit)
  ans <- NA_character_
  for (cand in candidates(x)) {
    m <- match_set(cand)
    if (length(m) == 1L) { ans <- m; break }
  }
  if (is.na(ans)) {
    m <- match_set(x)
    if (length(m) == 1L) ans <- m
  }
  assign(key, ans, envir = .country_cache)
  ans
}

# Overseas territories fold into their sovereign, as in check_coord_sanity.R:
# an address in Saint-Denis de La Reunion that also says France names one
# country, not two.
sovereign_of <- c(
  REU = "FRA", MYT = "FRA", GLP = "FRA", MTQ = "FRA", GUF = "FRA",
  NCL = "FRA", PYF = "FRA", SPM = "FRA", WLF = "FRA", BLM = "FRA", MAF = "FRA",
  PRI = "USA", VIR = "USA", GUM = "USA", ASM = "USA", MNP = "USA",
  ABW = "NLD", CUW = "NLD", SXM = "NLD", BES = "NLD",
  GIB = "GBR", FLK = "GBR", BMU = "GBR", IMN = "GBR", JEY = "GBR", GGY = "GBR",
  SHN = "GBR", CYM = "GBR", TCA = "GBR", VGB = "GBR", MSR = "GBR", AIA = "GBR",
  HKG = "CHN", MAC = "CHN", GRL = "DNK", FRO = "DNK", ALA = "FIN", SJM = "NOR"
)

# US place names that are also country names.  "Atlanta, Georgia" is not
# Georgia the country, "Notre Dame, IN" is not India, Norfolk VA is not Norfolk
# Island.  Only suppressed when the same string also says USA, so a genuine
# Georgian or Indian affiliation is untouched.
US_COLLISION <- c("GEO", "IND", "NFK")

# Every country a single string names, so a composite affiliation naming two is
# visible.  Whole-string scan on purpose: this one wants all of them.
countries_in <- function(x) {
  if (is.na(x) || !nzchar(trimws(x))) return(character(0))
  m <- match_set(x)
  m <- unique(ifelse(m %in% names(sovereign_of), sovereign_of[m], m))
  if ("USA" %in% m) m <- setdiff(m, US_COLLISION)
  m
}

# --- data ---------------------------------------------------------------------

co <- read_csv(coords_file, col_types = cols(.default = col_character())) %>%
  mutate(lat = suppressWarnings(as.numeric(latitude)),
         lon = suppressWarnings(as.numeric(longitude)),
         n_rows = suppressWarnings(as.numeric(n_rows)))

lk <- read_csv(lookup_file, col_types = cols(
  affiliation_simple = col_character(), affiliation = col_character(),
  n_rows = col_double()))

labels <- sort(unique(co$affiliation_simple))
message(sprintf("%d labels, %d affiliation strings", length(labels), nrow(lk)))

# --- normalising ---------------------------------------------------------------

norm <- function(x) {
  y <- tolower(fold(x))
  y <- gsub("[^a-z0-9 ]+", " ", y)
  trimws(gsub("\\s+", " ", y))
}

STOP <- c("of", "the", "for", "and", "a", "an", "at", "in", "on", "de", "du",
          "des", "la", "le", "les", "et", "en", "el", "y", "da", "do", "dos",
          "und", "der", "die", "das", "per", "di", "delle", "della")

# Institution-bearing comma field, e.g. "University of Notre Dame".  Departments
# and street addresses are dropped: they are not identity.
INST_RX <- paste0("(?i)\\b(universit|universidad|universidade|institut|",
                  "laborator|laboratoire|escola|school|college|hospital|",
                  "academy|academie|ministry|ministere|council|foundation|",
                  "agency|museum|centre|center|centro|programme|program|",
                  "organisation|organization|service|station|society|trust)")
DROP_RX <- paste0("(?i)^(department|dept|departement|division|unit|section|",
                  "faculty|facult|po box|p\\.o\\.|box |bp |b\\.p\\.|",
                  "[0-9])")

inst_phrases <- function(aff) {
  parts <- trimws(strsplit(aff, ",", fixed = TRUE)[[1]])
  parts <- parts[nzchar(parts)]
  keep <- parts[grepl(INST_RX, parts, perl = TRUE) &
                !grepl(DROP_RX, parts, perl = TRUE)]
  p <- unique(norm(keep))
  p[nchar(p) >= MIN_PHRASE_CHARS]
}

# The place a string names: the last comma field that is not a country, not an
# institution, and not a street address or box number.  Usually the city; NA
# when the string names none, which is common and is not itself a fault.
NOTPLACE_RX <- paste0("(?i)(\\bunit(e|s)?\\b|\\bgroupe?\\b|\\bequipe\\b|",
                      "\\bteam\\b|\\breseau\\b|\\bnetwork\\b|\\bproje[ct]\\b|",
                      "\\bresearch\\b|\\brecherche\\b|^u[mp]?r\\b|^ea\\b)")

# A place field still carries the postcode it was written with.  Montpellier,
# "Montpellier Cedex" and "Montpellier Cedex 5" are one city.
tidy_place <- function(n) {
  n <- gsub("\\bcedex\\b\\s*[0-9]*", "", n)
  n <- gsub("\\b[a-z]{1,2}[0-9]{1,2}[a-z]?\\s+[0-9][a-z]{2}\\b", "", n)  # UK postcode
  n <- gsub("\\b[0-9]{3,6}\\b", "", n)
  trimws(gsub("\\s+", " ", n))
}

place_of <- function(aff) {
  p <- trimws(strsplit(gsub("[[:space:],.;]+$", "", aff), ",", fixed = TRUE)[[1]])
  p <- p[nzchar(p)]
  for (i in rev(seq_along(p))) {
    f <- p[i]
    if (length(match_set(f))) next                          # a country
    if (grepl(INST_RX, f, perl = TRUE)) next                # an institution
    if (grepl(DROP_RX, f, perl = TRUE)) next                # a department or address
    if (grepl(NOTPLACE_RX, f, perl = TRUE)) next            # a research unit
    if (grepl("(?i)\\b(department|departement|division|section|dept|facult)",
              f, perl = TRUE)) next                         # a department
    if (grepl("^[A-Za-z]{1,2}$", trimws(f))) next           # a state code
    n <- tidy_place(norm(f))
    if (nchar(n) >= 3) return(n)
  }
  NA_character_
}

# "Bobo Dioulasso" and "Antenne de Bobo Dioulasso" are one city written twice.
# Keep the shortest of any nested set.
distinct_places <- function(p) {
  p <- p[!is.na(p)]
  if (length(p) < 2) return(p)
  keep <- rep(TRUE, length(p))
  for (i in seq_along(p)) for (j in seq_along(p))
    if (i != j && keep[i] && keep[j] && grepl(p[j], p[i], fixed = TRUE)) keep[i] <- FALSE
  p[keep]
}

# The abbreviations a phrase could plausibly be written as.  Three forms,
# because this corpus uses all three: initials of the significant words
# ("liverpool school of tropical medicine" -> lstm), initials of every word
# including the stop words (-> lsotm), and the stop words spelt out
# ("university of nairobi" -> uofn).  Without the last two, every `UoN` /
# `UoK` / `UofK` style label is invisible to the acronym test, since its `o`
# comes from the "of" that the first form throws away.
abbrevs_of <- function(phrase) {
  w <- strsplit(phrase, " ", fixed = TRUE)[[1]]
  w <- w[nzchar(w)]
  if (length(w) < 2L) return(character(0))
  sig <- w[!(w %in% STOP)]
  out <- character(0)
  if (length(sig) >= 2L) out <- c(out, paste(substr(sig, 1L, 1L), collapse = ""))
  out <- c(out, paste(substr(w, 1L, 1L), collapse = ""))
  out <- c(out, paste(ifelse(w %in% STOP, w, substr(w, 1L, 1L)), collapse = ""))
  unique(out[nchar(out) >= 2L])
}

# A contraction rather than an initialism: `uonbi` for "University of Nairobi",
# the shape institutional domain names take - the word initials, then a
# fragment of the last word.  A plain subsequence test is useless here: a long
# phrase contains nearly every short string in order, and it produced 105 pairs
# of which one was real.  So the core must *begin* with one of the phrase's
# abbreviations and the rest must run through the final word in order.
is_contraction <- function(core, phrase) {
  a <- gsub(" ", "", core)
  if (nchar(a) < 4L || nchar(a) > 8L) return(FALSE)
  ab <- abbrevs_of(phrase)
  ab <- ab[nchar(ab) >= 2L & nchar(ab) < nchar(a)]
  ab <- ab[startsWith(a, ab)]
  if (!length(ab)) return(FALSE)
  words <- strsplit(phrase, " ", fixed = TRUE)[[1]]
  last <- words[length(words)]
  tail_chars <- strsplit(substring(a, nchar(ab[which.max(nchar(ab))]) + 1L), "")[[1]]
  b <- strsplit(last, "")[[1]]
  j <- 1L
  for (ch in tail_chars) {
    k <- which(b[j:length(b)] == ch)
    if (!length(k)) return(FALSE)
    j <- j + k[1]
  }
  TRUE
}

# The label with its trailing country set aside, so `UoK Sudan` and `UofK Sudan`
# are compared on `uok` / `uofk`.
label_core <- function(lab) {
  n <- norm(lab)
  cn <- country_of(lab)
  if (!is.na(cn)) {
    for (cand in candidates(lab))
      if (identical(match_set(cand), cn)) {
        nc <- norm(cand)
        if (nzchar(nc) && nchar(nc) < nchar(n))
          n <- trimws(sub(paste0(nc, "$"), "", n))
      }
  }
  n
}

# --- per-label facts -----------------------------------------------------------

aff_by_label <- lk %>%
  filter(!is.na(affiliation), !is.na(affiliation_simple)) %>%
  group_by(affiliation_simple) %>%
  summarise(affs = list(affiliation), .groups = "drop")

lab_tbl <- co %>%
  select(affiliation_simple, coord_status, lat, lon, n_rows) %>%
  left_join(aff_by_label, by = "affiliation_simple") %>%
  mutate(affs = ifelse(vapply(affs, is.null, logical(1)), list(character(0)), affs))

lab_tbl$core     <- vapply(lab_tbl$affiliation_simple, label_core, character(1))
lab_tbl$country  <- vapply(lab_tbl$affiliation_simple, country_of, character(1))
lab_tbl$phrases  <- lapply(lab_tbl$affs, function(a) unique(unlist(lapply(a, inst_phrases))))
lab_tbl$acronym  <- vapply(lab_tbl$affiliation_simple, function(x) {
  tok <- strsplit(trimws(x), "\\s+")[[1]][1]
  tok <- gsub("[^A-Za-z0-9]", "", tok)
  if (is.na(tok) || nchar(tok) < 2L || nchar(tok) > 8L) return(NA_character_)
  if (!grepl("[A-Z]", tok)) return(NA_character_)
  if (grepl("^[A-Z][a-z]+$", tok)) return(NA_character_)   # a word, not an acronym
  tolower(tok)
}, character(1))

message(sprintf("%d labels carry at least one institution phrase",
                sum(lengths(lab_tbl$phrases) > 0)))

# --- part A: duplicate candidates ----------------------------------------------

pair_key <- function(a, b) ifelse(a < b, paste0(a, "", b), paste0(b, "", a))

ev <- list()   # data frames of (key, evidence, detail)

# 1. the same affiliation string under two labels
shared_aff <- lk %>%
  filter(!is.na(affiliation), !is.na(affiliation_simple)) %>%
  distinct(affiliation, affiliation_simple) %>%
  group_by(affiliation) %>%
  filter(n() > 1) %>%
  summarise(labs = list(sort(unique(affiliation_simple))), .groups = "drop")
if (nrow(shared_aff)) {
  rows <- do.call(rbind, lapply(seq_len(nrow(shared_aff)), function(i) {
    labs <- shared_aff$labs[[i]]
    cb <- utils::combn(labs, 2)
    data.frame(key = pair_key(cb[1, ], cb[2, ]),
               evidence = "shared_affiliation",
               detail = substr(shared_aff$affiliation[i], 1, 120),
               stringsAsFactors = FALSE)
  }))
  ev[["shared_affiliation"]] <- rows
}

# 2. a distinctive institution phrase under two labels
ph <- lab_tbl %>%
  select(affiliation_simple, phrases) %>%
  unnest_longer(phrases, values_to = "phrase") %>%
  filter(!is.na(phrase)) %>%
  distinct(affiliation_simple, phrase)
ph_n <- ph %>% count(phrase, name = "n_labels")
ph_ok <- ph %>% inner_join(filter(ph_n, n_labels > 1, n_labels <= MAX_PHRASE_LABELS),
                           by = "phrase")
ph_pairwise <- ph_ok %>% filter(n_labels == 2L) %>% pull(phrase) %>% unique()
if (nrow(ph_ok)) {
  rows <- ph_ok %>%
    group_by(phrase) %>%
    summarise(labs = list(sort(unique(affiliation_simple))), .groups = "drop") %>%
    filter(lengths(labs) > 1)
  rows <- do.call(rbind, lapply(seq_len(nrow(rows)), function(i) {
    cb <- utils::combn(rows$labs[[i]], 2)
    data.frame(key = pair_key(cb[1, ], cb[2, ]),
               evidence = "shared_phrase",
               detail = rows$phrase[i], stringsAsFactors = FALSE)
  }))
  rows$evidence[rows$detail %in% ph_pairwise] <- "shared_phrase_only2"
  ev[["shared_phrase"]] <- rows
}

# 3. one label's acronym written out under another
ph_init <- ph %>%
  mutate(init = lapply(phrase, abbrevs_of)) %>%
  tidyr::unnest_longer(init, values_to = "init") %>%
  filter(!is.na(init))
acro <- lab_tbl %>% filter(!is.na(acronym)) %>% select(affiliation_simple, acronym)
hit <- acro %>%
  inner_join(ph_init, by = c("acronym" = "init"),
             relationship = "many-to-many") %>%
  filter(affiliation_simple.x != affiliation_simple.y)
if (nrow(hit)) {
  ev[["acronym"]] <- data.frame(
    key = pair_key(hit$affiliation_simple.x, hit$affiliation_simple.y),
    evidence = "acronym",
    detail = paste0(hit$acronym, " = ", hit$phrase), stringsAsFactors = FALSE)
}

# 3b. a label that is a contraction of an institution written out elsewhere
ct <- lab_tbl %>%
  select(affiliation_simple, core) %>%
  filter(nchar(gsub(" ", "", core)) >= 4, nchar(gsub(" ", "", core)) <= 7)
if (nrow(ct)) {
  cand_ct <- ct %>%
    inner_join(ph, by = character(), relationship = "many-to-many") %>%
    filter(affiliation_simple.x != affiliation_simple.y)
  keep_ct <- mapply(is_contraction, cand_ct$core, cand_ct$phrase)
  cand_ct <- cand_ct[keep_ct, , drop = FALSE]
  if (nrow(cand_ct))
    ev[["contraction"]] <- data.frame(
      key = pair_key(cand_ct$affiliation_simple.x, cand_ct$affiliation_simple.y),
      evidence = "contraction",
      detail = paste0(cand_ct$core, " <- ", cand_ct$phrase),
      stringsAsFactors = FALSE)
}

# 4. labels that differ only in spelling, same country
core <- lab_tbl$core
names(core) <- lab_tbl$affiliation_simple
keep <- nchar(core) >= MIN_CORE_CHARS
cn <- lab_tbl$country
d <- adist(core[keep], core[keep])
span <- outer(nchar(core[keep]), nchar(core[keep]), pmax)
idx <- which(upper.tri(d) & d > 0 & d / span <= MAX_REL_EDIT, arr.ind = TRUE)
if (nrow(idx)) {
  a <- lab_tbl$affiliation_simple[keep][idx[, 1]]
  b <- lab_tbl$affiliation_simple[keep][idx[, 2]]
  ca <- cn[keep][idx[, 1]]; cb2 <- cn[keep][idx[, 2]]
  same_country <- (is.na(ca) & is.na(cb2)) | (!is.na(ca) & !is.na(cb2) & ca == cb2)
  if (any(same_country))
    ev[["label_text"]] <- data.frame(
      key = pair_key(a[same_country], b[same_country]),
      evidence = "label_text",
      detail = paste0(core[keep][idx[same_country, 1]], " / ",
                      core[keep][idx[same_country, 2]]),
      stringsAsFactors = FALSE)
}

# 5. coordinates on top of each other
hav <- function(la1, lo1, la2, lo2) {
  R <- 6371.0; p <- pi / 180
  x <- sin((la2 - la1) * p / 2)^2 +
       cos(la1 * p) * cos(la2 * p) * sin((lo2 - lo1) * p / 2)^2
  2 * R * asin(pmin(1, sqrt(x)))
}
withc <- lab_tbl %>% filter(!is.na(lat), !is.na(lon))
if (nrow(withc) > 1) {
  n <- nrow(withc)
  ii <- rep(seq_len(n - 1), times = (n - 1):1)
  jj <- unlist(lapply(seq_len(n - 1), function(i) (i + 1):n))
  dk <- hav(withc$lat[ii], withc$lon[ii], withc$lat[jj], withc$lon[jj])
  sel <- dk <= NEAR_POINT_KM
  if (any(sel))
    ev[["point"]] <- data.frame(
      key = pair_key(withc$affiliation_simple[ii][sel], withc$affiliation_simple[jj][sel]),
      evidence = ifelse(dk[sel] <= SAME_POINT_KM, "same_point", "near_point"),
      detail = sprintf("%.3f km apart", dk[sel]), stringsAsFactors = FALSE)
}

all_ev <- bind_rows(ev)

if (nrow(all_ev) == 0) {
  message("no duplicate candidates")
  dup <- tibble(label_a = character(), label_b = character())
} else {
  grouped <- all_ev %>%
    distinct(key, evidence, detail) %>%
    group_by(key, evidence) %>%
    summarise(detail = paste(unique(detail), collapse = " | "), .groups = "drop") %>%
    group_by(key) %>%
    summarise(evidence = paste(sort(unique(evidence)), collapse = "+"),
              detail = paste(paste0(evidence, ": ", detail), collapse = " || "),
              .groups = "drop")

  parts <- strsplit(grouped$key, "", fixed = TRUE)
  dup <- tibble(
    label_a = vapply(parts, `[`, character(1), 1),
    label_b = vapply(parts, `[`, character(1), 2),
    evidence = grouped$evidence,
    detail = grouped$detail)

  # near_point on its own is a city, not a duplicate: drop it.
  dup <- dup %>% filter(evidence != "near_point")

  info <- lab_tbl %>% select(affiliation_simple, coord_status, lat, lon, n_rows,
                             country)
  dup <- dup %>%
    left_join(info, by = c("label_a" = "affiliation_simple")) %>%
    rename(status_a = coord_status, lat_a = lat, lon_a = lon,
           n_rows_a = n_rows, country_a = country) %>%
    left_join(info, by = c("label_b" = "affiliation_simple")) %>%
    rename(status_b = coord_status, lat_b = lat, lon_b = lon,
           n_rows_b = n_rows, country_b = country) %>%
    mutate(distance_km = ifelse(is.na(lat_a) | is.na(lat_b), NA_real_,
                                round(hav(lat_a, lon_a, lat_b, lon_b), 3)),
           same_country = is.na(country_a) | is.na(country_b) |
                          country_a == country_b,
           hard = grepl("shared_affiliation|same_point", evidence),
           n_signals = lengths(strsplit(evidence, "+", fixed = TRUE)),
           strength = n_signals +
             grepl("shared_affiliation", evidence) * 2 +
             grepl("same_point", evidence) * 2 +
             grepl("shared_phrase", evidence) * 1 +
             grepl("shared_phrase_only2", evidence) * 1 +
             grepl("contraction", evidence) * 1) %>%
    filter(hard | same_country) %>%
    arrange(desc(strength), desc(n_rows_a + n_rows_b)) %>%
    select(label_a, label_b, evidence, n_signals, strength,
           n_rows_a, n_rows_b, status_a, status_b,
           lat_a, lon_a, lat_b, lon_b, distance_km,
           same_country, country_a, country_b, detail)
}

write_csv(dup, "output/review_label_duplicates.csv", na = "")
message(sprintf("duplicates: %d pairs -> output/review_label_duplicates.csv", nrow(dup)))

# --- part B: lumping candidates -------------------------------------------------

lump <- lab_tbl %>%
  rowwise() %>%
  mutate(
    n_affs = length(affs),
    per_string_countries = list(lapply(affs, countries_in)),
    countries = list(local({
      m <- sort(unique(unlist(per_string_countries)))
      if ("USA" %in% m) setdiff(m, US_COLLISION) else m
    })),
    n_countries = length(countries),
    composite = sum(lengths(per_string_countries) > 1),
    places = list(distinct_places(sort(unique(vapply(affs, place_of, character(1)))))),
    n_places = length(places),
    n_phrases = length(phrases)
  ) %>%
  ungroup()

# Two institution phrases count as distinct only when neither contains the other
# - "university of notre dame" and "university of notre dame galvin life
# sciences" are one institution written twice.
distinct_heads <- function(p) {
  if (length(p) < 2) return(p)
  keep <- rep(TRUE, length(p))
  for (i in seq_along(p)) for (j in seq_along(p))
    if (i != j && keep[i] && keep[j] && grepl(p[j], p[i], fixed = TRUE)) keep[i] <- FALSE
  p[keep]
}
lump$heads   <- lapply(lump$phrases, distinct_heads)
lump$n_heads <- lengths(lump$heads)

lump_out <- lump %>%
  mutate(flags = paste(c(character(0)), collapse = "")) %>%
  rowwise() %>%
  mutate(flags = paste(c(
    if (n_countries > 1)  "multi_country",
    if (composite > 0)    "composite_string",
    if (n_heads > 1)      "multi_institution",
    if (n_places > 1)     "multi_place"), collapse = "+")) %>%
  ungroup() %>%
  filter(n_countries > 1 | composite > 0 | n_places > 1 |
         n_heads >= MIN_HEADS_ALONE) %>%
  mutate(
    strength = (n_countries > 1) * 3 + (composite > 0) * 2 +
               (n_places > 1) * 2 + (n_heads > 1) * 1,
    countries_named = vapply(countries, paste, character(1), collapse = "; "),
    institutions = vapply(heads, function(h)
      paste(substr(h, 1, 60), collapse = " | "), character(1)),
    places_named = vapply(places, function(p)
      paste(utils::head(p, 8), collapse = " | "), character(1))) %>%
  arrange(desc(strength), desc(n_countries), desc(n_rows)) %>%
  select(affiliation_simple, flags, strength, n_rows, n_affs,
         coord_status, lat, lon, n_countries, countries_named,
         n_heads, institutions, n_places, places_named)

write_csv(lump_out, "output/review_label_lumping.csv", na = "")
message(sprintf("lumping: %d labels -> output/review_label_lumping.csv", nrow(lump_out)))

message("\nduplicate signals:")
print(as.data.frame(count(dup, evidence, sort = TRUE)))
message("\nlumping flags:")
print(as.data.frame(count(lump_out, flags, sort = TRUE)))
