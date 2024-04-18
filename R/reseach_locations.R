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


writeRaster(
  x = res_dist,
  filename = "output/res_dist_all.tif"
)

plot(res_dist)

mask_v <- make_africa_mask(type = "vector")


library(gstat)
library(sp)
data(meuse)

### inverse distance weighted (IDW)
r <- rast(system.file("ex/meuse.tif", package="terra"))
mg <- gstat(id = "zinc", formula = zinc~1, locations = ~x+y, data=meuse,
            nmax=7, set=list(idp = .5))
z <- interpolate(res_dist, mg, debug.level=0, index=1)
