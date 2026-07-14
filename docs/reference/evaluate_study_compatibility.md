# Evaluate yaml-declared compatibility from parsed metadata

Evaluate yaml-declared compatibility from parsed metadata

## Usage

``` r
evaluate_study_compatibility(meta, ctx, do_materialize = TRUE, engines = NULL)
```

## Arguments

- meta:

  Parsed replication metadata.

- ctx:

  Paper context.

- do_materialize:

  Materialize folder or package materials when `TRUE`.

## Value

List with `kind`, `languages`, `dependencies`, `ready`,
`install_needed`.
