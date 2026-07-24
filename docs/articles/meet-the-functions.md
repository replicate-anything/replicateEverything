# Meet the functions

**replicateEverything** has two sides. On the **consumer** side you
browse the registry, run a table or figure, and inspect the code that
produced it. On the **producer** side you set up a study repository,
validate it, and register it so others can replicate your work.

Start with the overview:
[`vignette("why-replicateEverything", package = "replicateEverything")`](https://replicate-anything.github.io/replicateEverything/articles/why-replicateEverything.md).

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

`list_replications(..., grouped = TRUE)` returns **one entry per logical
group**. When both R and Stata exist for the same table, the default is
R.

``` r

list_replications("10.1257/aer.91.5.1369", grouped = TRUE)
list_replications("10.1257/aer.91.5.1369", grouped = TRUE, language = "stata")
```

Pipeline steps (transforms) are listed separately:

``` r

list_replications("10.1017/s0003055426101749", include = "pipeline")
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

These functions split **contributors** (authors preparing a study repo)
from **maintainers** (registry operators syncing stubs and auditing the
fleet).

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

### Maintainer setup (dependencies)

Live Run and Shiny **probe** dependencies only. Maintainers install once
with:

``` r

check_study_compatibility("10.1017/S0003055426101749")
install_dependencies("10.1017/S0003055426101749")  # folder or package DOI
install_dependencies("everywhere")                  # every study in the registry
```

Build display outputs with \[build_study_outputs()\]. Full details:
[`vignette("maintainer-setup")`](https://replicate-anything.github.io/replicateEverything/articles/maintainer-setup.md).

### Folder-backed studies (contributor)

Study repos hold `replication.yml`, `code/`, `data/`, and `outputs/`.
See
[`vignette("folder-replication-checklist")`](https://replicate-anything.github.io/replicateEverything/articles/folder-replication-checklist.md).

\[build_study_outputs()\] runs every replication and writes display
files under `outputs/` plus `outputs/manifest.json`.

``` r

build_study_outputs(".", install_deps = TRUE)
```

\[check_replication()\] runs a transparent checklist: layout, yaml,
outputs, tests, and optional live runs.

``` r

check_replication(".", full_replication = FALSE)
```

[`check_and_bake_study()`](https://replicate-anything.github.io/replicateEverything/reference/check_and_bake_study.md)
runs the same checklist and (optionally) bakes `outputs/` first — the
single contributor entrypoint. It writes nothing into the study repo or
a registry; it only validates.

``` r

check_and_bake_study(".", build_artifacts = TRUE)
```

### Registry sync (maintainer)

There is **no study-local registry handoff**. A maintainer with a local
registry checkout writes the stub directly from the study’s
`replication.yml`:

``` r

options(replicateEverything.registry_root = "../registry")
sync_study_to_registry("../rep-10.1177-00491241211036161")
refresh_registry("../registry", audit = TRUE)
```

[`register_study()`](https://replicate-anything.github.io/replicateEverything/reference/register_study.md)
runs
[`check_and_bake_study()`](https://replicate-anything.github.io/replicateEverything/reference/check_and_bake_study.md)
then
[`sync_study_to_registry()`](https://replicate-anything.github.io/replicateEverything/reference/sync_study_to_registry.md)
in one call:

``` r

register_study("../rep-10.1177-00491241211036161", registry_root = "../registry")
```

See
[`vignette("maintainer-setup")`](https://replicate-anything.github.io/replicateEverything/articles/maintainer-setup.md)
for the full maintainer workflow.

### Check precomputed outputs

\[validate_outputs()\] checks that declared table and figure files exist
on disk (for Shiny **Display**). It does not run live replications.

``` r

validate_outputs(location = "../rep-10.1177-00491241211036161")
validate_outputs("10.1177/00491241211036161", what = "everything")
options(replicateEverything.registry_root = "../registry")
validate_outputs(doi = "everywhere", what = "everything")
```

### Package-backed studies (contributor)

Package-backed studies must **not** define or ship
[`run_replication()`](https://replicate-anything.github.io/replicateEverything/reference/run_replication.md),
[`list_replications()`](https://replicate-anything.github.io/replicateEverything/reference/list_replications.md),
[`load_artifact()`](https://replicate-anything.github.io/replicateEverything/reference/load_artifact.md),
or
[`get_code()`](https://replicate-anything.github.io/replicateEverything/reference/get_code.md)
— those verbs live only in **replicateEverything**. Study packages
export pure `make_*()` / `format_*()` analysis helpers named in yaml.
Validate with \[check_replication()\] (or \[check_and_bake_study()\]),
then a maintainer syncs the stub with
[`sync_study_to_registry()`](https://replicate-anything.github.io/replicateEverything/reference/sync_study_to_registry.md)
— no `inst/registry/` handoff files.

``` r

check_replication("../rep-10.1371-journal.pone.0278337")
check_replication("../rep-10.1371-journal.pone.0278337", full_replication = TRUE)
```

See
[`vignette("package-replication-checklist")`](https://replicate-anything.github.io/replicateEverything/articles/package-replication-checklist.md)
for layout and API requirements.

### Registry audit

[`audit_everything()`](https://replicate-anything.github.io/replicateEverything/reference/audit_everything.md)
attempts every table and figure in the registry (all engines), with a
per-object time limit. Use it to check registry health after changes.
Restrict with `dois =` or `collections =` (e.g. `"APSR"`).

``` r

audit <- audit_everything(patience = 20, dois = "10.1177/00491241211036161")
# audit <- audit_everything(patience = 20, collections = "APSR")
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
| What can I replicate? | [`list_replications()`](https://replicate-anything.github.io/replicateEverything/reference/list_replications.md), `list_replications(..., grouped = TRUE)` |
| Run one result | [`run_replication()`](https://replicate-anything.github.io/replicateEverything/reference/run_replication.md) |
| Run whole paper | `run_replication(doi, "everything")` |
| View code | [`get_code()`](https://replicate-anything.github.io/replicateEverything/reference/get_code.md) |
| Interactive browser | [`run_shiny_app()`](https://replicate-anything.github.io/replicateEverything/reference/run_shiny_app.md), [`save_local_shiny()`](https://replicate-anything.github.io/replicateEverything/reference/save_local_shiny.md) |
| **Contributor** |  |
| Check machine vs study yaml | [`check_study_compatibility()`](https://replicate-anything.github.io/replicateEverything/reference/check_study_compatibility.md) |
| Install deps (one study) | [`install_dependencies()`](https://replicate-anything.github.io/replicateEverything/reference/install_dependencies.md) |
| Install deps (all studies) | `install_dependencies("everywhere")` |
| Build study outputs | [`build_study_outputs()`](https://replicate-anything.github.io/replicateEverything/reference/build_study_outputs.md) |
| Validate (+ optional bake) | [`check_and_bake_study()`](https://replicate-anything.github.io/replicateEverything/reference/check_and_bake_study.md) |
| Validate study (checklist only) | [`check_replication()`](https://replicate-anything.github.io/replicateEverything/reference/check_replication.md) |
| Check precomputed outputs | [`validate_outputs()`](https://replicate-anything.github.io/replicateEverything/reference/validate_outputs.md) |
| **Maintainer** |  |
| Validate then sync in one call | [`register_study()`](https://replicate-anything.github.io/replicateEverything/reference/register_study.md) |
| Sync study into registry | [`sync_study_to_registry()`](https://replicate-anything.github.io/replicateEverything/reference/sync_study_to_registry.md) |
| Rebuild index + audit all | [`refresh_registry()`](https://replicate-anything.github.io/replicateEverything/reference/refresh_registry.md) |
| Rebuild index only | [`build_registry_index()`](https://replicate-anything.github.io/replicateEverything/reference/build_registry_index.md) |
| Registry output check | `validate_outputs(doi = "everywhere", what = "everything")` |
| Registry health check | [`audit_everything()`](https://replicate-anything.github.io/replicateEverything/reference/audit_everything.md) |
