# 03_screening_did.R
# Natural experiment: Denmark started national colorectal cancer screening
# (FIT, ages 50-74) in March 2014. Finland and Norway only started national
# programmes in 2022, so in 1995-2021 they can act as comparison countries.
#
# Difference-in-differences with Poisson-type models on age-specific counts:
#   log E[count] = year effects (shared by all countries)
#                + country x age group x sex effects
#                + effect of screening in Denmark after 2014
#                + log(population)
# The year effects absorb anything that hit all countries in the same year
# (for example COVID-19 in 2020).
#
# Checks:
#   - event study (one Denmark effect per year) to look at pre-trends
#   - placebo age group: ages 0-49 were not invited
#   - negative control outcome: lung cancer at ages 50-74
#   - placebo year: pretend screening started in 2008 (data 1995-2013 only)
#   - adding Sweden as a comparison country (it had a regional programme
#     in Stockholm-Gotland from 2008, so it is not in the main analysis)

source("R/00_setup.R")

counts <- read_processed("counts")

did_years <- 1995:2021
screen_ages <- c("50-54", "55-59", "60-64", "65-69", "70-74")
young_ages  <- c("0-4", "5-9", "10-14", "15-19", "20-24", "25-29",
                 "30-34", "35-39", "40-44", "45-49")

make_did_data <- function(which_measure, which_cancer, ages,
                          controls = c("Finland", "Norway"), years = did_years) {
  counts |>
    filter(measure == which_measure, cancer == which_cancer,
           country %in% c("Denmark", controls), year %in% years,
           age_group %in% ages, population > 0) |>
    mutate(country = droplevels(country),
           denmark = as.integer(country == "Denmark"),
           cell    = interaction(country, age_group, sex, drop = TRUE),
           fyear   = factor(year))
}

# Two post periods: 2014-2017 is the first screening round (it was rolled out
# over about four years), where many hidden cancers are found, so incidence is
# expected to go UP; 2018-2021 is later rounds, where removed polyps should
# start to lower incidence.
# dk_trend = TRUE also gives Denmark its own linear time trend (fitted mostly
# on the pre-2014 years), as a check when parallel trends look doubtful.
fit_did <- function(d, start = 2014, split = 2018, dk_trend = FALSE) {
  d <- d |> mutate(post_early = denmark * (year >= start & year < split),
                   post_late  = denmark * (year >= split),
                   dk_trend   = denmark * (year - 2004))
  f <- count ~ fyear + cell + post_early + post_late + offset(log(population))
  if (dk_trend) f <- update(f, . ~ . + dk_trend)
  m <- glm(f, family = quasipoisson, data = d)
  est <- coef(m)[c("post_early", "post_late")]
  se  <- sqrt(diag(vcov(m))[c("post_early", "post_late")])
  tibble(term = c(sprintf("%d-%d", start, split - 1), sprintf("%d-%d", split, max(d$year))),
         rate_ratio = exp(est), lower = exp(est - 1.96 * se), upper = exp(est + 1.96 * se),
         p_value = 2 * pt(-abs(est / se), df = m$df.residual))
}

# Placebo year: only one post period
fit_did_single <- function(d, start) {
  d <- d |> mutate(post = denmark * (year >= start))
  m <- glm(count ~ fyear + cell + post + offset(log(population)),
           family = quasipoisson, data = d)
  b <- coef(m)[["post"]]; se <- sqrt(vcov(m)["post", "post"])
  tibble(term = sprintf("%d-%d", start, max(d$year)),
         rate_ratio = exp(b), lower = exp(b - 1.96 * se), upper = exp(b + 1.96 * se),
         p_value = 2 * pt(-abs(b / se), df = m$df.residual))
}

# ---- Main results and checks -----------------------------------------------

results <- bind_rows(
  fit_did(make_did_data("Incidence", "Colorectal", screen_ages)) |>
    mutate(analysis = "Main: colorectal incidence, ages 50-74"),
  fit_did(make_did_data("Mortality", "Colorectal", screen_ages)) |>
    mutate(analysis = "Colorectal mortality, ages 50-74"),
  fit_did(make_did_data("Incidence", "Colorectal", young_ages)) |>
    mutate(analysis = "Placebo ages: colorectal incidence, ages 0-49"),
  fit_did(make_did_data("Incidence", "Lung", screen_ages)) |>
    mutate(analysis = "Negative control: lung incidence, ages 50-74"),
  fit_did_single(make_did_data("Incidence", "Colorectal", screen_ages, years = 1995:2013),
                 start = 2008) |>
    mutate(analysis = "Placebo year: fake start 2008, data 1995-2013"),
  fit_did(make_did_data("Incidence", "Colorectal", screen_ages,
                        controls = c("Finland", "Norway", "Sweden"))) |>
    mutate(analysis = "Sensitivity: Sweden added to comparison group"),
  fit_did(make_did_data("Incidence", "Colorectal", screen_ages), dk_trend = TRUE) |>
    mutate(analysis = "Sensitivity: incidence, Denmark's own trend allowed"),
  fit_did(make_did_data("Mortality", "Colorectal", screen_ages), dk_trend = TRUE) |>
    mutate(analysis = "Sensitivity: mortality, Denmark's own trend allowed")
) |>
  relocate(analysis)

write_csv(results, "output/screening_did_results.csv")

