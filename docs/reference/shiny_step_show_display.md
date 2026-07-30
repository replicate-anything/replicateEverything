# Whether Shiny should show a Display control for a step

Correct enablement (do **not** invert):

- Baked sink present (`output_exists`): always show Display, including
  engine/data gaps that still have a precomputed artifact.

- Engine/data gap or generic incomplete *without* a sink: omit Display
  entirely (padlock / wrench open Code). Never treat gap kind as a
  reason to show an active Display affordance.

- Normal runnable step without a detected sink: still show Display (prep
  preview / live path may work; avoids greying available steps).

## Usage

``` r
shiny_step_show_display(
  output_exists = FALSE,
  gap_kind = NULL,
  incomplete = FALSE
)
```

## Arguments

- output_exists:

  Whether a declared display artifact is already available.

- gap_kind:

  From
  [`classify_shiny_run_gap()`](https://replicate-anything.github.io/replicateEverything/reference/classify_shiny_run_gap.md)
  (`"padlock"`, `"hammer"`, or `NULL`).

- incomplete:

  Whether the step is marked incomplete.

## Value

Logical.

## Details

The historical bug was `displayable = output_exists || is_gap`, which
greyd available prep rows without html/png sinks while leaving
Mathematica / data-gap rows clickable.
