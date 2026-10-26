# Is Finland falling behind? Cancer trends in Finland and the other Nordic countries, 1990-2023

## 1. Background and questions

The Nordic countries have similar health systems and some of the best cancer registries in the world, so they are often compared with each other. Finland has usually done well in these comparisons. In this project I wanted to check if that is still true for four common cancers: colorectal, lung, female breast and prostate cancer.

I had three questions:

1. How have incidence, mortality and 5-year survival changed in Finland since 1990, compared with Sweden, Norway and Denmark?
2. Did the Danish colorectal cancer screening programme, which started in 2014, change colorectal cancer rates in Denmark? Finland and Norway did not have national screening until 2022, so they can be used as a comparison.
3. How many cancer diagnoses were missing during the COVID-19 pandemic?

This is a portfolio project. I used only open, aggregated data, so the results describe countries and not individual patients.

## 2. Data

All data come from NORDCAN version 9.6, the cancer database of the Association of the Nordic Cancer Registries and IARC. I used:

- yearly age-standardised incidence and mortality rates (Nordic standard population), 1960-2024
- the number of new cases and deaths and the population for 18 five-year age groups, by country, sex and year
- age-standardised 5-year relative survival with 95% confidence intervals, for 5-year diagnosis periods from 1990-94 to 2020-24

The main analysis covers 1990-2023. I left 2024 out of the models because the newest year in a cancer registry is often incomplete; it is only shown in the figures.

I checked the downloads before using them. There were no missing values or duplicate rows, and the age-specific counts add up exactly to the yearly totals (5,190 rows checked). One odd thing: Finland's age-specific counts are often not whole numbers (for example 0.6 cases), although the totals are correct. I could not find the reason in the NORDCAN documentation.

## 3. Methods

All analysis was done in R. The code is in the `R/` folder and `run_all.R` runs everything from the raw files.

### Trends

For each country, cancer and sex I fitted a quasi-Poisson regression to the age-specific counts, with age group and calendar year as covariates and log(population) as an offset. I added a dummy for 2020 so the COVID-19 dip would not affect the trend. The year coefficient gives the average annual percent change (APC). I used quasi-Poisson because the counts were overdispersed, and it also works with Finland's non-integer counts. To test whether Finland's trend differed from the other three countries, I fitted one model per cancer with an extra slope term for Finland. To find years where the trend changed, I used segmented regression on log(rate) with the `segmented` package. The number of breakpoints (0, 1 or 2) was chosen by BIC, which is similar to joinpoint regression.

### Danish screening (difference-in-differences)

I compared colorectal cancer at ages 50-74 (the invited ages) in Denmark with Finland and Norway, 1995-2021. The model had a separate effect for each year (shared by all countries), a separate effect for each country-age-sex group, and two screening terms for Denmark: 2014-2017 and 2018-2021. I split the post period because the first screening round finds many cancers that already exist, so incidence should first go up, and only later go down when removed polyps stop turning into cancer. Sweden was not in the main comparison group because Stockholm and Gotland have had regional screening since 2008. I also ran an event study (one Denmark effect for each year) to check that Denmark and the comparison countries moved in parallel before 2014. Then I ran three placebo tests where no effect should appear: ages 0-49, which were not invited; lung cancer at ages 50-74; and a fake start year of 2008.

### COVID-19 (interrupted time series)

For each country and cancer I fitted a quasi-Poisson model to the 2010-2019 counts (ages 40 and over, which covers 96-100% of cases) and predicted the expected number of cases for 2020-2022. I got 95% intervals by simulating the model coefficients 2,000 times. Danish colorectal cancer was left out because its 2010-2019 baseline includes the screening peak.

### Survival

I compared Finland's 5-year relative survival with the average of the other three countries in each period. I worked out the standard errors from the published confidence intervals.

## 4. Results

### 4.1 Incidence and mortality

![Mortality trends](../figures/fig2_mortality_trends.png)

