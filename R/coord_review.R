# coord_review.R ---------------------------------------------------------------
#
# The spreadsheet loop for coordinate decisions.
#
#   Rscript R/coord_review.R
#   -> open data/coord_review.xlsx, put yes/no in the `accepted` column, save
#   Rscript R/coord_review.R          # answers -> data/affiliation_decisions.csv
#   python3 R/tidy_affiliations.py && python3 R/verify_affiliations.py
#
# Run it as often as you like. Every run does the same two things:
#   1. reads your answers out of the sheet and writes the `coordinate` rows of
#      data/affiliation_decisions.csv from them;
#   2. rebuilds the sheet, keeping every answer you have already given.
#
# One row per *candidate* coordinate. A label with two competing coordinates
# gets two rows; put yes against the one you want. Two yeses for one label is
# an error and the script stops rather than picking for you.
#
# The sheet is .xlsx, not .csv, deliberately. Excel round-trips xlsx as UTF-8
# without touching the accents, so this is the one project file it is safe to
# open, edit and save. See CLAUDE.md rule 1 for what happened to the CSVs.
#
# Nothing here edits a deliverable. It only writes the decisions file, which
# tidy_affiliations.py then applies.

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
})
stopifnot(requireNamespace("readxl", quietly = TRUE),
          requireNamespace("writexl", quietly = TRUE))

# project root: this directory, or the nearest ancestor holding output/ and data/
root <- getwd()
while (!all(dir.exists(file.path(root, c("output", "data")))) &&
       dirname(root) != root) root <- dirname(root)
if (!all(dir.exists(file.path(root, c("output", "data")))))
  stop("run this from the project root (the directory holding data/ and output/)",
       call. = FALSE)

F_SHEET     <- file.path(root, "data", "coord_review.xlsx")
F_DECISIONS <- file.path(root, "data", "affiliation_decisions.csv")
F_PROPOSED  <- file.path(root, "output", "proposed_coords_missing88_20260818.csv")
F_CONFLICTS <- file.path(root, "output", "review_coord_conflicts.csv")
F_SANITY    <- file.path(root, "output", "review_coord_sanity.csv")
F_COORDS    <- file.path(root, "output", "final", "affiliation_simple_coords_20260817.csv")
F_LOOKUP    <- file.path(root, "output", "final", "affiliation_lookup_20260817.csv")

DEC_COLS <- c("decision_type", "target", "new_value", "latitude", "longitude",
              "note", "decided_on")

# order matters: `accepted` is column A so it is the first thing you land on, and
# the affiliation strings sit beside the label, before you get to the coordinate
SHEET_COLS <- c("accepted", "status", "affiliation_simple", "affiliation_simple_v3",
                "n_affiliations", "affiliation", "case",
                "latitude", "longitude", "precision", "confidence",
                "resolved_name", "your_note", "decided_on", "n_rows",
                "source_name", "source_url", "google_maps",
                "nearest_existing_label", "nearest_existing_km",
                "same_coord_group", "geocoder_notes", "existing_project_note")

blank  <- function(x) ifelse(is.na(x), "", as.character(x))
key    <- function(lab, la, lo) paste(lab, sprintf("%.7f", as.numeric(la)),
                                      sprintf("%.7f", as.numeric(lo)), sep = "|")

# Transcription of join_key() in tidy_affiliations.py:164. The coordinate files
# were snapshotted at different points in the find-and-replace history, so
# `CDC USA` in one and `CDC United States` in the other are the same label.
# Used only for looking things up; the label written out is untouched.
join_key <- function(s) {
  s <- gsub("United States", "\001", s, fixed = TRUE)
  s <- gsub("United Kingdom", "\002", s, fixed = TRUE)
  s <- gsub("u\\.?s\\.?a\\.?", "\001", s, perl = TRUE, ignore.case = TRUE)
  s <- gsub("u\\.?s\\.?",      "\001", s, perl = TRUE, ignore.case = TRUE)
  s <- gsub("u\\.?k\\.?",      "\002", s, perl = TRUE, ignore.case = TRUE)
  s <- stringi::stri_trans_nfkd(s)
  s <- gsub("\\p{Mn}", "", s, perl = TRUE)
  gsub("[^a-z0-9\001\002]", "", tolower(s), perl = TRUE)
}

