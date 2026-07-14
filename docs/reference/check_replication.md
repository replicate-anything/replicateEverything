# Validate a folder-backed replication study

Runs a transparent checklist: study layout, `replication.yml`, code and
data paths, baked display outputs, optional `tests/testthat/`,
substantive (published-value) checks under `tests/substantive/`, and
(optionally) live execution of every table and figure.

## Usage

``` r
check_folder_replication(
  location = ".",
  full_replication = FALSE,
  registry_root = NULL
)

check_package_replication(location, full_replication = FALSE)

check_replication(
  location = ".",
  full_replication = FALSE,
  registry_root = NULL
)
```

## Arguments

- location:

  Local study path, GitHub address, or installed package path. Defaults
  to the current working directory when it contains `replication.yml` or
  `DESCRIPTION`.

- full_replication:

  If `TRUE`, also run every table and figure via
  [`run_replication()`](https://replicate-anything.github.io/replicateEverything/reference/run_replication.md)
  and require success.

- registry_root:

  Optional path to the registry checkout (folder studies in a monorepo).
  Defaults to `getOption("replicateEverything.registry_root")`.

## Value

A list with `ok` (logical), `checks` (data frame), and `study_path`.

A list with `ok` (logical), `checks` (data frame), and `package_path`.

A list with `ok` (logical), `checks` (data frame), and `study_path` or
`package_path`.

## Functions

- `check_folder_replication()`: Folder-backed implementation.

  Runs a transparent checklist: study layout, `replication.yml`, code
  and data paths, baked display outputs under `outputs/`, optional
  `tests/testthat/`, substantive (published-value) checks under
  `tests/substantive/`, and (optionally) live execution of every table
  and figure.

- `check_package_replication()`: Package-backed implementation.

  Runs a transparent checklist: package layout, `replication.yml`,
  exported API, baked artifacts, substantive (published-value) checks
  under `tests/substantive/`, and (optionally) live execution of every
  table and figure.

## Examples

``` r
if (FALSE) { # \dontrun{
check_replication(".")
check_replication(".", full_replication = TRUE)
check_replication("../rep-10.1371_journal.pone.0278337")
} # }
```
