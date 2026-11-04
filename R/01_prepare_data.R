
# Homework 5 - Yelp New Orleans Data Preparation
# Project 2: Steps 1 and 2
#
# The original Yelp JSON files are stored in data/raw/.
# They are excluded from GitHub because they are very large.
# This script documents how the New Orleans RDS files
# were created.

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
