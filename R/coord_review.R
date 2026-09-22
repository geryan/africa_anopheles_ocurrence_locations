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
# A label that is staying without a coordinate takes `absent` in column A instead,
# with the reason in `your_note`: that appends an `accept_as_is` row to the decisions
# file and the label stops being offered. See section 3b.
#
# A `case = place` row - the point is in the right country but not in the town its
# text names - takes `checked` in column A if the point is right after all: that
# keeps the coordinate exactly as `yes` does and signs the label off, so
# R/check_coord_place.R stops raising it. See section 4.
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

# the gazetteer, for the `place_check` column and the `case = place` rows: what
# town each coordinate is actually in, beside the town its text names
source(file.path(root, "R", "place_lookup.R"))

F_SHEET     <- file.path(root, "data", "coord_review.xlsx")
F_DECISIONS <- file.path(root, "data", "affiliation_decisions.csv")
F_PROPOSED  <- file.path(root, "output", "proposed_coords_missing88_20260818.csv")
F_CONFLICTS <- file.path(root, "output", "review_coord_conflicts.csv")
F_SANITY    <- file.path(root, "output", "review_coord_sanity.csv")
F_PLACE     <- file.path(root, "output", "review_coord_place.csv")
F_COORDS    <- file.path(root, "output", "final", "affiliation_simple_coords_with_notes.csv")
F_LOOKUP    <- file.path(root, "output", "final", "affiliation_lookup.csv")
F_LAKE_ROWS   <- file.path(root, "data", "gia_final_data", "lake_region_source_affiliations_africa.csv")
F_LAKE_COUNTS <- file.path(root, "data", "gia_final_data", "lake_region_source_counts.csv")
LAKE_SRC      <- "lake_region_source_counts"   # coord_source tidy_affiliations.py gives her points

DEC_COLS <- c("decision_type", "target", "new_value", "latitude", "longitude",
              "note", "decided_on")

# order matters: `accepted` is column A so it is the first thing you land on, and
# the affiliation strings sit beside the label, before you get to the coordinate
SHEET_COLS <- c("accepted", "status", "affiliation_simple", "affiliation_simple_v3",
                "n_affiliations", "affiliation", "case",
                "latitude", "longitude", "precision", "confidence",
                "resolved_name", "your_note", "decided_on", "n_rows",
                "source_name", "source_url", "google_maps", "place_check",
                "nearest_existing_label", "nearest_existing_km",
                "same_coord_group", "geocoder_notes", "existing_project_note")
# `place_check` (S) sits after google_maps deliberately: every letter this project
# documents - A, C, G, H, I, M, N, Q, R - keeps its position, and the columns that
# move are display-only. Nothing is read back by letter in any case (section 2
# reads by name), but the sheet is navigated by letter.

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

