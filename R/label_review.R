# label_review.R ---------------------------------------------------------------
#
# The spreadsheet loop for label merges, exactly like coord_review.R is for
# coordinates.  You never hand-write a decision line.
#
#   Rscript R/label_review.R
#   -> open data/label_review.xlsx, put yes/no in the `accepted` column, save
#   Rscript R/label_review.R          # answers -> data/affiliation_decisions.csv
#   Rscript R/coord_review.R          # re-emit the coordinate rows
#   python3 R/tidy_affiliations.py && python3 R/verify_affiliations.py
#
# One row per *candidate pair*: two labels that may be one place.  Column A is
# `accepted`; column C is `keep`, the label that survives.  `keep` is filled in
# for you with a guess.  Retype it to change the answer, and it does not have to
# be one of the two labels on the row - name any label and both of them merge
# into it.  So "these three are all one place, keep the third one" is a single
# yes on a single row.  Everything else is evidence, regenerated each run.
#
# Ticking several rows that share a label merges the whole group.  The script
# resolves the group first, then writes one `label_rename` per label that is
# disappearing, each naming the final survivor directly.  That is what stops the
# chained-rename trap in CLAUDE.md - a rename whose target is itself renamed
# later reports no_match and fails verify.
#
# What it owns: every `label_rename` row of data/affiliation_decisions.csv.
# Renames already in that file when you first run this are seeded into the sheet
# as answered rows, so nothing is lost, and they are re-emitted every run.
# `coordinate`, `affiliation_relabel` and every other decision type is passed
# through untouched, the mirror of what coord_review.R does.
#
# Rows are grouped, not listed one by one.  Every pair that shares a label with
# another pair is in the same cluster, and the whole cluster sits together in
# the sheet under one `group` name - the cluster's busiest label - so a family
# of five spellings is thought about once rather than prosecuted five times in
# five places.  Clusters with unanswered rows come first.
#
# Column Q `warning` is the one to read before you tick.  A merge keeps one
# coordinate and throws the other away without asking - the survivor's, unless
# only the label merged away carries a coordinate you chose, which then follows
# the merge - so it says how far apart the two points are, whether the one being
# discarded is a coordinate you chose yourself rather than an unexamined source
# value, and whether either point is one of the suspects in
# review_coord_sanity.csv.  The two google_maps columns (W, X) are there so you
# can look at both before deciding.  Column Y `lake` says which side carries Gia's
# lake-region rows: a, b or both.
# A merge whose discarded point is the sanity-flagged one is the comfortable
# case; keeping a flagged point is the one to think about.
#
# Coordinates.  Merging a label away strands any `coordinate` decision naming
# it, which fails verify.  This script fixes that in data/coord_review.xlsx, the
# only place coordinate answers may live:
#   - survivor has no coordinate of its own -> the merged label's sheet row is
#     retargeted to the survivor, so the coordinate you already chose follows
#     the merge;
#   - both have one -> the survivor keeps its own and the merged label's row is
#     blanked in column A.
# Both are reported line by line.  Run coord_review.R afterwards to turn the
# patched sheet back into decisions.
#
# The sheet is .xlsx, not .csv, deliberately - see CLAUDE.md rule 1.
#
# Nothing here edits a deliverable.

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
})
stopifnot(requireNamespace("readxl", quietly = TRUE),
          requireNamespace("writexl", quietly = TRUE))

root <- getwd()
while (!all(dir.exists(file.path(root, c("output", "data")))) &&
       dirname(root) != root) root <- dirname(root)
if (!all(dir.exists(file.path(root, c("output", "data")))))
  stop("run this from the project root (the directory holding data/ and output/)",
       call. = FALSE)

F_SHEET     <- file.path(root, "data", "label_review.xlsx")
F_COORD     <- file.path(root, "data", "coord_review.xlsx")
F_DECISIONS <- file.path(root, "data", "affiliation_decisions.csv")
F_PAIRS     <- file.path(root, "output", "review_label_duplicates.csv")
F_SANITY    <- file.path(root, "output", "review_coord_sanity.csv")
F_SOURCES   <- file.path(root, "output", "label_sources.csv")

FLAG_MERGE_KM <- 5    # coordinates further apart than this are worth a look

DEC_COLS <- c("decision_type", "target", "new_value", "latitude", "longitude",
              "note", "decided_on")

