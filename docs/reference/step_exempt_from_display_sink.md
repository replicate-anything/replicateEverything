# Whether a step is exempt from baked Display-sink requirements

Gap steps (`incomplete` / `data_unavailable` / `requires_engine`) may
omit display sinks; Shiny shows Code + a clean gap message instead.

## Usage

``` r
step_exempt_from_display_sink(entry)
```
