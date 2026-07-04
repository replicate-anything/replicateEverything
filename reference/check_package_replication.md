# Validate a package-backed replication study

Runs a transparent checklist: package layout, `replication.yml`,
exported API, baked artifacts, and (optionally) live execution of every
table and figure.

## Usage

``` r
check_package_replication(location, full_replication = FALSE)
```

## Arguments

- location:

  Local package path or GitHub address (`org/repo` or URL).

- full_replication:

  If `TRUE`, also run every table and figure via
  [`run_replication()`](https://replicate-anything.github.io/replicateEverything/reference/run_replication.md)
  and require success.

## Value

A list with `ok` (logical), `checks` (data frame), and `package_path`.

## Examples

``` r
if (FALSE) { # \dontrun{
check_package_replication("../rep-10.1371_journal.pone.0278337")
check_package_replication("../rep-10.1371_journal.pone.0278337", full_replication = TRUE)
} # }
```