SHEET_COLS <- c("accepted", "status", "keep", "label_a", "label_b",
                "group", "group_n", "evidence", "strength",
                "n_rows_a", "n_rows_b", "coord_status_a", "coord_status_b",
                "coordinate_a", "coordinate_b", "distance_km", "warning",
                "your_note", "decided_on", "detail",
                "affiliations_a", "affiliations_b",
                "google_maps_a", "google_maps_b", "lake")

blank <- function(x) ifelse(is.na(x), "", as.character(x))
today <- format(Sys.Date(), "%Y-%m-%d")

deliverable <- function(name) {
  f <- file.path(root, "output", "final", name)
  if (!file.exists(f)) stop(f, " not found; run python3 R/tidy_affiliations.py first",
                            call. = FALSE)
  f
}

# A pair is identified by its two labels, whichever order they were written in.
pair_key <- function(a, b) ifelse(a < b, paste(a, b, sep = "\001"),
                                        paste(b, a, sep = "\001"))

# Transcription of join_key() in tidy_affiliations.py:164, the same one
# coord_review.R carries. Used here only to refuse a new label whose key matches a
# label that already exists: tidy_affiliations.py would then call a `coordinate`
# decision naming either of them ambiguous.
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

# --- the labels as they stand --------------------------------------------------

d3 <- read_csv(deliverable("affiliation_simple_coords.csv"),
               col_types = cols(.default = col_character()), progress = FALSE) %>%
  mutate(n_rows = suppressWarnings(as.integer(n_rows)))

lookup <- read_csv(deliverable("affiliation_lookup.csv"),
                   show_col_types = FALSE, progress = FALSE)

aff_of <- lookup %>%
  group_by(affiliation_simple) %>%
  summarise(affs = paste(sort(unique(affiliation)), collapse = " | "),
            .groups = "drop")

info <- d3 %>%
  transmute(label = affiliation_simple, n_rows,
            coord_status,
            coordinate = ifelse(is.na(latitude) | !nzchar(blank(latitude)), "",
                                paste0(latitude, ", ", longitude))) %>%
  left_join(aff_of, by = c("label" = "affiliation_simple")) %>%
  mutate(affs = blank(affs))

live <- info$label

# Labels the coordinate sanity sweep flagged.  Used only to annotate the
# warning column; absent file just means no annotation.
flagged <- if (file.exists(F_SANITY)) {
  read_csv(F_SANITY, show_col_types = FALSE, progress = FALSE)$affiliation_simple
} else character(0)

# Which labels carry Gia's lake-region rows, for the `lake` column. Written by
# tidy_affiliations.py; absent file just means an empty column.
lake_rows <- if (file.exists(F_SOURCES)) {
  s_ <- read_csv(F_SOURCES, col_types = cols(.default = col_character()), progress = FALSE)
  setNames(suppressWarnings(as.integer(s_$n_rows_lake)), s_$affiliation_simple)
} else integer(0)
has_lake <- function(l) { v <- unname(lake_rows[l]); !is.na(v) & v > 0 }

maps_url <- function(coord) ifelse(nzchar(coord),
  paste0("https://www.google.com/maps/search/?api=1&query=",
         gsub(" ", "", coord, fixed = TRUE)), "")

# Which of a pair should survive, unless you say otherwise.  A short label beats
# a whole affiliation string, a settled coordinate beats an unsettled one, more
# rows beats fewer.  It is only a default; column C is yours to retype.
is_short <- function(l) !grepl(",", l, fixed = TRUE) &
                        lengths(strsplit(l, "\\s+")) <= 5L
rank_of <- function(l) {
  i <- match(l, info$label)
  st <- ifelse(is.na(i), "", info$coord_status[i])
  nr <- ifelse(is.na(i), 0L, info$n_rows[i])
  cbind(as.integer(is_short(l)),
        match(st, c("decided", "ok", "missing", "absent", ""), nomatch = 9L) * -1L,
        nr,
        -lengths(strsplit(l, "\\s+")),
        -nchar(l))
}
better <- function(a, b) {
  ra <- rank_of(a); rb <- rank_of(b)
  res <- rep(NA, length(a))
  for (j in seq_len(ncol(ra))) {
    open <- is.na(res)
    res[open & ra[, j] > rb[, j]] <- TRUE
    res[open & ra[, j] < rb[, j]] <- FALSE
  }
  res[is.na(res)] <- TRUE
  res
}
default_keep <- function(a, b) ifelse(better(a, b), a, b)

# --- 1. candidate pairs from the sweep -----------------------------------------

