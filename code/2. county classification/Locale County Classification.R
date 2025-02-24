# Load necessary libraries
library(sf)
library(dplyr)
library(data.table)
library(tidyverse)
library(bit64)

# Set project paths
path_project <- "/Users/sarah/Documents/GitHub/county-classification"
path_data <- file.path(path_project, "data")
path_csvs <- file.path(path_data, "csvs/csvs_mod")
path_shapefiles <- file.path(path_data, "shapefiles")
path_output <- file.path(path_project, "output")

# Load shapefiles and CSV data
bg_locale_inter <- st_read(file.path(path_shapefiles, "bg_locale_inter.shp"))
counties <- st_read(file.path(path_shapefiles, "cb_2023_us_county_500k.shp"))
cities <- st_read(file.path(path_shapefiles, "cb_2023_us_place_500k.shp"))

bg_data <- fread(file.path(path_csvs, "bg_data.csv"))
county_data <- fread(file.path(path_csvs, "county_data.csv"))
city_data <- fread(file.path(path_csvs, "city_data.csv"))
metro_data <- fread(file.path(path_csvs, "metro_data.csv"))

# Ensure join columns are of type integer64
bg_data[, bg_fips := as.integer64(bg_fips)]
county_data[, county_fips := as.integer64(county_fips)]
city_data[, city_fips := as.integer64(city_fips)]
metro_data[, metro_cnt_fips := as.integer64(metro_cnt_fips)]

# Convert shapefile join columns to integer64
bg_locale_inter <- bg_locale_inter %>%
  mutate(geoid_bg = as.integer64(geoid_bg))

counties <- counties %>%
  mutate(geoid_cn = as.integer64(geoid_cn))

cities <- cities %>%
  mutate(geoid_pl = as.integer64(geoid_pl))

# 1. Join block groups shapefile with population data
bg_locale_inter <- bg_locale_inter %>%
  left_join(bg_data, by = c("geoid_bg" = "bg_fips"))

# 2. Calculate bg_pop_locale (share of block group population in each locale)
bg_locale_inter <- bg_locale_inter %>%
  mutate(bg_pop_locale = bg_pop * bg_r_sh)

# 3. Extract county FIPS (geoid_bg_cnt) from geoid_bg
bg_locale_inter <- bg_locale_inter %>%
  mutate(
    geoid_bg_str = as.character(geoid_bg), 
    geoid_bg_cnt = ifelse(
      nchar(geoid_bg_str) == 11,  
      paste0("0", substr(geoid_bg_str, 1, 4)),
      substr(geoid_bg_str, 1, 5)
    ),
    geoid_bg_cnt = as.integer64(geoid_bg_cnt)
  )

# 4. Join counties shapefile with population data
counties <- counties %>%
  left_join(county_data, by = c("geoid_cn" = "county_fips"))

# 5. Join cities shapefile with population data, remove NAME column, and filter cities with population >= 50,000
cities <- cities %>%
  select(-NAME) %>%
  left_join(city_data, by = c("geoid_pl" = "city_fips")) %>%
  filter(city_pop >= 50000)

# 6. Convert cities to point file based on geographic center
cities_points <- st_centroid(cities)

# 7. Spatially join counties with city points
counties_with_cities <- st_join(counties, cities_points, join = st_contains)

# 8. Create county-level data table summing block group population (using bg_pop_locale)
county_pop_summary <- bg_locale_inter %>%
  st_drop_geometry() %>%  
  group_by(geoid_bg_cnt) %>%  
  summarise(total_pop = sum(bg_pop_locale, na.rm = TRUE))

# 9. Sum block group population by locale for each county (using bg_pop_locale)
locale_pop_summary <- bg_locale_inter %>%
  st_drop_geometry() %>%  
  group_by(geoid_bg_cnt, LOCALE) %>% 
  summarise(pop = sum(bg_pop_locale, na.rm = TRUE)) %>%
  pivot_wider(names_from = LOCALE, values_from = pop, names_prefix = "pop_")

# Merge county_pop_summary and locale_pop_summary
county_summary <- county_pop_summary %>%
  left_join(locale_pop_summary, by = "geoid_bg_cnt") %>%
  left_join(county_data, by = c("geoid_bg_cnt" = "county_fips"))

