# 00_setup.R
# Packages, constants and plot style shared by all analysis scripts.

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(purrr)
  library(ggplot2)
})

# segmented loads MASS, which hides dplyr's select(); keep the dplyr versions
select <- dplyr::select
filter <- dplyr::filter

dir.create("figures", showWarnings = FALSE)
dir.create("output",  showWarnings = FALSE)

# Main analysis window. 2024 is the newest year and may still be missing
# late-registered cases, so it is only shown in plots, not used in models.
year_start <- 1990
year_end   <- 2023

countries <- c("Finland", "Sweden", "Norway", "Denmark")

# Finland is the focus country, so it gets the strongest colour and a thicker line.
country_cols <- c(Finland = "#2a78d6", Sweden = "#eb6834",
                  Norway  = "#1baf7a", Denmark = "#eda100")
country_lwd  <- c(Finland = 1.1, Sweden = 0.6, Norway = 0.6, Denmark = 0.6)

# The six cancer-sex series used in the project
series_levels <- c("Colorectal, men", "Colorectal, women", "Lung, men",
                   "Lung, women", "Breast, women", "Prostate, men")
make_series <- function(cancer, sex) {
  factor(paste0(cancer, ", ", tolower(sex)), levels = series_levels)
}

theme_report <- function() {
  theme_minimal(base_size = 10) +
    theme(panel.grid.minor = element_blank(),
          panel.grid.major = element_line(colour = "grey90", linewidth = 0.3),
          strip.text = element_text(face = "bold", hjust = 0),
          panel.spacing.x = unit(2, "lines"),
          legend.position = "top",
          plot.title.position = "plot",
          plot.caption = element_text(colour = "grey40", hjust = 0),
          plot.background = element_rect(fill = "white", colour = NA))
}

# Annual percent change from a log-scale slope (and its CI)
apc <- function(b) 100 * (exp(b) - 1)

read_processed <- function(name) {
  read_csv(file.path("data/processed", paste0(name, ".csv")), show_col_types = FALSE) |>
    mutate(across(any_of("sex"), ~ factor(.x, levels = c("Men", "Women"))),
           across(any_of("country"), ~ factor(.x, levels = countries)))
}
