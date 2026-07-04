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
| Studies audited               |                1 |
| Replication runs              |                2 |
| Successful                    |                2 |
| Failed                        |                0 |
| Timed out                     |                0 |
| Audit started                 | 2026-07-04 08:35 |
| Audit finished                | 2026-07-04 08:35 |

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

#### Fixture

| Object  | ID    | Engine | Status | Seconds | Error |
|:--------|:------|:-------|:-------|--------:|:------|
| Table 1 | tab_1 | r      | OK     |       1 |       |

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
