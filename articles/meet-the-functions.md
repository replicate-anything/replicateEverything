# Meet the functions

**replicateEverything** has two sides. On the **consumer** side you
browse the registry, run a table or figure, and inspect the code that
produced it. On the **producer** side you set up a study repository,
validate it, and register it so others can replicate your work.

This vignette walks through the main exported functions on each side.
For full contributor checklists see the folder and package replication
articles; for Stata-specific behaviour see *Stata replications*.

``` r

library(replicateEverything)
```

## Using replicateEverything

These functions are for **readers and replicators**: you have a DOI (or
a registry handle), you want to see what is available, run it, and read
the scripts.

### Find a paper in the registry

Start with the index.
[`load_index()`](https://replicate-anything.github.io/replicateEverything/reference/load_index.md)
returns registry `index.csv` as a data frame (DOI, title, journal, year,
authors, study repo).

``` r

idx <- load_index()
head(idx[, c("doi", "title", "year")])
```

Example output:

    #>                              doi                                    title year
    #> 1 10.1177/00491241211036161   Bounding Causes of Effects with Randomized... 2022
    #> 2 10.1017/S0003055403000534   Ethnicity, Insurgency, and Civil War        2003

[`search_papers()`](https://replicate-anything.github.io/replicateEverything/reference/search_papers.md)
keyword-searches titles and authors.

``` r

search_papers("insurgency")
```

Example output:

    #>                              doi                                  title
    #> 1 10.1017/S0003055403000534 Ethnicity, Insurgency, and Civil War

For one paper,
[`list_replications()`](https://replicate-anything.github.io/replicateEverything/reference/list_replications.md)
lists every registered table and figure, including engine (`r` /
`stata`) when declared.

``` r

list_replications("10.1177/00491241211036161")
```

Example output (abbreviated):

    #> [[1]]
    #> $id
    #> [1] "fig_1"
    #> $type
    #> [1] "figure"

[`list_replication_groups()`](https://replicate-anything.github.io/replicateEverything/reference/list_replication_groups.md)
returns **one entry per logical group**. When both R and Stata exist for
the same table, the default is R.

``` r

list_replication_groups("10.1257/aer.91.5.1369")
```

### Run a replication

[`run_replication()`](https://replicate-anything.github.io/replicateEverything/reference/run_replication.md)
is the main entry point. Pass a DOI (or registry handle) and a
replication id (`"fig_1"`, `"tab_1"`, and so on). By default you get the
**analysis object** — a `ggplot`, model, or `data.frame`. Pass
`format = TRUE` for display-ready HTML or a formatted plot.

``` r

run_replication("10.1177/00491241211036161", "fig_1")

run_replication("10.1017/S0003055403000534", "tab_1", format = TRUE)

# Stata engine when both exist:
run_replication("10.1257/aer.91.5.1369", "tab_1", language = "stata", format = TRUE)
```

To reproduce an entire paper, set `what = "everything"`. The function
runs every logical replication group (R by default where both engines
exist).

``` r

run_replication("10.1177/00491241211036161", "everything")
```

### View the replication code

[`get_code()`](https://replicate-anything.github.io/replicateEverything/reference/get_code.md)
returns the script behind a replication — R source or merged Stata `.do`
files. Use it when you want to see *how* a result was produced, not only
the output. The bundled Shiny app shows the same text on its Code tab.

``` r

cat(get_code("10.1177/00491241211036161", "fig_1"), sep = "\n")
```

### Browse interactively in Shiny

The Shiny app is the consumer interface in a browser: pick a paper,
switch between tables and figures, run replications, and copy the
[`run_replication()`](https://replicate-anything.github.io/replicateEverything/reference/run_replication.md)
call.

[`run_shiny_app()`](https://replicate-anything.github.io/replicateEverything/reference/run_shiny_app.md)
launches the bundled app from the installed package.

``` r

run_shiny_app()
```

[`save_local_shiny()`](https://replicate-anything.github.io/replicateEverything/reference/save_local_shiny.md)
copies `app.R` and assets into a directory for Shiny Server (it never
overwrites an existing `local.R`).

``` r

save_local_shiny("/srv/shiny/replicate")
```

See
[`vignette("shiny-app", package = "replicateEverything")`](https://replicate-anything.github.io/replicateEverything/articles/shiny-app.md)
for deployment details. A live demo runs at
[shiny2.wzb.eu/ipi/replicate/](https://shiny2.wzb.eu/ipi/replicate/).

## Ready to contribute to replicateEverything?

These functions are for **authors and maintainers**: you have (or are
building) a study repository with `replication.yml`, code, data, and
artifacts, and you want to validate it and register it.

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

### Folder-backed studies

Study repos hold `replication.yml`, `code/`, `data/`, and `artifacts/`.
See
[`vignette("folder-replication-checklist")`](https://replicate-anything.github.io/replicateEverything/articles/folder-replication-checklist.md).

[`build_study_artifacts()`](https://replicate-anything.github.io/replicateEverything/reference/build_study_artifacts.md)
runs every replication and writes PNG/HTML under `artifacts/` plus
`manifest.json`.

``` r

build_study_artifacts(".", install_deps = TRUE)
```

[`check_folder_replication()`](https://replicate-anything.github.io/replicateEverything/reference/check_folder_replication.md)
runs a transparent checklist: layout, yaml, artifacts, tests, and
optional live runs.

``` r

check_folder_replication(".", full_replication = FALSE)
```

[`prepare_folder_paper()`](https://replicate-anything.github.io/replicateEverything/reference/prepare_folder_paper.md)
builds artifacts (optional), runs checks, and writes
`registry/replication.yml` and `registry/index.csv` in the study repo.

``` r

prepare_folder_paper(".", build_artifacts = FALSE, registry_root = "../registry")
```

[`sync_folder_paper()`](https://replicate-anything.github.io/replicateEverything/reference/sync_folder_paper.md)
copies prepared stub files into a local registry checkout.

``` r

options(replicateEverything.registry_root = "../registry")
sync_folder_paper(".")
```

### Package-backed studies

Package-backed studies export
[`run_replication()`](https://replicate-anything.github.io/replicateEverything/reference/run_replication.md),
[`get_code()`](https://replicate-anything.github.io/replicateEverything/reference/get_code.md),
and related helpers from the study package itself. Validate with
[`check_package_replication()`](https://replicate-anything.github.io/replicateEverything/reference/check_package_replication.md).

``` r

check_package_replication("../rep-10.1371_journal.pone.0278337")
check_package_replication("../rep-10.1371_journal.pone.0278337", full_replication = TRUE)
```

See
[`vignette("package-replication-checklist")`](https://replicate-anything.github.io/replicateEverything/articles/package-replication-checklist.md)
for layout and API requirements.

### Registry audit

[`audit_everything()`](https://replicate-anything.github.io/replicateEverything/reference/audit_everything.md)
attempts every table and figure in the registry (all engines), with a
per-object time limit. Use it to check registry health after changes.

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
| **Consumer** |  |
| Browse registry | [`load_index()`](https://replicate-anything.github.io/replicateEverything/reference/load_index.md), [`search_papers()`](https://replicate-anything.github.io/replicateEverything/reference/search_papers.md) |
| What can I replicate? | [`list_replications()`](https://replicate-anything.github.io/replicateEverything/reference/list_replications.md), [`list_replication_groups()`](https://replicate-anything.github.io/replicateEverything/reference/list_replication_groups.md) |
| Run one result | [`run_replication()`](https://replicate-anything.github.io/replicateEverything/reference/run_replication.md) |
| Run whole paper | `run_replication(doi, "everything")` |
| View code | [`get_code()`](https://replicate-anything.github.io/replicateEverything/reference/get_code.md) |
| Interactive browser | [`run_shiny_app()`](https://replicate-anything.github.io/replicateEverything/reference/run_shiny_app.md), [`save_local_shiny()`](https://replicate-anything.github.io/replicateEverything/reference/save_local_shiny.md) |
| **Contributor** |  |
| Build folder artifacts | [`build_study_artifacts()`](https://replicate-anything.github.io/replicateEverything/reference/build_study_artifacts.md) |
| Validate folder study | [`check_folder_replication()`](https://replicate-anything.github.io/replicateEverything/reference/check_folder_replication.md), [`prepare_folder_paper()`](https://replicate-anything.github.io/replicateEverything/reference/prepare_folder_paper.md), [`sync_folder_paper()`](https://replicate-anything.github.io/replicateEverything/reference/sync_folder_paper.md) |
| Validate package study | [`check_package_replication()`](https://replicate-anything.github.io/replicateEverything/reference/check_package_replication.md) |
| Registry health check | [`audit_everything()`](https://replicate-anything.github.io/replicateEverything/reference/audit_everything.md) |