if (!file.exists(F_PAIRS))
  stop(F_PAIRS, " not found - run Rscript R/check_label_candidates.R first",
       call. = FALSE)

pairs <- read_csv(F_PAIRS, show_col_types = FALSE, progress = FALSE) %>%
  transmute(label_a, label_b,
            evidence = blank(evidence),
            strength = as.integer(strength),
            distance_km = blank(distance_km),
            detail = blank(detail)) %>%
  filter(label_a %in% live, label_b %in% live)

# --- 2. renames already recorded, so the sheet owns them without losing them ----

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

prior <- existing %>%
  filter(decision_type == "label_rename",
         !is.na(target), !is.na(new_value)) %>%
  transmute(label_a = target, label_b = new_value,
            keep = new_value,
            evidence = "already applied", strength = NA_integer_,
            distance_km = "", detail = "",
            your_note = blank(note), decided_on = blank(decided_on))

# --- 3. your answers from last time --------------------------------------------

read_answers <- function() {
  empty <- tibble(pk = character(), accepted = character(), keep = character(),
                  label_a = character(), label_b = character(),
                  your_note = character(), decided_on = character())
  if (!file.exists(F_SHEET)) return(empty)
  s <- readxl::read_excel(F_SHEET, col_types = "text")
  for (cl in c("accepted", "keep", "label_a", "label_b", "your_note", "decided_on"))
    if (!cl %in% names(s)) s[[cl]] <- NA_character_
  s %>%
    filter(!is.na(label_a), nzchar(trimws(label_a)),
           !is.na(label_b), nzchar(trimws(label_b))) %>%
    transmute(label_a = trimws(label_a), label_b = trimws(label_b),
              keep = trimws(blank(keep)),
              accepted = tolower(trimws(blank(accepted))),
              your_note = blank(your_note), decided_on = blank(decided_on)) %>%
    mutate(accepted = case_when(
             accepted %in% c("y", "yes", "true", "1", "x") ~ "yes",
             accepted %in% c("n", "no", "false", "0")      ~ "no",
             accepted == ""                                 ~ "",
             TRUE                                           ~ accepted),
           # `new: DRASS Reunion` in `keep` merges the row into a label of that
           # name, creating it. The marker is deliberate: a bare unknown name is
           # far more often a typo, and without the marker that typo would rename
           # real labels into something nobody meant. The prefix is stripped here,
           # so the sheet shows the plain name from the next run on.
           keep_new = grepl("^new:", keep, ignore.case = TRUE),
           keep     = trimws(sub("^new:", "", keep, ignore.case = TRUE)),
           pk = pair_key(label_a, label_b))
}

ans <- read_answers()

bad <- setdiff(unique(ans$accepted), c("", "yes", "no"))
if (length(bad))
  stop("`accepted` must be yes, no or blank. Found: ",
       paste(sprintf("'%s'", bad), collapse = ", "), call. = FALSE)

# Seed from the decisions file only the first time, or for renames the sheet has
# never carried, so a row you have since said `no` to is not resurrected.
prior_new <- prior %>%
  mutate(pk = pair_key(label_a, label_b)) %>%
  filter(!pk %in% ans$pk)
if (nrow(prior_new))
  ans <- bind_rows(ans, transmute(prior_new, pk, accepted = "yes", keep,
                                  keep_new = FALSE,
                                  label_a, label_b, your_note, decided_on))

# --- 4. the sheet ---------------------------------------------------------------

cand <- pairs %>% mutate(pk = pair_key(label_a, label_b))

# rows you have answered whose pair the sweep no longer raises: the merge has
# been applied, or a label has gone.  Keep them, they are the record.
carried <- ans %>%
  filter(!pk %in% cand$pk, accepted != "") %>%
  transmute(label_a, label_b, pk,
            evidence = "already applied", strength = NA_integer_,
            distance_km = "", detail = "")

cand <- bind_rows(cand, carried) %>%
  left_join(select(ans, pk, accepted, keep_ans = keep, keep_new, your_note, decided_on),
            by = "pk") %>%
  mutate(accepted   = blank(accepted),
         your_note  = blank(your_note),
         decided_on = blank(decided_on),
         keep_new   = !is.na(keep_new) & keep_new,
         keep       = ifelse(nzchar(blank(keep_ans)), blank(keep_ans),
                             default_keep(label_a, label_b)))

