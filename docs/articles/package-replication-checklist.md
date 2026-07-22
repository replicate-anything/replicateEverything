# Package replication checklist

## Two models

| Model | Registry | Materials |
|----|----|----|
| **Folder-backed** | `studies/<folder>.yml` stub only | Study repo: `code/`, `data/`, `outputs/` |
| **Package-backed** | `studies/<folder>.yml` stub only | Study R package on GitHub |

This checklist covers **package-backed** studies (recommended for
multi-table papers).

## Package layout

    rep_<doi-slug>/
      DESCRIPTION
      replication.yml              # full metadata + replications list
      inst/replication.yml         # copy for installed package
      R/
        make_figure_*.R             # analysis
        make_table_*.R
        format_*.R                  # display formatting
        build_report.R              # optional: bake Display artifacts
      inst/replication_code/        # synced copies for Code tab / get_code()
      inst/report/artifacts/        # baked Display outputs (build_report())
      data/                         # analysis datasets (LazyData)
      tests/
        testthat/                   # smoke tests
        substantive/                # optional published-value benchmarks

## Required `replication.yml` fields

**Paper metadata**

- `paper.doi` — full DOI URL
- `paper.title`
- `paper.package` — must match `DESCRIPTION` `Package:` field
- `paper.package_repo` or top-level `repo` — GitHub slug (`org/repo`)
- `paper.package_ref` — branch/tag (default `main`)
- `paper.package_folder` — optional; sibling folder name for monorepo
  dev

**Maintainer and collections** (required for registry sync)

- `maintainer.name` and `maintainer.email` — contact shown as
  `[maintainer]` on the Studies tab
- `collections` — tags for bibliography filtering (`APSR`, `PED`,
  `World Bank`, `IPI`, …)
- `languages` — engines used by the package (usually `r`)

``` yaml
maintainer:
  name: Jane Maintainer
  email: maintainer@example.org

collections:
  - IPI

languages:
  - r
```

**Each figure or table**

``` yaml
replications:
  - id: fig_1
    type: figure
    make: make_figure_1
    format: format_figure_1
    data: my_dataset
  - id: tab_1
    type: table
    make: make_table_1
    format: format_table_1
    data: my_dataset
```

Rules:

- `id` — short slug used by Shiny and
  [`replicateEverything::run_replication()`](https://replicate-anything.github.io/replicateEverything/reference/run_replication.md)
- `type` — `figure` or `table`
- `make` — exported function returning analysis output (`ggplot` or
  `data.frame` / `kableExtra`)
- `format` — exported function returning display-ready output (`ggplot`
  or HTML string)
- `data` — package dataset name(s), not file paths

## Study package surface

Export the `make_*` / `format_*` helpers named in yaml (plus shared
helpers and data). Optionally export `build_report()` to bake
`inst/report/artifacts/`.

Do **not** put these in the study package — they live only in
**replicateEverything**:

| Function                   | Purpose                                |
|----------------------------|----------------------------------------|
| `list_replications(doi)`   | Entries from study yaml                |
| `run_replication(doi, id)` | Calls package `make_*` then `format_*` |
| `load_artifact(doi, id)`   | Display HTML or PNG path               |
| `get_code(doi, id)`        | Source for Code tab                    |
| `check_replication(".")`   | Validate package study                 |

## Artifacts (Display tab)

Run once before registering:

``` r

build_report()
# or: replicateEverything::build_study_outputs("rep1371journalpone0278337")
```

This writes:

- `inst/report/artifacts/<id>.png` for each figure
- `inst/report/artifacts/<id>.html` for each table (must contain a
  `<table>`)

The registry stub does **not** store artifacts.

## Prepare and register

### Contributor: validate

``` r

library(replicateEverything)

prepare_study_for_registry(
  "../rep-10.1371-journal.pone.0278337",
  build_artifacts = TRUE
)
check_replication("../rep-10.1371-journal.pone.0278337")
```

### Maintainer: sync into the central registry

``` r

options(replicateEverything.registry_root = "../registry")

sync_study_to_registry(
  "../rep-10.1371-journal.pone.0278337",
  registry_root = "../registry",
  audit = TRUE
)

# After several syncs:
refresh_registry("../registry", audit = TRUE)
```

### Checks only

``` r

check_replication(
  "../rep-10.1371-journal.pone.0278337",
  full_replication = FALSE
)

check_replication(
  "../rep-10.1371-journal.pone.0278337",
  full_replication = TRUE
)
```

## Substantive (published-value) checks

Package-backed studies use the same `tests/substantive/<step_id>.R`
convention as folder-backed repos. Define
`substantive_check_<step_id>(object)` and call it from
`tests/testthat/`. \[check_replication()\] reports coverage;
`full_replication = TRUE` runs defined checks. \[audit_everything()\]
includes them in the registry audit (`substantive = TRUE`, default).

See Fearon & Laitin Table 1 in
[rep-10.1017-S0003055403000534](https://github.com/replicate-anything/rep-10.1017-S0003055403000534)
for a reference substantive check (study-specific benchmarks live in the
study repo).

## Reference implementation

See
[rep-10.1371-journal.pone.0278337](https://github.com/replicate-anything/rep-10.1371-journal.pone.0278337)
(vaccine solidarity paper).
