# Data Cleaning and Export Script for Census Files

# when prompted, select ".../county-classification/data/csvs" as the project folder.

# Function to select project folder
select_project_folder <- function() {
  # Open a file dialog to select the project folder
  project_folder <- rstudioapi::selectDirectory(caption = "Select Project Folder")
  
  # Check if a folder was selected
  if (is.null(project_folder)) {
    stop("No folder selected. Exiting script.")
  }
  
  # Create a subfolder for modified CSVs if it doesn't exist
  csvs_mod_path <- file.path(project_folder, "csvs_mod")
  if (!dir.exists(csvs_mod_path)) {
    dir.create(csvs_mod_path)
  }
  
  # Return a list with project folder and modified CSVs folder
  return(list(
    project_folder = project_folder,
    csvs_mod_path = csvs_mod_path
  ))
}

# Main data processing function
process_census_files <- function() {
  # Select project folder
  folders <- select_project_folder()
  project_folder <- folders$project_folder
  csvs_mod_path <- file.path(project_folder, "csvs_mod")

  
  # Load required libraries
  library(readr)
  library(dplyr)
  
  # 1. Process County Estimates File
  county_file <- list.files(project_folder, pattern = "co-est2023-alldata", full.names = TRUE)
  county_data <- read_csv(county_file) %>%
    filter(SUMLEV == "50") %>%  # Changed to character "050"
    mutate(
      county_nm = paste(CTYNAME, STNAME, sep = ", "),
      county_fips = as.numeric(paste0(
        sprintf("%02d", as.numeric(STATE)), 
        sprintf("%03d", as.numeric(COUNTY))
      )),
      county_pop = POPESTIMATE2023
    ) %>%
    select(county_fips, county_nm, county_pop)
  
  # Export county data
  write_csv(county_data, file.path(csvs_mod_path, "county_data.csv"))
  
  # 2. Process Block Group Population File
  blk_pop_file <- list.files(project_folder, pattern = "ACSDT5Y2023.B01003-Data", full.names = TRUE)
  bg_data <- read_csv(blk_pop_file) %>%
    filter(NAME != "Geographic Area Name") %>%  # Filter based on the original column NAME
    mutate(
      bg_fips = as.numeric(gsub("^1500000US", "", GEO_ID)),  # Remove "1500000US" prefix and convert to numeric
      bg_nm = NAME,  # Rename NAME to bg_nm after filtering
      bg_pop = as.numeric(B01003_001E)
    ) %>%
    select(bg_fips, bg_nm, bg_pop)
  
  # Export block group data
  write_csv(bg_data, file.path(csvs_mod_path, "bg_data.csv"))
  
  # 3. Process Subcounty Estimates File
  sub_est_file <- list.files(project_folder, pattern = "sub-est2023", full.names = TRUE)
  city_data <- read_csv(sub_est_file) %>%
    filter(SUMLEV == 162) %>%
    mutate(
      city_fips = as.numeric(paste0(
        sprintf("%02d", as.numeric(STATE)), 
        sprintf("%05d", as.numeric(PLACE))
      )),
      city_nm = paste(NAME, STNAME, sep = ", "),
      city_pop = POPESTIMATE2023
    ) %>%
    select(city_fips, city_nm, city_pop)
  
  # Export city data
  write_csv(city_data, file.path(csvs_mod_path, "city_data.csv"))
  
  # 4. Process Metropolitan Definitions File
  metro_def_file <- list.files(project_folder, pattern = "metro_def", full.names = TRUE)
  metro_data <- read_csv(metro_def_file) %>%
    filter(`Metropolitan/Micropolitan Statistical Area` == "Metropolitan Statistical Area") %>%
    mutate(
      metro_fips = `CBSA Code`,
      metro_nm = `CBSA Title`,
      metro_cnt_fips = as.numeric(paste0(
        sprintf("%02d", as.numeric(`FIPS State Code`)), 
        sprintf("%03d", as.numeric(`FIPS County Code`))
      ))
    ) %>%
    select(metro_fips, metro_nm, metro_cnt_fips)
  
  # Export metro data
  write_csv(metro_data, file.path(csvs_mod_path, "metro_data.csv"))
  
  # Confirmation message
  cat("Data processing complete. Files exported to:", csvs_mod_path, "\n")
}

# Run the data processing
process_census_files()
