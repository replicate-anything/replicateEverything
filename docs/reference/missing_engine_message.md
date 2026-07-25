# Message when an output cannot be shown or re-run due to a missing engine

Two modes (exact phrasing):

- `not_available`:
  `"{output} not available because of missing {Engine} engine"`

- `not_reproducible`:
  `"{output} not reproducible because of missing {Engine} engine"`

## Usage

``` r
missing_engine_message(
  output,
  engine,
  mode = c("not_available", "not_reproducible")
)
```
