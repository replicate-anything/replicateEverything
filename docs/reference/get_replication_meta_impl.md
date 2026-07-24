# Fetch replication metadata for a paper

Deterministic resolution order (first hit wins; no silent URL
scavenges):

1.  Local study root (`ctx$local_root` or configured study folders /
    monorepo)

2.  Configured registry stub (`registry_root/studies/<folder>.yml`)

3.  Remote registry stub URL for the configured registry repo

## Usage

``` r
get_replication_meta_impl(doi, repo = NULL, folder = NULL)
```

## Arguments

- doi:

  Character. DOI of the paper.

- repo:

  Optional repository slug.

- folder:

  Optional registry folder name from `index.csv`.

## Value

Parsed `replication.yml` contents.
