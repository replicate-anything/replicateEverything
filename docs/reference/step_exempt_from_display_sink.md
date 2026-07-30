# Whether a step is exempt from baked Display-sink requirements

Gap steps (`incomplete` / `data_unavailable` / `requires_engine`) may
omit display sinks; Shiny shows Code via the padlock / wrench Run slot
and only keeps Display when a baked sink exists.

## Usage

``` r
step_exempt_from_display_sink(entry)
```