# Labels signed off with `accept_as_is` or `note_only`: looked at, and staying as
# they are. check_coord_sanity.R honours the same two types.
signed_off_labels <- function() {
  if (!file.exists(F_DECISIONS)) return(character())
  d <- read_csv(F_DECISIONS, col_types = cols(.default = col_character()),
                progress = FALSE)
  if (!all(c("decision_type", "target") %in% names(d))) return(character())
  x <- d$target[d$decision_type %in% c("accept_as_is", "note_only")]
  unique(x[!is.na(x)])
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

  # Suspects from R/check_coord_place.R: the point is in the right country but not
  # in the town the label or its affiliations name. Same shape as a sanity row --
  # the coordinate as it stands, so ticking it means "checked, this is right" --
  # and the same reason for existing: an `ok` or `decided` label reaches this sheet
  # no other way. Every one of these passes check_coord_sanity.R, which tests the
  # country and stops there: `MTTI Kendu Bay Kenya` is in Mombasa, 693 km from
  # Kendu Bay, and is `decided`.
  #
  # Ticking one appends an `accept_as_is` as well as writing the coordinate
  # (section 4), because the sweep tests geography, not status, and would
  # otherwise raise the same label on every run for ever.
  pl <- if (file.exists(F_PLACE)) {
    x <- read_csv(F_PLACE, show_col_types = FALSE, progress = FALSE)
    for (cl in c("latitude", "longitude", "named_km", "nearest_town_km", "n_rows"))
      if (cl %in% names(x)) x[[cl]] <- suppressWarnings(as.numeric(x[[cl]]))
    x
  } else NULL

  place_rows <- if (!is.null(pl) && nrow(pl)) {
    pl <- filter(pl, !affiliation_simple %in% sanity_rows$affiliation_simple)
    if (nrow(pl)) tibble(
      affiliation_simple = pl$affiliation_simple,
      case = "place", latitude = pl$latitude, longitude = pl$longitude,
      precision = "", confidence = "",
      # deliberately blank, both of them: this row re-offers a coordinate that is
      # already in the deliverables and came from somewhere else, so it has no
      # provenance to contribute. Everything the note builder in section 4 reads
      # stays empty, which is what makes ticking one leave the decisions file
      # exactly as it was.
      resolved_name = "", n_rows = as.integer(pl$n_rows),
      source_name = "", source_url = "",
      google_maps = blank(pl$google_maps),
      nearest_existing_label = "", nearest_existing_km = NA_real_,
      same_coord_group = "",
      geocoder_notes = paste0(blank(pl$place_note),
        ". If this point is right, put `checked` in column A and it stops being ",
        "raised; otherwise type the right coordinate into H and I with yes"),
      existing_project_note = blank(pl$affiliation_excerpt)) else NULL
  } else NULL

  # A label that deliverable 3 gives no coordinate but that no source offers a
  # candidate for would never reach this sheet at all -- the trap that hid
  # `U Nijmegen` in September. Give it an empty row to type into instead.
  #
  # `absent` counts as well as `missing`. It means only that the round-1 coordinate
  # file had ABSENT in its latitude and longitude cells, not that no coordinate
  # exists, and it kept twelve real institutions off this sheet until 2026-09-15.
  # Two kinds of label are left out: `ABSENT` itself, which stands for papers with
  # no affiliation and so names nothing to geocode, and a label signed off with
  # accept_as_is or note_only, which is how one is left without a coordinate on
  # purpose.
  d3 <- read_csv(F_COORDS, show_col_types = FALSE, progress = FALSE)

  # Gia's lake-region coordinates, while her rows are part of the build. Two kinds of
  # row, both case = lake:
  #   - every label whose coordinate came from her counts file and is still `ok`.
  #     Nothing else would ever put her points in front of you, and the sanity sweep
  #     tests only the country: `MasenoU Maseno Kenya` sits in Nairobi and passes.
  #     yes means "checked, this is right" and makes the label `decided`.
  #   - a point of hers that no label in the deliverables uses (her counts file says
  #     `ILRI Nairobi Kenya` where her rows say `ILRAD Nairobi Kenya`), offered to every
  #     label without a coordinate whose name ends in the same two words. A point
  #     offered to no label is named.
  lake_rows <- NULL
  if (file.exists(F_LAKE_ROWS) && file.exists(F_LAKE_COUNTS)) {
    maps <- function(la, lo)
      sprintf("https://www.google.com/maps/search/?api=1&query=%.7f,%.7f", la, lo)
    hers <- d3 %>%
      filter(coord_status == "ok", coord_source == LAKE_SRC,
             !affiliation_simple %in% c(sanity_rows$affiliation_simple,
                                        place_rows$affiliation_simple))
    to_check <- if (nrow(hers)) tibble(
      affiliation_simple = hers$affiliation_simple, case = "lake",
      latitude = as.numeric(hers$latitude), longitude = as.numeric(hers$longitude),
      precision = "", confidence = "",
      resolved_name = "Gia's coordinate as it stands - tick this if it is right",
      n_rows = as.integer(hers$n_rows),
      source_name = "lake_region_source_counts.csv", source_url = "",
      google_maps = maps(as.numeric(hers$latitude), as.numeric(hers$longitude)),
      nearest_existing_label = "", nearest_existing_km = NA_real_, same_coord_group = "",
      geocoder_notes = paste("from Gia's counts file, never checked; the sanity sweep tests",
                             "only the country, so check the point is in the place the label names"),
      existing_project_note = "") else NULL

    renames <- if (file.exists(F_DECISIONS)) {
      d <- read_csv(F_DECISIONS, col_types = cols(.default = col_character()), progress = FALSE)
      d[d$decision_type == "label_rename", c("target", "new_value")]
    } else tibble(target = character(), new_value = character())
    lc <- read_csv(F_LAKE_COUNTS, col_types = cols(.default = col_character()),
                   progress = FALSE) %>%
      mutate(label = trimws(gsub("\\s+", " ", affiliation_simple)),
             now = ifelse(label %in% renames$target,
                          renames$new_value[match(label, renames$target)], label),
             latitude = as.numeric(latitude), longitude = as.numeric(longitude))
    unused <- filter(lc, !join_key(now) %in% join_key(d3$affiliation_simple))
    takers <- d3 %>%
      filter(coord_status %in% c("missing", "absent"), affiliation_simple != "ABSENT",
             !join_key(affiliation_simple) %in% join_key(signed_off_labels()))
    last2 <- function(x) vapply(strsplit(tolower(trimws(x)), "\\s+"), function(w)
      if (length(w) >= 3) paste(tail(w, 2), collapse = " ") else NA_character_, character(1))
    offers <- list(); nobody <- character(0)
    for (i in seq_len(nrow(unused))) {
      t2 <- last2(unused$label[i])
      hit <- takers[!is.na(t2) & last2(takers$affiliation_simple) %in% t2, ]
      if (!nrow(hit)) {
        nobody <- c(nobody, sprintf("%s (%s, %s)", unused$label[i],
                                    unused$latitude[i], unused$longitude[i]))
        next
      }
      offers[[length(offers) + 1]] <- tibble(
        affiliation_simple = hit$affiliation_simple, case = "lake",
        latitude = unused$latitude[i], longitude = unused$longitude[i],
        precision = "", confidence = "",
        resolved_name = sprintf("Gia's point for '%s', a label none of her rows uses",
                                unused$label[i]),
        n_rows = as.integer(hit$n_rows),
        source_name = "lake_region_source_counts.csv", source_url = "",
        google_maps = maps(unused$latitude[i], unused$longitude[i]),
        nearest_existing_label = "", nearest_existing_km = NA_real_, same_coord_group = "",
        geocoder_notes = sprintf(paste("offered because both labels end in '%s'; tick it only if",
                                       "'%s' is this institution"), t2, unused$label[i]),
        existing_project_note = "")
    }
    lake_rows <- bind_rows(to_check, bind_rows(offers))
    # Once every one of her points is settled and no unused point has a taker,
    # both parts are empty and bind_rows() returns a tibble with no columns at
    # all, so reading $affiliation_simple off it warns. That is where
    # "Unknown or uninitialised column" came from on a clean run.
    if (!NROW(lake_rows)) lake_rows <- NULL
    cat(sprintf("Gia's coordinates: %d label(s) to check, %d point(s) offered to a label without one\n",
                NROW(to_check), length(offers)))
    if (length(nobody)) {
      cat(sprintf("a point in her counts file that no label uses and none could take: %d\n",
                  length(nobody)))
      cat(sprintf("  %s\n", nobody), sep = "")
    }
  }

  offered <- unique(c(missing_rows$affiliation_simple, conflict_rows$affiliation_simple,
                      sanity_rows$affiliation_simple, place_rows$affiliation_simple,
                      lake_rows$affiliation_simple))
  orphan <- d3 %>%
    filter(coord_status %in% c("missing", "absent"), affiliation_simple != "ABSENT",
           !affiliation_simple %in% offered)
  staying <- join_key(orphan$affiliation_simple) %in% join_key(signed_off_labels())
  if (any(staying)) {
    cat(sprintf("left without a coordinate, signed off with accept_as_is/note_only: %d\n",
                sum(staying)))
    cat(sprintf("  %s\n", orphan$affiliation_simple[staying]), sep = "")
    orphan <- orphan[!staying, , drop = FALSE]
  }
  orphan_rows <- if (nrow(orphan)) tibble(
    affiliation_simple = orphan$affiliation_simple,
    case = "needs a coordinate", latitude = NA_real_, longitude = NA_real_,
    precision = "", confidence = "",
    resolved_name = "no candidate from any source - type the coordinate into H and I",
    n_rows = as.integer(orphan$n_rows),
    source_name = "", source_url = "", google_maps = "",
    nearest_existing_label = "", nearest_existing_km = NA_real_,
    same_coord_group = "",
    geocoder_notes = ifelse(orphan$coord_status == "absent",
      "the round-1 coordinate file recorded ABSENT for this label, and nothing has proposed a coordinate",
      "this label has no coordinate and nothing proposed one"),
    existing_project_note = "") else NULL

  out <- bind_rows(missing_rows, conflict_rows, sanity_rows, place_rows, lake_rows,
                   orphan_rows)

  # A `place` row re-opens a coordinate the deliverables already carry, so it can
  # land on the same label and point as a row another source offers -- one of the
  # 88 proposals, or a conflict candidate. Two rows sharing a key both get your
  # answer, and the "one yes per label" deduplication below then removes them by
  # key and takes both: four coordinate decisions disappeared the first time this
  # was wired up, 168 -> 164, with nothing said. Keep the place row, which carries
  # what the sweep found. Its source columns stay empty on purpose (above), so the
  # decision note is preserved by the `carry` rule in section 4 rather than rebuilt
  # from this row.
  if (!is.null(place_rows) && nrow(place_rows)) {
    kk <- key(out$affiliation_simple, out$latitude, out$longitude)
    is_place <- out$case == "place"
    dupe <- kk %in% kk[is_place] & !is_place
    for (i in which(dupe)) {
      j <- which(is_place & kk == kk[i])[1]
      if (!nzchar(blank(out$existing_project_note[j])))
        out$existing_project_note[j] <- out$existing_project_note[i]
    }
    if (any(dupe)) {
      cat(sprintf("%d candidate row(s) replaced by the place-sweep row for the same label and point\n",
                  sum(dupe)))
      out <- out[!dupe, , drop = FALSE]
    }
  }

  out <- out %>%
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

# Every row of the sheet that carries a label, with or without a coordinate. The
# rows without one come back too, so that anything typed on them can be named
# rather than vanishing when the sheet is rewritten.
read_answers <- function() {
  if (!file.exists(F_SHEET)) {
    return(tibble(k = character(), accepted = character(),
                  your_note = character(), decided_on = character(),
                  latitude = numeric(), longitude = numeric(),
                  affiliation_simple = character(), case = character()))
  }
  s <- readxl::read_excel(F_SHEET, col_types = "text")
  for (cl in c("accepted", "your_note", "decided_on", "affiliation_simple",
               "latitude", "longitude", "case"))
    if (!cl %in% names(s)) s[[cl]] <- NA_character_

  # A coordinate copied from a web page can carry U+2212 rather than "-"; it is
  # read as the minus sign it is.
  s <- s %>%
    filter(!is.na(affiliation_simple), nzchar(trimws(affiliation_simple))) %>%
    transmute(
      affiliation_simple = trimws(affiliation_simple),
      case      = blank(case),
      lat_txt   = trimws(gsub("−", "-", blank(latitude), fixed = TRUE)),
      lon_txt   = trimws(gsub("−", "-", blank(longitude), fixed = TRUE)),
      latitude  = suppressWarnings(as.numeric(lat_txt)),
      longitude = suppressWarnings(as.numeric(lon_txt)),
      accepted  = tolower(trimws(blank(accepted))),
      your_note = blank(your_note),
      decided_on = blank(decided_on))

  # Anything in H or I that is not a number used to be dropped without a word,
  # taking the row's answer with it. Stop instead, before anything is written, so
  # the sheet on disk still holds what was typed.
  unreadable <- s %>%
    filter((nzchar(lat_txt) | nzchar(lon_txt)) & (is.na(latitude) | is.na(longitude)))
  if (nrow(unreadable))
    stop("latitude (H) and longitude (I) must both be plain numbers in decimal degrees,\n",
         "one in each column. Not readable:\n",
         paste(sprintf("  %-40s H '%s'  I '%s'", unreadable$affiliation_simple,
                       unreadable$lat_txt, unreadable$lon_txt), collapse = "\n"),
         "\nNothing was written.", call. = FALSE)

  s %>%
    select(-lat_txt, -lon_txt) %>%
    mutate(
      accepted = case_when(
        accepted %in% c("y", "yes", "true", "1", "x") ~ "yes",
        accepted %in% c("n", "no", "false", "0")      ~ "no",
        accepted %in% c("absent", "leave absent")     ~ "absent",
        accepted %in% c("checked", "check")           ~ "checked",
        accepted == ""                                 ~ "",
        TRUE                                           ~ accepted),
      # `checked` is `yes` plus a sign-off: keep the coordinate, and stop
      # R/check_coord_place.R raising the label because the point is not in the
      # town its text names (section 4). It is normalised to `yes` here so that
      # every rule about answers - one yes per label, what becomes a decision,
      # what `status` says - goes on seeing the three words it always saw.
      place_signed = accepted == "checked",
      accepted = ifelse(accepted == "checked", "yes", accepted),
      k = key(affiliation_simple, latitude, longitude))
}

# ---- 3. join, validate -------------------------------------------------------

cand     <- build_candidates()
sheet_in <- read_answers()
ans      <- filter(sheet_in, !is.na(latitude), !is.na(longitude))

# `absent` is an answer about the label -- it stays without a coordinate -- so on a
# row that carries one it contradicts itself.
contradiction <- filter(ans, accepted == "absent")
if (nrow(contradiction))
  stop("`absent` in column A says the label stays without a coordinate, but these rows\n",
       "carry one. Clear H and I to sign the label off, or put yes to take the\n",
       "coordinate:\n",
       paste(sprintf("  %-40s %s, %s", contradiction$affiliation_simple,
                     contradiction$latitude, contradiction$longitude), collapse = "\n"),
       "\nNothing was written.", call. = FALSE)

bad <- setdiff(unique(ans$accepted), c("", "yes", "no"))
if (length(bad))
  stop("`accepted` must be yes, no, absent or blank. Found: ",
       paste(sprintf("'%s'", bad), collapse = ", "), call. = FALSE)

# ---- 3b. labels left without a coordinate ------------------------------------
#
# The third answer, beside a coordinate and a merge: this label stays without one.
# `absent` in column A of a row with no coordinate writes an `accept_as_is` decision,
# which is what the hand-written sign-offs already in the file are, and what both the
# orphan filter above and check_coord_sanity.R honour. From the next run on the label
# is no longer offered, and every run names it.
#
# These rows are appended and never rewritten: the decisions file is the record of
# every change (rule 2 in CLAUDE.md), and a sign-off already in it is left exactly as
# it stands. So blanking column A does not undo one -- that means taking the line out
# of the file deliberately.
real_labels <- unique(read_csv(F_LOOKUP, show_col_types = FALSE,
                               progress = FALSE)$affiliation_simple)

signoff <- sheet_in %>%
  filter(accepted == "absent", is.na(latitude), is.na(longitude)) %>%
  distinct(affiliation_simple, .keep_all = TRUE)

unknown <- filter(signoff, !join_key(affiliation_simple) %in% join_key(real_labels))
if (nrow(unknown)) {
  cat(sprintf("not a label in the deliverables, so not signed off: %d\n", nrow(unknown)))
  cat(sprintf("  %s\n", unknown$affiliation_simple), sep = "")
  signoff <- filter(signoff, !affiliation_simple %in% unknown$affiliation_simple)
}

# What a candidate row can carry back: an answer keyed to its coordinate, or an
# `absent` sign-off keyed to a label that has none.
carried <- sheet_in %>%
  filter((!is.na(latitude) & !is.na(longitude)) | accepted == "absent") %>%
  distinct(k, .keep_all = TRUE)

cand <- cand %>%
  mutate(k = key(affiliation_simple, latitude, longitude)) %>%
  left_join(select(carried, k, accepted, your_note, decided_on, place_signed),
            by = "k") %>%
  mutate(accepted   = blank(accepted),
         your_note  = blank(your_note),
         decided_on = blank(decided_on),
         place_signed = !is.na(place_signed) & place_signed)

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
            k, accepted, your_note, decided_on, place_signed)

