# absent_review.R --------------------------------------------------------------
#
# The spreadsheet loop for affiliations recorded as ABSENT.
#
#   Rscript R/absent_review.R
#   -> open data/absent_review.xlsx, type the affiliation and its label, save
#   Rscript R/absent_review.R          # answers -> data/added_affiliations.csv
#   python3 R/tidy_affiliations.py && python3 R/verify_affiliations.py
#
# 59 rows of deliverable 1 carry `affiliation = ABSENT`, over 58 papers: whoever
# entered them could not find an affiliation for that paper. This puts one row in
# front of you per ABSENT row, with the citation and a search link, and turns what
# you type into rows of data/added_affiliations.csv - the same file that carried
# the five affiliations of Diop et al. 2002.
#
# Two columns are yours:
#   A affiliation         the affiliation as published. Leave blank to skip
#   B affiliation_simple  the short label. An existing one merges this paper into
#                         it; a new one creates a new label, which will then want a
#                         coordinate and will appear in coord_review.xlsx by itself.
#                         Already filled in where the row had a label but no
#                         affiliation text - leave it alone unless it is wrong
#
# ONE PAPER, SEVERAL AFFILIATIONS: copy the whole row, paste it below, and change
# the affiliation. Any row carrying a citation and an affiliation is read, so the
# sheet does not limit how many a paper can have. The seeded rows are one per
# ABSENT row, not per paper, so a paper with two placeholders starts with two.
#
# What happens to the ABSENT row itself: tidy_affiliations.py drops it. Any
# citation with real rows in added_affiliations.csv has its ABSENT placeholders
# removed, so the paper ends up with the affiliations you entered and nothing else.
#
# What it owns: the rows of data/added_affiliations.csv whose citation is one of
# the ABSENT papers. Every other row in that file - Diop et al. 2002, say - is
# passed through untouched.
#
# The sheet is .xlsx, not .csv, deliberately - see CLAUDE.md rule 1.

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

F_SHEET <- file.path(root, "data", "absent_review.xlsx")
F_ADDED <- file.path(root, "data", "added_affiliations.csv")
F_D1    <- file.path(root, "output", "final", "affiliations_complete_20260817.csv")

ADD_COLS   <- c("source_citation", "affiliation", "affiliation_simple",
                "note", "added_on")
SHEET_COLS <- c("affiliation", "affiliation_simple", "status", "source_citation",
                "n", "other_labels_on_this_paper", "your_note", "added_on",
                "find_the_paper")

blank <- function(x) ifelse(is.na(x), "", as.character(x))
today <- format(Sys.Date(), "%Y-%m-%d")

# --- which rows are ABSENT ------------------------------------------------------

d1 <- read_csv(F_D1, col_types = cols(.default = col_character()))

is_absent <- function(x) is.na(x) | toupper(trimws(blank(x))) == "ABSENT"

absent <- d1 %>%
  mutate(row_i = row_number()) %>%
  filter(is_absent(affiliation))

papers <- unique(absent$source_citation)

# Labels already on the same paper, so a paper that has real affiliations as well
# as a placeholder shows what the others were called.
others <- d1 %>%
  filter(source_citation %in% papers, !is_absent(affiliation),
         !is.na(affiliation_simple)) %>%
  group_by(source_citation) %>%
  summarise(other_labels_on_this_paper =
              paste(sort(unique(affiliation_simple)), collapse = " | "),
            .groups = "drop")

# A search link, built from the title where the citation marks one up in <b>.
search_url <- function(cit) {
  title <- sub(".*<b>(.*?)</b>.*", "\\1", cit)
  if (identical(title, cit)) title <- substr(gsub("<[^>]+>", "", cit), 1, 120)
  title <- gsub("<[^>]+>", "", title)
  paste0("https://scholar.google.com/scholar?q=",
         utils::URLencode(trimws(title), reserved = TRUE))
}

# Some rows have no affiliation text but DO already carry a label - the geocoding
# works, only the published wording is missing. Seed the label so it is not lost:
# the ABSENT row is dropped once the paper is supplied, and a blank column B would
# take the label with it.
seed <- absent %>%
  transmute(source_citation,
            n = blank(n),
            affiliation = "",
            affiliation_simple = ifelse(is_absent(affiliation_simple), "",
                                        blank(affiliation_simple)),
            your_note = "", added_on = "") %>%
  left_join(others, by = "source_citation") %>%
  mutate(other_labels_on_this_paper = blank(other_labels_on_this_paper),
         find_the_paper = vapply(source_citation, search_url, character(1)))

# --- what you typed last time ---------------------------------------------------

