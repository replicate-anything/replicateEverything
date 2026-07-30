# Fetch replication metadata for a paper

Deterministic resolution order (first hit wins; no silent URL
scavenges):

1.  Local study root (`ctx$local_root` or configured study folders /
    monorepo)

2.  Configured registry stub (`registry_root/studies/<folder>.yml`)

3.  Remote registry stub URL for the configured registry repo

## Usage

``` r
get_replication_meta(doi, repo = NULL, folder = NULL)
```

## Arguments

- doi:

  Character. DOI of the paper (or study handle / local path accepted by
  [`prepare_doi_for_replication()`](https://replicate-anything.github.io/replicateEverything/reference/prepare_doi_for_replication.md)).

- repo:

  Optional repository slug.

- folder:

  Optional registry folder name from `index.csv`.

## Value

Parsed `replication.yml` contents.

## Details

Results are memoized in-process by DOI / repo / folder so repeated Shiny
and audit lookups do not re-read yaml.
