library(dplyr)
library(readr)
library(lubridate)

affils <- read_csv("data/Affiliation spreadsheet (version 2).csv")


unique_affils <- affils |>
  select(affiliation_simple, affiliation) |>
  filter(!is.na(affiliation)) |>
  distinct() |>
  arrange(affiliation_simple)

unique_affils

write_csv(
  x = unique_affils,
  file = sprintf(
    "output/unique_affiliations_%s.csv",
    today()  |>
      gsub("-", "", x = _)
  )
)