# affiliation strings per label, from deliverable 2, keyed so that the 13
# USA/UK-spelt conflict labels (which exist only in the coordinate files, never
# in version 3) still pick up the affiliation text of their v3 counterpart.
aff_by_label <- function() {
  readr::read_csv(F_LOOKUP, show_col_types = FALSE, progress = FALSE) %>%
    mutate(k = join_key(affiliation_simple)) %>%
    group_by(k) %>%
    summarise(
      n_affiliations        = n_distinct(affiliation),   # before `affiliation` is collapsed
      affiliation           = paste(sort(unique(affiliation)), collapse = " | "),
      affiliation_simple_v3 = paste(sort(unique(affiliation_simple)), collapse = " | "),
      .groups = "drop")
}

# ---- 1. the candidate rows ---------------------------------------------------
# Three sources, all of them things needing a yes/no: the 88 researched
# proposals, the 29 labels that already carry more than one coordinate, and the
# suspects from R/check_coord_sanity.R -- coordinates that are already settled
# but sit outside the country their affiliation names. The third source is what
# lets a coordinate be re-opened after it has been accepted, which is otherwise
# impossible: an `ok` label never reaches this sheet.

build_candidates <- function() {
  prop <- read_csv(F_PROPOSED, show_col_types = FALSE, progress = FALSE)

  missing_rows <- prop %>%
    transmute(
      affiliation_simple,
      case      = "missing",
      latitude, longitude,
      precision  = blank(precision),
      confidence = blank(confidence),
      resolved_name = blank(resolved_name),
      n_rows     = as.integer(n_rows),
      source_name = blank(source_name),
      source_url  = blank(source_url),
      google_maps = blank(google_maps),
      nearest_existing_label = blank(nearest_existing_label),
      nearest_existing_km    = as.numeric(nearest_existing_km),
      same_coord_group       = blank(same_coord_group),
      geocoder_notes        = blank(notes),
      existing_project_note = blank(existing_project_note)
    )

  conf <- read_csv(F_CONFLICTS, show_col_types = FALSE, progress = FALSE)

  # "lat,lon; lat,lon" -> one row per candidate
  conflict_rows <- conf %>%
    rowwise() %>%
    do({
      r     <- .
      parts <- trimws(strsplit(r$candidates, ";", fixed = TRUE)[[1]])
      parts <- parts[nzchar(parts)]
      xy    <- do.call(rbind, lapply(strsplit(parts, ",", fixed = TRUE),
                                     function(p) as.numeric(trimws(p[1:2]))))
      tibble(
        affiliation_simple = r$affiliation_simple,
        case               = "conflict",
        latitude           = xy[, 1],
        longitude          = xy[, 2],
        precision          = "",
        confidence         = "",
        resolved_name      = "",
        n_rows             = NA_integer_,
        source_name        = blank(r$source),
        source_url         = "",
        google_maps        = sprintf("https://www.google.com/maps/place/%.7f,%.7f",
                                     xy[, 1], xy[, 2]),
        nearest_existing_label = "",
        nearest_existing_km    = NA_real_,
        same_coord_group       = "",
        geocoder_notes = sprintf(
          "existing coordinate on record; %s candidates for this label, up to %s km apart",
          r$n_candidates, format(round(as.numeric(r$max_separation_km), 3), trim = TRUE)),
        existing_project_note = blank(r$note)
      )
    }) %>%
    ungroup()

  # Sanity suspects: the coordinate as it stands, so ticking it means "checked,
  # this is right", plus the arithmetic repair when the sweep found one that
  # lands inside the expected country.
  # A header-only sanity file types every column as character, which used to
  # blow bind_rows up with "Can't combine <double> and <character>". Read it,
  # then coerce, then bail out if there is nothing in it.
  sn <- if (file.exists(F_SANITY)) {
    x <- read_csv(F_SANITY, show_col_types = FALSE, progress = FALSE)
    for (cl in c("latitude", "longitude", "repair_latitude", "repair_longitude",
                 "distance_km_to_expected", "n_rows"))
      if (cl %in% names(x)) x[[cl]] <- suppressWarnings(as.numeric(x[[cl]]))
    x
  } else NULL

  sanity_rows <- if (!is.null(sn) && nrow(sn)) {
    diag <- sprintf("%s; point is in %s, expected %s%s",
                    blank(sn$flag_type),
                    ifelse(is.na(sn$point_country_name), "open sea", sn$point_country_name),
                    blank(sn$expected_country),
                    ifelse(is.na(sn$distance_km_to_expected), "",
                           sprintf(", %s km outside it",
                                   format(round(sn$distance_km_to_expected, 1), trim = TRUE))))
    current <- tibble(
      affiliation_simple = sn$affiliation_simple,
      case = "sanity", latitude = sn$latitude, longitude = sn$longitude,
      precision = "", confidence = "",
      resolved_name = "the coordinate as it stands - tick this if it is right",
      n_rows = as.integer(sn$n_rows),
      source_name = "review_coord_sanity.csv", source_url = "",
      google_maps = blank(sn$google_maps),
      nearest_existing_label = "", nearest_existing_km = NA_real_,
      same_coord_group = "", geocoder_notes = diag,
      existing_project_note = blank(sn$affiliation_excerpt))
    fixed <- sn %>% filter(!is.na(repair_type))
    repaired <- if (nrow(fixed)) tibble(
      affiliation_simple = fixed$affiliation_simple,
      case = "sanity", latitude = fixed$repair_latitude,
      longitude = fixed$repair_longitude,
      precision = "", confidence = "",
      resolved_name = sprintf("repair: %s", fixed$repair_type),
      n_rows = as.integer(fixed$n_rows),
      source_name = "review_coord_sanity.csv", source_url = "",
      google_maps = sprintf("https://www.google.com/maps/search/?api=1&query=%.7f,%.7f",
                            fixed$repair_latitude, fixed$repair_longitude),
      nearest_existing_label = "", nearest_existing_km = NA_real_,
      same_coord_group = "",
      geocoder_notes = sprintf("this lands inside %s", fixed$expected_country),
      existing_project_note = blank(fixed$affiliation_excerpt)) else NULL
    bind_rows(current, repaired)
  } else NULL

  # A label that deliverable 3 says is `missing` but that no source offers a
  # candidate for would never reach this sheet at all -- the trap that hid
  # `U Nijmegen` in September. Give it an empty row to type into instead.
  offered <- unique(c(missing_rows$affiliation_simple, conflict_rows$affiliation_simple,
                      sanity_rows$affiliation_simple))
  d3 <- read_csv(F_COORDS, show_col_types = FALSE, progress = FALSE)
  orphan <- d3 %>%
    filter(coord_status == "missing", !affiliation_simple %in% offered)
  orphan_rows <- if (nrow(orphan)) tibble(
    affiliation_simple = orphan$affiliation_simple,
    case = "needs a coordinate", latitude = NA_real_, longitude = NA_real_,
    precision = "", confidence = "",
    resolved_name = "no candidate from any source - type the coordinate into H and I",
    n_rows = as.integer(orphan$n_rows),
    source_name = "", source_url = "", google_maps = "",
    nearest_existing_label = "", nearest_existing_km = NA_real_,
    same_coord_group = "",
    geocoder_notes = "this label has no coordinate and nothing proposed one",
    existing_project_note = "") else NULL

  out <- bind_rows(missing_rows, conflict_rows, sanity_rows, orphan_rows) %>%
    mutate(k_lab = join_key(affiliation_simple)) %>%
    left_join(aff_by_label(), by = c(k_lab = "k"))

  # Both sources are snapshots: the proposals file is static, and the coordinate
  # files keep their own copy of every label. A label that has since been renamed
  # or merged away therefore goes on generating candidate rows for something the
  # deliverables no longer contain, and no yes/no against it can do anything --
  # a `coordinate` decision naming it comes back `no_match`. Drop those rows and
  # name them. Hand-typed rows are left alone: an unknown label there is a typo
  # worth surfacing, and verify fails loudly on it.
  # Both files are snapshots, so these reappear and are re-dropped on every run.
  # Print the count, and only enough names to recognise them by.
  gone <- is.na(out$affiliation_simple_v3)
  if (any(gone)) {
    nm <- sort(unique(out$affiliation_simple[gone]))
    cat(sprintf("dropped %d candidate row(s) for %d merged-away label(s): %s\n",
                sum(gone), length(nm),
                paste(c(substr(head(nm, 3), 1, 34),
                        if (length(nm) > 3) sprintf("... and %d more", length(nm) - 3)),
                      collapse = "; ")))
  }

  out[!gone, , drop = FALSE] %>%
    select(-k_lab) %>%
    mutate(n_affiliations = as.integer(n_affiliations),
           across(where(is.character), blank))
}