# Typed into the sheet but not kept by this run. Named at the end rather than lost
# when the sheet is rewritten. Two ways it happens: a row with no coordinate has no
# coordinate to accept or reject, so `no` on it goes nowhere -- `absent` is the answer
# that signs the label off (3b); and a coordinate no source proposed is kept only
# while column A says yes. Blanking A is also how such a coordinate is withdrawn, so a
# withdrawn `manual` row is named here once, as it goes. Generated rows whose source
# has stopped offering them are not.
unkept <- bind_rows(
  sheet_in %>%
    filter(is.na(latitude), is.na(longitude), accepted != "absent",
           nzchar(accepted) | nzchar(your_note)) %>%
    mutate(why = "no coordinate on the row; to leave the label without one, put absent in A"),
  ans %>%
    filter(!k %in% cand$k, accepted != "yes",
           case %in% c("", "needs a coordinate", "manual")) %>%
    mutate(why = "a coordinate no source proposed, without yes in column A"))

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
  mutate(.row = row_number()) %>%
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
drop_k <- yes %>%
  group_by(k_lab) %>%
  filter(n() > 1) %>%
  arrange(!affiliation_simple %in% real_labels, affiliation_simple, .by_group = TRUE) %>%
  slice(-1) %>%
  ungroup()
if (nrow(drop_k)) {
  cat("duplicate spellings of one label, same coordinate; keeping one:\n")
  cat(sprintf("  dropped %s\n", drop_k$affiliation_simple), sep = "")
  # By row, not by key: two rows can share a key as well as a label (a place row
  # and the row whose coordinate it re-opens), and dropping on the key took both,
  # leaving the label with no coordinate decision at all.
  cand <- cand[!(seq_len(nrow(cand)) %in% drop_k$.row), , drop = FALSE]
}