# 10. Calculate population shares
county_summary <- county_summary %>%
  mutate(
    urban_suburban_pop = rowSums(select(., pop_11, pop_12, pop_13, pop_21, pop_22, pop_23), na.rm = TRUE),
    rural_pop = rowSums(select(., pop_41, pop_42, pop_43), na.rm = TRUE),
    urban_suburban_perc = urban_suburban_pop / total_pop,
    rural_perc = rural_pop / total_pop
  )

# 11. Add metro_name and metro_fips
county_summary <- county_summary %>%
  left_join(metro_data, by = c("geoid_bg_cnt" = "metro_cnt_fips"))

# Spatially join cities_points with counties to determine which cities are in which counties
cities_in_counties <- st_join(cities_points, counties, join = st_within)

# Aggregate city data by county
city_summary <- cities_in_counties %>%
  st_drop_geometry() %>% 
  group_by(geoid_cn) %>%  
  summarise(
    city_name = city_nm[which.max(city_pop)],  
    city_pop = max(city_pop, na.rm = TRUE),  
    contains_small_urban = ifelse(any(city_pop >= 50000 & city_pop < 100000), 1, 0),
    contains_mid_sized_urban = ifelse(any(city_pop >= 100000 & city_pop < 250000), 1, 0),
    contains_large_urban = ifelse(any(city_pop >= 250000), 1, 0)
  )

# Rename columns in city_summary to avoid conflicts
city_summary <- city_summary %>%
  rename(
    city_contains_small_urban = contains_small_urban,
    city_contains_mid_sized_urban = contains_mid_sized_urban,
    city_contains_large_urban = contains_large_urban
  )

# Join city_summary with county_summary
county_summary <- county_summary %>%
  left_join(city_summary, by = c("geoid_bg_cnt" = "geoid_cn")) %>%
  group_by(metro_fips) %>%
  mutate(
    MSA_large_urban = ifelse(any(city_contains_large_urban == 1, na.rm = TRUE), 1, 0),
    MSA_mid_sized_urban = ifelse(MSA_large_urban == 1, 0,
                                 ifelse(any(city_contains_mid_sized_urban == 1, na.rm = TRUE), 1, 0))
  ) %>%
  ungroup()

# 13. Classify locale_type
county_summary <- county_summary %>%
  mutate(
    locale_type = case_when(
      city_contains_large_urban == 1 | pop_11 / county_pop >= 0.98 ~ "Large urban",
      city_contains_mid_sized_urban == 1 & MSA_large_urban == 0 ~ "Mid-sized urban",
      (city_contains_small_urban == 1 | city_contains_mid_sized_urban == 1) & (MSA_mid_sized_urban == 1 | MSA_large_urban == 1) ~ "Suburban",
      (city_contains_small_urban == 1 | (urban_suburban_perc > 0.5 | urban_suburban_pop > 50000)) & MSA_mid_sized_urban == 0 & MSA_large_urban == 0 ~ "Small urban",
      urban_suburban_perc > 0.5 | urban_suburban_pop > 50000 ~ "Suburban",
      (urban_suburban_pop < 50000 & urban_suburban_perc < 0.5 & rural_perc < 0.5) | (rural_perc > 0.5 & rural_perc < 0.75 & county_pop > 50000) ~ "Small town",
      TRUE ~ "Rural"
    )
  )

# Remove geometry column, filter out rows where county_nm is blank, and rename columns
county_summary_final <- county_summary %>%
  st_drop_geometry() %>%
  filter(!is.na(county_nm) & county_nm != "") %>%  
  rename(
    county_fips = geoid_bg_cnt,
    total_bg_pop = total_pop
  )

# Order 'pop_' columns by their ending number
pop_columns <- county_summary_final %>%
  select(starts_with("pop_")) %>%
  names()

# Sort pop_ columns numerically by extracting the suffix
pop_columns <- pop_columns[order(as.numeric(sub("pop_", "", pop_columns)))]

# Define column order
column_order <- c(
  "county_fips", "county_nm", "county_pop",  # Reordered first
  "total_bg_pop",
  pop_columns,  # Ordered pop_ columns
  setdiff(names(county_summary_final), c("county_fips", "county_nm", "county_pop", "total_bg_pop", pop_columns))  # Remaining columns
)

# Reorder columns
county_summary_final <- county_summary_final %>%
  select(all_of(column_order))

# Save final output
fwrite(county_summary_final, file.path(path_output, "county_summary_final.csv"))