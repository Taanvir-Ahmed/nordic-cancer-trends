# 05_survival.R
# 5-year relative survival (age-standardised, from NORDCAN) by 5-year
# diagnosis period, 1990-94 to 2020-24.
# The "Finland gap" is Finland's survival minus the average of Sweden, Norway
# and Denmark in the same period. Standard errors are taken from the published
# 95% confidence intervals: SE = (upper - lower) / (2 * 1.96).

source("R/00_setup.R")

surv <- read_processed("survival") |>
  filter(mid_year >= 1992) |>                       # 1990-1994 onwards
  mutate(series = make_series(cancer, sex),
         se = (upper - lower) / (2 * 1.96))

# ---- Figure: survival trends -------------------------------------------------

p1 <- ggplot(surv, aes(mid_year, surv5, colour = country, linewidth = country)) +
  geom_line() +
  geom_point(size = 0.9) +
  facet_wrap(~ series, ncol = 3, scales = "free_y") +
  scale_colour_manual(values = country_cols, name = NULL) +
  scale_linewidth_manual(values = country_lwd, name = NULL) +
  scale_x_continuous(breaks = c(1992, 2007, 2022),
                     labels = c("1990-94", "2005-09", "2020-24"),
                     expand = expansion(mult = 0.1)) +
  labs(x = "Period of diagnosis", y = "5-year relative survival (%)",
       title = "5-year relative survival by period of diagnosis",
       caption = "Age-standardised (ICSS weights). Source: NORDCAN v9.6.") +
  theme_report()
ggsave("figures/fig7_survival_trends.png", p1, width = 8, height = 5, dpi = 200)

# ---- Finland gap ---------------------------------------------------------------

gap <- surv |>
  group_by(series, period, mid_year) |>
  summarise(finland = surv5[country == "Finland"],
            others  = mean(surv5[country != "Finland"]),
            se_fi   = se[country == "Finland"],
            se_oth  = sqrt(sum(se[country != "Finland"]^2)) / 3,
            best_other = as.character(country[country != "Finland"][which.max(surv5[country != "Finland"])]),
            .groups = "drop") |>
  mutate(gap   = finland - others,
         se    = sqrt(se_fi^2 + se_oth^2),
         lower = gap - 1.96 * se,
         upper = gap + 1.96 * se) |>
  select(series, period, mid_year, finland, others, gap, lower, upper, best_other)

write_csv(gap, "output/survival_finland_gap.csv")

# Change in survival from 1990-94 to 2020-24, by country
change <- surv |>
  filter(mid_year %in% c(1992, 2022)) |>
  select(series, country, mid_year, surv5) |>
  pivot_wider(names_from = mid_year, values_from = surv5, names_prefix = "surv_") |>
  mutate(gain = surv_2022 - surv_1992)
write_csv(change, "output/survival_change.csv")

p2 <- ggplot(gap, aes(mid_year, gap)) +
  geom_hline(yintercept = 0, colour = "grey50", linewidth = 0.3) +
  geom_ribbon(aes(ymin = lower, ymax = upper), fill = "#2a78d6", alpha = 0.18) +
  geom_line(colour = "#2a78d6", linewidth = 0.8) +
  geom_point(colour = "#2a78d6", size = 1.2) +
  facet_wrap(~ series, ncol = 3) +
  scale_x_continuous(breaks = c(1992, 2007, 2022),
                     labels = c("1990-94", "2005-09", "2020-24"),
                     expand = expansion(mult = 0.1)) +
  labs(x = "Period of diagnosis",
       y = "Finland minus average of\nSweden, Norway, Denmark (percentage points)",
       title = "Finland's 5-year survival compared with the other three countries",
       caption = "Below zero = Finland lower. Band = approximate 95% CI from published survival CIs.") +
  theme_report()
ggsave("figures/fig8_survival_gap.png", p2, width = 8, height = 5, dpi = 200)

print(filter(gap, mid_year %in% c(1992, 2022)), width = 150)