# ---- 2. your answers from last time ------------------------------------------

read_answers <- function() {
  if (!file.exists(F_SHEET)) {
    return(tibble(k = character(), accepted = character(),
                  your_note = character(), decided_on = character(),
                  latitude = numeric(), longitude = numeric(),
                  affiliation_simple = character(), manual = logical()))
  }
  s <- readxl::read_excel(F_SHEET, col_types = "text")
  for (cl in c("accepted", "your_note", "decided_on", "affiliation_simple",
               "latitude", "longitude"))
    if (!cl %in% names(s)) s[[cl]] <- NA_character_

  s %>%
    filter(!is.na(affiliation_simple), nzchar(trimws(affiliation_simple)),
           !is.na(latitude), !is.na(longitude)) %>%
    transmute(
      affiliation_simple = trimws(affiliation_simple),
      latitude  = suppressWarnings(as.numeric(latitude)),
      longitude = suppressWarnings(as.numeric(longitude)),
      accepted  = tolower(trimws(blank(accepted))),
      your_note = blank(your_note),
      decided_on = blank(decided_on)
    ) %>%
    filter(!is.na(latitude), !is.na(longitude)) %>%
    mutate(
      accepted = case_when(
        accepted %in% c("y", "yes", "true", "1", "x") ~ "yes",
        accepted %in% c("n", "no", "false", "0")      ~ "no",
        accepted == ""                                 ~ "",
        TRUE                                           ~ accepted),
      k = key(affiliation_simple, latitude, longitude))
}