# ---- Pre-trend test ------------------------------------------------------------
# Before 2014, did Denmark's rates (ages 50-74) move differently from Finland
# and Norway? Extra linear slope for Denmark, 1995-2013. DiD needs this to be
# close to zero ("parallel trends").
pretrend_test <- function(which_measure) {
  pre <- make_did_data(which_measure, "Colorectal", screen_ages, years = 1995:2013) |>
    mutate(dk_trend = denmark * (year - 2004))
  m <- glm(count ~ fyear + cell + dk_trend + offset(log(population)),
           family = quasipoisson, data = pre)
  b <- coef(m)[["dk_trend"]]; se <- sqrt(vcov(m)["dk_trend", "dk_trend"])
  tibble(outcome = paste("Colorectal", tolower(which_measure), "ages 50-74"),
         extra_apc_denmark = apc(b), lower = apc(b - 1.96 * se),
         upper = apc(b + 1.96 * se), p_value = 2 * pt(-abs(b / se), df = m$df.residual))
}
pretrend <- bind_rows(pretrend_test("Incidence"), pretrend_test("Mortality"))
write_csv(pretrend, "output/screening_pretrend.csv")

# ---- Event study -----------------------------------------------------------------
# One Denmark-vs-comparison effect per year, with 2013 (the last year before
# screening) as the reference year.

event_study <- function(which_measure, which_cancer, ages, label) {
  d <- make_did_data(which_measure, which_cancer, ages)
  for (y in setdiff(did_years, 2013)) d[[paste0("dk_", y)]] <- d$denmark * (d$year == y)
  terms <- paste0("dk_", setdiff(did_years, 2013))
  f <- reformulate(c("fyear", "cell", terms, "offset(log(population))"), response = "count")
  m <- glm(f, family = quasipoisson, data = d)
  tibble(year = setdiff(did_years, 2013), b = coef(m)[terms],
         se = sqrt(diag(vcov(m))[terms])) |>
    bind_rows(tibble(year = 2013, b = 0, se = 0)) |>
    mutate(rate_ratio = exp(b), lower = exp(b - 1.96 * se), upper = exp(b + 1.96 * se),
           outcome = label)
}

es_all <- bind_rows(
  event_study("Incidence", "Colorectal", screen_ages, "Colorectal cancer, ages 50-74 (screened ages)"),
  event_study("Incidence", "Colorectal", young_ages,  "Colorectal cancer, ages 0-49 (placebo: not invited)"),
  event_study("Incidence", "Lung",       screen_ages, "Lung cancer, ages 50-74 (negative control)"),
  event_study("Mortality", "Colorectal", screen_ages, "Colorectal cancer DEATHS, ages 50-74")
) |>
  mutate(outcome = factor(outcome, levels = unique(outcome)))
write_csv(select(es_all, outcome, year, rate_ratio, lower, upper), "output/screening_event_study.csv")

es <- filter(es_all, !grepl("DEATHS", outcome)) |> mutate(outcome = droplevels(outcome))
p_es <- ggplot(es, aes(year, rate_ratio)) +
  annotate("rect", xmin = 2013.5, xmax = Inf, ymin = 0.5, ymax = 2, fill = "#2a78d6", alpha = 0.06) +
  geom_hline(yintercept = 1, colour = "grey50", linewidth = 0.3) +
  geom_vline(xintercept = 2013.5, colour = "grey30", linetype = "dashed", linewidth = 0.3) +
  geom_ribbon(aes(ymin = lower, ymax = upper), fill = "#2a78d6", alpha = 0.18) +
  geom_line(colour = "#2a78d6", linewidth = 0.7) +
  geom_point(colour = "#2a78d6", size = 1.2) +
  facet_wrap(~ outcome, ncol = 1) +
  scale_y_log10(breaks = c(0.6, 0.8, 1, 1.25, 1.5)) +
  coord_cartesian(ylim = c(0.6, 1.6)) +
  labs(x = NULL, y = "Rate ratio, Denmark vs Finland + Norway\n(relative to 2013, log scale)",
       title = "Incidence in Denmark compared with Finland and Norway, by year",
       caption = paste("Shaded area: years after Danish screening started (March 2014).",
                       "Quasi-Poisson event-study model, 95% CI.")) +
  theme_report()
ggsave("figures/fig4_screening_event_study.png", p_es, width = 7, height = 7.5, dpi = 200)

# Plain rates for the screened age group, for a simple descriptive figure
rates <- read_processed("rates")
p_raw <- rates |>
  filter(cancer == "Colorectal", age_range == "50-74", measure == "Incidence",
         year >= 1995, year <= 2024) |>
  ggplot(aes(year, asr_nordic, colour = country, linewidth = country)) +
  annotate("rect", xmin = 2023.5, xmax = 2024.5, ymin = -Inf, ymax = Inf, fill = "grey93") +
  geom_vline(xintercept = 2014, colour = "grey30", linetype = "dashed", linewidth = 0.3) +
  geom_line() +
  facet_wrap(~ sex) +
  scale_colour_manual(values = country_cols, name = NULL) +
  scale_linewidth_manual(values = c(Finland = 0.6, Sweden = 0.6, Norway = 0.6, Denmark = 1.1),
                         name = NULL) +
  scale_y_continuous(limits = c(0, NA)) +
  labs(x = NULL, y = "Cases per 100,000\n(age-standardised)",
       title = "Colorectal cancer incidence at ages 50-74",
       caption = "Dashed line: Danish screening starts (2014). Grey band = 2024, may be incomplete. Source: NORDCAN v9.6.") +
  theme_report()
ggsave("figures/fig5_colorectal_50_74.png", p_raw, width = 8, height = 3.8, dpi = 200)

print(results, width = 150)
print(pretrend)
