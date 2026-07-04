# Default engine when multiple entries share a logical id

Prefers R when available, otherwise Stata.

## Usage

``` r
default_replication_language(entries, paper_meta = NULL)
```

## Arguments

- entries:

  List of replication entries sharing a logical id.

- paper_meta:

  Optional paper-level metadata.

## Value

`"r"` or `"stata"`.
