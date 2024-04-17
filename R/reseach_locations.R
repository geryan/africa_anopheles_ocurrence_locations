library(terra)
library(readr)
library(dplyr)
library(lubridate)
library(sdmtools)

locs_raw <- read_csv("data/unique_affiliations_Lat_Long.csv")


locs_all <- locs_raw |>
  select(x = Longitude, y = Latitude) |>
  filter(!is.na(x), !is.na(y)) |>
  distinct()


africa_mask <- make_africa_mask(
  file_name = "data/africa_mask.tif",
  res = c("high")
)

locs_v <- vect(
  locs_all |>
    #rename(longitude = x, latitude = y) |>
    as.matrix()
)



locs_v |>
  terra::crop(africa_mask, mask = TRUE)

write_csv(
  x = locs,
  file = sprintf(
    "output/research_locations_%s.csv",
    today() |>
    gsub("-", "", x = _)
  )
)


# create travel time map using
# https://access-mapper.appspot.com
# per Weiss, D.J., Nelson, A., Vargas-Ruiz, C.A. et al. Global maps of travel
# time to healthcare facilities. Nat Med 26, 1835–1838 (2020).
# https://doi.org/10.1038/s41591-020-1059-1

res_dist <- list.files(
  path = "data/accessmapper_20240415/",
  pattern = "*.tif",
  full.names = TRUE
) |>
  sapply(
    FUN = terra::rast
  ) |>
  sapply(
    FUN = terra::extend,
    y = africa_mask
  ) |>
  sprc() |>
  merge(
    filename = "output/res_dist.tif",
    overwrite = TRUE
  )

plot(res_dist)
