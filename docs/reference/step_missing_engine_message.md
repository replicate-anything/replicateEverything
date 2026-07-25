# User-facing blocked-step message, distinguishing absent vs baked-but-blocked

User-facing blocked-step message, distinguishing absent vs
baked-but-blocked

## Usage

``` r
step_missing_engine_message(meta, what, output_exists = FALSE)
```

## Arguments

- output_exists:

  Whether a declared display artifact is already on disk (or otherwise
  fetchable). When `TRUE`, the step is "not reproducible"; when `FALSE`,
  it is "not available".