cand <- cand %>%
  group_by(affiliation_simple) %>%
  mutate(status = case_when(
    # first, so it sorts to the top of the sheet and cannot read as done: a
    # coordinate the place sweep flags that has not been answered since. Most of
    # these arrive carrying the `yes` they were given before the sweep existed,
    # which would otherwise show as `settled` and be invisible - exactly the
    # complaint that `MTTI Kendu Bay Kenya` was ticked in Mombasa in the first place.
    any(case == "place" & !place_signed)      ~ "FLAGGED - not in the town the text names",
    any(accepted == "yes")                    ~ "settled",
    any(accepted == "absent")                 ~ "left absent - signed off",
    all(accepted == "no") & n() > 0           ~ "rejected - needs a new coordinate",
    any(accepted == "no")                     ~ "open - some candidates rejected",
    TRUE                                      ~ "open")) %>%
  ungroup() %>%
  mutate(decided_on = ifelse(accepted %in% c("yes", "absent") & !nzchar(decided_on),
                             as.character(Sys.Date()), decided_on),
         decided_on = ifelse(accepted %in% c("yes", "absent"), decided_on, ""))

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

# A ticked row whose source stops offering it -- a sanity suspect once settled, one
# of Gia's points once checked -- comes back as case = manual, which has no source
# of its own, so its decision was rewritten without the provenance recorded when it
# was ticked ("source: lake_region_source_counts.csv"). Keep the note already on
# record for the same label and coordinate, unless the note typed in M has changed.
prev_note <- existing %>%
  filter(decision_type == "coordinate") %>%
  transmute(k_prev = paste(join_key(target), latitude, longitude, sep = "|"),
            prev = blank(note)) %>%
  distinct(k_prev, .keep_all = TRUE)
