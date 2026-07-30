# Registry audit

## What `audit_everything()` does

[`audit_everything()`](https://replicate-anything.github.io/replicateEverything/reference/audit_everything.md)
walks the [replication
registry](https://github.com/replicate-anything/registry) and attempts
**every table and figure** in **each listed engine** (R and Stata where
both exist). It is meant as a health check: some failures are expected
as studies, data, and dependencies change over time.

Key behaviour:

- **`patience`** (default `20` seconds; registry reports often use `60`)
  — each table or figure is halted after this audit cap; the audit
  **continues** with the next object. Timeout rows record
  `timeout_seconds` and an explicit “Timed out after N seconds (audit
  cap)” message.
- **Failures do not stop the run** — results are collected in a data
  frame.
- **Incomplete / unavailable steps are skipped** — yaml
  `incomplete: true` (including `requires_engine:` / `data_unavailable:`
  gaps) is **not** attempted. Rows are recorded with status **Skipped**
  and a reason, and are **not** counted as success or failure. Distinct
  from fail/timeout.
- **Report fields** — study, object id, engine, success, skipped flag,
  elapsed seconds, timeout_seconds (audit cap), timed-out flag, and a
  short error / skip-reason snippet.
- **Substantive checks** (default `substantive = TRUE`) — when a study
  defines `tests/substantive/<step_id>.R`, the audit compares replicated
  estimates to published benchmarks (see Fearon & Laitin `tab_1`).
  Failures appear as `[substantive]` in the printed summary.
- **Related studies** are compiled when the registry index is rebuilt
  ([`build_registry_index()`](https://replicate-anything.github.io/replicateEverything/reference/build_registry_index.md)):
  upstream from `paper.related` / `paper.extends`, downstream by
  reversing those pointers. Use `summary(get_study(doi))` for a quick
  console view; the audit itself does not re-fetch related links per
  run.

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

## Incremental CSV job store (0.7.40)

As of replicateEverything **0.7.40**, registry audits no longer replace
the whole portfolio snapshot on every call. When a registry root is set,
each run **upserts** into a flat CSV and rebuilds derived files from the
**full** store.

### Source of truth: `registry/audit_jobs.csv`

| File | Role |
|----|----|
| `audit_jobs.csv` | **Source of truth** — one row per job, keyed by **doi × object × engine** |
| `audit_summary.json` | Derived portfolio counts + `progress` (Shiny health bar) |
| `audit_latest.rds` | Derived full `audit_everything` object rebuilt from the CSV |

Upsert means: rows for jobs in this run are updated; every other study’s
rows stay put. A one-DOI or one-collection audit therefore **does not
wipe** the Shiny health bar or drop other studies from the derived
summary.

### Full portfolio vs add / refresh a subset

``` r

# Full registry (every index row)
audit <- audit_everything(patience = 20)

# Add or refresh only these DOIs / collections (upsert; others kept)
audit <- audit_everything(patience = 30, dois = "10.1257/aer.91.5.1369")
audit <- audit_everything(patience = 20, collections = "APSR")
```

After either kind of run, disk holds the **full** portfolio:
[`write_registry_audit_record()`](https://replicate-anything.github.io/replicateEverything/reference/write_registry_audit_record.md)
merges this run into `audit_jobs.csv`, then rebuilds JSON and RDS from
every CSV row.

### Seed without live runs

[`seed_registry_audit_jobs()`](https://replicate-anything.github.io/replicateEverything/reference/seed_registry_audit_jobs.md)
fills gaps so the health bar is not empty before the first full audit.
It does **not** execute replications.

- From a prior `audit_latest.rds` (`from_rds = TRUE`)
- From bake timings / local artifact mtimes as provisional ok rows
  (`from_bake = TRUE`)
- Existing `source = "audit"` rows are kept; bake/artifact rows only
  fill gaps (or refresh provisional bake rows)

``` r

seed_registry_audit_jobs(registry_root = "registry")
```

### Rebuild summary from CSV only

[`refresh_registry_audit_summary()`](https://replicate-anything.github.io/replicateEverything/reference/refresh_registry_audit_summary.md)
rewrites `audit_summary.json` and `audit_latest.rds` from the current
CSV without running audits. Use after manual CSV edits or after seeding.

``` r

refresh_registry_audit_summary(registry_root = "registry")
```

A normal
[`audit_everything()`](https://replicate-anything.github.io/replicateEverything/reference/audit_everything.md)
already upserts and refreshes derived files; you do not need a separate
rebuild after a live audit.

### `last_success_at`

Each CSV row carries `last_success_at`:

1.  On a **successful** audit for that job → set to this run’s finish
    time.
2.  Otherwise → keep the prior CSV value when present.
3.  If still empty → fall back to bake timing `recorded_at`, else the
    local artifact’s mtime.

Failed or timed-out passes therefore do not erase the last known success
time.

## How to read audit outputs

| Source | What it represents |
|----|----|
| `audit_jobs.csv` | Full portfolio job history (canonical). Inspect or edit here. |
| `audit_summary.json` | Baked counts + `progress` buckets for the **Shiny health bar**. Prefer this for first paint / lightweight consumers. |
| `audit_latest.rds` | Full `audit_everything` object derived from the **entire** CSV (not just the last call’s subset). |
| In-memory return of [`audit_everything()`](https://replicate-anything.github.io/replicateEverything/reference/audit_everything.md) | **This run only** — if you passed `dois =` / `collections =`, `$results` and `$summary` cover that subset. Do not treat the return value as the portfolio when writing vignette snapshots or reports. |

For vignette or package snapshots, copy the registry RDS (full
portfolio), not `saveRDS(audit)` from a filtered call:

``` r

file.copy(
  file.path(getOption("replicateEverything.registry_root"), "audit_latest.rds"),
  "inst/vignette-data/audit_latest.rds",
  overwrite = TRUE
)
```

## Quarto report

The Quarto document in the registry repo still works the same way.
Render it (or `scripts/run_audit.R`) to run a live audit and write the
HTML report. After write, disk always holds the **full** portfolio CSV +
derived JSON/RDS, even when params restrict `dois` / `collections`.

``` r

# Quarto report lives in the registry repo (sibling registry/ in a monorepo)
quarto::quarto_render(audit_everything_qmd(), execute_params = list(patience = 20))
quarto::quarto_render(
  audit_everything_qmd(),
  execute_params = list(patience = 20, collections = "APSR")
)

# Or: live R audit, then HTML from saved RDS (no second live run)
# Rscript scripts/run_audit.R
# quarto render audit_everything.qmd -P refresh:false
```

## Console progress tags (0.7.39)

With `verbose = TRUE` (default), each finished job prints a short status
tag aligned with the health-bar buckets:

| Tag | Meaning |
|----|----|
| `ok` | Runnable job succeeded (including substantive checks when defined) |
| `timeout` | Hit the `patience` audit cap |
| `substantive_fail` | Replication ran but published-value check failed |
| `missing_engine` | Engine / dependency gap (e.g. Stata not found) |
| `other` | Other failure or skip bucket |

Example line: `- Table 1 (table, r) [ok]`.

## Commit checklist (registry repo)

After an audit (or seed + refresh) that you want on GitHub / Shiny:

1.  `audit_jobs.csv` — always commit with the derived files
2.  `audit_summary.json` — health bar
3.  `audit_latest.rds` — full snapshot
4.  `audit_everything.html` (+ `audit_everything_files/` if present) —
    only if you are publishing the Quarto report

Push the **registry** repository so remote consumers see the new
summary. Optional: copy `audit_latest.rds` into
`replicateEverything/inst/vignette-data/` and rebuild pkgdown so this
article’s tables stay current.

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
| Patience (seconds per object) |               60 |
| Studies audited               |               14 |
| Replication runs              |               96 |
| Successful                    |               85 |
| Failed                        |               10 |
| Timed out                     |                7 |
| Skipped                       |                1 |
| Audit started                 | 2026-07-29 10:53 |
| Audit finished                | 2026-07-29 11:10 |

``` r

attempted <- sm$runs - (sm$skipped %||% 0L)
if (attempted > 0) {
  pct <- round(100 * sm$success / attempted, 1)
  cat(sprintf("**Pass rate (excluding skipped):** %s%%\n", pct))
}
#> **Pass rate (excluding skipped):** 89.5%
```

### Results by study

``` r

if (!"skipped" %in% names(results)) {
  results$skipped <- FALSE
}
studies <- unique(results$title)
for (study in studies) {
  cat("\n\n#### ", study, "\n\n", sep = "")
  sub <- results[results$title == study, , drop = FALSE]
  sub$status <- replicateEverything::audit_result_status(
    sub$success, sub$timed_out, sub$skipped
  )
  sub$seconds <- ifelse(is.na(sub$seconds), NA, round(sub$seconds, 2))
  show <- sub[, c(
    "object_label", "object", "engine", "status", "seconds", "error_snippet"
  )]
  names(show) <- c("Object", "ID", "Engine", "Status", "Seconds", "Error")
  print(knitr::kable(show, row.names = FALSE))
}
```

#### A Welfare Analysis of Policies Impacting Climate Change

| Object | ID | Engine | Status | Seconds | Error |
|:---|:---|:---|:---|---:|:---|
| Figure 1 | fig_1 | stata | Timed out | 60.11 | Timed out after 60 seconds (audit cap; timeout_seconds: 60) \| ! Native call to `processx_wait` failed \| Caused by error in `chain_clean_call(...)`: \| ! reached elapsed time limit |
| Figure 2 | fig_2 | stata | Timed out | 60.12 | Timed out after 60 seconds (audit cap; timeout_seconds: 60) \| ! Native call to `processx_wait` failed \| Caused by error in `chain_clean_call(...)`: \| ! reached elapsed time limit |
| Figure 3 | fig_3 | stata | Timed out | 60.11 | Timed out after 60 seconds (audit cap; timeout_seconds: 60) \| ! Native call to `processx_wait` failed \| Caused by error in `chain_clean_call(...)`: \| ! reached elapsed time limit |
| Figure 5 | fig_5 | stata | Timed out | 60.21 | Timed out after 60 seconds (audit cap; timeout_seconds: 60) \| ! Native call to `processx_wait` failed \| Caused by error in `chain_clean_call(...)`: \| ! reached elapsed time limit |
| Figure 6 | fig_6 | stata | Timed out | 60.11 | Timed out after 60 seconds (audit cap; timeout_seconds: 60) \| ! Native call to `processx_wait` failed \| Caused by error in `chain_clean_call(...)`: \| ! reached elapsed time limit |
| Figure 4 | fig_4 | stata | Failed | 3.96 | Expected Stata output not found. \| Expected file: C:/WZB Dropbox/Macartan Humphreys/5_github/replicate_everything/rep-10.1257-aer.20250166/outputs/mvpf_subsidies_Fig4_scc193.png \| Stata ran: yes \| Executable: C:/Program Files/Stata17/StataM… |
| Figure 7 | fig_7 | stata | Failed | 3.56 | Expected Stata output not found. \| Expected file: C:/WZB Dropbox/Macartan Humphreys/5_github/replicate_everything/rep-10.1257-aer.20250166/outputs/mvpf_taxes_Fig7_scc193_with_CIs.png \| Stata ran: yes \| Executable: C:/Program Files/Stata17/S… |
| Figure 8 | fig_8 | stata | Failed | 3.58 | Expected Stata output not found. \| Expected file: C:/WZB Dropbox/Macartan Humphreys/5_github/replicate_everything/rep-10.1257-aer.20250166/outputs/mvpf_intl_Fig8_scc193_with_CIs.png \| Stata ran: yes \| Executable: C:/Program Files/Stata17/St… |
| Table 1 | tab_1 | stata | Timed out | 60.22 | Timed out after 60 seconds (audit cap; timeout_seconds: 60) \| ! Native call to `processx_wait` failed \| Caused by error in `chain_clean_call(...)`: \| ! reached elapsed time limit |
| Table 2 | tab_2 | stata | Timed out | 60.30 | Timed out after 60 seconds (audit cap; timeout_seconds: 60) \| ! Native call to `processx_wait` failed \| Caused by error in `chain_clean_call(...)`: \| ! reached elapsed time limit |

#### Beyond Belief Change: The Persuasive Returns of Targeting Attitude-Relevant Beliefs

| Object  | ID    | Engine | Status | Seconds | Error |
|:--------|:------|:-------|:-------|--------:|:------|
| Table 1 | tab_1 | r      | OK     |   11.96 |       |
| Table 3 | tab_3 | r      | OK     |    3.99 |       |

#### Bounding Causes of Effects With Mediators

| Object   | ID    | Engine | Status | Seconds | Error |
|:---------|:------|:-------|:-------|--------:|:------|
| Figure 1 | fig_1 | r      | OK     |    0.22 |       |

#### COVID-19 vaccine acceptance and hesitancy in low- and middle-income countries

| Object               | ID        | Engine | Status | Seconds | Error |
|:---------------------|:----------|:-------|:-------|--------:|:------|
| Table 2              | tab_2     | r      | OK     |    0.33 |       |
| Fig. 1               | fig_1     | r      | OK     |    5.05 |       |
| Fig. 2               | fig_2     | r      | OK     |    3.81 |       |
| Fig. 3               | fig_3     | r      | OK     |    7.83 |       |
| Extended Data Fig. 1 | ext_fig_1 | r      | OK     |    8.52 |       |
| Extended Data Fig. 2 | ext_fig_2 | r      | OK     |   41.73 |       |

#### Ethnicity, Insurgency, and Civil War

| Object  | ID          | Engine | Status | Seconds | Error |
|:--------|:------------|:-------|:-------|--------:|:------|
| Table 1 | tab_1       | r      | OK     |    0.53 |       |
| Table 1 | tab_1_stata | stata  | OK     |    5.40 |       |

#### Ideological Alignment and Evidence-Based Policy Adoption

| Object | ID | Engine | Status | Seconds | Error |
|:---|:---|:---|:---|---:|:---|
| Table H.1 | tab_h1 | stata | Skipped | NA | Table H.1 not available because of proprietary data |
| Table 1 | tab_1 | stata | OK | 9.42 |  |
| Table 2 | tab_2 | stata | OK | 5.52 |  |
| Table 3 | tab_3 | stata | OK | 5.25 |  |
| Table 4 | tab_4 | stata | OK | 5.27 |  |
| Figure 2 | fig_2 | stata | OK | 19.39 |  |

#### Migration, Families, and Counterfactual Families

| Object     | ID              | Engine | Status | Seconds | Error |
|:-----------|:----------------|:-------|:-------|--------:|:------|
| Table 1    | tab_1           | stata  | OK     |   21.06 |       |
| Table 2    | tab_2           | stata  | OK     |   13.47 |       |
| Table 3    | tab_3           | stata  | OK     |   11.32 |       |
| Table A.1  | tab_A_1         | stata  | OK     |   22.15 |       |
| Table A.2  | tab_A_2         | stata  | OK     |   19.72 |       |
| Table A.3  | tab_A_3         | stata  | OK     |   19.94 |       |
| Table A.4  | tab_A_4         | stata  | OK     |   20.40 |       |
| Table A.5  | tab_A_5         | stata  | OK     |   19.40 |       |
| Figure 1   | fig_1           | stata  | OK     |    5.42 |       |
| Figure 1   | fig_1_panel_b   | stata  | OK     |    5.96 |       |
| Figure A.2 | fig_A_2         | stata  | OK     |    5.76 |       |
| Figure 2   | fig_2_panel_a   | stata  | OK     |    6.36 |       |
| Figure 2   | fig_2_panel_b   | stata  | OK     |    6.47 |       |
| Figure A.1 | fig_A_1_panel_a | stata  | OK     |    7.22 |       |
| Figure A.1 | fig_A_1_panel_b | stata  | OK     |    7.45 |       |
| Figure 3   | fig_3_panel_a   | stata  | OK     |    4.88 |       |
| Figure 3   | fig_3_panel_b   | stata  | OK     |    5.02 |       |
| Figure 4   | fig_4_panel_a   | stata  | OK     |    4.94 |       |
| Figure 4   | fig_4_panel_b   | stata  | OK     |    5.11 |       |

#### Minimal folder-backed template study

| Object       | ID    | Engine | Status | Seconds | Error |
|:-------------|:------|:-------|:-------|--------:|:------|
| Simple table | tab_1 | r      | OK     |     0.1 |       |

#### Minimal reanalysis template repo

| Object  | ID    | Engine | Status | Seconds | Error |
|:--------|:------|:-------|:-------|--------:|:------|
| Table 1 | tab_1 | r      | OK     |    0.22 |       |

#### Portraits of Power: Facial Appearance and the Tacit Domain of Political Selection in China

| Object   | ID    | Engine | Status | Seconds | Error |
|:---------|:------|:-------|:-------|--------:|:------|
| Table 1  | tab_1 | stata  | OK     |    8.43 |       |
| Table 2  | tab_2 | stata  | OK     |    7.28 |       |
| Table 3  | tab_3 | stata  | OK     |    7.12 |       |
| Figure 2 | fig_2 | python | OK     |   30.74 |       |
| Figure 4 | fig_4 | r      | OK     |    4.45 |       |
| Figure 5 | fig_5 | r      | OK     |    3.51 |       |

#### Preventing Rebel Resurgence after Civil War: A Field Experiment in Security and Justice Provision in Rural Colombia

| Object  | ID    | Engine | Status | Seconds | Error |
|:--------|:------|:-------|:-------|--------:|:------|
| Table 1 | tab_1 | stata  | OK     |    4.97 |       |

#### Public support for global vaccine sharing in the COVID-19 pandemic: Evidence from Germany

| Object   | ID    | Engine | Status | Seconds | Error |
|:---------|:------|:-------|:-------|--------:|:------|
| Figure 1 | fig_1 | r      | OK     |    4.50 |       |
| Figure 2 | fig_2 | r      | OK     |    8.41 |       |
| Figure 3 | fig_3 | r      | OK     |    1.22 |       |
| Figure 4 | fig_4 | r      | OK     |    1.31 |       |
| Figure 5 | fig_5 | r      | OK     |    1.88 |       |
| Figure 6 | fig_6 | r      | OK     |    2.61 |       |
| Figure 7 | fig_7 | r      | OK     |    4.47 |       |
| Figure 8 | fig_8 | r      | OK     |    4.67 |       |
| Table 2  | tab_2 | r      | OK     |    4.00 |       |
| Table 1  | tab_1 | r      | OK     |    3.70 |       |

#### Sovereignty, Substance, and Public Support for European Courts’ Human Rights Rulings

| Object | ID | Engine | Status | Seconds | Error |
|:---|:---|:---|:---|---:|:---|
| Table 3a — Summary statistics, Deportation vignette | tab_3a | r | OK | 1.42 |  |
| Table 3b — Summary statistics, Quran burning and Eviction vignettes | tab_3b | r | OK | 1.20 |  |
| Figure 1 — Treatment summaries | fig_1 | r | OK | 9.62 |  |
| Figure 2a — Effect of EC disagreeing with domestic court (H1) | fig_2a | r | OK | 3.00 |  |
| Figure 2b — Effect of EC disagreeing with domestic court, by country | fig_2b | r | OK | 3.93 |  |
| Figure 2c — Effect of EC disagreeing with domestic court, by country (averaged over vignettes) | fig_2c | r | OK | 2.64 |  |
| Figure 3a — H1 heterogeneity by domestic rule-of-law satisfaction | fig_3a | r | OK | 6.47 |  |
| Figure 3b — H1 heterogeneity by domestic rule-of-law satisfaction (UK/Denmark only) | fig_3b | r | OK | 4.48 |  |
| Figure 3c — Difference in EC-disagreement effect by rule-of-law satisfaction (UK/Denmark only) | fig_3c | r | OK | 3.03 |  |
| Figure 4a — Effect of case outcome (H2) | fig_4a | r | OK | 3.31 |  |
| Figure 4b — Difference between case outcome effect and sovereignty effect | fig_4b | r | OK | 2.73 |  |
| Figure 5a — H2 interactions by sympathy toward applicant | fig_5a | r | OK | 6.97 |  |
| Figure 5b — Difference in outcome effect between sympathetic and unsympathetic respondents | fig_5b | r | OK | 4.44 |  |
| Figure 6 — Heterogeneity by nationalism | fig_6 | r | OK | 11.63 |  |
| Figure 7 — Heterogeneity by authoritarianism | fig_7 | r | OK | 14.08 |  |

#### The Colonial Origins of Comparative Development

| Object  | ID          | Engine | Status | Seconds | Error |
|:--------|:------------|:-------|:-------|--------:|:------|
| Table 1 | tab_1       | r      | OK     |    0.77 |       |
| Table 1 | tab_1_stata | stata  | OK     |    1.85 |       |
| Table 2 | tab_2       | r      | OK     |    0.16 |       |
| Table 2 | tab_2_stata | stata  | OK     |    2.60 |       |
| Table 3 | tab_3       | r      | OK     |    0.15 |       |
| Table 3 | tab_3_stata | stata  | OK     |    2.86 |       |
| Table 4 | tab_4       | r      | OK     |    0.23 |       |
| Table 4 | tab_4_stata | stata  | OK     |    2.98 |       |
| Table 5 | tab_5       | r      | OK     |    0.23 |       |
| Table 5 | tab_5_stata | stata  | OK     |    3.12 |       |
| Table 6 | tab_6       | r      | OK     |    0.19 |       |
| Table 6 | tab_6_stata | stata  | OK     |    3.60 |       |
| Table 7 | tab_7       | r      | OK     |    0.20 |       |
| Table 7 | tab_7_stata | stata  | OK     |    3.53 |       |
| Table 8 | tab_8       | r      | OK     |    0.31 |       |
| Table 8 | tab_8_stata | stata  | OK     |    3.96 |       |

### Failures (concise)

``` r

if (!"skipped" %in% names(results)) {
  results$skipped <- FALSE
}
fails <- results[results$success %in% FALSE & !results$skipped %in% TRUE, , drop = FALSE]
if (nrow(fails) == 0) {
  cat("All recorded runnable jobs succeeded (or were skipped).\n")
} else {
  fails$seconds <- ifelse(is.na(fails$seconds), NA, round(fails$seconds, 2))
  fails$status <- replicateEverything::audit_result_status(
    fails$success, fails$timed_out, fails$skipped
  )
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
| A Welfare Analysis of Policies Impacting Climate Change | Figure 1 | fig_1 | stata | Timed out | 60.11 | Timed out after 60 seconds (audit cap; timeout_seconds: 60) \| ! Native call to `processx_wait` failed \| Caused by error in `chain_clean_call(...)`: \| ! reached elapsed time limit |
| A Welfare Analysis of Policies Impacting Climate Change | Figure 2 | fig_2 | stata | Timed out | 60.12 | Timed out after 60 seconds (audit cap; timeout_seconds: 60) \| ! Native call to `processx_wait` failed \| Caused by error in `chain_clean_call(...)`: \| ! reached elapsed time limit |
| A Welfare Analysis of Policies Impacting Climate Change | Figure 3 | fig_3 | stata | Timed out | 60.11 | Timed out after 60 seconds (audit cap; timeout_seconds: 60) \| ! Native call to `processx_wait` failed \| Caused by error in `chain_clean_call(...)`: \| ! reached elapsed time limit |
| A Welfare Analysis of Policies Impacting Climate Change | Figure 5 | fig_5 | stata | Timed out | 60.21 | Timed out after 60 seconds (audit cap; timeout_seconds: 60) \| ! Native call to `processx_wait` failed \| Caused by error in `chain_clean_call(...)`: \| ! reached elapsed time limit |
| A Welfare Analysis of Policies Impacting Climate Change | Figure 6 | fig_6 | stata | Timed out | 60.11 | Timed out after 60 seconds (audit cap; timeout_seconds: 60) \| ! Native call to `processx_wait` failed \| Caused by error in `chain_clean_call(...)`: \| ! reached elapsed time limit |
| A Welfare Analysis of Policies Impacting Climate Change | Figure 4 | fig_4 | stata | Failed | 3.96 | Expected Stata output not found. \| Expected file: C:/WZB Dropbox/Macartan Humphreys/5_github/replicate_everything/rep-10.1257-aer.20250166/outputs/mvpf_subsidies_Fig4_scc193.png \| Stata ran: yes \| Executable: C:/Program Files/Stata17/StataM… |
| A Welfare Analysis of Policies Impacting Climate Change | Figure 7 | fig_7 | stata | Failed | 3.56 | Expected Stata output not found. \| Expected file: C:/WZB Dropbox/Macartan Humphreys/5_github/replicate_everything/rep-10.1257-aer.20250166/outputs/mvpf_taxes_Fig7_scc193_with_CIs.png \| Stata ran: yes \| Executable: C:/Program Files/Stata17/S… |
| A Welfare Analysis of Policies Impacting Climate Change | Figure 8 | fig_8 | stata | Failed | 3.58 | Expected Stata output not found. \| Expected file: C:/WZB Dropbox/Macartan Humphreys/5_github/replicate_everything/rep-10.1257-aer.20250166/outputs/mvpf_intl_Fig8_scc193_with_CIs.png \| Stata ran: yes \| Executable: C:/Program Files/Stata17/St… |
| A Welfare Analysis of Policies Impacting Climate Change | Table 1 | tab_1 | stata | Timed out | 60.22 | Timed out after 60 seconds (audit cap; timeout_seconds: 60) \| ! Native call to `processx_wait` failed \| Caused by error in `chain_clean_call(...)`: \| ! reached elapsed time limit |
| A Welfare Analysis of Policies Impacting Climate Change | Table 2 | tab_2 | stata | Timed out | 60.30 | Timed out after 60 seconds (audit cap; timeout_seconds: 60) \| ! Native call to `processx_wait` failed \| Caused by error in `chain_clean_call(...)`: \| ! reached elapsed time limit |

### Skipped (incomplete / unavailable)

``` r

if (!"skipped" %in% names(results)) {
  results$skipped <- FALSE
}
skips <- results[results$skipped %in% TRUE, , drop = FALSE]
if (nrow(skips) == 0) {
  cat("No steps were skipped as incomplete / unavailable.\n")
} else {
  skips$status <- "Skipped"
  show <- skips[, c(
    "title", "object_label", "object", "engine", "status", "error_snippet"
  )]
  names(show) <- c(
    "Study", "Object", "ID", "Engine", "Status", "Reason"
  )
  knitr::kable(show, row.names = FALSE)
}
```

| Study | Object | ID | Engine | Status | Reason |
|:---|:---|:---|:---|:---|:---|
| Ideological Alignment and Evidence-Based Policy Adoption | Table H.1 | tab_h1 | stata | Skipped | Table H.1 not available because of proprietary data |

## Interpreting failures

Common reasons a run fails or times out:

- **Missing study package or folder** — install the study repo locally
  or set `replicateEverything.study_folders_root` to your monorepo root.
- **Stata not installed** — Stata-backed entries fail until Stata is
  found; see the *Stata replications* vignette.
- **Network / data** — folder-backed studies may need data files
  downloaded on first run.
- **Patience / audit cap** — slow jobs may time out under the configured
  `patience` (e.g. 60s in the registry report). That is recorded as
  **Timed out** with `timeout_seconds` and an explicit audit-cap
  message, not as a silent failure.
- **Skipped steps** — Mathematica / proprietary / incomplete yaml steps
  appear as **Skipped**, not Failed or Timed out.

Re-run locally and refresh the package vignette snapshot:

``` r

Sys.setenv(REPLICATE_AUDIT_LIVE = "true")
options(
  replicateEverything.registry_root = "/path/to/replicate_everything/registry",
  replicateEverything.study_folders_root = "/path/to/replicate_everything",
  replicateEverything.use_sibling_packages = TRUE
)
audit <- audit_everything(patience = 20)
# Prefer the registry portfolio RDS (derived from audit_jobs.csv), not a
# filtered in-memory return value:
file.copy(
  file.path(getOption("replicateEverything.registry_root"), "audit_latest.rds"),
  "inst/vignette-data/audit_latest.rds",
  overwrite = TRUE
)

# Full HTML report: quarto render audit_everything.qmd (in the registry repo)
```

After adding or updating registry stubs, maintainers typically run
\[refresh_registry()\] so `index.csv` and the audit stay in sync:

``` r

refresh_registry("../registry", audit = TRUE, patience = 20)
```
