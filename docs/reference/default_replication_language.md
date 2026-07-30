# Default engine when multiple entries share a logical id

Prefers a runnable multi-language path whose languages include R when
[`group_uses_path_boxes()`](https://replicate-anything.github.io/replicateEverything/reference/group_uses_path_boxes.md)
applies; otherwise prefers an R dispatch engine, then Stata.

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

`"r"`, `"stata"`, `"python"`, or `"mathematica"`.
