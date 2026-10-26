# 02_trends.R
# Incidence and mortality trends, 1990-2023.
#  (a) Plots of age-standardised rates (ASR, Nordic standard).
#  (b) Annual percent change (APC) per country from a quasi-Poisson model on
#      age-specific counts:  log E[cases] = age group + year + 2020 dummy + log(pop)
#  (c) Does Finland's APC differ from the other three countries? (interaction model)
#  (d) Joinpoint-style segmented regression on log(ASR) to find years where
#      the trend changes (0, 1 or 2 breakpoints chosen by BIC).

source("R/00_setup.R")
library(segmented)

rates  <- read_processed("rates")  |> filter(age_range == "all ages")
counts <- read_processed("counts")

rates  <- rates  |> mutate(series = make_series(cancer, sex))
counts <- counts |> mutate(series = make_series(cancer, sex))

# ---- (a) Trend plots ---------------------------------------------------------

plot_rates <- function(which_measure, file) {
  d <- rates |> filter(measure == which_measure, year >= year_start)
  p <- ggplot(d, aes(year, asr_nordic, colour = country, linewidth = country)) +
    annotate("rect", xmin = 2023.5, xmax = 2024.5, ymin = -Inf, ymax = Inf,
             fill = "grey93") +
    geom_line() +
    facet_wrap(~ series, scales = "free_y", ncol = 3) +
    scale_colour_manual(values = country_cols, name = NULL) +
    scale_linewidth_manual(values = country_lwd, name = NULL) +
    scale_y_continuous(limits = c(0, NA)) +
    labs(x = NULL, y = "Rate per 100,000 (age-standardised, Nordic)",
         title = paste(which_measure, "of four cancers, 1990-2024"),
         caption = "Source: NORDCAN v9.6. Grey band = 2024, may be incomplete.") +
    theme_report()
  ggsave(file, p, width = 8, height = 5, dpi = 200)
}
plot_rates("Incidence", "figures/fig1_incidence_trends.png")
plot_rates("Mortality", "figures/fig2_mortality_trends.png")

# ---- (b) APC per country from age-specific counts ------------------------------

model_data <- counts |>
  filter(year >= year_start, year <= year_end, population > 0) |>
  mutate(year_c = year - 2005,                      # centred year
         covid  = as.integer(year == 2020))

fit_apc <- function(d) {
  m  <- glm(count ~ age_group + year_c + covid + offset(log(population)),
            family = quasipoisson, data = d)
  b  <- coef(m)[["year_c"]]
  se <- sqrt(vcov(m)["year_c", "year_c"])
  tibble(apc = apc(b), lower = apc(b - 1.96 * se), upper = apc(b + 1.96 * se),
         dispersion = summary(m)$dispersion)
}

apc_table <- model_data |>
  group_by(measure, series, country) |>
  group_modify(~ fit_apc(.x)) |>
  ungroup()

write_csv(apc_table, "output/apc_by_country.csv")

p_apc <- ggplot(apc_table, aes(apc, country, colour = country)) +
  geom_vline(xintercept = 0, colour = "grey50", linewidth = 0.3) +
  geom_pointrange(aes(xmin = lower, xmax = upper), size = 0.25, linewidth = 0.5) +
  facet_grid(series ~ measure) +
  scale_colour_manual(values = country_cols, guide = "none") +
  scale_y_discrete(limits = rev(countries)) +
  labs(x = "Average annual percent change, 1990-2023 (95% CI)", y = NULL,
       title = "How fast rates changed per year, by country",
       caption = "Quasi-Poisson model on age-specific counts, adjusted for age; 2020 has its own dummy.") +
  theme_report() +
  theme(strip.text.y = element_text(angle = 0, hjust = 0))
ggsave("figures/fig3_apc.png", p_apc, width = 7, height = 7.5, dpi = 200)

# ---- (c) Finland vs the other three --------------------------------------------
# Common age pattern per country, separate intercepts, and one slope for the
# other countries plus an extra slope term for Finland. exp(extra) - 1 tells how
# much faster (+) or slower (-) the Finnish rate changed per year.

fit_finland_diff <- function(d) {
  d <- d |> mutate(finland = as.integer(country == "Finland"))
  m <- glm(count ~ country * age_group + year_c + year_c:finland + covid +
             offset(log(population)), family = quasipoisson, data = d)
  b  <- coef(m)[["year_c:finland"]]
  se <- sqrt(vcov(m)["year_c:finland", "year_c:finland"])
  tibble(diff_apc = apc(b), lower = apc(b - 1.96 * se), upper = apc(b + 1.96 * se),
         p_value = 2 * pt(-abs(b / se), df = m$df.residual))
}

finland_diff <- model_data |>
  group_by(measure, series) |>
  group_modify(~ fit_finland_diff(.x)) |>
  ungroup()

write_csv(finland_diff, "output/finland_vs_others_apc.csv")

# ---- (d) Joinpoint-style segmented regression ----------------------------------

fit_joinpoints <- function(d) {
  d <- arrange(d, year)
  m0 <- lm(log(asr_nordic) ~ year, data = d)
  # selgmented() compares 0, 1 and 2 breakpoints with BIC
  sel <- tryCatch(
    suppressWarnings(selgmented(m0, seg.Z = ~ year, Kmax = 2, type = "bic",
                                msg = FALSE, return.fit = TRUE)),
    error = function(e) m0)
  if (!inherits(sel, "segmented")) {
    b <- coef(m0)[["year"]]
    return(tibble(segment = 1, from = min(d$year), to = max(d$year),
                  apc = apc(b), breakpoint_ci = NA_character_))
  }
  bp  <- confint(sel)                # breakpoint estimates and CI
  sl  <- slope(sel)$year             # slopes of each segment
  brk <- round(bp[, 1])
  tibble(segment = seq_len(nrow(sl)),
         from = c(min(d$year), brk),
         to   = c(brk, max(d$year)),
         apc  = apc(sl[, 1]),
         breakpoint_ci = c(NA, sprintf("%.0f-%.0f", bp[, 2], bp[, 3])))
}

joinpoints <- rates |>
  filter(year >= year_start, year <= year_end) |>
  group_by(measure, series, country) |>
  group_modify(~ fit_joinpoints(.x)) |>
  ungroup()

write_csv(joinpoints, "output/joinpoints.csv")

cat("Trend models done:", nrow(apc_table), "APC estimates,",
    nrow(joinpoints), "segments\n")