carry <- accepted$case %in% c("manual", "place")
if (any(carry)) {
  k_new <- paste(join_key(new_coords$target), new_coords$latitude, new_coords$longitude,
                 sep = "|")
  old <- prev_note$prev[match(k_new, prev_note$k_prev)]
  typed <- blank(accepted$your_note)
  keep_old <- carry & !is.na(old) & nzchar(old) & old != new_coords$note &
              (!nzchar(typed) | mapply(grepl, typed, old, MoreArgs = list(fixed = TRUE)))
  new_coords$note[keep_old] <- old[keep_old]
}

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
#
# A label a `label_rename` in this same file is about to take away counts as gone,
# even though the deliverables still list it: they are a snapshot from before the
# rename was written. Without this the decision survives the run that merges its
# label, `label_rename` removes the label in the rebuild that follows, and the
# build ends `42 checks, 2 failed` -- once for the `no_match` and once for the
# coordinate that did not land. It cleared on the next run, which is exactly the
# kind of "run it twice" that hides a real fault. Found merging `DRASS France`
# into a new label on 2026-09-16.
renamed_away <- join_key(existing$target[existing$decision_type == "label_rename"])
tgt_key <- join_key(existing$target)
dead <- existing$decision_type == "coordinate" &
        ((!(tgt_key %in% sheet_labels) & !(tgt_key %in% join_key(real_labels))) |
         tgt_key %in% renamed_away)
