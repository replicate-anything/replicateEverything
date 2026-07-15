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
- **Substantive checks** (default `substantive = TRUE`) — when a study
  defines `tests/substantive/<step_id>.R`, the audit compares replicated
  estimates to published benchmarks (see Fearon & Laitin `tab_1`).
  Failures appear as `[substantive]` in the printed summary.

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

You can restrict to specific DOIs, a **collection** tag, or render the
Quarto report in the [registry
repository](https://github.com/replicate-anything/registry):

``` r

audit <- audit_everything(patience = 30, dois = "10.1257/aer.91.5.1369")
audit <- audit_everything(patience = 20, collections = "APSR")

# Quarto report lives in the registry repo (sibling registry/ in a monorepo)
quarto::quarto_render(audit_everything_qmd(), execute_params = list(patience = 20))
quarto::quarto_render(
  audit_everything_qmd(),
  execute_params = list(patience = 20, collections = "APSR")
)
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
| Patience (seconds per object) |              120 |
| Studies audited               |               11 |
| Replication runs              |               79 |
| Successful                    |               79 |
| Failed                        |                0 |
| Timed out                     |                0 |
| Audit started                 | 2026-07-15 21:41 |
| Audit finished                | 2026-07-15 21:45 |

``` r

if (sm$runs > 0) {
  pct <- round(100 * sm$success / sm$runs, 1)
  cat(sprintf("**Pass rate:** %s%%\n", pct))
}
#> **Pass rate:** 100%
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

#### Beyond Belief Change: The Persuasive Returns of Targeting Attitude-Relevant Beliefs

| Object  | ID    | Engine | Status | Seconds | Error |
|:--------|:------|:-------|:-------|--------:|:------|
| Table 1 | tab_1 | r      | OK     |   18.82 |       |
| Table 3 | tab_3 | r      | OK     |    4.91 |       |

#### Bounding Causes of Effects With Mediators

| Object   | ID    | Engine | Status | Seconds | Error |
|:---------|:------|:-------|:-------|--------:|:------|
| Figure 1 | fig_1 | r      | OK     |    0.22 |       |

#### COVID-19 vaccine acceptance and hesitancy in low- and middle-income countries

| Object | ID | Engine | Status | Seconds | Error |
|:---|:---|:---|:---|---:|:---|
| Acceptance Rates (disaggregated by group) | fig_1 | r | OK | 1.03 |  |
| Robustness check using leave-m-out approach | fig_2 | r | OK | 0.25 |  |
| Reason not to take vaccine | fig_3 | r | OK | 0.36 |  |
| Trust | fig_4 | r | OK | 9.13 |  |
| Trust by acceptance | fig_5 | r | OK | 9.81 |  |
| Trust by gender | fig_6 | r | OK | 10.07 |  |
| Vaccine Data from WGM, WHO | tab_1 | r | OK | 0.32 |  |
| Summary of Studies’ Sampling | tab_2 | r | OK | 0.16 |  |
| Differences in Means | tab_3 | r | OK | 1.24 |  |
| Difference in Means (by study) | tab_4 | r | OK | 2.54 |  |
| Differences between groups within studies (Summary) | tab_5 | r | OK | 2.39 |  |
| Reason to take | tab_6 | r | OK | 2.25 |  |
| Reason to take the vaccine. All categories. | tab_7 | r | OK | 4.74 |  |
| Reason to take the vaccine: by age. | tab_8 | r | OK | 2.72 |  |
| Reason not to take the vaccine | tab_9 | r | OK | 4.89 |  |
| Vaccination Decision-making: most trusted source. | tab_10 | r | OK | 10.31 |  |
| Summary Stats | tab_11 | r | OK | 8.31 |  |

#### Ethnicity, Insurgency, and Civil War

| Object  | ID          | Engine | Status | Seconds | Error |
|:--------|:------------|:-------|:-------|--------:|:------|
| Table 1 | tab_1       | r      | OK     |    0.89 |       |
| Table 1 | tab_1_stata | stata  | OK     |    5.80 |       |

#### Illustration of re-analysis repo

| Object  | ID    | Engine | Status | Seconds | Error |
|:--------|:------|:-------|:-------|--------:|:------|
| Table 1 | tab_1 | r      | OK     |    0.25 |       |

#### Migration, Families, and Counterfactual Families

| Object   | ID    | Engine | Status | Seconds | Error |
|:---------|:------|:-------|:-------|--------:|:------|
| Table 1  | tab_1 | stata  | OK     |   20.47 |       |
| Figure 1 | fig_1 | stata  | OK     |   14.42 |       |

#### Portraits of Power: Facial Appearance and the Tacit Domain of Political Selection in China

| Object   | ID    | Engine | Status | Seconds | Error |
|:---------|:------|:-------|:-------|--------:|:------|
| Table 1  | tab_1 | stata  | OK     |    7.42 |       |
| Table 2  | tab_2 | stata  | OK     |    7.47 |       |
| Table 3  | tab_3 | stata  | OK     |    6.97 |       |
| Figure 2 | fig_2 | python | OK     |   30.04 |       |
| Figure 4 | fig_4 | r      | OK     |    3.45 |       |
| Figure 5 | fig_5 | r      | OK     |    2.58 |       |

#### Preventing Rebel Resurgence after Civil War: A Field Experiment in Security and Justice Provision in Rural Colombia

| Object  | ID    | Engine | Status | Seconds | Error |
|:--------|:------|:-------|:-------|--------:|:------|
| Table 1 | tab_1 | stata  | OK     |    3.69 |       |

#### Public support for global vaccine sharing in the COVID-19 pandemic: Evidence from Germany

| Object   | ID    | Engine | Status | Seconds | Error |
|:---------|:------|:-------|:-------|--------:|:------|
| Figure 1 | fig_1 | r      | OK     |    6.23 |       |
| Figure 2 | fig_2 | r      | OK     |    9.16 |       |
| Figure 3 | fig_3 | r      | OK     |    1.57 |       |
| Figure 4 | fig_4 | r      | OK     |    1.48 |       |
| Figure 5 | fig_5 | r      | OK     |    2.07 |       |
| Figure 6 | fig_6 | r      | OK     |    2.95 |       |
| Figure 7 | fig_7 | r      | OK     |    4.87 |       |
| Figure 8 | fig_8 | r      | OK     |    5.31 |       |
| Table 2  | tab_2 | r      | OK     |    4.96 |       |
| Table 1  | tab_1 | r      | OK     |    3.98 |       |

#### Selection and Incentives in Local Service Provision: Theory and Evidence from Sierra Leone

| Object | ID | Engine | Status | Seconds | Error |
|:---|:---|:---|:---|---:|:---|
| Components of performance outcome variable | fig_1 | r | OK | 0.45 |  |
| Components of quality / surveillance outcome variable | fig_2 | r | OK | 0.25 |  |
| Results Service Provider Quality Period 2 (post) | tab_1 | r | OK | 0.18 |  |
| Results Service Provider Quality Period 1 (pre) | tab_2 | r | OK | 0.17 |  |
| Results Service Provider Quality (Average) | tab_3 | r | OK | 0.16 |  |
| Results Service Provider Performance (Effort, Period 2) | tab_4 | r | OK | 0.17 |  |
| Results Service Provider Performance (Effort, Period 1) | tab_5 | r | OK | 0.16 |  |
| Results Service Provider Performance (Effort, Average) | tab_6 | r | OK | 0.17 |  |
| Structural Model: Posterior Distributions on Model parameters | fig_3 | r | OK | 0.21 |  |
| Experiments: Expected CAHW Effort | fig_4 | r | OK | 0.20 |  |
| Experiments: Posterior Probability that Bureaucratic Package Outperforms Community Package | fig_5 | r | OK | 0.19 |  |
| Model-Based Estimates of Treatment Effects | fig_6 | r | OK | 0.21 |  |
| Appendix: Performance Index components (without standardization) | fig_7 | r | OK | 0.20 |  |
| Appendix: Variable Description and Summary Information | tab_a5 | r | OK | 0.11 |  |
| Appendix: Manipulation checks | tab_a6 | r | OK | 0.19 |  |
| Appendix: Manipulation checks, frequency reward CAHW | tab_8 | r | OK | 0.11 |  |
| Appendix: Manipulation checks, frequency motivation CAHW | tab_9 | r | OK | 0.10 |  |
| Appendix: Timeline | tab_10 | r | OK | 0.13 |  |
| Appendix: Balance table | tab_11 | r | OK | 0.14 |  |
| Appendix: Distribution CAHW Performance Index by Treatment Arm | fig_8 | r | OK | 0.25 |  |
| Appendix: Results by CAHW Performance Index’s Subcomponents | tab_13 | r | OK | 0.16 |  |

#### The Colonial Origins of Comparative Development

| Object  | ID          | Engine | Status | Seconds | Error |
|:--------|:------------|:-------|:-------|--------:|:------|
| Table 1 | tab_1       | r      | OK     |    0.91 |       |
| Table 1 | tab_1_stata | stata  | OK     |    1.11 |       |
| Table 2 | tab_2       | r      | OK     |    0.17 |       |
| Table 2 | tab_2_stata | stata  | OK     |    1.98 |       |
| Table 3 | tab_3       | r      | OK     |    0.16 |       |
| Table 3 | tab_3_stata | stata  | OK     |    2.09 |       |
| Table 4 | tab_4       | r      | OK     |    0.27 |       |
| Table 4 | tab_4_stata | stata  | OK     |    2.21 |       |
| Table 5 | tab_5       | r      | OK     |    0.20 |       |
| Table 5 | tab_5_stata | stata  | OK     |    2.22 |       |
| Table 6 | tab_6       | r      | OK     |    0.23 |       |
| Table 6 | tab_6_stata | stata  | OK     |    2.27 |       |
| Table 7 | tab_7       | r      | OK     |    0.24 |       |
| Table 7 | tab_7_stata | stata  | OK     |    2.33 |       |
| Table 8 | tab_8       | r      | OK     |    0.38 |       |
| Table 8 | tab_8_stata | stata  | OK     |    2.78 |       |

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
#> All recorded runs succeeded.
```

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

After adding or updating registry stubs, maintainers typically run
\[refresh_registry()\] so `index.csv` and the audit stay in sync:

``` r

refresh_registry("../registry", audit = TRUE, patience = 20)
```