# `keep` may name a label that is not on the row - then both of the row's labels
# merge into it - so the only thing to check is that the name is real.  A label
# merged away in an earlier run is no longer live but is still a legitimate
# answer: the group resolution below carries it through to the final survivor.
known <- unique(c(live,
                  cand$label_a[cand$accepted == "yes"],
                  cand$label_b[cand$accepted == "yes"]))
bad_keep <- cand$accepted == "yes" & !(cand$keep %in% known) & !cand$keep_new
if (any(bad_keep)) {
  cat("`keep` must be an affiliation_simple that exists. These do not:\n")
  cat(sprintf("  keep=%s   (row: %s | %s)\n", cand$keep[bad_keep],
              cand$label_a[bad_keep], cand$label_b[bad_keep]), sep = "")
  stop("fix `keep` in ", basename(F_SHEET), ", or write it as `new: <name>` to ",
       "merge the row into a label of that name and create it", call. = FALSE)
}

# A `new:` name that is not new. Two labels whose join_key matches make every
# `coordinate` decision naming either of them ambiguous in tidy_affiliations.py,
# so such a name is refused rather than created.
new_named <- cand$accepted == "yes" & cand$keep_new
if (any(new_named)) {
  made  <- unique(cand$keep[new_named])
  clash <- made[join_key(made) %in% join_key(live)]
  if (length(clash)) {
    cat("`new:` names a label that already exists, or resolves to one:\n")
    for (x in clash)
      cat(sprintf("  new: %-36s -> %s\n", x,
                  paste(live[join_key(live) == join_key(x)], collapse = ", ")))
    stop("drop the `new:` to merge into it, or choose another name", call. = FALSE)
  }
  cat(sprintf("new label%s created by this run: %s\n",
              if (length(made) > 1) "s" else "", paste(made, collapse = "; ")))
}

# --- 5. resolve the accepted merges into groups --------------------------------

acc <- cand %>% filter(accepted == "yes")

renames <- tibble(target = character(), new_value = character(),
                  note = character(), decided_on = character())

# A rename is dated when it was first applied, not when this script last ran.
# Most applied rows carry no date in the sheet, and falling back to `today` on
# every run re-dated them all each time: on 2026-09-11 it moved 67 renames from
# 2026-09-10, itself only the previous run's date. So the sheet's date if one
# was given, else the date already recorded for this same rename, else today.
recorded_on <- existing %>%
  filter(decision_type == "label_rename", nzchar(blank(decided_on))) %>%
  distinct(target, new_value, .keep_all = TRUE)
recorded_on <- setNames(recorded_on$decided_on,
                        paste(recorded_on$target, recorded_on$new_value, sep = "\r"))
date_for <- function(sheet_date, target, new_value) {
  if (!is.na(sheet_date) && nzchar(sheet_date)) return(sheet_date)
  d <- unname(recorded_on[paste(target, new_value, sep = "\r")])
  if (length(d) == 1L && !is.na(d)) d else today
}

if (nrow(acc)) {
  labs <- unique(c(acc$label_a, acc$label_b, acc$keep))
  parent <- setNames(labs, labs)
  find <- function(x) { while (parent[[x]] != x) x <- parent[[x]]; x }
  join <- function(x, y) {
    rx <- find(x); ry <- find(y)
    if (rx != ry) parent[[ry]] <<- rx
  }
  for (i in seq_len(nrow(acc))) {
    join(acc$label_a[i], acc$label_b[i])
    join(acc$label_a[i], acc$keep[i])
  }
  comp <- vapply(labs, find, character(1))

  # every label on an accepted row that is not the one it says to keep
  gone <- unique(unlist(lapply(seq_len(nrow(acc)), function(i)
    setdiff(c(acc$label_a[i], acc$label_b[i]), acc$keep[i]))))

  for (g in unique(comp)) {
    members <- labs[comp == g]
    survivors <- setdiff(members, gone)
    if (length(survivors) == 0L)
      stop("every label in this merge group is being merged away, so nothing ",
           "survives - one of them must be named in `keep`:\n  ",
           paste(members, collapse = "\n  "), call. = FALSE)
    if (length(survivors) > 1L)
      stop("this merge group names ", length(survivors), " survivors; it can ",
           "only have one. Make `keep` agree across its rows:\n  ",
           paste(survivors, collapse = "\n  "), call. = FALSE)
    surv <- survivors[1]
    for (m in setdiff(members, surv)) {
      row <- which((acc$label_a == m | acc$label_b == m) & acc$keep != m)[1]
      renames <- bind_rows(renames, tibble(
        target = m, new_value = surv,
        note = if (!is.na(row) && nzchar(acc$your_note[row])) acc$your_note[row]
               else sprintf("merged into %s", surv),
        decided_on = date_for(if (!is.na(row)) acc$decided_on[row] else NA_character_,
                              m, surv)))
    }
  }
}

