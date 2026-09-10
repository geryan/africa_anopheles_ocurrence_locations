# tidy_affiliations.R -------------------------------------------------------
#
# Rebuilds the three affiliation deliverables from the source spreadsheets.
# Run from the project root (the RStudio project working directory).
#
# NOT EXECUTED BY ITS AUTHOR. R was unavailable in the environment where this
# was written, so this script has never been run. It is a line-for-line
# transcription of tidy_affiliations.py, which was run and whose outputs are
# shipped alongside it. Two guards are therefore built in:
#
#   * a self-test (section 0) that stops immediately if iconv on this machine
#     does not behave as the encoding repair assumes;
#   * a parity check (section 12) that compares what this script produces
#     against the shipped CSVs and stops on any differing cell.
#
# If both pass, this script and the Python reference agree exactly.
#
# Inputs   data/affiliation_decisions.csv                (your judgement calls; optional)
#          data/twatasha_final_data/Affiliation spreadsheet_version 3. 26 Sep. 2024.xlsx
#          data/twatasha_final_data/unique_entries 26.sep.2024.xls
#          data/unique_affiliations_Lat_Long.csv      (Mac Roman on disk)
#          output/twatasha_todo.csv                   (clean UTF-8 reference)
#
# Outputs  output/affiliations_complete_<stamp>.csv
#          output/affiliation_lookup_<stamp>.csv
#          output/affiliation_simple_coords_<stamp>.csv
#          output/diff_report_<stamp>.csv
#          output/decisions_report.csv
#          output/review_*.csv
# ---------------------------------------------------------------------------

library(readxl)
library(readr)
library(dplyr)
library(stringr)
library(stringi)
library(purrr)
library(tibble)

STAMP     <- "20260817"   # set to format(Sys.Date(), "%Y%m%d") for a fresh stamp
OUT       <- "output"
PARITY_TO <- "output/shipped"   # shipped reference CSVs; the script writes to OUT,
                                # so the two must be different directories

# == 0. encoding repair, and the self-test that gates it ====================
#
# Two separate corruptions, each a byte-level misreading, each invertible:
#   layer A   UTF-8 bytes displayed through Mac Roman   "Deuxi√®me" -> "Deuxième"
#   layer B   CP1252 bytes displayed through Mac Roman  "GÈnÈtique" -> "Génétique"

MARK_A <- strsplit("√‚Ä†©≠¥£¢ß∞", "")[[1]]
MARK_B <- strsplit("ÈÙËÏÌÓÔÒÚÛÊÁÎÍ", "")[[1]]

to_mac_bytes <- function(s) {
  r <- iconv(s, from = "UTF-8", to = "macintosh", toRaw = TRUE)[[1]]
  if (is.null(r)) NULL else r
}

layer_A <- function(s) {                       # mac bytes reinterpreted as UTF-8
  r <- to_mac_bytes(s); if (is.null(r)) return(s)
  out <- rawToChar(r); Encoding(out) <- "UTF-8"
  if (validUTF8(out)) out else s
}

layer_B <- function(s) {                       # mac bytes reinterpreted as CP1252
  r <- to_mac_bytes(s); if (is.null(r)) return(s)
  out <- iconv(rawToChar(r), from = "windows-1252", to = "UTF-8")
  if (is.na(out)) s else out
}

repair_one <- function(s) {
  if (is.na(s)) return(NA_character_)
  cur <- s
  for (i in 1:3) {
    if (any(strsplit(cur, "")[[1]] %in% MARK_A)) {
      nxt <- layer_A(cur)
      if (!identical(nxt, cur)) { cur <- nxt; next }
    }
    break
  }
  if (any(strsplit(cur, "")[[1]] %in% MARK_B)) {
    nxt <- layer_B(cur)
    if (!identical(nxt, cur)) cur <- nxt
  }
  cur
}
repair <- function(x) vapply(x, repair_one, character(1), USE.NAMES = FALSE)

# -- us / uk find-and-replace reversal --------------------------------------
# Only mid-word occurrences are damage; standalone `United States` / `United
# Kingdom` were a deliberate expansion and are left alone.
MIDWORD <- "(?<=\\w)United (?:States|Kingdom)|United (?:States|Kingdom)(?=\\w)"

unreplace_one <- function(s) {
  if (is.na(s) || !str_detect(s, "United States|United Kingdom")) return(s)
  m <- gregexpr(MIDWORD, s, perl = TRUE)[[1]]
  if (m[1] == -1) return(s)
  starts <- as.integer(m); lens <- attr(m, "match.length")
  out <- ""; i <- 1L
  for (j in seq_along(starts)) {
    st <- starts[j]; en <- st + lens[j] - 1L
    out <- paste0(out, substr(s, i, st - 1L))
    short  <- if (str_detect(substr(s, st, en), "States")) "us" else "uk"
    before <- if (st > 1L)        substr(s, st - 1L, st - 1L) else ""
    after  <- if (en < nchar(s))  substr(s, en + 1L, en + 1L) else ""
    # The following character decides: `MUnited Stateseum` is Museum, not
    # MUSeum, because the M is only capitalised as the first letter of the
    # word. Fall back to the preceding character when nothing follows.
    upper <- if (str_detect(after,  "[A-Za-z]")) str_detect(after,  "[A-Z]")
        else if (str_detect(before, "[A-Za-z]")) str_detect(before, "[A-Z]")
        else FALSE
    out <- paste0(out, if (upper) toupper(short) else short)
    i <- en + 1L
  }
  paste0(out, substr(s, i, nchar(s)))
}
unreplace <- function(x) vapply(x, unreplace_one, character(1), USE.NAMES = FALSE)

