# Meet the functions

This vignette walks through the **main exported functions** in
**replicateEverything**. For full contributor checklists see the folder
and package replication articles; for Stata-specific behaviour see
*Stata replications*.

## Local development setup

When you work inside a monorepo checkout (sibling `registry/` and
`rep-*` study folders), point the package at local paths before calling
discovery or run functions:

``` r

options(
  replicateEverything.registry_root = "/path/to/replicate_everything/registry",
  replicateEverything.study_folders_root = "/path/to/replicate_everything",
  replicateEverything.use_sibling_packages = TRUE
)
```

Without these options the package reads the public registry from GitHub
and clones study materials on demand.

``` r

library(replicateEverything)
```

## Discovery

### `load_index()`

Returns the registry `index.csv` as a data frame (DOI, title, journal,
year, authors, study repo).

``` r

idx <- load_index()
head(idx[, c("doi", "title", "year")])
```

Example output:

    #>                              doi                                    title year
    #> 1 10.1177/00491241211036161   Bounding Causes of Effects with Randomized... 2022
    #> 2 10.1017/S0003055403000534   Ethnicity, Insurgency, and Civil War        2003

### `search_papers()`

Keyword search over titles (and authors) in the index.

``` r

search_papers("insurgency")
```

Example output:

    #>                              doi                                  title
    #> 1 10.1017/S0003055403000534 Ethnicity, Insurgency, and Civil War

### `list_replications()`

Lists every registered table and figure for one paper, including engine
(`r` / `stata`) when declared.

``` r

list_replications("10.1177/00491241211036161")
```

Example output (abbreviated):

    #> [[1]]
    #> $id
    #> [1] "fig_1"
    #> $type
    #> [1] "figure"

### `list_replication_groups()`

Like
[`list_replications()`](https://replicate-anything.github.io/replicateEverything/reference/list_replications.md),
but returns **one entry per logical group**. When both R and Stata exist
for the same table, the default is R.

``` r

list_replication_groups("10.1257/aer.91.5.1369")
```

### `get_code()`

Returns the replication script for the Code tab in Shiny (R source or
merged Stata `.do` files).

``` r

cat(get_code("10.1177/00491241211036161", "fig_1"), sep = "\n")
```

## Run replications

### `run_replication()`

Runs one table or figure. By default you get the **analysis object**
(e.g. `ggplot`, model, or `data.frame`). Pass `format = TRUE` for
display-ready HTML or a formatted plot.

``` r

run_replication("10.1177/00491241211036161", "fig_1")

run_replication("10.1017/S0003055403000534", "tab_1", format = TRUE)

# Stata engine when both exist:
run_replication("10.1257/aer.91.5.1369", "tab_1", language = "stata", format = TRUE)
```

### `run_replication(..., what = "everything")`

Runs every logical replication group for a paper (R by default where
bilingual).

``` r

run_replication("10.1177/00491241211036161", "everything")
```

## Shiny demo

### `run_shiny_app()`

Launches the bundled Shiny app from the installed package.

``` r

run_shiny_app()
```

### `save_local_shiny()`

Copies `app.R` and assets into a directory for Shiny Server (never
overwrites an existing `local.R`).

``` r

save_local_shiny("/srv/shiny/replicate")
```

See
[`vignette("shiny-app", package = "replicateEverything")`](https://replicate-anything.github.io/replicateEverything/articles/shiny-app.md)
for deployment details.

## Contribute: folder-backed studies

Study repos hold `replication.yml`, `code/`, `data/`, and `artifacts/`.
See
[`vignette("folder-replication-checklist")`](https://replicate-anything.github.io/replicateEverything/articles/folder-replication-checklist.md).

### `build_study_artifacts()`

Runs every replication and writes PNG/HTML under `artifacts/` plus
`manifest.json`.

``` r

build_study_artifacts(".", install_deps = TRUE)
```

### `check_folder_replication()`

Transparent checklist: layout, yaml, artifacts, tests, optional live
runs.

``` r

check_folder_replication(".", full_replication = FALSE)
```

### `prepare_folder_paper()`

Builds artifacts (optional), runs checks, and writes
`registry/replication.yml` and `registry/index.csv` in the study repo.

``` r

prepare_folder_paper(".", build_artifacts = FALSE, registry_root = "../registry")
```

### `sync_folder_paper()`

Copies prepared stub files into a local registry checkout.

``` r

options(replicateEverything.registry_root = "../registry")
sync_folder_paper(".")
```

## Contribute: package-backed studies

Package-backed studies export
[`run_replication()`](https://replicate-anything.github.io/replicateEverything/reference/run_replication.md),
[`get_code()`](https://replicate-anything.github.io/replicateEverything/reference/get_code.md),
and related helpers from the study package. Validate with:

``` r

check_package_replication("../rep-10.1371_journal.pone.0278337")
check_package_replication("../rep-10.1371_journal.pone.0278337", full_replication = TRUE)
```

See
[`vignette("package-replication-checklist")`](https://replicate-anything.github.io/replicateEverything/articles/package-replication-checklist.md)
for layout and
[`check_package_replication()`](https://replicate-anything.github.io/replicateEverything/reference/check_package_replication.md).

## Registry audit

### `audit_everything()`

Attempts every table and figure in the registry (all engines), with a
per-object time limit.

``` r

audit <- audit_everything(patience = 20, dois = "10.1177/00491241211036161")
print(audit)
```

Example summary line:

    #> Studies: 1 | Runs: 4 | OK: 4 | Failed: 0 | Timed out: 0

See
[`vignette("audit")`](https://replicate-anything.github.io/replicateEverything/articles/audit.md)
for the latest snapshot table shipped with the package.

## Quick reference

| Task | Function |
|----|----|
| Browse registry | [`load_index()`](https://replicate-anything.github.io/replicateEverything/reference/load_index.md), [`search_papers()`](https://replicate-anything.github.io/replicateEverything/reference/search_papers.md) |
| What can I replicate? | [`list_replications()`](https://replicate-anything.github.io/replicateEverything/reference/list_replications.md), [`list_replication_groups()`](https://replicate-anything.github.io/replicateEverything/reference/list_replication_groups.md) |
| View code | [`get_code()`](https://replicate-anything.github.io/replicateEverything/reference/get_code.md) |
| Run one result | [`run_replication()`](https://replicate-anything.github.io/replicateEverything/reference/run_replication.md) |
| Run whole paper | `run_replication(doi, "everything")` |
| Interactive browser | [`run_shiny_app()`](https://replicate-anything.github.io/replicateEverything/reference/run_shiny_app.md), [`save_local_shiny()`](https://replicate-anything.github.io/replicateEverything/reference/save_local_shiny.md) |
| Folder study workflow | [`build_study_artifacts()`](https://replicate-anything.github.io/replicateEverything/reference/build_study_artifacts.md), [`check_folder_replication()`](https://replicate-anything.github.io/replicateEverything/reference/check_folder_replication.md), [`prepare_folder_paper()`](https://replicate-anything.github.io/replicateEverything/reference/prepare_folder_paper.md), [`sync_folder_paper()`](https://replicate-anything.github.io/replicateEverything/reference/sync_folder_paper.md) |
| Package study workflow | [`check_package_replication()`](https://replicate-anything.github.io/replicateEverything/reference/check_package_replication.md) |
| Health check | [`audit_everything()`](https://replicate-anything.github.io/replicateEverything/reference/audit_everything.md) |
