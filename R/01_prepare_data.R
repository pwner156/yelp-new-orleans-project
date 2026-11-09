# Project 2: New Orleans Cajun/Creole and Seafood Restaurants
#
# Main focus: Cajun/Creole and Seafood
# Supporting category: Southern
#
# Study region: New Orleans, Louisiana
# Selected geographic units: ZIP Code Tabulation Areas (ZCTAs)
#
# This script documents data preparation, restaurant categories,
# review joins, geographic mapping, and the comparison of
# ZCTAs with census tracts.
#
# The original Yelp JSON files are not included on GitHub.
# The analysis uses saved RDS files in data/new_orleans/.

library(tidyverse)
library(jsonlite)

# STEP 1: Load Yelp business data

business_raw <- jsonlite::stream_in(
  file("data/raw/yelp_academic_dataset_business.json"),
  verbose = FALSE
)

# Keep the business columns used for this project
business <- business_raw |>
  select(
    business_id, name, address, city, state,
    postal_code, latitude, longitude,
    stars, review_count, categories
  )

# STEP 2: Filter New Orleans restaurants

new_orleans_restaurants <- business |>
  filter(
    state == "LA",
    city == "New Orleans",
    !is.na(categories),
    str_detect(
      categories,
      regex("Restaurants", ignore_case = TRUE)
    )
  ) |>
  mutate(
    postal_code = na_if(postal_code, ""),
    categories = str_squish(categories),
    business_name = str_squish(name)
  ) |>
  distinct(business_id, .keep_all = TRUE)

nrow(new_orleans_restaurants)

# STEP 3: Save New Orleans restaurants

dir.create("data/new_orleans",
           recursive = TRUE,
           showWarnings = FALSE)

saveRDS(
  new_orleans_restaurants,
  "data/new_orleans/business_new_orleans.rds",
  compress = "xz"
)

# STEP 4: Filter Yelp reviews in batches

restaurant_ids <- new_orleans_restaurants$business_id

review_file <- "data/raw/yelp_academic_dataset_review.json"
output_file <- "data/new_orleans/reviews_filtered.json"

# Remove an old temporary output before starting
if (file.exists(output_file)) {
  file.remove(output_file)
}

input <- file(review_file, open = "r")

repeat {
  lines <- readLines(input, n = 10000, warn = FALSE)
  
  if (length(lines) == 0) break
  
  chunk <- jsonlite::stream_in(
    textConnection(lines),
    verbose = FALSE
  )
  
  filtered <- chunk |>
    filter(business_id %in% restaurant_ids)
  
  if (nrow(filtered) > 0) {
    con <- file(output_file, open = "a")
    jsonlite::stream_out(filtered, con, verbose = FALSE)
    close(con)
  }
}

close(input)

# STEP 5: Load and select filtered reviews

new_orleans_reviews <- jsonlite::stream_in(
  file("data/new_orleans/reviews_filtered.json"),
  verbose = FALSE
)

new_orleans_reviews <- new_orleans_reviews |>
  select(
    business_id, user_id, stars,
    date, text, useful, funny, cool
  )

# STEP 6: Save reviews as compressed RDS

saveRDS(
  new_orleans_reviews,
  "data/new_orleans/reviews_new_orleans.rds",
  compress = "xz"
)

# STEP 7: Verify saved datasets

restaurants_check <- readRDS(
  "data/new_orleans/business_new_orleans.rds"
)

reviews_check <- readRDS(
  "data/new_orleans/reviews_new_orleans.rds"
)

nrow(restaurants_check)
nrow(reviews_check)

# Expected results:
# 2259 New Orleans restaurants
# 476421 associated reviews


# PROJECT 2 - STEP 3: Analyze restaurant categories

# Load the saved datasets
new_orleans_restaurants <- readRDS(
  "data/new_orleans/business_new_orleans.rds"
)

new_orleans_reviews <- readRDS(
  "data/new_orleans/reviews_new_orleans.rds"
)

