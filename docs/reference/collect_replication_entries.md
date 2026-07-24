# Collect step entries from parsed metadata

Registry stubs omit `steps:`. For package-backed stubs, load steps from
the installed study package. Otherwise require a non-empty `steps:`
block.

## Usage

``` r
collect_replication_entries(meta)
```

## Arguments

- meta:

  Parsed replication metadata.

## Value

List of non-format step entries.
