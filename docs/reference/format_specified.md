# Check whether a replication entry defines a separate format step

True when the entry has a legacy `format:` field, or when `meta` lists a
`type: format` child (e.g. `tab_1_format`).

## Usage

``` r
format_specified(rep, meta = NULL)
```

## Arguments

- rep:

  A single replication entry from `replication.yml`.

- meta:

  Optional full study metadata (needed to detect format children).