# ---- 3. join, validate -------------------------------------------------------

cand <- build_candidates()
ans  <- read_answers()

bad <- setdiff(unique(ans$accepted), c("", "yes", "no"))
if (length(bad))
  stop("`accepted` must be yes, no or blank. Found: ",
       paste(sprintf("'%s'", bad), collapse = ", "), call. = FALSE)

cand <- cand %>%
  mutate(k = key(affiliation_simple, latitude, longitude)) %>%
  left_join(select(ans, k, accepted, your_note, decided_on), by = "k") %>%
  mutate(accepted   = blank(accepted),
         your_note  = blank(your_note),
         decided_on = blank(decided_on))

# a coordinate you typed in yourself: in the sheet, not in the candidate list
manual <- ans %>%
  filter(!k %in% cand$k, accepted == "yes") %>%
  transmute(affiliation_simple, case = "manual", latitude, longitude,
            precision = "", confidence = "", resolved_name = "",
            n_rows = NA_integer_,
            source_name = "", source_url = "",
            google_maps = sprintf("https://www.google.com/maps/place/%.7f,%.7f",
                                  latitude, longitude),
            nearest_existing_label = "", nearest_existing_km = NA_real_,
            same_coord_group = "",
            geocoder_notes = "coordinate entered by hand in the sheet",
            existing_project_note = "",
            k, accepted, your_note, decided_on)