squash <- function(x) {
  x <- str_replace_all(x, "\\u200b", "")
  str_trim(str_replace_all(x, "\\s+", " "))
}

deaccent <- function(x) stri_trans_general(x, "Latin-ASCII")

# citation match key: encoding-repaired, us/uk-neutral, punctuation-free
SENT_US <- "\u0001"; SENT_UK <- "\u0002"   # sentinels: keep us/uk distinguishable
ckey <- function(x) {
  x <- repair(x)
  x <- str_replace_all(x, "United States",  SENT_US)
  x <- str_replace_all(x, "United Kingdom", SENT_UK)
  x <- str_replace_all(x, regex("usa", ignore_case = TRUE), SENT_US)
  x <- str_replace_all(x, regex("us",  ignore_case = TRUE), SENT_US)
  x <- str_replace_all(x, regex("uk",  ignore_case = TRUE), SENT_UK)
  x <- str_replace_all(x, "<[^>]+>", "")
  str_replace_all(tolower(deaccent(x)), "[^0-9a-z\\u0001\\u0002]+", "")
}
ckey_nodigit <- function(x) str_replace_all(ckey(x), "[0-9]", "")

# label keys
label_key <- function(x) str_replace_all(tolower(deaccent(x)), "[^a-z0-9]", "")
join_key  <- function(x) {                       # tolerant of the us/uk expansion
  x <- str_replace_all(x, "United States",  SENT_US)
  x <- str_replace_all(x, "United Kingdom", SENT_UK)
  x <- str_replace_all(x, regex("u\\.?s\\.?a\\.?", ignore_case = TRUE), SENT_US)
  x <- str_replace_all(x, regex("u\\.?s\\.?",      ignore_case = TRUE), SENT_US)
  x <- str_replace_all(x, regex("u\\.?k\\.?",      ignore_case = TRUE), SENT_UK)
  str_replace_all(tolower(deaccent(x)), "[^a-z0-9\\u0001\\u0002]", "")
}

# -- SELF-TEST: stop now if this machine's iconv disagrees ------------------
selftest <- list(
  c(repair_one("Deuxi√®me"),                       "Deuxième"),
  c(repair_one("GÈnÈtique"),                       "Génétique"),
  c(repair_one("ContrÙle"),                             "Contrôle"),
  c(repair_one("YaoundÈ"),                              "Yaoundé"),
  c(unreplace_one("MUnited Stateseum"),                      "Museum"),
  c(unreplace_one("KNUnited StatesT"),                       "KNUST"),
  c(unreplace_one("United StatesTTB"),                       "USTTB"),
  c(unreplace_one("CampUnited States"),                      "Campus"),
  c(unreplace_one("Anopheles funestUnited States"),          "Anopheles funestus"),
  c(unreplace_one("Atlanta, Georgia, United States"),        "Atlanta, Georgia, United States"),
  c(unreplace_one("LSHTM United Kingdom"),                   "LSHTM United Kingdom")
)
failed <- Filter(function(p) !identical(p[1], p[2]), selftest)
if (length(failed)) {
  for (p in failed) message("  got: ", p[1], "   expected: ", p[2])
  stop("encoding/us-uk self-test failed. iconv on this machine does not support\n",
       "  the 'macintosh' encoding as assumed, or stringi is missing. Do not trust\n",
       "  the output; use the shipped CSVs instead.", call. = FALSE)
}
message("self-test passed (", length(selftest), " cases)")

# == 1. load =================================================================
v3 <- read_excel("data/twatasha_final_data/Affiliation spreadsheet_version 3. 26 Sep. 2024.xlsx",
                 col_types = "text") %>%
  rename_with(str_trim) %>%
  rename(affiliation_original = `affiliation - original`) %>%
  select(source_citation, n, affiliation_original, affiliation, affiliation_simple) %>%
  mutate(row_xlsx = row_number() + 1L)

# Papers in twatasha_todo.csv that version 3 never gave an affiliation cannot be
# fixed by a decision - there is no row to decide about. They are appended from
# data/added_affiliations.csv so the source spreadsheet stays the artefact it was
# delivered as, and row_xlsx from 90001 up marks a row as coming from that file.
# Mirrors tidy_affiliations.py; like the rest of this file, never executed.
F_ADD <- "data/added_affiliations.csv"
N_ADDED <- 0L
if (file.exists(F_ADD)) {
  add <- read_csv(F_ADD, col_types = cols(.default = "c")) %>%
    mutate(across(everything(), ~ ifelse(is.na(.x), "", .x))) %>%
    filter(str_trim(source_citation) != "")
  need <- setdiff(c("source_citation", "affiliation", "affiliation_simple",
                    "note", "added_on"), names(add))
  if (length(need))
    stop(F_ADD, " is missing columns: ", paste(need, collapse = ", "), call. = FALSE)
  if (nrow(add)) {
    na_if_blank <- function(x) ifelse(str_trim(x) == "", NA_character_, x)
    v3 <- bind_rows(v3, tibble(
      source_citation      = add$source_citation,
      n                    = NA_character_,
      affiliation_original = NA_character_,
      affiliation          = na_if_blank(add$affiliation),
      affiliation_simple   = na_if_blank(add$affiliation_simple),
      row_xlsx             = seq_len(nrow(add)) + 90000L))
    N_ADDED <- nrow(add)
  }
}