# --- 6. write the decisions file ------------------------------------------------

kept <- existing %>% filter(decision_type != "label_rename")

out <- bind_rows(
  kept,
  transmute(renames, decision_type = "label_rename", target, new_value,
            latitude = "", longitude = "", note, decided_on)
) %>%
  mutate(across(everything(), blank))

write_csv(out, F_DECISIONS, na = "")

# --- 7. keep coord_review.xlsx consistent ---------------------------------------

coord_notes <- character(0)
if (nrow(renames) && file.exists(F_COORD)) {
  cs <- readxl::read_excel(F_COORD)
  for (cl in c("accepted", "affiliation_simple", "your_note", "decided_on"))
    if (cl %in% names(cs)) cs[[cl]] <- as.character(cs[[cl]])

  acc_yes <- tolower(trimws(blank(cs$accepted))) %in% c("y", "yes", "true", "1", "x")
  survivors_with_coord <- unique(cs$affiliation_simple[acc_yes])
  changed <- FALSE

  for (i in seq_len(nrow(renames))) {
    from <- renames$target[i]; to <- renames$new_value[i]
    hit <- which(acc_yes & cs$affiliation_simple == from)
    if (!length(hit)) next
    if (to %in% survivors_with_coord) {
      cs$accepted[hit] <- ""
      coord_notes <- c(coord_notes, sprintf(
        "  blanked accepted for '%s' (row %d) - '%s' keeps its own coordinate",
        from, hit[1] + 1L, to))
    } else {
      cs$affiliation_simple[hit] <- to
      survivors_with_coord <- c(survivors_with_coord, to)
      coord_notes <- c(coord_notes, sprintf(
        "  retargeted '%s' -> '%s' (row %d) - the coordinate follows the merge",
        from, to, hit[1] + 1L))
    }
    changed <- TRUE
  }
  if (changed) writexl::write_xlsx(cs, F_COORD)
}

# --- 8. rebuild the sheet --------------------------------------------------------

side <- function(lab, field) {
  i <- match(lab, info$label)
  ifelse(is.na(i), "", blank(info[[field]][i]))
}

# --- 8a. clusters -------------------------------------------------------------
# Connected components of the candidate-pair graph.  Every edge counts, weak
# ones included: the point is to see everything that might be related to the
# label in hand at the same time, and dismissing a weak edge is cheap once you
# are already looking at the family.

cl_labels <- unique(c(cand$label_a, cand$label_b))
cl_parent <- setNames(cl_labels, cl_labels)
cl_find <- function(x) { while (cl_parent[[x]] != x) x <- cl_parent[[x]]; x }
for (i in seq_len(nrow(cand))) {
  ra <- cl_find(cand$label_a[i]); rb <- cl_find(cand$label_b[i])
  if (ra != rb) cl_parent[[rb]] <- ra
}
cl_root <- vapply(cl_labels, cl_find, character(1))

# The cluster is named after its busiest label, so the name means something and
# survives a rebuild.
rows_of <- function(l) {
  i <- match(l, info$label)
  ifelse(is.na(i), 0L, info$n_rows[i])
}
anchor <- tapply(cl_labels, cl_root, function(ls) {
  n <- rows_of(ls)
  ls[order(-n, nchar(ls), ls)][1]
})
group_of <- function(l) unname(anchor[cl_root[l]])
group_size <- table(cl_root)