Mortality fell for all cancers in all countries except lung cancer in women. Lung cancer mortality in women rose in the 1990s and 2000s; since about 2007-2010 it has been falling in Sweden, Norway and Denmark, but in Finland it has been flat since 2014 (APC 0.3%). Incidence trends are in `figures/fig1_incidence_trends.png`.

For lung cancer in men, Finland had the fastest fall of the four countries: incidence fell 2.2% per year (95% CI 2.1-2.3) and mortality 2.7% per year (2.6-2.8). For prostate cancer, Finnish mortality fell about as fast as in Norway (2.1% per year), and faster than in Sweden and Denmark.

For colorectal and breast cancer the picture is different. In 1990 Finland had the lowest mortality of the four countries for both cancers. Since then Finnish mortality has fallen more slowly than in the other countries:

| Mortality, APC 1990-2023 (%) | Finland | Sweden | Norway | Denmark |
|---|---|---|---|---|
| Colorectal, men | -0.6 | -1.0 | -1.5 | -2.1 |
| Colorectal, women | -1.0 | -0.6 | -1.0 | -1.9 |
| Breast, women | -0.9 | -1.2 | -2.0 | -1.8 |

In the model with an extra slope for Finland, the Finnish decline was slower by 0.9 percentage points per year for colorectal cancer in men (95% CI 0.7-1.1) and by 0.8 points for breast cancer (0.6-1.0). For colorectal cancer in women the difference was small and not clear (0.16, CI -0.02 to 0.34). The segmented regression shows when this happened: colorectal cancer mortality in Finnish men has been flat since about 2009 (APC 0.0%; the breakpoint itself is uncertain, 95% CI 2002-2016), while in the other three countries the decline sped up after 2011-2015, to about 2.4-3.5% per year. By 2023 the age-standardised colorectal mortality for men was 25.0 per 100,000 in Finland and 23.5 in Sweden, so Finland was no longer the lowest. For breast cancer, Norway (18.9) and Sweden (19.8) were below Finland (21.1) in 2023.

All APCs, the Finland comparison and all breakpoints are in `output/`.

### 4.2 Survival

![Survival gap](../figures/fig8_survival_gap.png)

5-year relative survival went up in every country for all four cancers (`figures/fig7_survival_trends.png`). In 1990-94 Finland was at or above the average of the other three countries for every cancer. This has changed for lung cancer and, to a smaller degree, colorectal cancer in men.

For lung cancer in men diagnosed in 2020-24, 5-year survival was 17.9% in Finland and 30.1% on average in the other countries, a gap of 12.2 percentage points (95% CI 10.7-13.6). In 1990-94 there was no gap (-0.1 points). Finnish men gained 9.6 points of survival over the period; men in the other countries gained 21-22 points. For women with lung cancer the gap in 2020-24 was 7.4 points (5.5-9.2), and in 1990-94 Finland had been 2.7 points ahead. For colorectal cancer in men Finland was 2.4 points behind (1.1-3.8) in 2020-24, after being 2.1 points ahead in 1990-94. For colorectal cancer in women, breast cancer and prostate cancer the four countries are now almost equal.

These data cannot say why Finnish lung cancer survival is lower. Possible reasons are later diagnosis (a higher share of advanced stage), differences in treatment, or differences in how cases are registered. Checking this would need stage and treatment data at the patient level.

### 4.3 Colorectal cancer screening in Denmark

![Event study](../figures/fig4_screening_event_study.png)

Before 2014, colorectal cancer incidence at ages 50-74 in Denmark moved together with Finland and Norway. The extra yearly trend for Denmark in 1995-2013 was 0.1% (95% CI -0.1 to 0.4). After screening started, Danish incidence went up first and then down (top panel of the figure above, and `figures/fig5_colorectal_50_74.png`):

| | Rate ratio, Denmark vs Finland + Norway (95% CI) |
|---|---|
| 2014-2017 (first screening round) | 1.18 (1.14-1.21) |
| 2018-2021 | 0.91 (0.88-0.94) |

So in the first round Denmark had about 18% more colorectal cancers than expected, and in 2018-2021 about 9% fewer. This is the pattern you would expect if screening first finds existing cancers and later prevents some by removing polyps.

