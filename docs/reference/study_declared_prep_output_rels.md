# Declared `outputs:` paths for a prep/transform step (any extension)

Unlike
[`study_declared_displayable_rels()`](https://replicate-anything.github.io/replicateEverything/reference/study_declared_displayable_rels.md),
this keeps marker sinks such as `.done` so local baked prep products
resolve before type-default `outputs/<id>.html` remote URLs.

## Usage

``` r
study_declared_prep_output_rels(rep)
```

## Arguments

- rep:

  A single replication entry from `replication.yml`.
