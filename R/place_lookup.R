# place_lookup.R ---------------------------------------------------------------
#
# Where a coordinate actually is, in words, and whether it agrees with the place
# its text names.  Sourced by R/check_coord_place.R and R/coord_review.R: it
# defines functions and builds a gazetteer, and does nothing else.
#
#   source("R/place_lookup.R")
#   place_line(-4.0435, 39.6682, "MTTI Kendu Bay Kenya", "KEN")
#   #> "1 km from Mombasa, Kenya (pop 823,500); text names Kendu Bay, 693 km away"
#
# Why this exists
#   R/check_coord_sanity.R tests the country and nothing else, so a point in the
#   wrong town passes it: `MasenoU Maseno Kenya` sat in Nairobi and was flagged by
#   nothing.  The 98 km Montpellier error passed it too.  This is the missing
#   half - the town, not the country.
#
# The gazetteer is maps::world.cities, 43,645 populated places, offline, already
# a dependency of check_coord_sanity.R.  Its coverage is uneven: it has Kendu Bay
# (pop 441) and Ahero (8,932) but not Maseno, Mbita or Juja, and only 997 places
# in the USA.  So a forward test ("is the point near the town the text names?")
# can only be run where the name resolves, and that is reported honestly rather
# than assumed.  The reverse direction - "what town is this point in?" - always
# works, and is the evidence that would have caught every one of the four
# far-from-town points of step 8, including the two the forward test cannot see.
# ------------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(dplyr)
  library(maps)
  library(countrycode)
})

# --- the gazetteer ------------------------------------------------------------

.fold <- function(x) {
  y <- iconv(x, "UTF-8", "ASCII//TRANSLIT")
  y <- ifelse(is.na(y), x, y)
  tolower(gsub("[`'^\"~]", "", y))
}
.norm <- function(x) trimws(gsub("\\s+", " ", gsub("[^a-z0-9 ]", " ", .fold(x))))

utils::data("world.cities", package = "maps", envir = environment())
GZ <- world.cities %>%
  transmute(name, country = country.etc, pop,
            lat, lon = long, key = .norm(name)) %>%
  filter(nzchar(key))
local({
  u <- unique(GZ$country)
  iso <- suppressWarnings(countrycode(u, "country.name", "iso3c", warn = FALSE))
  GZ$iso <<- unname(setNames(iso, u)[GZ$country])
})
GZ_BY_ISO <- split(seq_len(nrow(GZ)), GZ$iso)

# --- what counts as a place name in a piece of text ---------------------------
#
# Every word of every country name is a stopword, because a country name is not
# a town: "leone" in "Sierra Leone" matched a village called Leone in American
# Samoa, 17,623 km from the point, and that was the only candidate the label had.
# The institutional vocabulary goes the same way, and so does "borne", which
# "vector-borne" contributed to a 5,617 km false positive.
.country_words <- local({
  cn <- unique(c(countrycode::codelist$country.name.en,
                 countrycode::codelist$country.name.fr))
  w <- unique(unlist(strsplit(.norm(cn[!is.na(cn)]), " ")))
  w[nchar(w) >= 3]
})

PLACE_STOPWORDS <- unique(c(.country_words, c(
  "box", "bag", "private", "post", "road", "street", "avenue", "university",
  "institute", "institut", "instituto", "universite", "universidade",
  "universidad", "facultad", "escuela", "research", "medical", "centre",
  "center", "college", "school", "hospital", "laboratory", "laboratoire",
  "health", "public", "national", "west", "east", "north", "south", "lake",
  "park", "hill", "valley", "general", "central", "city", "town", "state",
  "county", "province", "district", "region", "service", "ministry", "control",
  "programme", "program", "unit", "division", "section", "group", "trust",
  "fund", "foundation", "society", "academy", "council", "board", "agency",
  "office", "station", "field", "farm", "garden", "campus", "building", "house",
  "hall", "floor", "suite", "room", "department", "departement", "faculty",
  "science", "sciences", "biology", "zoology", "entomology", "parasitology",
  "tropical", "disease", "diseases", "vector", "borne", "malaria", "medicine",
  "international", "clinical", "microbiology", "molecular", "biomedical",
  "biological", "veterinary", "agriculture", "technology", "environmental",
  "population", "animal", "insect", "physiology", "ecology", "pathology",
  "immunology", "virology", "bacteriology", "epidemiology", "statistics",
  "informatics", "same", "mission", "union", "normal", "dept")))

# A comma field that is a street address or a box number holds no town name, and
# its words are a rich source of accidental matches: "Viale Regina Elena" gave
# Regina, Saskatchewan, 1,103 km from the Rome point that is perfectly correct.
.ADDRESS <- paste0("\\b(p\\.?\\s?o\\.?\\s?box|p\\.?\\s?m\\.?\\s?b|b\\.?p\\.?|",
                   "postbus|private bag|via|viale|rue|strasse|street|road|",
                   "avenue|ave|blvd|drive|lane|suite|floor|apt|no\\.|[0-9]{3,})\\b")

