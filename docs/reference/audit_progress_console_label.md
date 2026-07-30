# Console-friendly label for an audit progress category

Maps health-bar ids to short console tags: `ok`, `timeout`,
`substantive_fail`, `missing_engine`, `other`.

## Usage

``` r
audit_progress_console_label(category)
```

## Arguments

- category:

  Character scalar from
  [`audit_progress_category()`](https://replicate-anything.github.io/replicateEverything/reference/audit_progress_category.md).

## Value

Character scalar label.