read_answers <- function() {
  empty <- tibble(source_citation = character(), affiliation = character(),
                  affiliation_simple = character(), your_note = character(),
                  added_on = character())
  if (!file.exists(F_SHEET)) return(empty)
  s <- readxl::read_excel(F_SHEET, col_types = "text")
  for (cl in c("source_citation", "affiliation", "affiliation_simple",
               "your_note", "added_on"))
    if (!cl %in% names(s)) s[[cl]] <- NA_character_
  s %>%
    transmute(source_citation = trimws(blank(source_citation)),
              affiliation = trimws(blank(affiliation)),
              affiliation_simple = trimws(blank(affiliation_simple)),
              your_note = blank(your_note), added_on = blank(added_on)) %>%
    filter(nzchar(source_citation), nzchar(affiliation))
}

ans <- read_answers()

unknown <- setdiff(ans$source_citation, d1$source_citation)
if (length(unknown)) {
  cat("these citations are not in deliverable 1 - a typo, or the citation was\n",
      "edited rather than copied whole:\n", sep = "")
  cat(sprintf("  %s\n", substr(unknown, 1, 90)), sep = "")
  stop("fix `source_citation` in ", basename(F_SHEET), call. = FALSE)
}

# --- write the additions file ---------------------------------------------------

existing <- if (file.exists(F_ADDED)) {
  read_csv(F_ADDED, col_types = cols(.default = col_character()))
} else {
  as_tibble(setNames(rep(list(character()), length(ADD_COLS)), ADD_COLS))
}
miss <- setdiff(ADD_COLS, names(existing))
if (length(miss))
  stop(F_ADDED, " is missing columns: ", paste(miss, collapse = ", "), call. = FALSE)

# Rows for papers this sheet does not cover are none of its business.
kept <- existing %>% filter(!source_citation %in% papers)

# as.character() throughout: with no answers yet every ifelse() returns
# logical(0), and bind_rows then refuses to combine it with a character column.
DEFAULT_NOTE <- "entered by hand; the source recorded this paper's affiliation as ABSENT"
mine <- ans %>%
  transmute(source_citation = as.character(source_citation),
            affiliation = as.character(affiliation),
            affiliation_simple = as.character(affiliation_simple),
            note = as.character(ifelse(nzchar(your_note), your_note, DEFAULT_NOTE)),
            added_on = as.character(ifelse(nzchar(added_on), added_on, today)))

write_csv(bind_rows(kept, mine)[, ADD_COLS], F_ADDED, na = "")

# --- rebuild the sheet ----------------------------------------------------------
# Seeded rows for papers you have already answered are dropped: the answer rows
# replace them, so a paper never shows both a filled row and an empty one.

answered <- unique(mine$source_citation)

filled <- mine %>%
  transmute(source_citation, affiliation, affiliation_simple,
            your_note = as.character(ifelse(note == DEFAULT_NOTE, "", note)),
            added_on = as.character(added_on)) %>%
  left_join(select(seed, source_citation, n, other_labels_on_this_paper,
                   find_the_paper) %>% distinct(source_citation, .keep_all = TRUE),
            by = "source_citation")

sheet <- bind_rows(filled, filter(seed, !source_citation %in% answered)) %>%
  mutate(status = ifelse(nzchar(blank(affiliation)), "filled", "open")) %>%
  arrange(match(status, c("open", "filled")), source_citation) %>%
  select(all_of(SHEET_COLS))

writexl::write_xlsx(list(absent = sheet), F_SHEET)

# --- report ---------------------------------------------------------------------

cat("sheet    ", F_SHEET, "\n", sep = "")
cat(sprintf("         %d rows over %d papers\n", nrow(sheet),
            length(unique(sheet$source_citation))))
print(as.data.frame(count(sheet, status, name = "n")), row.names = FALSE)

cat("\nadditions ", F_ADDED, "\n", sep = "")
cat(sprintf("         %d row(s) written from this sheet, over %d paper(s)\n",
            nrow(mine), length(answered)))
cat(sprintf("         %d row(s) preserved for papers this sheet does not cover\n",
            nrow(kept)))

no_label <- mine %>% filter(!nzchar(affiliation_simple))
if (nrow(no_label))
  cat(sprintf("\n%d affiliation(s) have no affiliation_simple. That is allowed - the row\njoins no label and gets no coordinate - but it is usually a slip.\n",
              nrow(no_label)))

new_lab <- setdiff(mine$affiliation_simple[nzchar(mine$affiliation_simple)],
                   d1$affiliation_simple)
if (length(new_lab)) {
  cat(sprintf("\n%d new label(s), which will want a coordinate. They appear in\ncoord_review.xlsx as `needs a coordinate` rows after the next rebuild:\n",
              length(new_lab)))
  cat(sprintf("  %s\n", sort(new_lab)), sep = "")
}
