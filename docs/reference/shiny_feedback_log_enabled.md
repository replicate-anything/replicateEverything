# Whether server-side Shiny feedback CSV logging is enabled

Returns `FALSE` unless explicitly enabled via
`REPLICATE_SHINY_FEEDBACK_ENABLED=1` or
`options(replicate_shiny.feedback_enabled = TRUE)`.

## Usage

``` r
shiny_feedback_log_enabled()
```

## Value

Logical scalar.