# Verify the datasets
nrow(new_orleans_restaurants)
nrow(new_orleans_reviews)

# STEP 3B: Separate and count restaurant categories

restaurant_categories <- new_orleans_restaurants |>
  select(business_id, business_name, categories) |>
  separate_rows(categories, sep = ",") |>
  mutate(category = str_to_lower(str_trim(categories))) |>
  select(business_id, business_name, category) |>
  distinct()

# Count our three selected categories
category_counts <- restaurant_categories |>
  filter(category %in% c(
    "cajun/creole",
    "seafood",
    "southern"
  )) |>
  count(category, name = "number_of_restaurants") |>
  arrange(desc(number_of_restaurants))

print(category_counts)

# STEP 3C: Analyze category overlap

selected_categories <- c(
  "cajun/creole",
  "seafood",
  "southern"
)

category_overlap <- restaurant_categories |>
  filter(category %in% selected_categories) |>
  group_by(business_id) |>
  summarise(
    categories_matched = paste(sort(category), collapse = ", "),
    number_of_categories = n_distinct(category),
    .groups = "drop"
  )

# Count restaurants by number of matching categories
overlap_counts <- category_overlap |>
  count(number_of_categories, name = "number_of_restaurants")

print(overlap_counts)

# Count unique restaurants in our selected categories
nrow(category_overlap)

# STEP 3D: Count specific category combinations

category_combinations <- category_overlap |>
  count(
    categories_matched,
    name = "number_of_restaurants",
    sort = TRUE
  )

print(category_combinations)

# PROJECT 2 - STEP 4: Join restaurants and reviews

# Select restaurants matching at least one chosen category
selected_restaurants <- new_orleans_restaurants |>
  semi_join(category_overlap, by = "business_id")

# Check how many restaurants were selected
nrow(selected_restaurants)

# STEP 4B: Filter reviews for selected restaurants

selected_reviews <- new_orleans_reviews |>
  semi_join(
    selected_restaurants,
    by = "business_id"
  )

# Count the reviews
nrow(selected_reviews)

# Count how many selected restaurants have reviews
n_distinct(selected_reviews$business_id)

# STEP 4C: Join restaurant information with reviews

restaurant_reviews <- selected_reviews |>
  left_join(
    selected_restaurants |>
      select(
        business_id,
        business_name,
        city,
        latitude,
        longitude,
        categories
      ),
    by = "business_id"
  )

# Verify the join
nrow(restaurant_reviews)

# Preview the joined data
restaurant_reviews |>
  select(business_name, stars, date) |>
  head(5)

# PROJECT 2 - STEP 5: Geographic analysis

# Load mapping packages
library(sf)
library(tigris)

# Cache geographic data to avoid repeated downloads
options(tigris_use_cache = TRUE)

# Check for missing restaurant coordinates
selected_restaurants |>
  summarise(
    total_restaurants = n(),
    missing_latitude = sum(is.na(latitude)),
    missing_longitude = sum(is.na(longitude))
  )

# STEP 5B: Download Louisiana city boundaries

louisiana_places <- tigris::places(
  state = "LA",
  cb = TRUE,
  year = 2024,
  class = "sf"
)

# Find the official New Orleans boundary
new_orleans_boundary <- louisiana_places |>
  filter(NAME == "New Orleans")

# Check that we found the boundary
nrow(new_orleans_boundary)

# STEP 5C: Create restaurant map points

# Recreate our selected restaurant group
selected_restaurants <- new_orleans_restaurants |>
  filter(
    str_detect(
      categories,
      regex("Cajun/Creole|Seafood|Southern",
            ignore_case = TRUE)
    )
  )

# Convert restaurant coordinates into map points
restaurant_points <- selected_restaurants |>
  st_as_sf(
    coords = c("longitude", "latitude"),
    crs = 4326,
    remove = FALSE
  )

# Check the number of restaurant points
nrow(restaurant_points)

# STEP 5D: Match restaurants to official city boundaries

