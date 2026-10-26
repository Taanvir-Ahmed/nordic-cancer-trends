DATA LOG — Nordic Cancer Trends
================================

Source
------
NORDCAN 2.0 web tool, https://nordcan.iarc.fr/
Database version: 9.6
Data licence: data extracted from NORDCAN are in the public domain; the
source must be cited (see the main README). Copyright of the website: ANCR.

Common settings
---------------
Countries:  Denmark, Finland, Norway, Sweden (national; not grouped)
Cancers:    Colorectal (ICD-10 C18–C20, code 520), Lung (C33–C34, code 160),
            Breast (C50, code 180; females), Prostate (C61, code 240; males)
Sex codes:  1 = male, 2 = female

Files
-----
1) Incidence and mortality trends  (Data visualization > Trends)
   Display by: Population | Statistics: ASR (Nordic 2000) | Ages 0–85+
   Years 1960–2024 | By sex (breast: females, prostate: males)
   inc_colorectal.csv  inc_lung.csv  inc_breast.csv  inc_prostate.csv
   mort_colorectal.csv mort_lung.csv mort_breast.csv mort_prostate.csv
   Columns: ASR (World, Nordic, European 1976, European 2013), crude rate,
   cumulative risk 0–79, Numbers (cases/deaths).

2) Survival  (Data visualization > Survival - Trends)
   Display by: Population | 5-year relative survival, age-standardised
   Period of diagnosis span: 5 years | Years 1967–2024
   surv_colorectal.csv surv_lung.csv surv_breast.csv surv_prostate.csv
   "Year" = mid-year of the 5-year diagnosis period (1977 = 1975–79,
   2022 = 2020–24). "Survival (%)" is a JSON string with value, lowCI, upCI.

3) For the causal (screening) module and Poisson models
   Same source and version (NORDCAN 9.6). Retrieved through the NORDCAN web
   tool's data service (the same data the Trends page shows), via browser.
   inc_colorectal_50_74.csv  mort_colorectal_50_74.csv   ages 50-74
   inc_colorectal_0_49.csv   mort_colorectal_0_49.csv    ages 0-49 (placebo)
     Same columns as the Trends files; ASRs computed over that age range.
   agespecific_counts.csv
     Long format: measure, cancer_code, cancer, country, iso3, sex, year,
     age_group (18 five-year groups, 0-4 ... 85+), age_index (1-18),
     count (cases or deaths), population (person-years).
     4 cancers x incidence/mortality x 4 countries x 1960-2024; 56,052 rows.
   Checks: summed age-specific counts match "Numbers" in all 12 Trends files
   (5,190 rows checked, 0 mismatches).
   Note: Finland's age-specific counts are often non-integer (e.g. 0.6 cases),
   in every year; other countries are whole numbers. Totals still match.
   Use quasi-Poisson / negative binomial (or round) when modelling counts.

Data checks
-----------------------------
- No blank cells, no duplicate rows, no gaps in years.
- Norway mortality starts in 1961 (not 1960) — outside analysis window.
- Lung survival: 5 early periods missing (DK/FI females & NO males 1975–79,
  NO females 1980–84) — NORDCAN suppresses unstable estimates. Outside
  analysis window.
- 2020: visible dip in breast/prostate incidence (COVID-19 disruption to
  screening/diagnostics). Handle explicitly in models.
- 2024: possibly incomplete registration (e.g. lung incidence, Swedish men).
  Treat as provisional; main models use 1990–2023.
- ICD coding changes inside the analysis window: Norway and Sweden switched
  from ICD-7 to ICD-O-2 in 1993; Sweden to ICD-O-3 in 2005; Finland to
  ICD-O-3 ~2007. Check for jumps around these years.

Raw files must never be edited by hand. All cleaning is done in R/.