if (any(dead)) {
  cat(sprintf("dropped %d coordinate decision(s) for label(s) gone from the deliverables or renamed away:\n",
              sum(dead)))
  cat(sprintf("  %s\n", existing$target[dead]), sep = "")
  existing <- existing[!dead, , drop = FALSE]
}

kept <- existing %>%
  filter(decision_type != "coordinate" |
           !(join_key(target) %in% sheet_labels))
n_foreign <- sum(kept$decision_type == "coordinate", na.rm = TRUE)

# The sign-offs from 3b, appended: one per label, and only for a label that does not
# already carry one. Every sign-off already in the file passes through in `kept`,
# untouched, hand-written or not.
already_signed <- join_key(existing$target[existing$decision_type %in%
                                             c("accept_as_is", "note_only")])
both <- intersect(join_key(signoff$affiliation_simple), join_key(new_coords$target))
if (length(both))
  stop("a label cannot both take a coordinate and stay without one. Both were\n",
       "answered for:\n",
       paste(sprintf("  %s", signoff$affiliation_simple[
         join_key(signoff$affiliation_simple) %in% both]), collapse = "\n"),
       "\nNothing was written.", call. = FALSE)

# as.character() on both ifelse()s: over no rows they come back logical, and
# bind_rows() refuses to combine that with the character columns of the file.
new_signoff <- signoff %>%
  filter(!join_key(affiliation_simple) %in% already_signed) %>%
  transmute(decision_type = "accept_as_is",
            target        = as.character(affiliation_simple),
            new_value     = "", latitude = "", longitude = "",
            note          = as.character(ifelse(nzchar(your_note),
                                   paste0("left without a coordinate: ", your_note),
                                   "left without a coordinate")),
            decided_on    = as.character(ifelse(nzchar(decided_on), decided_on,
                                   as.character(Sys.Date()))))

