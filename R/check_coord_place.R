# check_coord_place.R ----------------------------------------------------------
#
# Is each coordinate in the TOWN its text names?  READ-ONLY except for the one
# file it writes, output/review_coord_place.csv.
#
#   Rscript R/check_coord_place.R
#
# The other half of R/check_coord_sanity.R, which tests the country and only the
# country: `MasenoU Maseno Kenya` sat in Nairobi, `MTTI Kendu Bay Kenya` sits in
# Mombasa, and the 98 km Montpellier error passed it, all with `0 flagged`.
#
# It fixes nothing and proposes nothing.  Coordinate calls are the owner's and
# are made in data/coord_review.xlsx: R/coord_review.R turns every row of this
# file into a `case = place` row there, carrying the coordinate as it stands, so
# ticking it means "checked, this is right" (CLAUDE.md rule 5).
#
# Method
#   1. Every row of deliverable 3 that carries a coordinate.
#   2. The town the point is actually in: nearest entry in maps::world.cities.
#      Always available, and the evidence the sheet shows on every row.
#   3. The towns the text names: 1-3 word runs inside each comma field of the
#      label and of its affiliation strings, looked up in the gazetteer,
#      restricted to the country the point is in.  The distance reported is the
#      smallest over those names, so one bad candidate cannot raise a flag on its
#      own - any real place named near the point pulls it back down.
#   4. Flag when that smallest distance is over THRESHOLD_KM.
#
# Why the point's country and not the expected one: check_coord_sanity.R owns the
# country question and currently flags 0, so while it passes, the two are the
# same country.  Where they are not, that sweep reports it and this one finds no
# candidates and says so, rather than measuring against the wrong country.
#
# What it cannot see
#   - a wrong point inside the right town.  Kenyatta University at Kahawa and the
#     centre of Nairobi are 13 km apart and both read as Nairobi.
#   - a town the gazetteer does not hold: Maseno, Mbita and Juja are all absent,
#     and 74 of 324 labels have no name in their text that resolves.  Those are
#     counted and named as `untestable`, never as clean.
#
# Offline throughout: no geocoding service is contacted.
# ------------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
})

root <- normalizePath(".", mustWork = FALSE)
while (!all(dir.exists(file.path(root, c("output", "data")))) &&
       dirname(root) != root) root <- dirname(root)
if (!all(dir.exists(file.path(root, c("output", "data")))))
  stop("run this from the project root (the directory holding data/ and output/)",
       call. = FALSE)

source(file.path(root, "R", "place_lookup.R"))

THRESHOLD_KM <- 25   # a campus is routinely 10-25 km from the city it addresses

F_COORDS <- file.path(root, "output", "final", "affiliation_simple_coords.csv")
F_LOOKUP <- file.path(root, "output", "final", "affiliation_lookup.csv")
F_DEC    <- file.path(root, "data", "affiliation_decisions.csv")
OUT_FILE <- file.path(root, "output", "review_coord_place.csv")

for (f in c(F_COORDS, F_LOOKUP))
  if (!file.exists(f)) stop(f, " not found; run python3 R/tidy_affiliations.py first")

message("coords: ", F_COORDS, "\nlookup: ", F_LOOKUP)

d3 <- read_csv(F_COORDS, show_col_types = FALSE, progress = FALSE) %>%
  mutate(lat = suppressWarnings(as.numeric(latitude)),
         lon = suppressWarnings(as.numeric(longitude)))
co <- filter(d3, !is.na(lat), !is.na(lon))
message(sprintf("%d rows in deliverable 3, %d carry a coordinate", nrow(d3), nrow(co)))

lookup <- read_csv(F_LOOKUP, show_col_types = FALSE, progress = FALSE)
txt <- lookup %>%
  group_by(affiliation_simple) %>%
  summarise(txt = paste(unique(affiliation), collapse = " ; "),
            excerpt = affiliation[which.max(n_rows)], .groups = "drop")

# A label the owner has already signed off is not a suspect - the same two
# decision types check_coord_sanity.R honours, and the same reason: a coordinate
# that is right but cannot pass a mechanical test must be silenceable for good.
signed_off <- character(0)
if (file.exists(F_DEC)) {
  d <- read_csv(F_DEC, col_types = cols(.default = col_character()), progress = FALSE)
  if ("decision_type" %in% names(d))
    signed_off <- unique(d$target[d$decision_type %in% c("accept_as_is", "note_only")])
  signed_off <- signed_off[!is.na(signed_off)]
}

co$point_country <- place_iso_at(co$lat, co$lon)
co$text <- txt$txt[match(co$affiliation_simple, txt$affiliation_simple)]
co$affiliation_excerpt <- txt$excerpt[match(co$affiliation_simple, txt$affiliation_simple)]