orig <- v3
todo <- read_csv("output/twatasha_todo.csv", col_types = cols(.default = "c"))
ue   <- read_excel("data/twatasha_final_data/unique_entries 26.sep.2024.xls", col_types = "text")
ull  <- read_csv("data/unique_affiliations_Lat_Long.csv",
                 col_types = cols(.default = "c"),
                 locale = locale(encoding = "macintosh"))

# == 1b. decisions ===========================================================
# data/affiliation_decisions.csv records your judgement calls so they survive
# every re-run. Absent file is fine: no decisions.
F_DEC     <- "data/affiliation_decisions.csv"
DEC_COLS  <- c("decision_type", "target", "new_value", "latitude", "longitude",
               "note", "decided_on")
DEC_TYPES <- c("token_replacement", "affiliation_relabel", "label_rename",
               "coordinate", "accept_as_is", "note_only")

DEC_REPORT <- list()
dec_log <- function(d, status, n_affected = 0L, message = "") {
  DEC_REPORT[[length(DEC_REPORT) + 1L]] <<- tibble(
    decision_type = d$decision_type, target = d$target, new_value = d$new_value,
    latitude = d$latitude, longitude = d$longitude, status = status,
    n_affected = as.integer(n_affected), message = message,
    note = d$note, decided_on = d$decided_on)
  invisible(NULL)
}

DECISIONS <- list()
if (file.exists(F_DEC)) {
  dec_raw <- read_csv(F_DEC, col_types = cols(.default = "c"), na = character())
  miss <- setdiff(DEC_COLS, names(dec_raw))
  if (length(miss))
    stop(F_DEC, " is missing required columns: ", paste(miss, collapse = ", "),
         "\n  expected header: ", paste(DEC_COLS, collapse = ","), call. = FALSE)
  dec_raw <- dec_raw[, DEC_COLS]
  for (i in seq_len(nrow(dec_raw))) {
    rec <- lapply(dec_raw[i, ], function(v) if (is.na(v)) "" else str_trim(v))
    if (all(unlist(rec) == "")) next
    DECISIONS[[length(DECISIONS) + 1L]] <- rec
  }
  message("decisions loaded: ", length(DECISIONS))
} else {
  message("no decisions file at ", F_DEC, " (nothing to apply)")
}

CHANGES <- list()
add_change <- function(rows, column, before, after, reason) {
  keep <- !is.na(before) | !is.na(after)
  keep <- keep & (is.na(before) != is.na(after) |
                    (!is.na(before) & !is.na(after) & before != after))
  if (!any(keep)) return(invisible(NULL))
  CHANGES[[length(CHANGES) + 1L]] <<- tibble(
    row_xlsx = rows[keep], column = column, reason = reason,
    before = coalesce(before[keep], ""), after = coalesce(after[keep], ""))
  invisible(NULL)
}

# == 2. repair encoding ======================================================
for (col in c("source_citation", "affiliation_original", "affiliation", "affiliation_simple")) {
  before <- v3[[col]]; after <- repair(before)
  add_change(v3$row_xlsx, col, before, after, "encoding")
  v3[[col]] <- after
}
for (col in c("affiliation", "affiliation_simple", "Note")) {
  ue[[col]]  <- repair(ue[[col]])
  ull[[col]] <- repair(ull[[col]])
}

# == 3. restore source_citation and n ========================================
ffill <- function(x) {                    # last non-missing value carried forward
  idx <- cumsum(!is.na(x)); idx[idx == 0L] <- NA_integer_
  x[!is.na(x)][idx]
}
blank_before <- is.na(v3$source_citation)
v3$source_citation <- ffill(v3$source_citation)
add_change(v3$row_xlsx[blank_before], "source_citation",
           rep(NA_character_, sum(blank_before)), v3$source_citation[blank_before],
           "blank-continuation-row (forward fill)")

todo_k  <- setNames(todo$source_citation, ckey(todo$source_citation))
kn      <- split(todo$source_citation, ckey_nodigit(todo$source_citation))
kn      <- lapply(kn, function(v) unique(v))
todo_n  <- setNames(todo$n, todo$source_citation)

resolve_one <- function(sc) {
  if (is.na(sc)) return(c(NA_character_, "blank"))
  if (sc %in% todo$source_citation) return(c(sc, "exact"))
  k <- ckey(sc)
  if (k %in% names(todo_k)) return(c(unname(todo_k[[k]]), "us-uk-neutral key"))
  cand <- kn[[ckey_nodigit(sc)]]
  if (!is.null(cand) && length(cand) == 1L)
    return(c(cand, "digit-stripped key (drag-down page number)"))
  if (!is.null(cand)) return(c(NA_character_, paste0("ambiguous (", length(cand), " candidates)")))
  c(NA_character_, "unmatched")
}
res <- t(vapply(v3$source_citation, resolve_one, character(2), USE.NAMES = FALSE))
v3$sc_resolved <- res[, 1]; v3$sc_how <- res[, 2]
UNMATCHED <- filter(v3, is.na(sc_resolved))

