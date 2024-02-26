library(tidyverse)


full_data <- read_csv("data/vector_extraction_data.csv") |>
  filter(anopheline_region_id == "Africa") |>
  select(
    sample_period_year_start,
    sample_period_year_end,
    collection_count,
    collection_method_name,
    control_method_name,
    anopheline_species,
    vector_site_coordinates_latitude,
    vector_site_coordinates_longitude,
    vector_site_full_name,
    source_citation
  )

glimpse(full_data)


completed_sources <- read_csv("data/lake_region_source_affiliations_africa.csv")

source_locations <- read_csv("data/lake_region_source_counts.csv")


summary_data <- full_data |>
  group_by(source_citation) |>
  summarise(
    n = n()
  )


twatasha_to_do <- summary_data |>
  left_join(completed_sources) |>
  filter(is.na(affiliation_simple)) |>
  arrange(-n)

library(readxl)
write_csv(twatasha_to_do, file = "output/twatasha_todo.csv")
