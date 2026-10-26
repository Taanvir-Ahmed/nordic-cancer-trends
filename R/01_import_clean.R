# 01_import_clean.R
# Reads the raw NORDCAN downloads in data/raw/ and writes three tidy files
# to data/processed/:
#   rates.csv     age-standardised rates and case/death numbers by year
#   counts.csv    cases/deaths and population by 5-year age group and year
#   survival.csv  5-year relative survival by 5-year diagnosis period
# The raw files are never changed.

library(dplyr)
library(tidyr)
library(readr)
library(purrr)
library(jsonlite)

raw_dir <- "data/raw"
out_dir <- "data/processed"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

sex_label <- function(x) factor(ifelse(x == 1, "Men", "Women"), levels = c("Men", "Women"))
countries <- c("Denmark", "Finland", "Norway", "Sweden")

# ---- 1. Rates (incidence and mortality trend files) -------------------------

# File names look like inc_lung.csv or mort_colorectal_50_74.csv
rate_files <- list.files(raw_dir, pattern = "^(inc|mort)_.*\\.csv$", full.names = TRUE)

read_rate_file <- function(path) {
  name  <- tools::file_path_sans_ext(basename(path))
  parts <- strsplit(name, "_")[[1]]
  ages  <- if (length(parts) == 4) paste0(parts[3], "-", parts[4]) else "all ages"

  # Read every column as text first: one column name has an unusual hyphen
  # in some downloads, so columns are picked by position, not by name.
  d <- read_csv(path, col_types = cols(.default = col_character()))
  stopifnot(ncol(d) == 13)
  names(d) <- c("country", "cancer_code", "country_code", "iso3", "sex", "year",
                "asr_world", "asr_nordic", "asr_eur1976", "asr_eur2013",
                "crude_rate", "cum_risk_0_79", "n")

  d |>
    mutate(measure   = ifelse(parts[1] == "inc", "Incidence", "Mortality"),
           cancer    = tools::toTitleCase(parts[2]),
           age_range = ages,
           across(c(year, cancer_code, country_code), as.integer),
           across(c(asr_world:n), as.numeric),
           sex = sex_label(as.integer(sex)))
}

rates <- map(rate_files, read_rate_file) |>
  list_rbind() |>
  select(measure, cancer, age_range, country, sex, year,
         asr_nordic, asr_world, crude_rate, n) |>
  arrange(measure, cancer, age_range, country, sex, year)

# ---- 2. Age-specific counts --------------------------------------------------

counts <- read_csv(file.path(raw_dir, "agespecific_counts.csv"), show_col_types = FALSE) |>
  mutate(measure = tools::toTitleCase(measure),
         sex     = sex_label(sex),
         age_group = factor(age_group, levels = unique(age_group[order(age_index)]))) |>
  select(measure, cancer, country, sex, year, age_index, age_group, count, population)

# ---- 3. Survival -------------------------------------------------------------

surv_files <- list.files(raw_dir, pattern = "^surv_.*\\.csv$", full.names = TRUE)

read_surv_file <- function(path) {
  d <- read_csv(path, col_types = cols(.default = col_character()))
  names(d) <- c("country", "cancer_code", "country_code", "iso3", "sex", "year", "surv_json")
  # The survival column is a small JSON text: {"value":"91.1","lowCI":"90.5","upCI":"91.8"}
  s <- map(d$surv_json, fromJSON)
  d |>
    mutate(cancer = tools::toTitleCase(sub("surv_", "", tools::file_path_sans_ext(basename(path)))),
           sex    = sex_label(as.integer(sex)),
           mid_year = as.integer(year),
           period = paste0(mid_year - 2, "-", mid_year + 2),   # 1977 means 1975-1979
           surv5  = as.numeric(map_chr(s, "value")),
           lower  = as.numeric(map_chr(s, "lowCI")),
           upper  = as.numeric(map_chr(s, "upCI"))) |>
    select(cancer, country, sex, period, mid_year, surv5, lower, upper)
}

survival <- map(surv_files, read_surv_file) |>
  list_rbind() |>
  arrange(cancer, country, sex, mid_year)

# ---- 4. Checks ---------------------------------------------------------------

stopifnot(
  all(rates$country %in% countries),
  all(counts$country %in% countries),
  all(survival$country %in% countries),
  !anyNA(rates$asr_nordic), !anyNA(counts$count), !anyNA(survival$surv5),
  !any(duplicated(select(rates, measure, cancer, age_range, country, sex, year))),
  !any(duplicated(select(counts, measure, cancer, country, sex, year, age_index)))
)

# Summed age-specific counts must equal the totals in the all-ages files
check <- counts |>
  group_by(measure, cancer, country, sex, year) |>
  summarise(n_from_ages = sum(count), .groups = "drop") |>
  inner_join(filter(rates, age_range == "all ages"),
             by = c("measure", "cancer", "country", "sex", "year"))
stopifnot(nrow(check) == nrow(filter(rates, age_range == "all ages")),
          max(abs(check$n_from_ages - check$n)) < 0.01)

# ---- 5. Save -----------------------------------------------------------------

write_csv(rates,    file.path(out_dir, "rates.csv"))
write_csv(counts,   file.path(out_dir, "counts.csv"))
write_csv(survival, file.path(out_dir, "survival.csv"))

cat("rates:", nrow(rates), "rows | counts:", nrow(counts),
    "rows | survival:", nrow(survival), "rows\n")
