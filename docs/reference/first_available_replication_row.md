# First replication row suitable for Shiny default selection

Walks `replications_df` in order and returns the first row where
[`shiny_step_default_available()`](https://replicate-anything.github.io/replicateEverything/reference/shiny_step_default_available.md)
is true. Falls back to row 1 when none qualify (or the frame is empty /
NULL).

## Usage

``` r
first_available_replication_row(
  replications_df,
  doi,
  folder = NULL,
  repo = NULL,
  language_for_row = NULL,
  resolve_id = NULL
)
```

## Arguments

- replications_df:

  Data frame from Shiny `replications_to_df()`.

- doi:

  Study DOI / key (for artifact lookup).

- folder:

  Optional local registry / study folder.

- repo:

  Optional study repo slug.

- language_for_row:

  Optional function `function(row) -> engine`.

- resolve_id:

  Optional function `function(row, engine) -> step id`.

## Value

One-row data frame, or `NULL`.
