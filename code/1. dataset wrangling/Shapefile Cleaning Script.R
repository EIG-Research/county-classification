rm(list = ls())

library(sf)
library(bit64)
library(dplyr)

# Set working directory
path_project = "/Users/sarah/Documents/GitHub/county-classification" # CHANGE LINE

path_data = file.path(path_project, "data/shapefiles")
setwd(data_path)



# Read shapefiles
county_sf <- st_read("cb_2023_us_county_500k.shp")
bg_locale_inter <- st_read("bg_locale_inter.shp")
place_sf <- st_read("cb_2023_us_place_500k.shp")

# Convert GEOID to integer64 for each shapefile
county_sf$geoid_cn <- as.integer64(county_sf$GEOID)
bg_locale_inter$geoid_bg <- as.integer64(bg_locale_inter$GEOID)
place_sf$geoid_pl <- as.integer64(place_sf$GEOID)

# Calculate area share as Area_nw divided by Area_og
bg_locale_inter$bg_area_shr <- as.numeric(bg_locale_inter$Area_nw / bg_locale_inter$Area_og)

# Overwrite shapefiles with modified data
st_write(county_sf, "cb_2023_us_county_500k.shp", append=FALSE)
st_write(bg_locale_inter, "bg_locale_inter.shp", append=FALSE)
st_write(place_sf, "cb_2023_us_place_500k.shp", append=FALSE)