The placebo tests found nothing. For ages 0-49 the rate ratios were 0.98 (0.90-1.07) and 0.98 (0.90-1.06). For lung cancer at ages 50-74 they were 0.95 (0.89-1.01) and 0.98 (0.92-1.04). The fake start year of 2008 gave 1.00 (0.97-1.02). The results were also similar when Sweden was added to the comparison group (1.20 and 0.92), and when Denmark was given its own linear trend (1.17 and 0.90).

For colorectal cancer deaths the result was less clear. The simple model gave a rate ratio of 0.75 in 2018-2021, but the parallel-trends check failed: Danish mortality was already falling 0.9% per year faster than in Finland and Norway before 2014 (95% CI 0.5-1.3). When I allowed Denmark its own trend the ratio was 0.87 (0.80-0.94), but this depends on how the old trend is extended. I don't think these data can show a mortality effect yet. Screening trials usually need more than ten years of follow-up for that.

### 4.4 COVID-19

![COVID-19](../figures/fig6_covid_observed_expected.png)

In 2020 there were fewer new cancer cases than the 2010-2019 trend predicted. Summed over the four countries, about 2,700 prostate cancers (10% of expected) and 1,300 breast cancers (6%) were missing. For colorectal and lung cancer the deficit was 2-4%. The largest single drop was prostate cancer in Sweden: 19% fewer cases than expected in 2020 (observed/expected 0.81, 95% interval 0.79-0.83), still 9% fewer in 2021, and 5% more than expected in 2022. Breast cancer in Norway fell 11% in 2020 and was back to normal in 2021. In Finland breast cancer cases were 6% below expected in 2020 and 9% below in 2022 (0.91, 0.88-0.95), so there was no clear catch-up. Denmark had the smallest changes.

## 5. Limitations

- The data are aggregated by country, sex, age and year. The results are about population rates, and nothing here can be applied to individual patients. Differences between countries can come from many things at once, such as smoking history, screening, diagnostics, treatment and registration practice.
- The difference-in-differences analysis has only one treated country and two comparison countries. The confidence intervals come from the count model and do not account for country-level variation, so they are probably too narrow. The placebo tests make the incidence result more believable, but they do not prove it.
- The comparison countries were not completely unscreened. Finland ran a randomised screening programme for part of the population aged 60-69 in 2004-2016, and both Finland and Norway started national screening in 2022.
- The 2018-2021 period includes the COVID-19 years. The shared year effects remove a common drop, but the pandemic may have affected screening differently in each country.
- The COVID-19 analysis assumes the 2010-2019 trend would have continued. For a few series (for example Finnish breast cancer) the trend was already changing, so the expected numbers are uncertain.
- I fitted the breakpoint models to age-standardised rates, not with the official Joinpoint software, so the results are close to joinpoint regression but not the same.
- Coding systems changed in Norway and Sweden in 1993 and in Sweden and Finland around 2005-2007. Some of the breakpoints found in the mid-1990s may be partly caused by this. I did not test it formally.
- Finland's non-integer age-specific counts are not explained in the documentation.

## 6. Conclusions

Finland is not behind in everything. Lung cancer incidence and mortality in Finnish men fell faster than in the other countries, and breast and prostate cancer survival is now the same in all four countries. But for colorectal cancer in men and for breast cancer, mortality has fallen more slowly in Finland than in the other countries, and Finland has lost the low mortality it had in 1990. The biggest gap is in lung cancer survival, where Finland was equal in the early 1990s and is now 12 percentage points behind for men and 7 points behind for women.

The Danish screening comparison shows that colorectal incidence first rose by about 18% and then fell by about 9% after screening started, and the placebo tests support this. Finland started national colorectal screening in 2022, and the Danish data suggest what Finnish incidence figures may look like over the next few years.

A useful next step would be patient-level data with stage at diagnosis, for example from the Finnish Cancer Registry, to see whether the lung cancer survival gap comes from later diagnosis.
