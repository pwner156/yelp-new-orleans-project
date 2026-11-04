# Yelp New Orleans Restaurant Analysis

## Homework 5 – Project 2, Steps 1 and 2

This repository contains my preparation of Yelp restaurant data for New Orleans, Louisiana, using R and RStudio.

### Data Source

Yelp Open Dataset: https://business.yelp.com/data/resources/open-dataset/

### Data Preparation

1. Downloaded and extracted the Yelp Open Dataset.
2. Loaded the original Yelp business data into R.
3. Filtered businesses to restaurants located in New Orleans, Louisiana.
4. Filtered the Yelp reviews to include only reviews associated with those restaurants.
5. Saved both filtered datasets as compressed RDS files.

### Results

- **New Orleans restaurants:** 2,259
- **Associated Yelp reviews:** 476,421

### Project Files

- `R/01_prepare_data.R` – Code documenting the data preparation process.
- `data/new_orleans/business_new_orleans.rds` – Filtered New Orleans restaurant data.
- `data/new_orleans/reviews_new_orleans.rds` – Filtered reviews for New Orleans restaurants.
- `.gitignore` – Excludes large raw Yelp files and temporary files from GitHub.

### Data Management

The original Yelp JSON files are too large to upload to GitHub, so they are stored locally and excluded from the repository.

The filtered datasets are saved as compressed RDS files to reduce storage requirements and make them easier to load in R.

To reproduce the data preparation process, download the original Yelp dataset, place the business and review JSON files in `data/raw/`, and run `R/01_prepare_data.R`.