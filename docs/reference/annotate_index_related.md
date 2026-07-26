# Fill related_upstream / related_downstream on a registry index

Upstream comes from each study's `paper.related` / `paper.extends`.
Downstream is the reverse map: if B points at A, A lists B.

## Usage

``` r
annotate_index_related(index, metas = NULL)
```

## Arguments

- index:

  Registry index data frame.

- metas:

  Optional list of stub/study metas aligned with `index` rows. When
  `NULL`, only ensures empty related columns exist.

## Value

Index with `related_upstream` and `related_downstream`.
