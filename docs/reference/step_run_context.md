# Paper context to use when running or checking a step

Inherited steps always redirect `base_url` / `materials_repo` to the
parent study — including on cold hosts where the parent is not checked
out locally (Shiny). Only `local_root` is conditional on a local base.

## Usage

``` r
step_run_context(step, meta, ctx)
```
