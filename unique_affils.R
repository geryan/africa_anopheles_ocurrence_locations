library(dplyr)
library(readr)
library(lubridate)

affils <- read_csv("data/Affiliation spreadsheet (version 2).csv")

# select only the affiliation columns
# get rid of any yet to be filled in (NA)
# get unique combinations of affiliation_simple and affiliation
# order by affiliation_simple
# NB repeats of affiliation_simple are expected as long affiliation might
# be found in different formats, e.g. different departments etc.
unique_affils <- affils |>
  select(affiliation_simple, affiliation) |>
  filter(!is.na(affiliation)) |>
  distinct() |>
  arrange(affiliation_simple)

unique_affils

# write to file with date-stamp
write_csv(
  x = unique_affils,
  file = sprintf(
    "output/unique_affiliations_%s.csv",
    today()  |>
      gsub("-", "", x = _)
  )
)