hit <- !is.na(v3$sc_resolved)
add_change(v3$row_xlsx[hit], "source_citation", v3$source_citation[hit], v3$sc_resolved[hit],
           paste0("re-keyed to twatasha_todo.csv (", v3$sc_how[hit], ")"))
v3$source_citation <- coalesce(v3$sc_resolved, v3$source_citation)

n_new <- unname(todo_n[v3$source_citation])
got <- !is.na(n_new)
add_change(v3$row_xlsx[got], "n", v3$n[got], n_new[got], "re-keyed to twatasha_todo.csv")
v3$n <- coalesce(n_new, v3$n)

# == 4. reverse mid-word us/uk ==============================================
# `token_replacement` decisions override the inferred case for a whole
# whitespace-delimited token; everything else falls through to unreplace().
TOKEN_OVERRIDE <- list()
for (d in DECISIONS) {
  if (d$decision_type != "token_replacement") next
  if (d$target == "" || d$new_value == "") {
    dec_log(d, "bad_decision", 0L, "token_replacement needs target and new_value"); next
  }
  TOKEN_OVERRIDE[[d$target]] <- d$new_value
}
# str_escape() is stringr >= 1.5; do it by hand so older installs work.
rx_escape <- function(s) gsub("([\\^$.|?*+()\\[\\]{}\\\\])", "\\\\\\1", s, perl = TRUE)
rx_replacement <- function(s) gsub("([\\\\$])", "\\\\\\1", s, perl = TRUE)
tok_pattern <- function(tk) paste0("(?<!\\w)", rx_escape(tk), "(?!\\w)")
count_token <- function(x, tk)
  sum(str_count(x[!is.na(x)], regex(tok_pattern(tk))))
apply_token_overrides <- function(x) {
  for (tk in names(TOKEN_OVERRIDE))
    x <- str_replace_all(x, regex(tok_pattern(tk)), rx_replacement(TOKEN_OVERRIDE[[tk]]))
  x
}
unreplace_decided <- function(x) unreplace(apply_token_overrides(x))

# self-test for the override machinery: lookarounds and regex escaping must work
local({
  probe <- "MUnited Stateseum"
  got <- str_replace_all("The MUnited Stateseum, London",
                         regex(tok_pattern(probe)), rx_replacement("Museum"))
  if (!identical(got, "The Museum, London"))
    stop("token_replacement self-test failed: regex lookaround or escaping is not\n",
         "  behaving as assumed on this machine. Decisions of type token_replacement\n",
         "  would silently misfire. Use the shipped CSVs instead.", call. = FALSE)
})
TOKEN_HITS <- setNames(integer(length(TOKEN_OVERRIDE)), names(TOKEN_OVERRIDE))
for (col in c("affiliation_original", "affiliation", "affiliation_simple"))
  for (tk in names(TOKEN_OVERRIDE))
    TOKEN_HITS[tk] <- TOKEN_HITS[tk] + count_token(v3[[col]], tk)

TOKENS <- list()
for (col in c("affiliation_original", "affiliation", "affiliation_simple")) {
  before <- v3[[col]]; after <- unreplace_decided(before)
  changed <- which(!is.na(before) & before != after)
  add_change(v3$row_xlsx[changed], col, before[changed], after[changed],
             "mid-word US/UK find-replace reversed")
  for (i in changed) {
    s <- before[i]
    m <- gregexpr(MIDWORD, s, perl = TRUE)[[1]]
    for (j in seq_along(m)) {
      st <- as.integer(m)[j]; en <- st + attr(m, "match.length")[j] - 1L
      lo <- max(unlist(gregexpr(" ", substr(s, 1, st - 1L), fixed = TRUE)), 0L) + 1L
      rest <- regexpr(" ", substr(s, en + 1L, nchar(s)), fixed = TRUE)
      hi <- if (rest == -1L) nchar(s) else en + rest - 1L
      tok <- str_replace_all(substr(s, lo, hi), "^[ .,;:()\\[\\]]+|[ .,;:()\\[\\]]+$", "")
      TOKENS[[length(TOKENS) + 1L]] <- tibble(column = col, broken_token = tok,
                                              proposed = unreplace_one(tok))
    }
  }
  v3[[col]] <- after
}
for (col in c("affiliation", "affiliation_simple")) {
  ue[[col]]  <- unreplace_decided(ue[[col]])
  ull[[col]] <- unreplace_decided(ull[[col]])
}
for (d in DECISIONS) {
  if (d$decision_type != "token_replacement") next
  if (!(d$target %in% names(TOKEN_OVERRIDE))) next
  n <- if (d$target %in% names(TOKEN_HITS)) TOKEN_HITS[[d$target]] else 0L
  dec_log(d, if (n > 0L) "applied" else "no_match", n,
          if (n > 0L) "" else "token not present in the spreadsheet")
}