# A `place` row ticked WITH A NOTE IN M is a sign-off as well as a coordinate: the
# point is not in the town its text names, you have looked, and it is right.
# R/check_coord_place.R tests geography and not status, so without a sign-off it
# raises the same label on every run for ever. `MoiU Eldoret Kenya` sits 26 km
# from Eldoret because the campus is at Kesses; `JKUAT Kenya` addresses Nairobi
# from Juja, 31 km away. Both are right, and both need saying once.
#
# The note is what makes it an act. A place row for a label that is already
# `decided` arrives carrying the yes you gave its coordinate before the sweep
# existed - `MTTI Kendu Bay Kenya` was ticked at a point in Mombasa - so a bare
# tick cannot mean "checked against the town" and must not sign anything off.
# Ticked with no note is reported at the end of every run instead, and the reason
# you type is what the decision records.
#
# Appended and never rewritten, exactly like the `absent` sign-offs above, and
# only for a label that does not already carry one. Typing a different coordinate
# on the row signs nothing off either: the row stops matching its candidate and
# comes back as `manual`, so `case` is still the test.
#
# It is an `accept_as_is`, which check_coord_sanity.R honours too, so this also
# stops the country sweep raising that label. That is the same trade the five
# existing sign-offs make.
new_place_signoff <- accepted %>%
  filter(case == "place", place_signed) %>%
  distinct(affiliation_simple, .keep_all = TRUE) %>%
  filter(!join_key(affiliation_simple) %in% already_signed) %>%
  transmute(decision_type = "accept_as_is",
            target        = as.character(affiliation_simple),
            new_value     = "", latitude = "", longitude = "",
            # what the sweep found, without the instruction the sheet cell carries,
            # plus anything typed in M
            note          = as.character(sprintf("place checked and correct: %s%s",
                              sub("\\. If this point.*$", "", geocoder_notes),
                              ifelse(nzchar(your_note), paste0("; ", your_note), ""))),
            # today, always: the date in N belongs to the coordinate answer this
            # row inherited, often years before the place sweep existed, and this
            # sign-off is being made now
            decided_on    = as.character(Sys.Date()))

