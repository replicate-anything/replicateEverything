# Report where the replication index was sought (for debugging Shiny)

When a package-backed study lists no tables/figures, this shows which
`replication.yml` URLs were checked. The study index should come from
the package repo (e.g.
`replicate-anything/rep_10.1371_journal.pone.0278337`), not only the
registry stub under `papers/<folder>/`.

## Usage

``` r
replication_index_diagnostics(doi, repo = NULL, folder = NULL)
```

## Arguments

- doi:

  Character DOI.

- repo:

  Optional registry repo slug from `index.csv`.

- folder:

  Optional registry folder name.

## Value

A list with `registry_sources`, `package_sources`, etc.

## Examples

``` r
if (FALSE) { # \dontrun{
replication_index_diagnostics("10.1177/00491241211036161")
} # }
```
