# Wait briefly for a declared Stata output file to appear or refresh

Some Windows / Dropbox-backed outputs (notably workbook files) can land
a fraction of a second after the Stata process exits cleanly. Poll the
declared output path for a short period before treating the run as a
hard failure.

## Usage

``` r
wait_for_stata_output_flush(
  path,
  before_tokens = NULL,
  max_checks = 10L,
  interval = 0.3
)
```