sheet_full <- cand %>%
  mutate(
    group   = group_of(label_a),
    group_n = as.integer(group_size[cl_root[label_a]]),
    status = case_when(accepted == "yes" & evidence == "already applied" ~ "applied",
                       accepted == "yes"                                 ~ "accepted",
                       accepted == "no"                                  ~ "rejected",
                       TRUE                                              ~ "open"),
    n_rows_a       = side(label_a, "n_rows"),
    n_rows_b       = side(label_b, "n_rows"),
    coord_status_a = side(label_a, "coord_status"),
    coord_status_b = side(label_b, "coord_status"),
    coordinate_a   = side(label_a, "coordinate"),
    coordinate_b   = side(label_b, "coordinate"),
    affiliations_a = substr(side(label_a, "affs"), 1, 500),
    affiliations_b = substr(side(label_b, "affs"), 1, 500),
    google_maps_a  = maps_url(coordinate_a),
    google_maps_b  = maps_url(coordinate_b),
    lake           = case_when(has_lake(label_a) & has_lake(label_b) ~ "both",
                               has_lake(label_a) ~ "a", has_lake(label_b) ~ "b",
                               TRUE ~ ""),
    dropped        = ifelse(keep == label_a, label_b, label_a),
    dropped_status = ifelse(keep == label_a, coord_status_b, coord_status_a),
    keep_status    = side(keep, "coord_status"),
    # Which point a merge keeps, as section 7 patches coord_review.xlsx: a survivor
    # with a coordinate you chose keeps it; otherwise a coordinate you chose for the
    # label merged away is retargeted onto the survivor and FOLLOWS the merge, and
    # it is the survivor's own point that goes.
    follows        = dropped_status == "decided" & keep_status != "decided",
    discarded_maps = ifelse(follows == (keep == label_a), google_maps_a, google_maps_b),
    km             = suppressWarnings(as.numeric(distance_km)),
    warning        = vapply(seq_len(n()), function(i) {
      w <- character(0)
      if (!is.na(km[i]) && km[i] > FLAG_MERGE_KM)
        w <- c(w, sprintf("%.0f km apart", km[i]))
      if (nzchar(dropped[i]) && dropped_status[i] == "decided") {
        if (keep_status[i] == "decided")
          w <- c(w, "discards a coordinate you chose")
        else if (keep_status[i] == "ok")
          w <- c(w, "the coordinate you chose follows the merge; the survivor's own point is discarded")
        else if (keep_status[i] == "conflict")
          w <- c(w, "the coordinate you chose follows the merge and settles the survivor's conflict")
      }
      lost <- if (follows[i]) keep[i] else dropped[i]
      held <- if (follows[i]) dropped[i] else keep[i]
      if (lost %in% flagged)
        w <- c(w, "the discarded point is sanity-flagged")
      if (held %in% flagged)
        w <- c(w, "KEEPS a sanity-flagged point")
      paste(w, collapse = "; ")
    }, character(1))) %>%
  group_by(group) %>%
  mutate(g_open     = any(status == "open"),
         g_strength = max(coalesce(strength, 0L))) %>%
  ungroup() %>%
  arrange(desc(g_open), desc(g_strength), desc(group_n), group,
          match(status, c("open", "accepted", "rejected", "applied")),
          desc(coalesce(strength, 0L)), label_a)
sheet <- select(sheet_full, all_of(SHEET_COLS))

writexl::write_xlsx(list(labels = sheet), F_SHEET)

# --- 9. say what happened --------------------------------------------------------

cat("sheet    ", F_SHEET, "\n", sep = "")
cat(sprintf("         %d candidate pairs over %d labels\n",
            nrow(sheet), length(unique(c(sheet$label_a, sheet$label_b)))))
print(as.data.frame(count(sheet, status, name = "n")), row.names = FALSE)

# Only merges not yet built: once a merge is applied the discarded coordinate
# is gone and the warning is history, kept in the sheet's `warning` column.
warned <- sheet_full %>% filter(status == "accepted", nzchar(warning))
if (nrow(warned)) {
  cat(sprintf("\n%d accepted merge(s) discard a coordinate worth checking:\n",
              nrow(warned)))
  w <- warned %>% arrange(desc(suppressWarnings(as.numeric(distance_km))))
  for (i in seq_len(nrow(w)))
    cat(sprintf("  %s\n    keep %s, drop %s\n    point discarded: %s\n",
                w$warning[i], w$keep[i],
                ifelse(w$keep[i] == w$label_a[i], w$label_b[i], w$label_a[i]),
                w$discarded_maps[i]))
}

cat("\ndecisions ", F_DECISIONS, "\n", sep = "")
cat(sprintf("         %d label_rename rows written from the sheet\n", nrow(renames)))
cat(sprintf("         %d other decision rows preserved\n", nrow(kept)))
if (length(coord_notes)) {
  cat("\ncoord_review.xlsx patched so no coordinate decision is stranded:\n")
  cat(coord_notes, sep = "\n"); cat("\n")
  cat("run Rscript R/coord_review.R next, then rebuild.\n")
}