# == 5. whitespace ===========================================================
# source_citation is deliberately excluded: it must stay byte-identical to
# twatasha_todo.csv so it still joins back to vector_extraction_data.csv.
for (col in c("affiliation_original", "affiliation", "affiliation_simple")) {
  before <- v3[[col]]; after <- squash(before)
  add_change(v3$row_xlsx, col, before, after, "whitespace normalised")
  v3[[col]] <- after
}
for (col in c("affiliation", "affiliation_simple")) {
  ue[[col]]  <- squash(ue[[col]])
  ull[[col]] <- squash(ull[[col]])
}

# == 5b. collapse formatting-only affiliation_simple duplicates =============
freq <- table(v3$affiliation_simple[!is.na(v3$affiliation_simple)])
lab  <- tibble(label = names(freq), n = as.integer(freq)) %>%
  mutate(lk = label_key(label))
CANON <- lab %>% group_by(lk) %>% arrange(desc(n), label, .by_group = TRUE) %>%
  mutate(winner = first(label)) %>% ungroup()
COLLAPSED <- CANON %>% filter(label != winner) %>%
  transmute(label_key = lk, from_label = label, n_rows = n, to_label = winner,
            n_rows_target = CANON$n[match(winner, CANON$label)])
canon_map <- setNames(CANON$winner, CANON$label)

before <- v3$affiliation_simple
after  <- ifelse(is.na(before), before, unname(canon_map[before]))
add_change(v3$row_xlsx, "affiliation_simple", before, after,
           "formatting-only duplicate label collapsed")
v3$affiliation_simple <- after
ue$affiliation_simple  <- coalesce(unname(canon_map[ue$affiliation_simple]),  ue$affiliation_simple)
ull$affiliation_simple <- coalesce(unname(canon_map[ull$affiliation_simple]), ull$affiliation_simple)

# == 5c. apply the label decisions ==========================================
# Order matters. affiliation_relabel moves individual affiliation strings onto a
# different label; label_rename then renames (and thereby merges) whole labels.
for (d in DECISIONS) {
  if (d$decision_type != "affiliation_relabel") next
  if (d$target == "" || d$new_value == "") {
    dec_log(d, "bad_decision", 0L, "affiliation_relabel needs target and new_value"); next
  }
  hit <- which(!is.na(v3$affiliation) & v3$affiliation == d$target)
  if (!length(hit)) {
    dec_log(d, "no_match", 0L, "no row has that exact affiliation string"); next
  }
  add_change(v3$row_xlsx[hit], "affiliation_simple", v3$affiliation_simple[hit],
             rep(d$new_value, length(hit)), "decision: affiliation_relabel")
  v3$affiliation_simple[hit] <- d$new_value
  dec_log(d, "applied", length(hit))
}

RENAME <- list()
for (d in DECISIONS) {
  if (d$decision_type != "label_rename") next
  if (d$target == "" || d$new_value == "") {
    dec_log(d, "bad_decision", 0L, "label_rename needs target and new_value"); next
  }
  if (d$target %in% names(RENAME) && RENAME[[d$target]] != d$new_value) {
    dec_log(d, "bad_decision", 0L,
            paste0("target already renamed to '", RENAME[[d$target]], "' elsewhere")); next
  }
  RENAME[[d$target]] <- d$new_value
}

# follow chains (A->B, B->C gives A->C); a loop leaves its members untouched
RENAME_CYCLES <- character(0)
resolved_rename <- list()
for (start in names(RENAME)) {
  seen <- start; cur <- RENAME[[start]]; looped <- FALSE
  while (cur %in% names(RENAME)) {
    if (cur %in% seen) { RENAME_CYCLES <- union(RENAME_CYCLES, seen); looped <- TRUE; break }
    seen <- c(seen, cur); cur <- RENAME[[cur]]
  }
  resolved_rename[[start]] <- if (looped) start else cur
}
RENAME <- resolved_rename

for (d in DECISIONS) {
  if (d$decision_type != "label_rename" || !(d$target %in% names(RENAME))) next
  if (d$target %in% RENAME_CYCLES) {
    dec_log(d, "cycle", 0L, "label_rename chain loops back on itself; not applied"); next
  }
  n <- sum(!is.na(v3$affiliation_simple) & v3$affiliation_simple == d$target)
  dec_log(d, if (n > 0L) "applied" else "no_match", n,
          if (n > 0L) "" else "no row currently carries that label")
}

if (length(RENAME)) {
  rn <- function(x) {
    hit <- !is.na(x) & x %in% names(RENAME)
    x[hit] <- unlist(RENAME[x[hit]], use.names = FALSE)
    x
  }
  before <- v3$affiliation_simple; after <- rn(before)
  add_change(v3$row_xlsx, "affiliation_simple", before, after, "decision: label_rename")
  v3$affiliation_simple  <- after
  ue$affiliation_simple  <- rn(ue$affiliation_simple)
  ull$affiliation_simple <- rn(ull$affiliation_simple)
}

# == 6-8. deliverables =======================================================
D1 <- select(v3, source_citation, n, affiliation_original, affiliation, affiliation_simple)
write_csv(D1, file.path(OUT, sprintf("affiliations_complete_%s.csv", STAMP)), na = "")

D2 <- v3 %>% filter(!is.na(affiliation), !is.na(affiliation_simple)) %>%
  count(affiliation_simple, affiliation, name = "n_rows") %>%
  arrange(tolower(affiliation_simple), tolower(affiliation)) %>%
  select(affiliation_simple, affiliation, n_rows)
