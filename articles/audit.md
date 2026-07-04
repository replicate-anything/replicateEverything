# Registry audit

## What `audit_everything()` does

[`audit_everything()`](https://replicate-anything.github.io/replicateEverything/reference/audit_everything.md)
walks the [replication
registry](https://github.com/replicate-anything/registry) and attempts
**every table and figure** in **each listed engine** (R and Stata where
both exist). It is meant as a health check: some failures are expected
as studies, data, and dependencies change over time.

Key behaviour:

- **`patience`** (default `20` seconds) — each table or figure is halted
  after this limit; the audit **continues** with the next object.
- **Failures do not stop the run** — results are collected in a data
  frame.
- **Report fields** — study, object id, engine, success, elapsed
  seconds, timed-out flag, and a short error snippet on failure.

``` r

library(replicateEverything)

# Point at a local monorepo checkout (optional)
options(
  replicateEverything.registry_root = "/path/to/replicate_everything/registry",
  replicateEverything.study_folders_root = "/path/to/replicate_everything",
  replicateEverything.use_sibling_packages = TRUE
)

audit <- audit_everything(patience = 20)
print(audit)
```

You can restrict to specific DOIs or render the Quarto report in the
[registry repository](https://github.com/replicate-anything/registry):

``` r

audit <- audit_everything(patience = 30, dois = "10.1257/aer.91.5.1369")

# Quarto report lives in the registry repo (sibling registry/ in a monorepo)
quarto::quarto_render(audit_everything_qmd(), execute_params = list(patience = 20))
```

## Latest audit results

The table below is built from a saved audit snapshot shipped with the
package (`inst/vignette-data/audit_latest.rds`). Set
`REPLICATE_AUDIT_LIVE=true` (and point at a local monorepo) only when
you intend to refresh that snapshot.

``` r

audit <- if (run_live) {
  tryCatch({
    monorepo <- Sys.getenv("REPLICATE_MONOREPO", unset = "")
    if (!nzchar(monorepo)) {
      parent <- normalizePath(
        file.path(find.package("replicateEverything"), "..", ".."),
        mustWork = FALSE
      )
      if (file.exists(file.path(parent, "registry", "index.csv"))) {
        monorepo <- parent
      }
    }
    if (nzchar(monorepo)) {
      options(
        replicateEverything.registry_root = file.path(monorepo, "registry"),
        replicateEverything.study_folders_root = monorepo,
        replicateEverything.use_sibling_packages = TRUE
      )
    }
    audit_everything(patience = 20, verbose = FALSE)
  }, error = function(e) {
    message("Live audit skipped: ", conditionMessage(e))
    NULL
  })
} else {
  NULL
}

if (is.null(audit) && nzchar(audit_rds) && file.exists(audit_rds)) {
  audit <- readRDS(audit_rds)
}
if (is.null(audit)) {
  stop("No audit results available.")
}
sm <- audit$summary
results <- audit$results
```

### Summary

| Metric                        |            Value |
|:------------------------------|-----------------:|
| Patience (seconds per object) |               20 |
| Studies audited               |                7 |
| Replication runs              |               71 |
| Successful                    |               67 |
| Failed                        |                4 |
| Timed out                     |                1 |
| Audit started                 | 2026-07-03 10:22 |
| Audit finished                | 2026-07-03 10:26 |

``` r

if (sm$runs > 0) {
  pct <- round(100 * sm$success / sm$runs, 1)
  cat(sprintf("**Pass rate:** %s%%\n", pct))
}
#> **Pass rate:** 94.4%
```

### Results by study

``` r

studies <- unique(results$title)
for (study in studies) {
  cat("\n\n#### ", study, "\n\n", sep = "")
  sub <- results[results$title == study, , drop = FALSE]
  sub$status <- ifelse(
    sub$success,
    "OK",
    ifelse(sub$timed_out, "Timed out", "Failed")
  )
  sub$seconds <- ifelse(is.na(sub$seconds), NA, round(sub$seconds, 2))
  show <- sub[, c(
    "object_label", "object", "engine", "status", "seconds", "error_snippet"
  )]
  names(show) <- c("Object", "ID", "Engine", "Status", "Seconds", "Error")
  print(knitr::kable(show, row.names = FALSE))
}
```

#### Ethnicity, Insurgency, and Civil War

| Object  | ID          | Engine | Status | Seconds | Error |
|:--------|:------------|:-------|:-------|--------:|:------|
| Table 1 | tab_1       | r      | OK     |    2.24 |       |
| Table 1 | tab_1_stata | stata  | OK     |    4.75 |       |

#### COVID-19 vaccine acceptance and hesitancy in low- and middle-income countries

| Object | ID | Engine | Status | Seconds | Error |
|:---|:---|:---|:---|---:|:---|
| Acceptance Rates (disaggregated by group) | fig_1 | r | OK | 2.06 |  |
| Robustness check using leave-m-out approach | fig_2 | r | OK | 0.22 |  |
| Reason not to take vaccine | fig_3 | r | OK | 0.44 |  |
| Trust | fig_4 | r | OK | 11.05 |  |
| Trust by acceptance | fig_5 | r | OK | 10.26 |  |
| Trust by gender | fig_6 | r | OK | 10.14 |  |
| Vaccine Data from WGM, WHO | tab_1 | r | OK | 0.17 |  |
| Summary of Studies’ Sampling | tab_2 | r | OK | 0.07 |  |
| Differences in Means | tab_3 | r | OK | 1.28 |  |
| Difference in Means (by study) | tab_4 | r | OK | 2.58 |  |
| Differences between groups within studies (Summary) | tab_5 | r | OK | 2.53 |  |
| Reason to take | tab_6 | r | OK | 2.44 |  |
| Reason to take the vaccine. All categories. | tab_7 | r | OK | 4.81 |  |
| Reason to take the vaccine: by age. | tab_8 | r | OK | 3.16 |  |
| Reason not to take the vaccine | tab_9 | r | OK | 5.30 |  |
| Vaccination Decision-making: most trusted source. | tab_10 | r | OK | 10.86 |  |
| Summary Stats | tab_11 | r | OK | 9.11 |  |

#### Bounding Causes of Effects With Mediators

| Object   | ID    | Engine | Status | Seconds | Error |
|:---------|:------|:-------|:-------|--------:|:------|
| Figure 1 | fig_1 | r      | OK     |    0.14 |       |

#### Public support for global vaccine sharing in the COVID-19 pandemic: Evidence from Germany

| Object   | ID    | Engine | Status | Seconds | Error |
|:---------|:------|:-------|:-------|--------:|:------|
| Figure 1 | fig_1 | r      | OK     |    6.07 |       |
| Figure 2 | fig_2 | r      | OK     |   10.20 |       |
| Figure 3 | fig_3 | r      | OK     |    1.14 |       |
| Figure 4 | fig_4 | r      | OK     |    0.84 |       |
| Figure 5 | fig_5 | r      | OK     |    0.91 |       |
| Figure 6 | fig_6 | r      | OK     |    3.56 |       |
| Figure 7 | fig_7 | r      | OK     |    5.81 |       |
| Figure 8 | fig_8 | r      | OK     |    5.36 |       |
| Table 2  | tab_2 | r      | OK     |    4.52 |       |
| Table 1  | tab_1 | r      | OK     |    3.75 |       |

#### Selection and Incentives in Local Service Provision: Theory and Evidence from Sierra Leone

| Object | ID | Engine | Status | Seconds | Error |
|:---|:---|:---|:---|---:|:---|
| Components of performance outcome variable | fig_1 | r | OK | 0.28 |  |
| Components of quality / surveillance outcome variable | fig_2 | r | OK | 0.23 |  |
| Results Service Provider Quality Period 2 (post) | tab_1 | r | OK | 0.11 |  |
| Results Service Provider Quality Period 1 (pre) | tab_2 | r | OK | 0.11 |  |
| Results Service Provider Quality (Average) | tab_3 | r | OK | 0.11 |  |
| Results Service Provider Performance (Effort, Period 2) | tab_4 | r | OK | 0.11 |  |
| Results Service Provider Performance (Effort, Period 1) | tab_5 | r | OK | 0.11 |  |
| Results Service Provider Performance (Effort, Average) | tab_6 | r | OK | 0.09 |  |
| Structural Model: Posterior Distributions on Model parameters | fig_3 | r | OK | 0.13 |  |
| Experiments: Expected CAHW Effort | fig_4 | r | OK | 0.14 |  |
| Experiments: Posterior Probability that Bureaucratic Package Outperforms Community Package | fig_5 | r | OK | 0.11 |  |
| Model-Based Estimates of Treatment Effects | fig_6 | r | OK | 0.12 |  |
| Appendix: Performance Index components (without standardization) | fig_7 | r | OK | 0.11 |  |
| Appendix: Manipulation checks, social sanctions | tab_7 | r | Failed | 0.05 | Custom GOF row 5 has a different number of values than there are models. \| Call: matrixreg(l, single.row = single.row, stars = stars, custom.model.names = custom.model.names, custom.coef.names = custom.coef.names, |
| Appendix: Manipulation checks, frequency reward CAHW | tab_8 | r | OK | 0.04 |  |
| Appendix: Manipulation checks, frequency motivation CAHW | tab_9 | r | OK | 0.05 |  |
| Appendix: Timeline | tab_10 | r | OK | 0.05 |  |
| Appendix: Balance table | tab_11 | r | OK | 0.06 |  |
| Appendix: Attrition | tab_12 | r | OK | 0.05 |  |
| Appendix: Distribution CAHW Performance Index by Treatment Arm | fig_8 | r | OK | 0.15 |  |
| Appendix: Results by CAHW Performance Index’s Subcomponents | tab_13 | r | OK | 0.11 |  |
| Appendix: Results by CAHW Performance Index’s Subcomponents | tab_14 | r | Failed | 0.08 | There are 3 models, but you provided 4 name(s) for them. \| Call: matrixreg(l, single.row = single.row, stars = stars, custom.model.names = custom.model.names, custom.coef.names = custom.coef.names, |
| Appendix: Results by CAHW Quality Index’s Subcomponents | tab_15 | r | Failed | 0.06 | Custom GOF row 5 has a different number of values than there are models. \| Call: matrixreg(l, single.row = single.row, stars = stars, custom.model.names = custom.model.names, custom.coef.names = custom.coef.names, |

#### Migration, Families, and Counterfactual Families

| Object | ID | Engine | Status | Seconds | Error |
|:---|:---|:---|:---|---:|:---|
| Table 1 | tab_1 | stata | Timed out | 25.03 | reached elapsed time limit \| Call: system2(stata, batch_args, wait = TRUE, stdout = ““, stderr =”“) |
| Figure 1 | fig_1 | stata | OK | 18.77 |  |

#### The Colonial Origins of Comparative Development

| Object  | ID          | Engine | Status | Seconds | Error |
|:--------|:------------|:-------|:-------|--------:|:------|
| Table 1 | tab_1       | r      | OK     |    0.36 |       |
| Table 1 | tab_1_stata | stata  | OK     |    1.42 |       |
| Table 2 | tab_2       | r      | OK     |    0.05 |       |
| Table 2 | tab_2_stata | stata  | OK     |    2.61 |       |
| Table 3 | tab_3       | r      | OK     |    0.07 |       |
| Table 3 | tab_3_stata | stata  | OK     |    3.07 |       |
| Table 4 | tab_4       | r      | OK     |    0.11 |       |
| Table 4 | tab_4_stata | stata  | OK     |    3.67 |       |
| Table 5 | tab_5       | r      | OK     |    0.14 |       |
| Table 5 | tab_5_stata | stata  | OK     |    3.22 |       |
| Table 6 | tab_6       | r      | OK     |    0.18 |       |
| Table 6 | tab_6_stata | stata  | OK     |    3.50 |       |
| Table 7 | tab_7       | r      | OK     |    0.17 |       |
| Table 7 | tab_7_stata | stata  | OK     |    3.24 |       |
| Table 8 | tab_8       | r      | OK     |    0.45 |       |
| Table 8 | tab_8_stata | stata  | OK     |    4.73 |       |

### Failures (concise)

``` r

fails <- results[!results$success, , drop = FALSE]
if (nrow(fails) == 0) {
  cat("All recorded runs succeeded.\n")
} else {
  fails$seconds <- ifelse(is.na(fails$seconds), NA, round(fails$seconds, 2))
  fails$status <- ifelse(fails$timed_out, "Timed out", "Failed")
  show <- fails[, c(
    "title", "object_label", "object", "engine",
    "status", "seconds", "error_snippet"
  )]
  names(show) <- c(
    "Study", "Object", "ID", "Engine", "Status", "Seconds", "Error"
  )
  knitr::kable(show, row.names = FALSE)
}
```

| Study | Object | ID | Engine | Status | Seconds | Error |
|:---|:---|:---|:---|:---|---:|:---|
| Selection and Incentives in Local Service Provision: Theory and Evidence from Sierra Leone | Appendix: Manipulation checks, social sanctions | tab_7 | r | Failed | 0.05 | Custom GOF row 5 has a different number of values than there are models. \| Call: matrixreg(l, single.row = single.row, stars = stars, custom.model.names = custom.model.names, custom.coef.names = custom.coef.names, |
| Selection and Incentives in Local Service Provision: Theory and Evidence from Sierra Leone | Appendix: Results by CAHW Performance Index’s Subcomponents | tab_14 | r | Failed | 0.08 | There are 3 models, but you provided 4 name(s) for them. \| Call: matrixreg(l, single.row = single.row, stars = stars, custom.model.names = custom.model.names, custom.coef.names = custom.coef.names, |
| Selection and Incentives in Local Service Provision: Theory and Evidence from Sierra Leone | Appendix: Results by CAHW Quality Index’s Subcomponents | tab_15 | r | Failed | 0.06 | Custom GOF row 5 has a different number of values than there are models. \| Call: matrixreg(l, single.row = single.row, stars = stars, custom.model.names = custom.model.names, custom.coef.names = custom.coef.names, |
| Migration, Families, and Counterfactual Families | Table 1 | tab_1 | stata | Timed out | 25.03 | reached elapsed time limit \| Call: system2(stata, batch_args, wait = TRUE, stdout = ““, stderr =”“) |

## Interpreting failures

Common reasons a run fails or times out:

- **Missing study package or folder** — install the study repo locally
  or set `replicateEverything.study_folders_root` to your monorepo root.
- **Stata not installed** — Stata-backed entries fail until Stata is
  found; see the *Stata replications* vignette.
- **Network / data** — folder-backed studies may need data files
  downloaded on first run.
- **Patience too low** — slow tables may need a higher `patience` value
  without indicating a true failure.

Re-run locally and refresh the package vignette snapshot:

``` r

Sys.setenv(REPLICATE_AUDIT_LIVE = "true")
options(
  replicateEverything.registry_root = "/path/to/replicate_everything/registry",
  replicateEverything.study_folders_root = "/path/to/replicate_everything",
  replicateEverything.use_sibling_packages = TRUE
)
audit <- audit_everything(patience = 20)
saveRDS(audit, "inst/vignette-data/audit_latest.rds")

# Full HTML report: quarto render audit_everything.qmd (in the registry repo)
```