# Candidate place names: 1-3 word runs inside each comma field.  A one-word
# candidate must be at least four characters and not a stopword; a multi-word one
# must not be all stopwords.
place_candidates <- function(txt) {
  if (is.na(txt) || !nzchar(trimws(txt))) return(character(0))
  fields <- trimws(unlist(strsplit(txt, "[,;()/|]")))
  fields <- fields[nzchar(fields)]
  out <- character(0)
  for (fld in fields) {
    if (grepl(.ADDRESS, .fold(fld), perl = TRUE)) next
    w <- unlist(strsplit(.norm(fld), " "))
    w <- w[nzchar(w)]
    if (!length(w)) next
    for (n in 1:3) {
      if (length(w) < n) break
      for (i in seq_len(length(w) - n + 1L)) {
        g <- paste(w[i:(i + n - 1L)], collapse = " ")
        gw <- w[i:(i + n - 1L)]
        if (n == 1L && (nchar(g) < 4 || g %in% PLACE_STOPWORDS)) next
        if (n > 1L && all(gw %in% PLACE_STOPWORDS)) next
        out <- c(out, g)
      }
    }
  }
  unique(out)
}

# --- distances ----------------------------------------------------------------

place_km <- function(lat1, lon1, lat2, lon2) {
  R <- 6371.0088; p <- pi / 180
  a <- sin((lat2 - lat1) * p / 2)^2 +
    cos(lat1 * p) * cos(lat2 * p) * sin((lon2 - lon1) * p / 2)^2
  2 * R * asin(pmin(1, sqrt(a)))
}

# The town a point sits in or nearest to, and the nearest one of any size worth
# naming.  A widening box keeps this off the full 43,645 rows in the normal case.
place_at <- function(lat, lon) {
  if (is.na(lat) || is.na(lon))
    return(list(name = NA_character_, country = NA_character_, km = NA_real_,
                pop = NA_real_, big_name = NA_character_, big_km = NA_real_))
  sel <- integer(0)
  for (deg in c(1, 4, 15)) {
    dlon <- deg / max(0.15, cos(lat * pi / 180))
    sel <- which(abs(GZ$lat - lat) <= deg & abs(GZ$lon - lon) <= dlon)
    if (length(sel)) break
  }
  if (!length(sel)) sel <- seq_len(nrow(GZ))
  d <- place_km(lat, lon, GZ$lat[sel], GZ$lon[sel])
  i <- sel[which.min(d)]
  big <- sel[GZ$pop[sel] >= 20000]
  j <- if (length(big)) big[which.min(place_km(lat, lon, GZ$lat[big], GZ$lon[big]))] else NA_integer_
  list(name = GZ$name[i], country = GZ$country[i], km = min(d), pop = GZ$pop[i],
       big_name = if (is.na(j)) NA_character_ else GZ$name[j],
       big_km = if (is.na(j)) NA_real_ else place_km(lat, lon, GZ$lat[j], GZ$lon[j]))
}

# The places the text names that the gazetteer knows, in `iso`, with the distance
# from the point to the nearest entry carrying each name.  Restricting to one
# country is what keeps accidental homonyms out; the minimum over the names is
# what makes one bad candidate harmless, since any real place named nearby pulls
# the distance back down.
place_named <- function(lat, lon, txt, iso) {
  empty <- list(n = 0L, km = NA_real_, name = NA_character_, all = character(0))
  if (is.na(lat) || is.na(lon) || is.na(iso) || is.null(GZ_BY_ISO[[iso]])) return(empty)
  cd <- place_candidates(txt)
  if (!length(cd)) return(empty)
  sub <- GZ_BY_ISO[[iso]]
  hit <- sub[GZ$key[sub] %in% cd]
  if (!length(hit)) return(empty)
  d <- place_km(lat, lon, GZ$lat[hit], GZ$lon[hit])
  best <- tapply(d, GZ$key[hit], min)
  best <- best[order(best)]
  list(n = length(best), km = unname(best[1]),
       name = GZ$name[hit[which.min(d)]],
       all = sprintf("%s (%s km)", names(best), format(round(best, 1), trim = TRUE)))
}

.km <- function(x) if (is.na(x)) "?" else if (x < 10) sprintf("%.1f km", x) else sprintf("%.0f km", x)

# One line for the sheet: where the point is, and what the text says it should be.
# Written to be read at a glance while ticking, which is the whole point - the
# four far-from-town points of step 8 were named in NEXT_STEPS.md and nowhere in
# the sheet the answers were typed into.
place_line <- function(lat, lon, txt, iso = NULL) {
  if (is.na(lat) || is.na(lon)) return("")
  at <- place_at(lat, lon)
  if (is.null(iso) || is.na(iso)) iso <- place_iso_at(lat, lon)
  nm <- place_named(lat, lon, txt, iso)
  where <- if (is.na(at$name)) "no town within 15 degrees" else
    sprintf("%s from %s, %s%s", .km(at$km), at$name, at$country,
            if (is.na(at$pop) || at$pop < 1000) "" else
              sprintf(" (pop %s)", format(round(at$pop), big.mark = ",", trim = TRUE)))
  said <- if (nm$n == 0L) "no place in the text resolves in the gazetteer" else
    sprintf("text names %s, %s away", nm$name, .km(nm$km))
  paste0(where, "; ", said)
}

# The country a point is in, ISO3, via the same offline map check_coord_sanity.R
# uses.  Vectorised.
place_iso_at <- function(lat, lon) {
  nm <- sub(":.*$", "", maps::map.where("world", lon, lat))
  suppressWarnings(countrycode(nm, "country.name", "iso3c", warn = FALSE))
}
