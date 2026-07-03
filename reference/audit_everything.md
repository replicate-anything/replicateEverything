# Audit all registry replications

Walks the replication registry and attempts every table and figure in
each available engine (R and Stata where defined). Failures do not stop
the audit; results are returned in a concise data frame. For a full HTML
report, render `audit_everything.qmd` in the [registry
repository](https://github.com/replicate-anything/registry) (see
[`audit_everything_qmd()`](https://replicate-anything.github.io/replicateEverything/reference/audit_everything_qmd.md)).

## Usage

``` r
audit_everything(
  patience = 20,
  index = NULL,
  dois = NULL,
  install_deps = FALSE,
  verbose = TRUE
)
```

## Arguments

- patience:

  Seconds to allow each table or figure before halting that run.
  Defaults to `20`.

- index:

  Registry index data frame; defaults to
  [`load_index()`](https://replicate-anything.github.io/replicateEverything/reference/load_index.md).

- dois:

  Optional character vector of DOIs to audit. When `NULL`, audits every
  row in `index`.

- install_deps:

  Logical. Passed to
  [`render_replication()`](https://replicate-anything.github.io/replicateEverything/reference/render_replication.md).

- verbose:

  Logical. Print progress messages.

## Value

An object of class `audit_everything` with components `results` (data
frame), `summary`, and metadata.

## Examples

``` r
if (FALSE) { # \dontrun{
audit <- audit_everything(patience = 20, dois = "10.1177/00491241211036161")
print(audit)
} # }
```