n <- nrow(co)
at_name <- at_country <- at_big <- character(n)
at_km <- at_pop <- big_km <- named_km <- rep(NA_real_, n)
named_name <- named_all <- character(n)
n_named <- integer(n)

for (i in seq_len(n)) {
  full <- paste(co$affiliation_simple[i], if (is.na(co$text[i])) "" else co$text[i])
  a <- place_at(co$lat[i], co$lon[i])
  m <- place_named(co$lat[i], co$lon[i], full, co$point_country[i])
  at_name[i] <- if (is.na(a$name)) "" else a$name
  at_country[i] <- if (is.na(a$country)) "" else a$country
  at_km[i] <- a$km; at_pop[i] <- a$pop
  at_big[i] <- if (is.na(a$big_name)) "" else a$big_name
  big_km[i] <- a$big_km
  n_named[i] <- m$n; named_km[i] <- m$km
  named_name[i] <- if (is.na(m$name)) "" else m$name
  named_all[i] <- paste(head(m$all, 8), collapse = "; ")
}

fmt_km <- function(x) ifelse(is.na(x), "?",
                             ifelse(x < 10, sprintf("%.1f km", x), sprintf("%.0f km", x)))
fmt_pop <- function(x) ifelse(is.na(x) | x < 1000, "",
                              sprintf(" (pop %s)", format(round(x), big.mark = ",", trim = TRUE)))

co <- co %>%
  mutate(
    nearest_town = at_name, nearest_town_country = at_country,
    nearest_town_km = at_km, nearest_town_pop = at_pop,
    nearest_big_town = at_big, nearest_big_town_km = big_km,
    n_named_places = n_named, named_place = named_name, named_km = named_km,
    named_places = named_all,
    place_line = sprintf("%s from %s, %s%s; %s",
                         fmt_km(at_km), at_name, at_country, fmt_pop(at_pop),
                         ifelse(n_named == 0L,
                                "no place in the text resolves in the gazetteer",
                                sprintf("text names %s, %s away", named_name,
                                        fmt_km(named_km)))),
    flag_type = case_when(
      n_named_places > 0L & !is.na(named_km) & named_km > THRESHOLD_KM ~ "far_from_named_place",
      TRUE ~ ""),
    place_note = ifelse(
      flag_type == "far_from_named_place",
      sprintf("the text names %s and this point is %s from it; the point is %s from %s, %s%s",
              named_place, fmt_km(named_km), fmt_km(nearest_town_km), nearest_town,
              nearest_town_country, fmt_pop(nearest_town_pop)),
      ""))

skipped <- co$affiliation_simple %in% signed_off & nzchar(co$flag_type)
if (any(skipped)) {
  message(sprintf("signed off with accept_as_is/note_only, not flagged: %d", sum(skipped)))
  message(paste0("    ", co$affiliation_simple[skipped], collapse = "\n"))
  co$flag_type[skipped] <- ""
}

out <- co %>%
  filter(nzchar(flag_type)) %>%
  transmute(affiliation_simple, latitude = lat, longitude = lon,
            coord_status, coord_source, n_rows,
            point_country, nearest_town, nearest_town_country,
            nearest_town_km = round(nearest_town_km, 2),
            nearest_town_pop,
            named_place, named_km = round(named_km, 2), n_named_places, named_places,
            flag_type, place_note, place_line,
            affiliation_excerpt = substr(gsub("[[:space:]]+", " ", affiliation_excerpt), 1, 160),
            google_maps = sprintf("https://www.google.com/maps/search/?api=1&query=%.7f,%.7f",
                                  latitude, longitude)) %>%
  arrange(desc(named_km))

dir.create(dirname(OUT_FILE), showWarnings = FALSE, recursive = TRUE)
write_csv(out, OUT_FILE, na = "")

# --- summary ------------------------------------------------------------------

message(sprintf("checked %d, flagged %d", nrow(co), nrow(out)))
message("threshold = ", THRESHOLD_KM, " km from the nearest place the text names")
message(sprintf("untestable (no place in the text resolves in the gazetteer): %d",
                sum(co$n_named_places == 0L)))
remote <- co %>% filter(!is.na(nearest_town_km), nearest_town_km > 50)
if (nrow(remote)) {
  message(sprintf("no town within 50 km of the point (gazetteer may be thin there): %d",
                  nrow(remote)))
  for (i in seq_len(nrow(remote)))
    message(sprintf("    %-45s %s from %s", substr(remote$affiliation_simple[i], 1, 45),
                    fmt_km(remote$nearest_town_km[i]), remote$nearest_town[i]))
}
if (nrow(out)) {
  message("worst first:")
  for (i in seq_len(min(nrow(out), 40)))
    message(sprintf("    %8s  %-42s %-8s %s", fmt_km(out$named_km[i]),
                    substr(out$affiliation_simple[i], 1, 42), out$coord_status[i],
                    out$place_line[i]))
}
message("written: ", OUT_FILE)
