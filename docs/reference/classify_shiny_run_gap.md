# Classify Shiny Run-slot chrome: padlock (data) vs hammer (engine)

Layered signals (first match wins for padlock):

1.  **Padlock:** yaml `data_unavailable:` (Shiny does not need audit).

2.  **Hammer (bake gap):** registry audit Skipped + missing-engine
    reason when provided; else `requires_engine:` with missing display
    outputs and/or `incomplete: true`.

3.  **Hammer (can't re-run):** outputs exist but live engine probe is
    false (`engine_available = FALSE`).

## Usage

``` r
classify_shiny_run_gap(
  entry,
  output_exists = FALSE,
  audit_skipped_engine = FALSE,
  engine_available = NULL
)
```

## Arguments

- entry:

  Step list (yaml entry or Shiny row fields as a list).

- output_exists:

  Whether a display artifact exists.

- audit_skipped_engine:

  `TRUE` when registry audit marks this step Skipped for a
  missing-engine reason.

- engine_available:

  Live probe for the required system engine; `NULL` means unknown (do
  not treat as missing).

## Value

List with `kind` (`"padlock"`, `"hammer"`, or `NULL`), `mode`,
`message`, `data_token`, `engine`.