# Make Louisiana boundaries use the same CRS as restaurant points
louisiana_places <- st_transform(
  louisiana_places,
  crs = st_crs(restaurant_points)
)

# Match restaurants to geographic places
restaurants_with_place <- restaurant_points |>
  st_join(
    louisiana_places |>
      select(GEOID, place_name = NAME),
    join = st_within,
    left = TRUE
  )

# Count restaurants by official geographic place
restaurants_with_place |>
  st_drop_geometry() |>
  count(place_name, sort = TRUE)

# STEP 5E: Map New Orleans restaurants

# Keep restaurants inside the official New Orleans boundary
new_orleans_map_data <- restaurants_with_place |>
  filter(place_name == "New Orleans")

# Make sure the boundary uses the same CRS
new_orleans_boundary <- st_transform(
  new_orleans_boundary,
  st_crs(new_orleans_map_data)
)

# Create the map
restaurant_map <- ggplot() +
  geom_sf(
    data = new_orleans_boundary,
    fill = "grey95",
    color = "grey35"
  ) +
  geom_sf(
    data = new_orleans_map_data,
    aes(color = stars),
    alpha = 0.7,
    size = 1.5
  ) +
  scale_color_gradient(
    low = "red",
    high = "darkgreen"
  ) +
  labs(
    title = "Cajun/Creole, Seafood, and Southern Restaurants",
    subtitle = "Restaurants within official New Orleans boundaries",
    color = "Yelp Stars"
  ) +
  theme_minimal()

# Display the map
print(restaurant_map)

# STEP 5F: Save restaurant map

# Create a folder for project figures
dir.create("figures", showWarnings = FALSE)

# Save the map as a PNG image
ggsave(
  filename = "figures/new_orleans_restaurant_map.png",
  plot = restaurant_map,
  width = 10,
  height = 8,
  dpi = 300
)

# PROJECT 2 - STEP 6: Compare geographic systems

# STEP 6A: Download ZIP Code Tabulation Areas

zcta_boundaries <- tigris::zctas(
  year = 2020,
  cb = TRUE,
  class = "sf"
)

# Match coordinate systems
zcta_boundaries <- st_transform(
  zcta_boundaries,
  st_crs(new_orleans_map_data)
)

# Check that boundaries loaded
nrow(zcta_boundaries)

# STEP 6B: Match restaurants to ZCTA areas

# Join restaurant locations to ZCTA boundaries
restaurants_with_zcta <- new_orleans_map_data |>
  st_join(
    zcta_boundaries |>
      select(ZCTA5CE20),
    join = st_within,
    left = TRUE
  )

# Count restaurants in each ZCTA
zcta_counts <- restaurants_with_zcta |>
  st_drop_geometry() |>
  count(ZCTA5CE20, name = "number_of_restaurants") |>
  arrange(desc(number_of_restaurants))

print(zcta_counts)

# Check how many restaurants were not matched
sum(is.na(restaurants_with_zcta$ZCTA5CE20))

# STEP 6C: Summarize restaurants by ZCTA

zcta_summary <- restaurants_with_zcta |>
  st_drop_geometry() |>
  group_by(ZCTA5CE20) |>
  summarise(
    number_of_restaurants = n(),
    average_stars = round(mean(stars, na.rm = TRUE), 2),
    total_reviews = sum(review_count, na.rm = TRUE),
    .groups = "drop"
  ) |>
  arrange(desc(number_of_restaurants))

print(zcta_summary)

# Count the number of ZCTAs containing restaurants
nrow(zcta_summary)

# STEP 6D: Download Louisiana census tracts

census_tracts <- tigris::tracts(
  state = "LA",
  county = "Orleans",
  year = 2024,
  cb = TRUE,
  class = "sf"
)

# Match the coordinate systems
census_tracts <- st_transform(
  census_tracts,
  st_crs(new_orleans_map_data)
)

# Check how many census tracts loaded
nrow(census_tracts)

# STEP 6E: Match restaurants to census tracts

