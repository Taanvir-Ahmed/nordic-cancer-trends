# 04_covid_its.R
# Interrupted time series: how many cancers were "missing" in 2020-2022?
# For each country and cancer, a quasi-Poisson model is fitted to the
# age-specific incidence counts of 2010-2019:
#   log E[cases] = age group + year + log(population)
# and used to predict the expected number of cases in 2020, 2021 and 2022.
# Observed / expected < 1 means fewer diagnoses than the pre-COVID trend.
# Uncertainty in the expected count comes from simulating the model
# coefficients (2,000 draws).
# Only ages 40+ are used (96-100% of cases): younger age groups have years
# with zero cases, which makes the model unstable.
# Danish colorectal cancer is left out: its 2010-2019 baseline contains the
# screening peak of 2014-2017, so it is not a fair test of COVID-19.

source("R/00_setup.R")
set.seed(2026)

counts <- read_processed("counts") |>
  filter(measure == "Incidence", population > 0, age_index >= 9) |>
  filter(!(cancer == "Colorectal" & country == "Denmark")) |>
  mutate(series = make_series(cancer, sex), age_group = droplevels(factor(age_group)))

oe_one <- function(d, n_sim = 2000) {
  train <- filter(d, year >= 2010, year <= 2019)
  test  <- filter(d, year %in% 2020:2022)
  m <- glm(count ~ age_group + year + offset(log(population)),
           family = quasipoisson, data = train)
  X <- model.matrix(~ age_group + year, data = test)
  draws <- MASS::mvrnorm(n_sim, coef(m), vcov(m))          # n_sim x p
  expected <- exp(X %*% t(draws) + log(test$population))   # rows x n_sim
  by_year <- split(seq_len(nrow(test)), test$year)
  map_dfr(names(by_year), function(y) {
    idx <- by_year[[y]]
    e_sims <- colSums(expected[idx, , drop = FALSE])
    obs <- sum(test$count[idx])
    tibble(year = as.integer(y), observed = obs, expected = median(e_sims),
           oe = obs / median(e_sims),
           lower = obs / quantile(e_sims, 0.975, names = FALSE),
           upper = obs / quantile(e_sims, 0.025, names = FALSE))
  })
}

covid <- counts |>
  group_by(series, country) |>
  group_modify(~ oe_one(.x)) |>
  ungroup()

write_csv(covid, "output/covid_observed_expected.csv")

# Cases "missing" in 2020 summed over the four countries
missing_2020 <- covid |>
  filter(year == 2020) |>
  group_by(series) |>
  summarise(observed = sum(observed), expected = sum(expected),
            missing = expected - observed, pct = 100 * (observed / expected - 1))
write_csv(missing_2020, "output/covid_missing_2020.csv")

p <- ggplot(covid, aes(factor(year), oe, colour = country)) +
  geom_hline(yintercept = 1, colour = "grey50", linewidth = 0.3) +
  geom_pointrange(aes(ymin = lower, ymax = upper),
                  position = position_dodge(width = 0.6), size = 0.2, linewidth = 0.5) +
  facet_wrap(~ series, ncol = 3) +
  scale_colour_manual(values = country_cols, name = NULL) +
  scale_y_continuous(labels = scales::percent) +
  labs(x = NULL, y = "Observed / expected new cases",
       title = "New cancer cases in 2020-2022 compared with the 2010-2019 trend",
       caption = paste("Ages 40+. Below 100% = fewer diagnoses than expected. 95% intervals from simulated model coefficients.",
                       "\nDanish colorectal cancer not shown (screening started 2014).")) +
  theme_report()
ggsave("figures/fig6_covid_observed_expected.png", p, width = 8, height = 5, dpi = 200)

print(missing_2020)
