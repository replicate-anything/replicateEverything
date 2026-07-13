# Ensure replication package dependencies are available

Ensure replication package dependencies are available

## Usage

``` r
ensure_replication_dependencies(
  replication_meta,
  paper_meta = NULL,
  install_missing = FALSE
)
```

## Arguments

- replication_meta:

  A single replication entry from `replication.yml`.

- paper_meta:

  Optional paper-level metadata list.

- install_missing:

  Logical. Install missing CRAN packages when `TRUE`.

## Value

Invisibly `TRUE`.