restaurants_with_tracts <- new_orleans_map_data |>
  st_join(
    census_tracts |>
      select(tract_id = GEOID),
    join = st_within,
    left = TRUE
  )

# Count restaurants in each census tract
tract_counts <- restaurants_with_tracts |>
  st_drop_geometry() |>
  filter(!is.na(tract_id)) |>
  count(
    tract_id,
    name = "number_of_restaurants"
  ) |>
  arrange(desc(number_of_restaurants))

# Show the 10 tracts with the most restaurants
print(head(tract_counts, 10))

# Count tracts containing restaurants
nrow(tract_counts)

# Count unmatched restaurants
sum(is.na(restaurants_with_tracts$tract_id))

# STEP 6F: Compare ZCTAs and census tracts

# Summarize census tract ratings
tract_summary <- restaurants_with_tracts |>
  st_drop_geometry() |>
  filter(!is.na(tract_id)) |>
  group_by(tract_id) |>
  summarise(
    number_of_restaurants = n(),
    average_stars = round(mean(stars, na.rm = TRUE), 2),
    total_reviews = sum(review_count, na.rm = TRUE),
    .groups = "drop"
  ) |>
  arrange(desc(number_of_restaurants))

# Compare the two geographic systems
geography_comparison <- tibble(
  geographic_system = c("ZCTA", "Census tract"),
  number_of_areas = c(nrow(zcta_summary), nrow(tract_summary)),
  restaurants_assigned = c(
    sum(zcta_summary$number_of_restaurants),
    sum(tract_summary$number_of_restaurants)
  ),
  unmatched_restaurants = c(
    sum(is.na(restaurants_with_zcta$ZCTA5CE20)),
    sum(is.na(restaurants_with_tracts$tract_id))
  ),
  smallest_area_count = c(
    min(zcta_summary$number_of_restaurants),
    min(tract_summary$number_of_restaurants)
  ),
  largest_area_count = c(
    max(zcta_summary$number_of_restaurants),
    max(tract_summary$number_of_restaurants)
  ),
  areas_with_fewer_than_5 = c(
    sum(zcta_summary$number_of_restaurants < 5),
    sum(tract_summary$number_of_restaurants < 5)
  )
)

print(geography_comparison)

# STEP 6G: Compare geographic systems visually

geography_plot <- ggplot(
  geography_comparison,
  aes(
    x = geographic_system,
    y = areas_with_fewer_than_5,
    fill = geographic_system
  )
) +
  geom_col(width = 0.6) +
  geom_text(
    aes(label = areas_with_fewer_than_5),
    vjust = -0.5,
    size = 5
  ) +
  labs(
    title = "Geographic Areas with Fewer Than 5 Restaurants",
    subtitle = "Selected New Orleans restaurants",
    x = "Geographic System",
    y = "Number of Areas"
  ) +
  theme_minimal() +
  theme(legend.position = "none")

# Display graph
print(geography_plot)

# Save graph
ggsave(
  "figures/geographic_comparison.png",
  plot = geography_plot,
  width = 9,
  height = 6,
  dpi = 300
)

# PROJECT 2 - STEP 7: Reviewer analysis

# STEP 7A: Calculate ratings from all reviewers

all_reviewer_summary <- selected_reviews |>
  group_by(business_id) |>
  summarise(
    number_of_reviews_all_reviewers = n(),
    average_stars_all_reviewers = mean(stars, na.rm = TRUE),
    median_stars_all_reviewers = median(stars, na.rm = TRUE),
    .groups = "drop"
  )

# Check how many restaurants were summarized
nrow(all_reviewer_summary)

# Show the 10 restaurants with the most reviews
all_reviewer_summary |>
  left_join(
    selected_restaurants |>
      select(business_id, business_name),
    by = "business_id"
  ) |>
  arrange(desc(number_of_reviews_all_reviewers)) |>
  select(
    business_name,
    number_of_reviews_all_reviewers,
    average_stars_all_reviewers
  ) |>
  head(10)