write_csv(D2, file.path(OUT, sprintf("affiliation_lookup_%s.csv", STAMP)), na = "")

as_num <- function(x) {
  x <- str_trim(str_replace(str_trim(x), ",$", ""))
  suppressWarnings(ifelse(toupper(x) == "ABSENT", NA_real_, as.numeric(x)))
}
haversine <- function(a, b, c, d) {
  R <- 6371; p <- function(z) z * pi / 180
  x <- sin(p(c - a) / 2)^2 + cos(p(a)) * cos(p(c)) * sin(p(d - b) / 2)^2
  2 * R * asin(sqrt(x))
}
prep <- function(d, src) {
  d %>% mutate(lat = as_num(Latitude), lon = as_num(Longitude),
               absent = toupper(str_trim(Latitude)) == "ABSENT" |
                        toupper(str_trim(Longitude)) == "ABSENT",
               lk = join_key(affiliation_simple), src = src)
}
# unique_entries (round 2) is the authority; unique_affiliations_Lat_Long
# (round 1) is consulted only for labels round 2 never covered. Conflicts are
# therefore computed within one source at a time, never manufactured by mixing.
sources  <- list(prep(ue, "unique_entries 26.sep.2024"),
                 prep(ull, "unique_affiliations_Lat_Long"))
resolved <- list(); CONFLICTS <- list()
for (frame in sources) {
  for (k in unique(frame$lk[!is.na(frame$lk)])) {
    # NB list[["absent name"]] errors in R, so membership is tested by name first
    if (k %in% names(resolved) && resolved[[k]]$status %in% c("ok", "conflict")) next
    d     <- filter(frame, lk == k)
    pairs <- distinct(filter(d, !is.na(lat), !is.na(lon)), lat, lon)
    note  <- paste(sort(unique(d$Note[!is.na(d$Note) & str_trim(d$Note) != ""])), collapse = "; ")
    if (nrow(pairs) == 0L) {
      resolved[[k]] <- list(lat = NA_real_, lon = NA_real_,
                            status = if (any(d$absent, na.rm = TRUE)) "absent" else "missing",
                            note = note, src = d$src[1])
    } else if (nrow(pairs) == 1L) {
      resolved[[k]] <- list(lat = pairs$lat[1], lon = pairs$lon[1], status = "ok",
                            note = note, src = d$src[1])
    } else {
      mx <- max(outer(seq_len(nrow(pairs)), seq_len(nrow(pairs)),
                      Vectorize(function(i, j) haversine(pairs$lat[i], pairs$lon[i],
                                                         pairs$lat[j], pairs$lon[j]))))
      resolved[[k]] <- list(lat = NA_real_, lon = NA_real_, status = "conflict",
                            note = note, src = d$src[1])
      CONFLICTS[[length(CONFLICTS) + 1L]] <- tibble(
        affiliation_simple = d$affiliation_simple[1],
        coord_file_label   = d$affiliation_simple[1], n_candidates = nrow(pairs),
        max_separation_km = round(mx, 4),
        candidates = paste(paste0(pairs$lat, ",", pairs$lon), collapse = "; "),
        source = d$src[1], note = note)
    }
  }
}
pull_field <- function(k, f, default) {
  if (!(k %in% names(resolved))) return(default)
  r <- resolved[[k]]; if (is.null(r[[f]])) default else r[[f]]
}
# `coordinate` decisions win over everything the source files say.
COORD_DECISION <- list()
for (d in DECISIONS) {
  if (d$decision_type != "coordinate") next
  la <- suppressWarnings(as.numeric(d$latitude)); lo <- suppressWarnings(as.numeric(d$longitude))
  if (is.na(la) || is.na(lo)) {
    dec_log(d, "bad_coordinate", 0L, "latitude/longitude do not parse as numbers"); next
  }
  if (la < -90 || la > 90 || lo < -180 || lo > 180) {
    dec_log(d, "bad_coordinate", 0L, "outside [-90,90] / [-180,180]"); next
  }
  COORD_DECISION[[d$target]] <- list(lat = la, lon = lo, note = d$note, d = d)
}

labels_all <- unique(v3$affiliation_simple[!is.na(v3$affiliation_simple)])
D3 <- tibble(affiliation_simple = labels_all[order(tolower(labels_all), method = "radix")]) %>%
  mutate(lk           = join_key(affiliation_simple),
         latitude     = map_dbl(lk, pull_field, "lat",    NA_real_),
         longitude    = map_dbl(lk, pull_field, "lon",    NA_real_),
         coord_status = map_chr(lk, pull_field, "status", "missing"),
         note         = map_chr(lk, pull_field, "note",   ""),
         coord_source = map_chr(lk, pull_field, "src",    ""),
         coord_status = ifelse(affiliation_simple == "ABSENT", "absent", coord_status)) %>%
  select(-lk)

