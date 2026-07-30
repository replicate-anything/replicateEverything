# Decide whether to show a long/slow Run indicator (hourglass) beside Run

Show when **all** of:

1.  A Display sink / baked artifact exists

2.  Registry audit marked the step as timed out

3.  The step is otherwise runnable (no padlock / wrench gap; not
    incomplete)

Generic across studies — any step matching these signals qualifies.

## Usage

``` r
shiny_step_long_run_indicator(
  output_exists = FALSE,
  audit_timed_out = FALSE,
  gap_kind = NULL,
  incomplete = FALSE,
  timeout_seconds = NA_real_,
  seconds = NA_real_,
  bake_seconds = NA_real_
)
```

## Arguments

- output_exists:

  Whether a display artifact exists.

- audit_timed_out:

  Whether the matching audit row timed out.

- gap_kind:

  From
  [`classify_shiny_run_gap()`](https://replicate-anything.github.io/replicateEverything/reference/classify_shiny_run_gap.md)
  (`NULL` when runnable).

- incomplete:

  Whether the step is marked incomplete.

- timeout_seconds:

  Optional audit cap seconds for the warning text.

- seconds:

  Optional elapsed seconds from the audit row.

- bake_seconds:

  Optional last successful bake seconds from
  [`lookup_study_replication_timing()`](https://replicate-anything.github.io/replicateEverything/reference/lookup_study_replication_timing.md).

## Value

List with `show`, `title`, `message`, `timeout_seconds`, `seconds`, and
`bake_seconds`.