out <- bind_rows(kept, new_coords, new_signoff, new_place_signoff) %>%
  mutate(across(everything(), blank))
write_csv(out, F_DECISIONS, na = "")

# ---- 4b. where each point actually is ----------------------------------------
#
# One line per row that carries a coordinate, saying what town the point is in and
# how far that is from the place the text names. Display only, regenerated every
# run, and the answer to how `MTTI Kendu Bay Kenya` was ticked at a point in
# Mombasa: the fact was in NEXT_STEPS.md and in no cell of the sheet the answer
# was typed into. It covers rows R/check_coord_place.R cannot flag, because the
# reverse direction always resolves - Maseno is not in the gazetteer, but "0.5 km
# from Nairobi" on a row labelled `MasenoU Maseno Kenya` is unmissable.
cand$place_check <- ""
has_xy <- !is.na(cand$latitude) & !is.na(cand$longitude)
if (any(has_xy)) {
  iso <- place_iso_at(cand$latitude[has_xy], cand$longitude[has_xy])
  cand$place_check[has_xy] <- unlist(Map(place_line,
    cand$latitude[has_xy], cand$longitude[has_xy],
    paste(cand$affiliation_simple[has_xy], blank(cand$affiliation[has_xy])),
    iso), use.names = FALSE)
}

# ---- 5. rebuild the sheet ----------------------------------------------------

sheet <- cand %>%
  mutate(across(where(is.character), blank),
         # write back the word that was typed, not the one it normalises to, so
         # the sheet goes on showing which coordinates you have checked against
         # the town their text names
         accepted = ifelse(place_signed & nzchar(accepted), "checked", accepted)) %>%
  arrange(match(status, c("FLAGGED - not in the town the text names",
                          "open", "open - some candidates rejected",
                          "rejected - needs a new coordinate",
                          "left absent - signed off", "settled")),
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
if (nrow(new_signoff))
  cat(sprintf("         %d accept_as_is row(s) appended: label(s) left without a coordinate\n",
              nrow(new_signoff)))
if (nrow(new_coords) == 0)
  cat("\nNothing accepted yet. Open the sheet, put yes against the coordinate you\n",
      "want for each label, save, and run this again.\n", sep = "")
place_unsigned <- accepted %>%
  filter(case == "place", !place_signed) %>%
  distinct(affiliation_simple, .keep_all = TRUE) %>%
  filter(!join_key(affiliation_simple) %in% already_signed)
if (nrow(place_unsigned)) {
  cat(sprintf("\n!! %d flagged coordinate(s) are ticked `yes`, which is the answer they carried\n",
              nrow(place_unsigned)))
  cat("   before the place sweep existed, so nothing has been checked against the town\n",
      "   the text names. They are raised again on every run until either the right\n",
      "   coordinate goes into H and I, or column A says `checked`:\n", sep = "")
  cat(sprintf("  %-42s %s\n", substr(place_unsigned$affiliation_simple, 1, 42),
              sub("\\. If this point.*$", "", place_unsigned$geocoder_notes)), sep = "")
}
if (nrow(unkept)) {
  cat(sprintf("\n!! %d row(s) typed into the sheet were not kept; the sheet has been rewritten without them:\n",
              nrow(unkept)))
  cat(sprintf("  %s\n    %s. A '%s'  H %s  I %s  M '%s'\n",
              unkept$affiliation_simple, unkept$why, unkept$accepted,
              ifelse(is.na(unkept$latitude), "-", sprintf("%.7f", unkept$latitude)),
              ifelse(is.na(unkept$longitude), "-", sprintf("%.7f", unkept$longitude)),
              unkept$your_note), sep = "")
}