D3_JK <- join_key(D3$affiliation_simple)
for (lbl in names(COORD_DECISION)) {
  cd  <- COORD_DECISION[[lbl]]
  hit <- which(D3$affiliation_simple == lbl)
  how <- ""
  if (!length(hit)) {
    # The coordinate files spell some labels differently from the spreadsheet
    # (`CDC USA` there, `CDC United States` here). A decision written against the
    # coordinate-file spelling is honoured by matching on join_key, provided that
    # resolves to exactly one label.
    cand <- D3$affiliation_simple[D3_JK == join_key(lbl)]
    if (length(cand) == 1L) {
      hit <- which(D3$affiliation_simple == cand)
      how <- paste0("matched via join key to '", cand, "'")
    } else if (length(cand) > 1L) {
      dec_log(cd$d, "no_match", 0L,
              paste0("ambiguous: join key matches ", paste(cand, collapse = " | "))); next
    }
  }
  if (!length(hit)) {
    dec_log(cd$d, "no_match", 0L,
            paste0("no affiliation_simple by that name (check spelling, and apply ",
                   "label_rename first if you renamed it)")); next
  }
  D3$latitude[hit]     <- cd$lat
  D3$longitude[hit]    <- cd$lon
  D3$coord_status[hit] <- "decided"
  D3$coord_source[hit] <- "affiliation_decisions.csv"
  if (nzchar(cd$note)) D3$note[hit] <- cd$note
  dec_log(cd$d, "applied", length(hit), how)
}

D3$n_rows <- as.integer(table(v3$affiliation_simple)[D3$affiliation_simple])
write_csv(D3, file.path(OUT, sprintf("affiliation_simple_coords_%s.csv", STAMP)), na = "")

# -- accept_as_is / note_only, and the decisions report ----------------------
REVIEWED <- character(0)
known_targets <- union(unique(v3$affiliation_simple[!is.na(v3$affiliation_simple)]),
                       unique(v3$affiliation[!is.na(v3$affiliation)]))
for (d in DECISIONS) {
  if (!(d$decision_type %in% c("accept_as_is", "note_only"))) next
  REVIEWED <- union(REVIEWED, d$target)
  ok_ <- d$target %in% known_targets
  dec_log(d, if (ok_) "applied" else "no_match", if (ok_) 1L else 0L,
          if (ok_) "" else "target matches no affiliation or affiliation_simple")
}
for (d in DECISIONS) {
  if (!(d$decision_type %in% DEC_TYPES))
    dec_log(d, "bad_decision", 0L,
            paste0("unknown decision_type; expected one of: ",
                   paste(sort(DEC_TYPES), collapse = ", ")))
}
mark_reviewed <- function(df, col) {
  df$reviewed <- df[[col]] %in% REVIEWED
  df
}
DR <- bind_rows(DEC_REPORT)
if (nrow(DR) == 0L)
  DR <- tibble(decision_type = character(), target = character(), new_value = character(),
               latitude = character(), longitude = character(), status = character(),
               n_affected = integer(), message = character(), note = character(),
               decided_on = character())
write_csv(DR, file.path(OUT, "decisions_report.csv"), na = "")

# == 9. review lists =========================================================
bind_rows(TOKENS) %>% count(column, broken_token, proposed, name = "n_occurrences") %>%
  arrange(column, broken_token) %>%
  write_csv(file.path(OUT, "review_us_uk_tokens.csv"), na = "")

CH <- bind_rows(CHANGES)
filter(CH, reason == "encoding") %>% write_csv(file.path(OUT, "review_encoding_repairs.csv"), na = "")

v3 %>% filter(!is.na(affiliation), !is.na(affiliation_simple)) %>%
  group_by(affiliation) %>%
  summarise(affiliation_simple_values = paste(sort(unique(affiliation_simple)), collapse = " | "),
            n_values = n_distinct(affiliation_simple), n_rows = n(), .groups = "drop") %>%
  filter(n_values > 1) %>%
  mutate(issue = "one affiliation, several affiliation_simple") %>%
  select(issue, affiliation, affiliation_simple_values, n_values, n_rows) %>%
  mark_reviewed("affiliation") %>%
  write_csv(file.path(OUT, "review_simple_conflicts.csv"), na = "")

write_csv(COLLAPSED, file.path(OUT, "review_labels_collapsed.csv"), na = "")

v3 %>% filter(!is.na(affiliation), !is.na(affiliation_simple)) %>%
  group_by(affiliation_simple) %>%
  summarise(n_distinct_affiliations = n_distinct(affiliation), n_rows = n(),
            affiliations = paste(sort(unique(affiliation)), collapse = " | "), .groups = "drop") %>%
  filter(n_distinct_affiliations > 1) %>% arrange(desc(n_distinct_affiliations)) %>%
  mark_reviewed("affiliation_simple") %>%
  write_csv(file.path(OUT, "review_simple_lumping.csv"), na = "")

# label the conflicts by the spreadsheet's spelling where one exists, so a decision
# made from this list targets a label the deliverables actually contain
v3_labels <- unique(v3$affiliation_simple[!is.na(v3$affiliation_simple)])
v3_jk     <- join_key(v3_labels)
CONF <- bind_rows(CONFLICTS)
if (nrow(CONF)) {
  CONF$affiliation_simple <- vapply(CONF$affiliation_simple, function(l) {
    m <- v3_labels[v3_jk == join_key(l)]
    if (length(m) == 1L) m else l
  }, character(1), USE.NAMES = FALSE)
  CONF <- CONF %>% select(affiliation_simple, coord_file_label, n_candidates,
                          max_separation_km, candidates, source, note)
}
CONF %>% arrange(desc(max_separation_km)) %>%
  write_csv(file.path(OUT, "review_coord_conflicts.csv"), na = "")

