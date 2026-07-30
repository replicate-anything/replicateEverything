# Whether a group of sibling entries should use language-path boxes

Path boxes are used when siblings share a `group:` and either:

- any sibling declares multi-language `languages:` (length \>= 2), or

- two or more siblings share the same dispatch `engine:` (so classic
  one-slot-per-engine toggles cannot distinguish them).

Classic bilingual R vs Stata tables (different engines, single-language
each) keep the icon-pill UI.

## Usage

``` r
group_uses_path_boxes(entries)
```

## Arguments

- entries:

  List of sibling step entries (same `group:`).

## Value

Logical.
