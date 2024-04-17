# Accessibility Mapping in R
# 
# Andy Nelson - derived from a script by Dan Weiss, Malaria Atlas Project, University of Oxford
# 2017-12-04
#
# This script requires the gdistance packge (van Etten, J. R Package gdistance: Distances and Routes on Geographical Grids. Journal of Statistical Software 76, 1-21)
#
# This script requires the three user supplied datasets:
# (a) The friction surface, which is available here:  http://www.map.ox.ac.uk/accessibility_to_cities/
# (b) A user-supplied .csv of points (i.e., known geographic coordinates) 
# (c) Zones to divide up the world into overlapping 30 x 30 tiles
#
# Notes:
# (a) All file paths and names should be changed as needed
# (b) Important runtime details can be found in the comments
#
# Citation: 
# 

## Required Packages
library(raster)
library(gdistance)
library(rgdal)
setwd("Z:\\Workspace\\FINALMAPS")
memory.limit(999999999999)
memory.size(999999999999)

# Input Files
# 1 normal friction
friction.filename <- 'friction_surface_2015_v1.0.tif'
# 2 uniform walking friction
#friction.filename <- 'friction_surface_v47_uniform_walking.tif'
friction <- raster(friction.filename)

# Just 5 columns.  Structured as [zones, right,left,bottom,top] Use a header.
zones.filename <- 'zones.csv' 
# Read in the zones table
zones <- read.csv(file = zones.filename)

# for each zone (24 in total), here we break into 4 groups of 6 for crude multi core processing
# without breaking our 512GB RAM limit.
for (zone in 1:25) {
  print(zone)
  mydata = as.matrix(zones)[zone,]
  left   <-  mydata[c(2)]
  right  <-  mydata[c(3)]
  bottom <-  mydata[c(4)]
  top    <-  mydata[c(5)]
  
  # crop the friction map
  friction.zone <- crop(friction, extent(left, right, bottom, top))
  
  # 1 corrected graphs normal friction
  T.GC.zone.filename   <- paste("zones\\global_",zone,".T.GC.rds",sep="")
  # 2 corrected graphs uniform walking friction
  #T.GC.zone.filename   <- paste("zones\\global_u",zone,".T.GC.rds",sep="")
  
  print(T.GC.zone.filename)
  
  # Make the graph and the geo-corrected version of the graph (or read in the latter).
  if (file.exists(T.GC.zone.filename)) {
    # Read in the transition matrix object if it has been pre-computed
    T.GC.zone <- readRDS(T.GC.zone.filename)
    print("read in transition matrix")
    
  } else {
    print("creating transition matrix")
    # Make and geocorrect the transition matrix (i.e., the graph)
    T.zone <- transition(friction.zone, function(x) 1/mean(x), 8) # RAM intensive, can be very slow for large areas
    T.GC.zone <- geoCorrection(T.zone)                    
    saveRDS(T.GC.zone, T.GC.zone.filename)
    print("transition matrix corrected and saved to file")
  }
  gc()
  
  # for each population layer
  for (pop in 1:12) {
    # for access to city borders, normal friction
    output.filename <- paste("zones\\global_",zone,"_",pop,".accessibility.tif",sep="")
    # for access to city borders, uniform walking friction
    # output.filename <- paste("zones\\global_u",zone,"_",pop,".accessibility.tif",sep="")
    # for access to city centroids, normal friction
    #output.filename <- paste("zones\\global_c",zone,"_",pop,".accessibility.tif",sep="")
    # for access to city centroids, uniform walking friction
    #output.filename <- paste("zones\\global_cu",zone,"_",pop,".accessibility.tif",sep="")
    
    if(!file.exists(output.filename)){
      print(pop)
      
      # 1 filename for city borders
      target.filename <- paste("GHSL2016_fix\\newpop_ll",pop,".shp",sep="")
      # 2 filename for city centroids
      #target.filename <- paste("GHSL\\gc",pop,".shp",sep="")
      #read in file
      targets <- readOGR(target.filename)
      # crop
      print("crop shapefile")
      targets.zone <- crop(targets, extent(left, right, bottom, top))
      rm(targets)
      
      # accumulated cost calculation to the nearest target using the geo-corrected graph and the target points. - THIS IS THE ACCESS SURFACE
      print("compute travel time")
      output.raster <- try(accCost(T.GC.zone, targets.zone))
      
      # Write the resulting raster
      try(writeRaster(output.raster, output.filename, format="GTiff", overwrite=TRUE))
      print("access raster saved to file")
      
      rm(targets.zone)
      try(rm(output.raster))
      gc()
    }
  }
  rm(friction.zone)
  gc()
}
rm(friction)
gc()
removeTmpFiles()