D3 %>% filter(coord_status %in% c("missing", "conflict")) %>%
  select(affiliation_simple, coord_status, n_rows, note) %>%
  write_csv(file.path(OUT, "review_missing_coords.csv"), na = "")

bind_rows(
  UNMATCHED %>% select(row_xlsx, source_citation, sc_how, affiliation, affiliation_simple) %>%
    mutate(issue = "v3 row not matched to twatasha_todo.csv"),
  tibble(issue = "todo source never given an affiliation",
         source_citation = setdiff(todo$source_citation, v3$source_citation))
) %>% write_csv(file.path(OUT, "review_unmatched_sources.csv"), na = "")

# == 10. diff report =========================================================
write_csv(CH, file.path(OUT, sprintf("diff_report_%s.csv", STAMP)), na = "")

# == 11. assertions ==========================================================
stopifnot(
  nrow(D1) == 1273,
  all(D1$source_citation %in% todo$source_citation),
  all(D1$n == unname(todo_n[D1$source_citation])),
  !any(str_detect(coalesce(D1$affiliation, ""), MIDWORD)),
  !any(str_detect(coalesce(D1$affiliation_simple, ""), MIDWORD)),
  !anyDuplicated(D3$affiliation_simple),
  setequal(D3$affiliation_simple, unique(D1$affiliation_simple[!is.na(D1$affiliation_simple)])),
  all(is.na(D3$latitude) | (D3$latitude >= -90 & D3$latitude <= 90)),
  all(is.na(D3$longitude) | (D3$longitude >= -180 & D3$longitude <= 180)),
  all(!is.na(D3$latitude) == (D3$coord_status %in% c("ok", "decided")))
)
if (nrow(DR)) {
  bad <- filter(DR, status != "applied")
  if (nrow(bad)) {
    message("\n!! ", nrow(bad), " decision(s) did NOT apply -- see output/decisions_report.csv")
    for (i in seq_len(nrow(bad)))
      message("   [", bad$status[i], "] ", bad$decision_type[i], " | ",
              substr(bad$target[i], 1, 60), " | ", bad$message[i])
  } else {
    message("all ", nrow(DR), " decisions applied")
  }
}
message("assertions passed")

# == 12. parity check against the shipped CSVs ==============================
# Remove this section once you trust the script.
parity <- function(fname, made) {
  path <- file.path(PARITY_TO, fname)
  if (!file.exists(path)) { message("parity: ", fname, " not present, skipped"); return(invisible()) }
  ship <- read_csv(path, col_types = cols(.default = "c"), progress = FALSE)
  made <- mutate(made, across(everything(), ~ ifelse(is.na(.x), NA_character_, as.character(.x))))
  # Row order is not part of the comparison: R and Python may collate strings
  # differently. Both sides are sorted the same way before the cells are matched.
  ord <- function(d) d[do.call(order, c(lapply(d, function(v) tolower(coalesce(v, ""))),
                                        list(method = "radix"))), , drop = FALSE]
  if (identical(names(ship), names(made))) { ship <- ord(ship); made <- ord(made) }
  if (!identical(dim(ship), dim(made)) || !identical(names(ship), names(made))) {
    stop("parity FAILED on ", fname, ": shape/columns differ (",
         paste(dim(ship), collapse = "x"), " vs ", paste(dim(made), collapse = "x"), ")",
         call. = FALSE)
  }
  cmp_col <- function(cn) {
    a <- ship[[cn]]; b <- made[[cn]]
    both_na <- is.na(a) & is.na(b)
    na <- suppressWarnings(as.numeric(a)); nb <- suppressWarnings(as.numeric(b))
    numeric_col <- all(is.na(a) == is.na(na)) && all(is.na(b) == is.na(nb)) && any(!is.na(na))
    same <- if (numeric_col) (abs(na - nb) < 1e-9) %in% TRUE else (a == b) %in% TRUE
    sum(!same & !both_na)
  }
  bad <- sum(vapply(names(ship), cmp_col, integer(1)))
  if (bad > 0) stop("parity FAILED on ", fname, ": ", bad, " differing cells", call. = FALSE)
  message("parity ok: ", fname)
}
# The shipped copies were produced with an empty decisions file. Once you start
# recording decisions the outputs legitimately diverge, so the check stands down.
if (length(DECISIONS)) {
  message("parity check skipped: ", length(DECISIONS), " decision(s) in force, so the ",
          "shipped\n  reference in ", PARITY_TO, " is deliberately out of date. ",
          "To re-check parity,\n  move data/affiliation_decisions.csv aside and re-run.")
} else {
  parity(sprintf("affiliations_complete_%s.csv", STAMP), D1)
  parity(sprintf("affiliation_lookup_%s.csv", STAMP), D2)
  parity(sprintf("affiliation_simple_coords_%s.csv", STAMP), D3)
}

message("done. ", nrow(D1), " rows, ", nrow(D2), " lookup pairs, ", nrow(D3), " labels, ",
        nrow(CH), " cell changes logged.")