# a hand-typed coordinate still gets the affiliation strings of its label
if (nrow(manual))
  manual <- manual %>%
    mutate(k_lab = join_key(affiliation_simple)) %>%
    left_join(aff_by_label(), by = c(k_lab = "k")) %>%
    select(-k_lab) %>%
    mutate(n_affiliations = as.integer(n_affiliations),
           across(where(is.character), blank))

cand <- bind_rows(cand, manual)

# exactly one yes per label.
#
# Grouped on join_key, not on the label text. Some labels appear in the sheet under
# two spellings -- the version-3 one (`ICAPB United Kingdom`) and the coordinate
# files' one (`ICAPB UK`) -- and tidy_affiliations.py resolves both onto the same
# label. Counting literal strings could not see that, so two contradicting
# `coordinate` decisions were written for one label and the later one silently won.
yes <- cand %>%
  filter(accepted == "yes") %>%
  mutate(k_lab = join_key(affiliation_simple),
         k_xy  = sprintf("%.7f|%.7f", latitude, longitude))

clash <- yes %>%
  group_by(k_lab) %>%
  filter(n_distinct(k_xy) > 1) %>%
  ungroup()
if (nrow(clash)) {
  msg <- clash %>%
    arrange(k_lab, affiliation_simple) %>%
    transmute(line = sprintf("  %-38s %14.7f %15.7f", affiliation_simple,
                             latitude, longitude)) %>%
    pull(line) %>% paste(collapse = "\n")
  stop("more than one coordinate accepted for the same label:\n", msg,
       "\nThese spellings are the same label once US/USA/U.S and UK/U.K are\n",
       "normalised, so they cannot carry different coordinates. Leave yes against\n",
       "exactly one of them. Nothing was written.", call. = FALSE)
}

# Same label, same point, spelt two ways: no contradiction, but only one decision
# should be written. Keep the spelling the deliverables actually use.
real_labels <- unique(read_csv(F_LOOKUP, show_col_types = FALSE,
                               progress = FALSE)$affiliation_simple)
drop_k <- yes %>%
  group_by(k_lab) %>%
  filter(n() > 1) %>%
  arrange(!affiliation_simple %in% real_labels, affiliation_simple, .by_group = TRUE) %>%
  slice(-1) %>%
  ungroup()
if (nrow(drop_k)) {
  cat("duplicate spellings of one label, same coordinate; keeping one:\n")
  cat(sprintf("  dropped %s\n", drop_k$affiliation_simple), sep = "")
  cand <- filter(cand, !(accepted == "yes" & k %in% drop_k$k))
}

cand <- cand %>%
  group_by(affiliation_simple) %>%
  mutate(status = case_when(
    any(accepted == "yes")                    ~ "settled",
    all(accepted == "no") & n() > 0           ~ "rejected - needs a new coordinate",
    any(accepted == "no")                     ~ "open - some candidates rejected",
    TRUE                                      ~ "open")) %>%
  ungroup() %>%
  mutate(decided_on = ifelse(accepted == "yes" & !nzchar(decided_on),
                             as.character(Sys.Date()), decided_on),
         decided_on = ifelse(accepted == "yes", decided_on, ""))

# ---- 4. write the coordinate rows of the decisions file ----------------------

accepted <- filter(cand, accepted == "yes")

new_coords <- accepted %>%
  transmute(
    decision_type = "coordinate",
    target        = affiliation_simple,
    new_value     = "",
    latitude      = sprintf("%.7f", latitude),
    longitude     = sprintf("%.7f", longitude),
    note          = {
      bits <- Map(function(pr, cf, rn, un, sn, su) {
        p <- c(if (nzchar(pr)) paste0("precision=", pr),
               if (nzchar(cf)) paste0("confidence=", cf),
               if (nzchar(rn)) rn,
               if (nzchar(un)) un,
               if (nzchar(sn)) paste0("source: ", sn),
               if (nzchar(su)) su)
        paste(p, collapse = "; ")
      }, precision, confidence, resolved_name, your_note, source_name, source_url)
      unlist(bits, use.names = FALSE)
    },
    decided_on)

