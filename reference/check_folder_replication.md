# Validate a folder-backed replication study

Runs a transparent checklist: study layout, `replication.yml`, code and
data paths, baked artifacts under `artifacts/`, optional
`tests/testthat/`, and (optionally) live execution of every table and
figure.

## Usage

``` r
check_folder_replication(
  location = ".",
  full_replication = FALSE,
  registry_root = NULL
)
```

## Arguments

- location:

  Local study path or GitHub address (`org/repo` or URL). Defaults to
  the current working directory when it contains `replication.yml`.

- full_replication:

  If `TRUE`, also run every table and figure via
  [`run_replication()`](https://replicate-anything.github.io/replicateEverything/reference/run_replication.md)
  and require success.

- registry_root:

  Optional path to the registry checkout (sibling of the study repo in a
  monorepo). Defaults to
  `getOption("replicateEverything.registry_root")`.

## Value

A list with `ok` (logical), `checks` (data frame), and `study_path`.

## Examples

``` r
if (FALSE) { # \dontrun{
check_folder_replication(".")
check_folder_replication(".", full_replication = TRUE)
} # }
```
