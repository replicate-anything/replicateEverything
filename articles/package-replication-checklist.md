# Package replication checklist

## Two models

| Model | Registry | Materials |
|----|----|----|
| **Folder-backed** | `papers/<folder>.yml` stub only | Study repo: `code/`, `data/`, `artifacts/` |
| **Package-backed** | `papers/<folder>.yml` stub only | Study R package on GitHub |

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
        replication_api.R           # orchestration API (below)
      inst/replication_code/        # synced copies for Code tab / get_code()
      inst/report/artifacts/        # baked Display outputs (build_report())
      data/                         # analysis datasets (LazyData)

## Required `replication.yml` fields

**Paper metadata**

- `paper.doi` — full DOI URL
- `paper.title`
- `paper.package` — must match `DESCRIPTION` `Package:` field
- `paper.package_repo` or top-level `repo` — GitHub slug (`org/repo`)
- `paper.package_ref` — branch/tag (default `main`)
- `paper.package_folder` — optional; sibling folder name for monorepo
  dev

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
  [`run_replication()`](https://replicate-anything.github.io/replicateEverything/reference/run_replication.md)
- `type` — `figure` or `table`
- `make` — exported function returning analysis output (`ggplot` or
  `data.frame` / `kableExtra`)
- `format` — exported function returning display-ready output (`ggplot`
  or HTML string)
- `data` — package dataset name(s), not file paths

## Required exported API

Your package must export:

| Function | Purpose |
|----|----|
| [`list_replications()`](https://replicate-anything.github.io/replicateEverything/reference/list_replications.md) | Entries from `replication.yml` |
| `replication_meta()` | Parsed yaml |
| `run_replication(id)` | `make_*` then `format_*` |
| `load_artifact(id)` | Display HTML or PNG path |
| `artifact_file(id)` | Path to baked artifact file |
| `get_code(id)` | Source for Code tab |
| `build_report()` | Write `inst/report/artifacts/` |

## Artifacts (Display tab)

Run once before registering:

``` r

build_report()
```

This writes:

- `inst/report/artifacts/<id>.png` for each figure
- `inst/report/artifacts/<id>.html` for each table (must contain a
  `<table>`)

The registry stub does **not** store artifacts.

## Register after checks pass

``` r

library(replicateEverything)

check_package_replication(
  "../rep-10.1371_journal.pone.0278337",
  full_replication = FALSE
)

check_package_replication(
  "../rep-10.1371_journal.pone.0278337",
  full_replication = TRUE
)
```

After checks pass, copy the generated registry stub into the [registry
repository](https://github.com/replicate-anything/registry)
(`papers/<folder>.yml` and a row in `index.csv` with `handle`, `doi`,
`title`, etc.).

## Reference implementation

See
[rep-10.1371_journal.pone.0278337](https://github.com/replicate-anything/rep-10.1371_journal.pone.0278337)
(vaccine solidarity paper).
