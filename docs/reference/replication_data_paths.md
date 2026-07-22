# Resolve data paths listed on a replication entry

Prefers `data:`; falls back to `inputs:` when `data:` is omitted so yaml
remains the execute recipe for
[`get_code()`](https://replicate-anything.github.io/replicateEverything/reference/get_code.md)
/ Live Run tips.

## Usage

``` r
replication_data_paths(rep)
```