# keep everything that is not a coordinate row, plus any coordinate row for a
# label the sheet does not cover (hand-written, not managed here)
existing <- if (file.exists(F_DECISIONS)) {
  read_csv(F_DECISIONS, col_types = cols(.default = col_character()),
           progress = FALSE)
} else {
  as_tibble(setNames(rep(list(character()), length(DEC_COLS)), DEC_COLS))
}
miss <- setdiff(DEC_COLS, names(existing))
if (length(miss))
  stop(F_DECISIONS, " is missing columns: ", paste(miss, collapse = ", "),
       call. = FALSE)
existing <- existing[, DEC_COLS]

# Matched on join_key for the same reason as the duplicate check above: a decision
# written against `ICAPB UK` belongs to the label the sheet calls `ICAPB United
# Kingdom`, so the sheet owns it. Comparing label text let such a row survive as
# "hand-written" once its sheet row was blanked, and it went on overriding the
# answer that was actually ticked.
sheet_labels <- join_key(cand$affiliation_simple)

# A coordinate decision naming a label that is not in the deliverables at all is
# dead: it can only ever report `no_match`, and verify fails the run on it. That
# happens when a label is merged away while its sheet row is blanked -- the row
# stops claiming the decision, so the "hand-written" clause below would otherwise
# protect it forever. Drop those and say so. Decisions for labels that DO exist
# but never reach the sheet (an `ok` or `absent` one) are still preserved.
dead <- existing$decision_type == "coordinate" &
        !(join_key(existing$target) %in% sheet_labels) &
        !(join_key(existing$target) %in% join_key(real_labels))
if (any(dead)) {
  cat(sprintf("dropped %d coordinate decision(s) for label(s) no longer in the deliverables:\n",
              sum(dead)))
  cat(sprintf("  %s\n", existing$target[dead]), sep = "")
  existing <- existing[!dead, , drop = FALSE]
}

kept <- existing %>%
  filter(decision_type != "coordinate" |
           !(join_key(target) %in% sheet_labels))
n_foreign <- sum(kept$decision_type == "coordinate", na.rm = TRUE)

out <- bind_rows(kept, new_coords) %>%
  mutate(across(everything(), blank))
write_csv(out, F_DECISIONS, na = "")

# ---- 5. rebuild the sheet ----------------------------------------------------

sheet <- cand %>%
  mutate(across(where(is.character), blank)) %>%
  arrange(match(status, c("open", "open - some candidates rejected",
                          "rejected - needs a new coordinate", "settled")),
          case, affiliation_simple, desc(accepted == "yes")) %>%
  select(all_of(SHEET_COLS))

writexl::write_xlsx(list(coordinates = sheet), F_SHEET, format_headers = TRUE)

# ---- 6. say what happened ----------------------------------------------------

lab <- cand %>% group_by(affiliation_simple) %>% summarise(st = status[1], .groups = "drop")
cat(sprintf("sheet    %s\n", F_SHEET))
cat(sprintf("         %d candidate rows over %d labels\n", nrow(sheet), nrow(lab)))
cat("labels:\n")
print(as.data.frame(count(lab, st, name = "n")), row.names = FALSE)
cat(sprintf("\ndecisions %s\n", F_DECISIONS))
cat(sprintf("         %d coordinate rows written from the sheet\n", nrow(new_coords)))
cat(sprintf("         %d other decision rows preserved (%d of them hand-written coordinates)\n",
            nrow(kept), n_foreign))
if (nrow(new_coords) == 0)
  cat("\nNothing accepted yet. Open the sheet, put yes against the coordinate you\n",
      "want for each label, save, and run this again.\n", sep = "")
