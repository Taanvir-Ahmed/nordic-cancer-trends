# run_all.R
# Runs the whole project from the raw NORDCAN files to tables and figures.
# Open nordic-cancer-trends.Rproj in RStudio (so the working directory is the
# project folder) and run:  source("run_all.R")

scripts <- c("R/01_import_clean.R",   # raw files -> data/processed/
             "R/02_trends.R",         # incidence and mortality trends
             "R/03_screening_did.R",  # Danish screening natural experiment
             "R/04_covid_its.R",      # COVID-19 interrupted time series
             "R/05_survival.R")       # 5-year survival and the Finland gap

for (s in scripts) {
  message("Running ", s)
  source(s, local = new.env())
}
message("Done. Tables are in output/, figures in figures/.")
